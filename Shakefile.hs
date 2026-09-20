import Config
import UBoot (bootRules, publish)
import Control.Monad (forM_, unless, when)
import Data.List (group, intercalate, nub, sort, sortOn)
import Development.Shake
import Development.Shake.FilePath
import qualified System.Directory as Dir
import System.Process (readProcess)
import System.Posix.Files (setFileMode)
import Data.Time.Clock.POSIX (posixSecondsToUTCTime)

archive :: FilePath
archive = "build/initramfs.cpio"

main :: IO ()
main = do
    validateConfig
    -- Resolve rustup's toolchain before moving Cargo outside the kernel tree.
    toolchain <- case cargoToolchain of
        Just name -> pure (Just name)
        Nothing | null initramfsCrates -> pure Nothing
        Nothing -> do
            active <- readProcess "rustup" ["show", "active-toolchain"] ""
            case words active of
                name : _ -> pure (Just name)
                [] -> fail "rustup did not report an active toolchain"
    shakeArgs shakeOptions { shakeFiles = "build/.shake" } $ do
        want [archive]
        bootRules archive
        phony "initramfs" $ need [archive]
        archive %> \out -> do
            need ["Config.hs", "Shakefile.hs"]
            -- Let Cargo track Rust inputs, build scripts, and path dependencies.
            -- Always consult it; unchanged executables do not get rebuilt.
            alwaysRerun
            when (null initramfsCrates) $
                putInfo "No userspace crates configured; creating an empty initramfs."
            withTempDir $ \work -> do
                root <- liftIO $ Dir.makeAbsolute work
                let stage = root </> "root"
                liftIO $ Dir.createDirectory stage
                forM_ (sortOn destination initramfsCrates) $ \crate -> do
                    need [manifest crate]
                    manifestPath <- liftIO $ Dir.makeAbsolute (manifest crate)
                    targetDir <- liftIO $ Dir.makeAbsolute ("build/cargo-userspace" </> destination crate)
                    let args = maybe [] (\t -> ["+" ++ t]) toolchain ++
                            [ "build", "--release", "--manifest-path", manifestPath
                            , "--bin", binary crate, "--target", cargoTarget
                            , "--target-dir", targetDir
                            ] ++ featureArgs crate ++ cargoExtraArgs
                    -- A separate cwd avoids inheriting the kernel's .cargo/config
                    -- (custom target and build-std). Use Config.hs for build options.
                    cmd_ (Cwd root) "cargo" args
                    let executable = targetDir </> cargoTarget </> "release" </> binary crate
                        installed = stage </> destination crate
                    liftIO $ Dir.createDirectoryIfMissing True (takeDirectory installed)
                    copyFile' executable installed
                    liftIO $ setFileMode installed 0o755

                -- Fresh staging removes deleted config entries from the archive.
                let files = sort $ map destination initramfsCrates
                    dirs = sort . nub $ "." : concatMap parentDirs files
                forM_ dirs $ \dir -> liftIO $ do
                    Dir.createDirectoryIfMissing True (stage </> dir)
                    setFileMode (stage </> dir) 0o755
                -- Reset directories last: creating children changes their mtime.
                forM_ (files ++ dirs) $ \path -> liftIO $
                    Dir.setModificationTime (stage </> path) (posixSecondsToUTCTime 0)
                let names = intercalate "\0" (dirs ++ files) ++ "\0"
                    packed = root </> "initramfs.cpio"
                cmd_ (Cwd stage) (Stdin names) "cpio"
                    [ "--create", "--format=newc", "--null", "--quiet"
                    , "--reproducible", "--owner=0:0", "--file", packed
                    ]
                -- Publish only after cpio succeeds; keep mtime if bytes are equal.
                liftIO $ Dir.createDirectoryIfMissing True (takeDirectory out)
                publish packed out

featureArgs :: Crate -> [String]
featureArgs crate = case features crate of
    [] -> []
    names -> ["--features", intercalate "," names]

parentDirs :: FilePath -> [FilePath]
parentDirs path = case takeDirectory path of
    "." -> []
    parent | parent == path -> []
           | otherwise -> parent : parentDirs parent

validateConfig :: IO ()
validateConfig = do
    let paths = map destination initramfsCrates
        duplicates = [first | first : _ : _ <- group (sort paths)]
    unless (null duplicates) $ fail $ "Duplicate initramfs destinations: " ++ show duplicates
    forM_ initramfsCrates $ \crate -> do
        let path = destination crate
            components = splitDirectories path
        when (path == "TRAILER!!!" || "TRAILER!!!" `elem` parentDirs path ||
              null path || isAbsolute path || hasTrailingPathSeparator path ||
              any (`elem` [".", ".."]) components || normalise path /= path ||
              any (`elem` ['\0', '\n', '\r']) path) $
            fail $ "Invalid initramfs destination: " ++ show path
        when (any (`elem` paths) (parentDirs path)) $
            fail $ "Initramfs file/directory collision: " ++ show path
        when (null (binary crate) || takeFileName (binary crate) /= binary crate ||
              binary crate `elem` [".", ".."]) $
            fail $ "Invalid Cargo binary name: " ++ show (binary crate)
    when (null cargoTarget || takeFileName cargoTarget /= cargoTarget) $
        fail "cargoTarget must be a Rust target triple, not a target JSON path"
