module Config where

-- Paths are relative to the repository; archive paths must not start with '/'.
data Crate = Crate
    { manifest :: FilePath
    , binary :: String
    , destination :: FilePath
    , features :: [String]
    } deriving (Show)

-- Add userspace executable crates here, not the kernel's static library.
-- Example (once this crate exists):
--   [ Crate { manifest = "userspace/init/Cargo.toml"
--           , binary = "init"
--           , destination = "sbin/init"
--           , features = []
--           }
--   ]
initramfsCrates :: [Crate]
initramfsCrates = []

-- Integer-only RISC-V userspace: trap entry does not save floating-point state.
cargoTarget :: String
cargoTarget = "riscv64imac-unknown-none-elf"

-- Nothing uses the repository's rustup toolchain. Set Just "stable", or a pinned
-- version, to build userspace with a different toolchain.
cargoToolchain :: Maybe String
cargoToolchain = Nothing

-- For example ["--offline"] or ["--locked"]. Builds use the release profile.
cargoExtraArgs :: [String]
cargoExtraArgs = []

-- U-Boot boot media. These are QEMU-oriented placeholders, not a board port.
-- The ELF must already exist; run the kernel build separately before packaging.
data BootImage = BootImage
    { kernelElf :: FilePath
    , deviceTree :: FilePath
    , kernelLoad :: Integer
    , kernelEntry :: Integer
    , fitLoad :: Integer
    , partitionStartMiB :: Integer
    , partitionMiB :: Integer
    , bootDevice :: String
    , bootDeviceNumber :: Int
    , supervisorBootReady :: Bool
    } deriving (Show)

bootImage :: BootImage
bootImage = BootImage
    { kernelElf = "os.elf"
    , deviceTree = "riscv64-virt.dtb"
    , kernelLoad = 0x80000000
    , kernelEntry = 0x80000000
    , fitLoad = 0x86000000
    , partitionStartMiB = 1
    , partitionMiB = 64
    , bootDevice = "virtio"
    , bootDeviceNumber = 0
    -- Entry supports M and S mode, but DTB/initramfs consumption is unfinished.
    -- Enable only after completing the boot-data handoff and choosing RAM addresses.
    , supervisorBootReady = False
    }

objcopyTool :: String
objcopyTool = "llvm-objcopy"
