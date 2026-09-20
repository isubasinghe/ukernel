#!/usr/bin/env sh
# Uses a built-in RV64 Rust target to test the handler independently of the old
# kernel target JSON/dependencies. No floating-point code is used by this test.
set -eu
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
for entry in machine supervisor supervisor-direct; do
    bios=none
    cpus=4
    entry_flags=-DEXPECT_ENTRY_MODE=3
    if [ "$entry" != machine ]; then
        bios=default
        cpus=1
        entry_flags='-DEXPECT_ENTRY_MODE=1 -Wl,--defsym=KERNEL_BASE=0x80200000'
    fi
    if [ "$entry" = supervisor-direct ]; then
        entry_flags="$entry_flags -DKNOWN_SUPERVISOR_ENTRY -Wl,-e,_start_s"
    fi
for mode in supervisor user; do
    rust_cfg=
    asm_cfg=
    if [ "$mode" = user ]; then
        rust_cfg='--cfg user_ecall_test'
        asm_cfg=-DUSER_ECALL_TEST
    fi
    "${RUSTC:-rustc}" --edition=2021 --target riscv64gc-unknown-none-elf \
        --crate-type staticlib -C panic=abort -C opt-level=2 $rust_cfg \
        tests/supervisor-smoke.rs -o "$work/handler.a"
    "${CC:-riscv64-unknown-linux-gnu-gcc}" -march=rv64gc -mabi=lp64d \
        -nostdlib -static -no-pie -Wl,--build-id=none,--gc-sections \
        $entry_flags -T src/lds/virt.ld $asm_cfg tests/supervisor-entry.S src/asm/*.S tests/supervisor-smoke.S \
        "$work/handler.a" -o "$work/supervisor.elf"
    output=$(timeout 10s "${QEMU:-qemu-system-riscv64}" -machine virt -smp "$cpus" -m 128M \
        -nographic -monitor none -serial stdio -bios "$bios" -kernel "$work/supervisor.elf") || { result=$?; printf '%s\n' "$output"; exit "$result"; }
    printf '%s\n' "$output"
    # Verify that Rust chose the specific handler, not the unknown-trap fallback.
    expected="Unhandled supervisor trap (illegal instruction)"
    if [ "$mode" = user ]; then
        expected="Unhandled supervisor trap (user ecall)"
    fi
    case "$output" in
        *"$expected"*) ;;
        *) printf '%s\n' "FAIL: expected $expected" >&2; exit 1 ;;
    esac
    printf '%s\n' "PASS: Rust SSIP return/register preservation and $mode exception delegation ($entry entry)"
done
done
