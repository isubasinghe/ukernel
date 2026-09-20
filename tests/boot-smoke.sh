#!/usr/bin/env sh
# Override CC and QEMU with paths to a RISC-V GCC and qemu-system-riscv64.
set -eu
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
"${CC:-riscv64-unknown-linux-gnu-gcc}" -march=rv64gc -mabi=lp64 \
    -nostdlib -static -no-pie -Wl,--build-id=none -T src/lds/virt.ld \
    src/asm/boot.S src/asm/strap.S src/asm/interrupts.S tests/boot-smoke.S -o "$work/boot.elf"
# Also link every production assembly file against the minimal Rust symbol stubs.
"${CC:-riscv64-unknown-linux-gnu-gcc}" -march=rv64gc -mabi=lp64 \
    -nostdlib -static -no-pie -Wl,--build-id=none -T src/lds/virt.ld \
    -DPRODUCTION_LINK_ONLY src/asm/*.S tests/boot-smoke.S -o "$work/production.elf"
timeout 10s "${QEMU:-qemu-system-riscv64}" -machine virt -smp 4 -m 128M \
    -nographic -monitor none -serial none -bios none -kernel "$work/boot.elf"
printf '%s\n' 'PASS: S-mode entry, aligned stacks, trap ABI, register restoration, SSIP acknowledgment'
