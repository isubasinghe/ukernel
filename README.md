# ukernel 

A simple kernel developed for fun on RISC-V. 

This was initially developed for x86_64 but since the aim here is to have fun, 
it was rewritten for RISC-V.

## TODO
  * Interrupts 
  * Timers 
  * Fastpath opt for local IPC
  * Memory manager 

## Ambitious TODO 
  * Multicore support 
  * UMP


## Building the initramfs

`Config.hs` selects the userspace executable crates to include. For example,
after creating an `init` binary crate:

```haskell
initramfsCrates =
    [ Crate { manifest = "userspace/init/Cargo.toml"
            , binary = "init"
            , destination = "sbin/init"
            , features = []
            }
    ]
```

Run from the repository root:

```sh
runghc Shakefile.hs initramfs
# or: make initramfs
```

This requires GHC with the `shake` package (plus `directory`, `filepath`,
`process`, `time`, and `unix`), GNU cpio, and Cargo/Rust. If Shake is not already
available to GHC, a Nix shell can provide it:

```sh
nix-shell -p 'haskellPackages.ghcWithPackages (p: [ p.shake ])' cpio
```

The output is `build/initramfs.cpio`, an uncompressed **newc CPIO** archive.
Executables are installed with mode 0755, uid/gid 0, and timestamps fixed to the
Unix epoch. A fresh staging directory prevents removed entries from lingering;
identical archive contents preserve the output file's modification time.

The list starts empty because this repository has no standalone userspace
executable crates yet. An empty list builds a valid empty archive. The kernel
library and the `src/userspace` module are not executable crates.

`cargoTarget` defaults to `riscv64imac-unknown-none-elf`, avoiding floating-point
state that trap entry does not currently preserve. Install that target for the
selected toolchain with `rustup target add riscv64imac-unknown-none-elf`. These
must be freestanding `no_std` executables with their own entry point/linker setup;
ordinary Linux binaries will not run on this kernel.

`cargoToolchain = Nothing` uses rustup's active toolchain at the repository root;
use `Just "stable"` or a pinned version to override it. `cargoExtraArgs` accepts
options such as `--offline` or `--locked`. Cargo is run outside the repository so
it does not inherit the kernel's custom target and `build-std` settings. Crate-local
`.cargo/config.toml` files are likewise not loaded automatically: put required
Cargo command options in `cargoExtraArgs`, and linker setup in the crate's build
script. Do not override the target, target directory, release profile, or binary
selection through `cargoExtraArgs`.

Shake consults Cargo on every build, allowing Cargo to track source changes,
features, build scripts, and path dependencies. Cargo's incremental artifacts
live in `build/cargo-userspace/`.

This packages executables only. Loading the archive and launching its first
process are separate kernel bootstrap work; no program is launched by this build.

Test the builder with real host Cargo crates and an independent CPIO reader:

```sh
python3 tests/initramfs-build.py
```

## U-Boot bundle and disk image

`bootImage` in `Config.hs` describes the kernel ELF, board device tree, RAM load
and entry addresses, boot device, and partition layout. The defaults describe a
QEMU-oriented **packaging template**, not a completed physical-board port.

```sh
make boot-config   # Generate readable boot.its and boot.cmd; no kernel needed.
make uboot         # Package an existing os.elf, initramfs, and DTB.
make image         # Also produce build/ukernel.img.
```

The default kernel input is `os.elf`, produced by `make all`. Packaging does not
invoke the kernel build or silently substitute a test kernel. The existing Rust
target/toolchain incompatibility must be resolved before building that kernel.
Alternatively, select an already-built compatible kernel ELF in `Config.hs`.
The ELF's linked addresses must match `kernelLoad` and `kernelEntry`.

Additional tools: `llvm-objcopy` (or configure `objcopyTool`), U-Boot `mkimage`,
`dtc`, GNU `dd`, util-linux `sfdisk`, and e2fsprogs `mkfs.ext2`. The Haskell build
also uses `bytestring`. On Nix these tools can be provided with:

```sh
nix-shell -p 'haskellPackages.ghcWithPackages (p: [ p.shake ])' \
  cpio dtc ubootTools llvmPackages.bintools util-linux e2fsprogs coreutils
```

Generated artifacts:

```text
build/uboot/
    kernel.bin     Raw loadable bytes converted from the configured ELF
    board.dtb      Configured hardware description
    boot.its       FIT source: kernel + ramdisk + DTB, each with SHA-256
    boot.itb       FIT bundle produced by mkimage
    boot.cmd       Readable U-Boot script
    boot.scr       Script wrapped for U-Boot's source command
build/ukernel.img
    MBR partition table
    reserved prefix (1 MiB by default, with NO firmware installed)
    partition 1: ext2, 64 MiB by default, label UKERNEL
        /boot/boot.itb
        /boot/boot.scr
        /boot/boot.cmd
```

The `.img` is a raw disk image, suitable as the basis for SD/USB media. It is not
an optical `.iso`, an EFI image, or a board BootROM image. The build only writes
regular files; it does not flash devices, mount filesystems, or require root.
The filesystem is populated by `mkfs.ext2 -d`. FIT/script timestamps are fixed;
ext2 filesystem metadata is not promised to be byte-reproducible across fresh
builds. An unchanged incremental build preserves the existing image.

An **already running U-Boot** with ext2 filesystem access, FIT/bootm support,
SHA-256 support, and script support can read this partition. Its script scanner
may find `/boot/boot.scr`; otherwise load and source it explicitly, for example:

```text
load virtio 0:1 ${scriptaddr} /boot/boot.scr
source ${scriptaddr}
```

Here `scriptaddr` must be a suitable RAM address provided by your board's U-Boot
environment. The script reuses `devtype`, `devnum`, and `distro_bootpart` when
provided by U-Boot, with the configured device and partition 1 as fallbacks.
It loads `/boot/boot.itb` at `fitLoad` and runs `bootm ...#conf`.

### Boot handoff still to implement

The FIT's `os = "linux"` selects U-Boot's Linux-style **boot protocol**; it does
not mean the payload is Linux. Our intended handoff is from S-mode U-Boot/OpenSBI:
`a0` contains the hart ID, `a1` the device-tree address, and `/chosen` in that tree
identifies the loaded initramfs through `linux,initrd-start` and
`linux,initrd-end`. The kernel must preserve/read this information, reserve the
archive's memory, parse CPIO, and load its first userspace executable.

The kernel now accepts M-mode or S-mode entry, but does not yet consume the
DTB/initramfs boot data. Consequently `supervisorBootReady = False` makes
`boot.scr` stop with a clear message. Set it to `True` only after completing the
boot-data handoff and selecting compatible kernel load/entry addresses. Directly invoking `bootm` bypasses that script check; the flag does not
make an incompatible kernel bootable.

For a physical board you must also supply the correct DTB, RAM addresses, device
selection, and board-specific firmware (BootROM/SPL/OpenSBI/U-Boot installation).
No such firmware is embedded in this `.img`. Packaging does not yet establish
that the current kernel boots through U-Boot.

References: [U-Boot FIT format](https://docs.u-boot.org/en/latest/usage/fit/source_file_format.html),
[RISC-V handoff](https://docs.u-boot.org/en/latest/arch/riscv.html).

Validate packaging with a tiny RV64 test ELF, FIT extraction/hash checks, script
checksums, and an independent inspection of the MBR and ext2 contents:

```sh
python3 tests/boot-image-build.py
```

This test additionally needs Clang/LLD, `dumpimage`, `fdtget`, `debugfs`, and
`e2fsck`. It verifies the package format, not execution of the kernel in U-Boot.

## M-mode and S-mode startup

`_start` detects the entry privilege with a guarded read of `mstatus`. In M-mode,
the read succeeds and the original machine initialization runs. In S-mode, the
illegal-instruction exception is handled by a temporary supervisor vector and
startup skips all machine CSR, PMP, and delegation setup. This requires firmware
to delegate or reflect that illegal instruction to S-mode (tested with OpenSBI).
Firmware that does not support that probe can enter `_start_s` explicitly instead.
Neither entry supports starting in U-mode or with address translation enabled.

Both paths set up BSS, kernel and supervisor trap stacks, and `stvec`, then enter
Rust as `kmain(hart_id, dtb_address, entry_mode)`. `entry_mode` is 3 for M-mode entry
and 1 for S-mode entry. Global supervisor interrupts and floating point remain off.
On S-mode entry, the boot hart supplied in `a0` is accepted; firmware must hand off
only one hart until SMP startup is implemented. Bare M-mode entry parks every
hart except hart 0 as before.

For OpenSBI, the kernel must be linked outside firmware's RAM region. The linker
script accepts `--defsym=KERNEL_BASE=0x80200000` (place this before `-T` in the linker
arguments). The default remains `0x80000000` for direct QEMU `-bios none` boots.
Update the FIT's `kernelLoad` and `kernelEntry` to match when using a relocated
kernel. Mode detection alone does not relocate a kernel linked over firmware.

`tests/supervisor-smoke.sh` tests M-mode entry, automatic S-mode detection through
OpenSBI, and explicit `_start_s` entry. Each path exercises register preservation,
software interrupts, illegal instructions, and user ecalls. S-mode tests also
verify a firmware SBI call and the preserved DTB pointer.
