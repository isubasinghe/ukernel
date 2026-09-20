#!/usr/bin/env python3
"""Exercise Shake/Cargo packaging in a temporary tree, without a kernel build."""
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]


def run(args, cwd, success=True):
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True, timeout=120)
    if (result.returncode == 0) != success:
        raise AssertionError(result.stdout + result.stderr)
    return result.stdout + result.stderr


def read_cpio(path):
    data = path.read_bytes()
    entries = {}
    offset = 0
    while True:
        assert data[offset:offset + 6] == b"070701"
        fields = [int(data[offset + 6 + n * 8:offset + 14 + n * 8], 16) for n in range(13)]
        _, mode, uid, gid, _, mtime, size, _, _, _, _, namesize, _ = fields
        offset += 110
        assert data[offset + namesize - 1] == 0
        name = data[offset:offset + namesize - 1].decode()
        offset = (offset + namesize + 3) & ~3
        payload = data[offset:offset + size]
        offset = (offset + size + 3) & ~3
        if name == "TRAILER!!!":
            return entries
        assert name not in entries
        assert (uid, gid, mtime) == (0, 0, 0)
        entries[name] = (mode, payload)


def main():
    host_info = run(["rustc", "+stable", "-vV"], REPO)
    host = next(line.removeprefix("host: ") for line in host_info.splitlines() if line.startswith("host: "))
    with tempfile.TemporaryDirectory(prefix="ukernel-initramfs-test-") as tmp:
        root = Path(tmp)
        shutil.copy(REPO / "Shakefile.hs", root)
        shutil.copy(REPO / "UBoot.hs", root)
        original = (REPO / "Config.hs").read_text()
        archive = root / "build/initramfs.cpio"

        def configure(paths):
            config = original.replace('"riscv64imac-unknown-none-elf"', f'"{host}"')
            config = config.replace("cargoToolchain = Nothing", 'cargoToolchain = Just "stable"')
            config = config.replace("cargoExtraArgs = []", 'cargoExtraArgs = ["--offline"]')
            crates = ', '.join(f'Crate "fixture/Cargo.toml" "{binary}" "{dest}" []' for binary, dest in paths)
            config = config.replace("initramfsCrates = []", f"initramfsCrates = [{crates}]")
            (root / "Config.hs").write_text(config)

        def build(success=True):
            return run(["runghc", "Shakefile.hs", "initramfs"], root, success)

        configure([])
        build()
        assert set(read_cpio(archive)) == {"."}

        # Deliberately poison the parent Cargo config: userspace must not inherit it.
        (root / ".cargo").mkdir()
        (root / ".cargo/config.toml").write_text('[build]\nrustc = "/does-not-exist"\n')
        (root / "fixture/src/bin").mkdir(parents=True)
        (root / "fixture/Cargo.toml").write_text(
            '[package]\nname = "fixture"\nversion = "0.1.0"\nedition = "2021"\n'
        )
        for name in ["init", "memory"]:
            (root / f"fixture/src/bin/{name}.rs").write_text(f'fn main() {{ println!("{name}"); }}\n')
        configure([("init", "sbin/init"), ("memory", "servers/memory")])
        build()
        entries = read_cpio(archive)
        assert set(entries) == {".", "sbin", "servers", "sbin/init", "servers/memory"}
        for name in ["sbin/init", "servers/memory"]:
            mode, contents = entries[name]
            assert stat.S_ISREG(mode) and stat.S_IMODE(mode) == 0o755
            assert contents.startswith(b"\x7fELF")
        before = archive.read_bytes(), archive.stat().st_mtime_ns
        build()
        assert before == (archive.read_bytes(), archive.stat().st_mtime_ns)

        (root / "fixture/src/bin/init.rs").write_text('fn main() { println!("updated init"); }\n')
        build()
        assert read_cpio(archive)["sbin/init"][1] != entries["sbin/init"][1]

        configure([("init", "sbin/init")])
        build()
        assert set(read_cpio(archive)) == {".", "sbin", "sbin/init"}
        last_good = archive.read_bytes()
        for invalid in [
            [("init", "../outside")], [("init", "/init")],
            [("init", "TRAILER!!!")], [("init", "sbin/init"), ("memory", "sbin/init")],
            [("init", "sbin"), ("memory", "sbin/memory")],
        ]:
            configure(invalid)
            build(success=False)
            assert archive.read_bytes() == last_good
        configure([("missing_binary", "sbin/missing")])
        build(success=False)
        assert archive.read_bytes() == last_good
    print("PASS: real Cargo binaries, archive metadata, reproducibility, source/config changes, validation, failure preservation")


if __name__ == "__main__":
    main()
