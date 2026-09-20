.option norvc
.section .text, "ax", @progbits
.global kmain
kmain:
    # Both entry paths preserve the firmware boot arguments and identify the mode.
    li t0, EXPECT_ENTRY_MODE
    bne a2, t0, test_fail
    bnez a0, test_fail # These tests boot on hart 0.
    beqz a1, test_fail
    lwu t0, 0(a1)
    li t1, 0xedfe0dd0 # Device-tree magic, read on a little-endian CPU.
    bne t0, t1, test_fail
#if EXPECT_ENTRY_MODE == 1
    # Firmware still owns M-mode traps: an SBI base call must work after entry.
    li a7, 0x10
    li a6, 0
    ecall
    bnez a0, test_fail
#endif
    la t0, boot_zero_probe
    ld t0, 0(t0)
    bnez t0, test_fail

    # Boot must route SSIP to S-mode without enabling global delivery yet.
    csrr t0, sstatus
    andi t0, t0, 2
    bnez t0, test_fail
    csrr t0, sie
    andi t0, t0, 2
    beqz t0, test_fail
    csrsi sstatus, 2

    li ra, 0x30
    li t0, 0x10
    li t1, 0x11
    li t2, 0x12
    li t3, 0x13
    li t4, 0x14
    li t5, 0x15
    li t6, 0x16
    li a0, 0x20
    li a1, 0x21
    li a2, 0x22
    li a3, 0x23
    li a4, 0x24
    li a5, 0x25
    li a6, 0x26
    li a7, 0x27
    li s0, 0x40
    csrsi sip, 2

.macro check reg, value
    li s1, \value
    bne \reg, s1, test_fail
.endm
    check ra, 0x30
    check t0, 0x10
    check t1, 0x11
    check t2, 0x12
    check t3, 0x13
    check t4, 0x14
    check t5, 0x15
    check t6, 0x16
    check a0, 0x20
    check a1, 0x21
    check a2, 0x22
    check a3, 0x23
    check a4, 0x24
    check a5, 0x25
    check a6, 0x26
    check a7, 0x27
    check s0, 0x40
    la t0, _stack_end
    bne sp, t0, test_fail
    la t0, _s_trap_stack_end
    csrr t1, sscratch
    bne t0, t1, test_fail
    csrr t0, sip
    andi t0, t0, 2
    bnez t0, test_fail
    csrr t0, sstatus
    andi t0, t0, 2
    beqz t0, test_fail

#ifdef USER_ECALL_TEST
    # Exercise entry from U-mode, with a different stack and global pointer.
    li t0, 1 << 8
    csrc sstatus, t0
    la t0, expected_fault
    csrw sepc, t0
    la sp, user_stack_end
    li gp, 0
    sret
#endif
.global expected_fault
expected_fault:
#ifdef USER_ECALL_TEST
    ecall
#else
    csrr t0, mstatus # Illegal in S-mode: must reach the Rust supervisor handler.
#endif
    j test_fail

.section .bss, "aw", @nobits
.balign 16
boot_zero_probe: .zero 8
.balign 16
user_stack: .zero 256
user_stack_end:
