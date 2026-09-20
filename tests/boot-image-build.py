#!/usr/bin/env python3
"""Test media packaging with a tiny RV64 ELF, without claiming a kernel boot."""
from pathlib import Path
import hashlib
import shutil
import struct
import subprocess
import tempfile
import zlib

REPO = Path(__file__).resolve().parents[1]


def run(args, cwd, success=True):
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=120)
    if (result.returncode == 0) != success:
        raise AssertionError(result.stdout + result.stderr)
    return result.stdout + result.stderr


def main():
    with tempfile.TemporaryDirectory(prefix="ukernel-image-test-") as tmp:
        root = Path(tmp)
        for name in ["Shakefile.hs", "UBoot.hs", "Config.hs", "riscv64-virt.dtb"]:
            shutil.copy(REPO / name, root / name)
        config = (root / "Config.hs").read_text().replace("partitionMiB = 64", "partitionMiB = 16")
        (root / "Config.hs").write_text(config)
        (root / "kernel.S").write_text('.section .text\n.global _start\n_start:\n j _start\n')
        run(["clang", "--target=riscv64-unknown-none-elf", "-march=rv64imac", "-mabi=lp64",
             "-nostdlib", "-fuse-ld=lld", "-Wl,-Ttext=0x80000000", "-Wl,--entry=_start",
             "kernel.S", "-o", "os.elf"], root)
        run(["runghc", "Shakefile.hs", "image"], root)
        fit = root / "build/uboot/boot.itb"
        listing = run(["dumpimage", "-l", str(fit)], root)
        assert "kernel" in listing and "ramdisk" in listing and "fdt" in listing
        assert run(["fdtget", "-t", "x", str(fit), "/images/kernel", "load"], root).strip() == "0 80000000"
        for index, source in enumerate(["build/uboot/kernel.bin", "build/initramfs.cpio", "riscv64-virt.dtb"]):
            extracted = root / f"payload-{index}"
            run(["dumpimage", "-T", "flat_dt", "-p", str(index), "-o", str(extracted), str(fit)], root)
            assert extracted.read_bytes() == (root / source).read_bytes()
            node = ["kernel", "ramdisk", "fdt"][index]
            digest = run(["fdtget", "-t", "bx", str(fit), f"/images/{node}/hash", "value"], root)
            assert bytes(int(x, 16) for x in digest.split()) == hashlib.sha256(extracted.read_bytes()).digest()

        script = (root / "build/uboot/boot.scr").read_bytes()
        header = list(struct.unpack(">7I4B32s", script[:64]))
        assert header[0] == 0x27051956 and header[9] == 6 # Legacy image, script type.
        crc_header = bytearray(script[:64])
        crc_header[4:8] = b"\0" * 4
        assert zlib.crc32(crc_header) == header[1]
        assert zlib.crc32(script[64:]) == header[6]
        assert script[72:] == (root / "build/uboot/boot.cmd").read_bytes()
        assert b"exit 1\n# Reuse" in script # Boot-data handoff is not enabled.

        image = root / "build/ukernel.img"
        with image.open("rb") as disk:
            mbr = disk.read(512)
            assert mbr[510:] == b"\x55\xaa"
            assert mbr[446] == 0x80 and mbr[450] == 0x83
            start, sectors = struct.unpack_from("<II", mbr, 454)
            assert start == 2048 and sectors == 16 * 1024 * 1024 // 512
            assert image.stat().st_size == (start + sectors) * 512
            disk.seek(start * 512)
            partition = root / "partition.ext2"
            partition.write_bytes(disk.read(sectors * 512))
        run(["e2fsck", "-fn", str(partition)], root)
        for name in ["boot.itb", "boot.scr", "boot.cmd"]:
            extracted = root / ("disk-" + name)
            run(["debugfs", "-R", f"dump /boot/{name} {extracted}", str(partition)], root)
            assert extracted.read_bytes() == (root / "build/uboot" / name).read_bytes()

        before = image.stat().st_mtime_ns
        run(["runghc", "Shakefile.hs", "image"], root)
        assert image.stat().st_mtime_ns == before
        (root / "Config.hs").write_text(config.replace("supervisorBootReady = False", "supervisorBootReady = True"))
        run(["runghc", "Shakefile.hs", "uboot"], root)
        enabled = (root / "build/uboot/boot.cmd").read_text()
        assert "boot handoff is not enabled" not in enabled
        assert "bootm 0x86000000#conf" in enabled
        (root / "Config.hs").write_text(config.replace("fitLoad = 0x86000000", "fitLoad = 0x80000000"))
        failure = run(["runghc", "Shakefile.hs", "uboot"], root, success=False)
        assert "FIT staging overlaps" in failure
    print("PASS: RV64 ELF -> hashed FIT, script CRCs, MBR/ext2 image contents, incremental build, boot readiness, overlap rejection")


if __name__ == "__main__":
    main()
