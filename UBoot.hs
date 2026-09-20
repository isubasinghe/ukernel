module UBoot (bootRules, publish) where

import Config
import Control.Monad (forM_, unless, when)
import Data.Char (isAlphaNum)
import qualified Data.ByteString as BS
import Development.Shake
import Development.Shake.FilePath
import Numeric (showHex)
import qualified System.Directory as Dir
import System.IO (IOMode (ReadMode, WriteMode), hSetFileSize, withBinaryFile)

bootDir :: FilePath
bootDir = "build/uboot"

-- Keep generated descriptions readable beside their binary counterparts.
bootRules :: FilePath -> Rules ()
bootRules initramfs = do
    phony "uboot" $ need [bootDir </> "boot.itb", bootDir </> "boot.scr"]
    phony "image" $ need ["build/ukernel.img"]
    phony "boot-config" $ need [bootDir </> "boot.its", bootDir </> "boot.cmd"]

    bootDir </> "kernel.bin" %> \out -> do
        configDependencies
        need [kernelElf bootImage]
        withTempDir $ \tmp -> do
            let binary = tmp </> "kernel.bin"
            cmd_ objcopyTool ["-O", "binary", kernelElf bootImage, binary]
            liftIO $ Dir.createDirectoryIfMissing True bootDir
            publish binary out

    bootDir </> "board.dtb" %> \out -> do
        configDependencies
        need [deviceTree bootImage]
        liftIO $ Dir.createDirectoryIfMissing True bootDir
        copyFileChanged (deviceTree bootImage) out

    bootDir </> "boot.its" %> \out -> do
        configDependencies
        writeFileChanged out fitDescription

    bootDir </> "boot.cmd" %> \out -> do
        configDependencies
        writeFileChanged out bootScript

    bootDir </> "boot.itb" %> \out -> do
        configDependencies
        need [bootDir </> "boot.its", bootDir </> "kernel.bin",
              bootDir </> "board.dtb", initramfs]
        -- Raw kernel placement and FIT staging must not overlap.
        kernelSize <- liftIO $ Dir.getFileSize (bootDir </> "kernel.bin")
        unless (kernelEntry bootImage >= kernelLoad bootImage &&
                kernelEntry bootImage < kernelLoad bootImage + kernelSize) $
            fail "kernelEntry must lie within the loaded kernel image"
        withTempDir $ \tmp -> do
            packed <- liftIO $ Dir.makeAbsolute (tmp </> "boot.itb")
            cmd_ (Cwd bootDir) (AddEnv "SOURCE_DATE_EPOCH" "0")
                "mkimage" ["-f", "boot.its", packed]
            fitSize <- liftIO $ Dir.getFileSize packed
            when (overlap (kernelLoad bootImage, kernelSize) (fitLoad bootImage, fitSize)) $
                fail "FIT staging overlaps the kernel load range; change fitLoad"
            publish packed out

    bootDir </> "boot.scr" %> \out -> do
        configDependencies
        need [bootDir </> "boot.cmd"]
        withTempDir $ \tmp -> do
            let packed = tmp </> "boot.scr"
            cmd_ (AddEnv "SOURCE_DATE_EPOCH" "0") "mkimage"
                [ "-A", "riscv", "-O", "linux", "-T", "script", "-C", "none"
                , "-n", "ukernel boot", "-d", bootDir </> "boot.cmd", packed
                ]
            publish packed out

    "build/ukernel.img" %> \out -> do
        configDependencies
        need [bootDir </> "boot.itb", bootDir </> "boot.scr", bootDir </> "boot.cmd"]
        withTempDir $ \tmp -> do
            let root = tmp </> "root"
                partition = tmp </> "boot.ext2"
                disk = tmp </> "ukernel.img"
                bytes = partitionMiB bootImage * 1024 * 1024
                startSector = partitionStartMiB bootImage * 2048
            liftIO $ Dir.createDirectoryIfMissing True (root </> "boot")
            forM_ ["boot.itb", "boot.scr", "boot.cmd"] $ \name ->
                copyFile' (bootDir </> name) (root </> "boot" </> name)
            liftIO $ do
                withBinaryFile partition WriteMode $ \h -> hSetFileSize h bytes
                withBinaryFile disk WriteMode $ \h -> hSetFileSize h (bytes + startSector * 512)
            -- Populate a regular-file filesystem directly: no mounts or root needed.
            cmd_ "mkfs.ext2"
                [ "-q", "-F", "-b", "4096", "-L", "UKERNEL"
                , "-U", "554b524e-0000-4000-8000-000000000001"
                , "-E", "lazy_itable_init=0", "-d", root, partition
                ]
            let table = unlines
                    [ "label: dos", "label-id: 0x554b524e", "unit: sectors", ""
                    , "start=" ++ show startSector ++ ", size=" ++ show (bytes `div` 512) ++ ", type=83, bootable"
                    ]
            cmd_ (Stdin table) "sfdisk" ["--no-reread", "--no-tell-kernel", disk]
            cmd_ "dd" ["if=" ++ partition, "of=" ++ disk, "bs=512", "seek=" ++ show startSector,
                       "conv=notrunc", "status=none"]
            publish disk out

configDependencies :: Action ()
configDependencies = do
    need ["Config.hs", "Shakefile.hs", "UBoot.hs"]
    unless (partitionStartMiB bootImage >= 1 && partitionStartMiB bootImage <= 1024) $
        fail "partitionStartMiB must be between 1 and 1024"
    unless (partitionMiB bootImage >= 16 && partitionMiB bootImage <= 2048) $
        fail "partitionMiB must be between 16 and 2048"
    unless (not (null (bootDevice bootImage)) &&
            all (\c -> isAlphaNum c || c == '_') (bootDevice bootImage) &&
            bootDeviceNumber bootImage >= 0) $
        fail "Invalid U-Boot device selection"
    forM_ [kernelLoad bootImage, kernelEntry bootImage, fitLoad bootImage] $ \address ->
        unless (address >= 0 && address < 2 ^ (64 :: Int) && address `mod` 4 == 0) $
            fail "Boot addresses must be aligned unsigned 64-bit values"

hex :: Integer -> String
hex n = "0x" ++ showHex n ""

-- FIT address properties use two 32-bit cells on RV64.
cells :: Integer -> String
cells n = "<" ++ hex (n `div` 2 ^ (32 :: Int)) ++ " " ++
    hex (n `mod` 2 ^ (32 :: Int)) ++ ">"

overlap :: (Integer, Integer) -> (Integer, Integer) -> Bool
overlap (a, aSize) (b, bSize) = a < b + bSize && b < a + aSize

fitDescription :: String
fitDescription = unlines
    [ "/dts-v1/;"
    , "/ {"
    , "    description = \"ukernel: RISC-V supervisor boot payload\";"
    , "    #address-cells = <2>;"
    , "    images {"
    , "        kernel {"
    , "            description = \"ukernel raw kernel\";"
    , "            data = /incbin/(\"kernel.bin\");"
    , "            type = \"kernel\"; arch = \"riscv\"; os = \"linux\";"
    , "            compression = \"none\";"
    , "            load = " ++ cells (kernelLoad bootImage) ++ ";"
    , "            entry = " ++ cells (kernelEntry bootImage) ++ ";"
    , "            hash { algo = \"sha256\"; };"
    , "        };"
    , "        ramdisk {"
    , "            description = \"userspace initramfs\";"
    , "            data = /incbin/(\"../initramfs.cpio\");"
    , "            type = \"ramdisk\"; arch = \"riscv\"; os = \"linux\";"
    , "            compression = \"none\";"
    , "            hash { algo = \"sha256\"; };"
    , "        };"
    , "        fdt {"
    , "            description = \"board device tree\";"
    , "            data = /incbin/(\"board.dtb\");"
    , "            type = \"flat_dt\"; arch = \"riscv\"; compression = \"none\";"
    , "            hash { algo = \"sha256\"; };"
    , "        };"
    , "    };"
    , "    configurations {"
    , "        default = \"conf\";"
    , "        conf { kernel = \"kernel\"; ramdisk = \"ramdisk\"; fdt = \"fdt\"; };"
    , "    };"
    , "};"
    ]

bootScript :: String
bootScript = unlines $
    [ "# Generated from Config.hs. Requires an existing U-Boot installation."
    , "# bootm uses the RISC-V Linux-style S-mode ABI; the kernel need not be Linux."
    ] ++ readiness ++
    [ "# Reuse the device selected by U-Boot's script scanner, or use config defaults."
    , "if test -z \"${devtype}\"; then setenv devtype " ++ bootDevice bootImage ++ "; fi"
    , "if test -z \"${devnum}\"; then setenv devnum " ++ show (bootDeviceNumber bootImage) ++ "; fi"
    , "if test -z \"${distro_bootpart}\"; then setenv distro_bootpart 1; fi"
    , "if load ${devtype} ${devnum}:${distro_bootpart} " ++ hex (fitLoad bootImage) ++ " /boot/boot.itb; then"
    , "    bootm " ++ hex (fitLoad bootImage) ++ "#conf"
    , "else"
    , "    echo Failed to load /boot/boot.itb"
    , "    exit 1"
    , "fi"
    ]
  where
    readiness
        | supervisorBootReady bootImage = []
        | otherwise =
            [ "echo ukernel boot handoff is not enabled: DTB/initramfs setup is unfinished."
            , "echo Complete the boot-data handoff, then set supervisorBootReady in Config.hs."
            , "exit 1"
            ]

-- Temporary files must not become Shake dependencies: they vanish after the rule.
-- Compare in bounded chunks, retaining output mtime when contents are unchanged.
publish :: FilePath -> FilePath -> Action ()
publish source output = liftIO $ do
    exists <- Dir.doesFileExist output
    same <- if not exists then pure False else
        withBinaryFile source ReadMode $ \a -> withBinaryFile output ReadMode $ \b ->
            let compareChunks = do
                    x <- BS.hGet a 65536
                    y <- BS.hGet b 65536
                    if x /= y then pure False
                    else if BS.null x then pure True else compareChunks
            in compareChunks
    unless same $ Dir.copyFile source output
