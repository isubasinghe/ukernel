# Test-only exception table: exercise boot.S's real entry/exit and interrupts.S.
.option norvc
.section .text, "ax", @progbits
.global kmain
kmain:
    andi t0, sp, 15
    bnez t0, fail
    la t0, zero_probe
    ld t1, 0(t0)
    bnez t1, fail
    li t0, 0x10
    li t1, 0x11
    li t2, 0x12
    li t3, 0x13
    li t4, 0x14
    li t5, 0x15
    li t6, 0x16
    li a0, 0x20
    li ra, 0x30
    li s0, 0x40
    li a4, 0x24
    li a5, 0x25
    li a6, 0x26
    li a7, 0x27
    ecall
    # A pending software interrupt must run before this second ecall.
    ecall
    li t0, 0x100000
    li t1, 0x5555
    sw t1, 0(t0)
1:  j 1b

check_trap:
    li t0, 9
    bne a0, t0, fail
    bnez a2, fail
    csrr t0, mstatus
    srli t0, t0, 11
    andi t0, t0, 3
    li t1, 1
    bne t0, t1, fail
    andi t0, sp, 15
    bnez t0, fail
    # Check the original register values on both sides of the interrupt.
.macro check offset, value
    ld t0, \offset(a3)
    li t1, \value
    bne t0, t1, fail
.endm
    check 40, 0x10
    check 48, 0x11
    check 56, 0x12
    check 224, 0x13
    check 232, 0x14
    check 240, 0x15
    check 248, 0x16
    check 80, 0x20
    check 8, 0x30
    check 64, 0x40
    check 112, 0x24
    check 120, 0x25
    check 128, 0x26
    check 136, 0x27
    ld t0, 16(a3)
    la t1, _stack_end
    bne t0, t1, fail
    la t0, trap_count
    ld t1, 0(t0)
    bnez t1, second_trap
    li t1, 1
    sd t1, 0(t0)
    li t0, 2
    csrc mideleg, t0 # This test specifically exercises the M-mode wrapper.
    csrs mie, t0
    csrs mip, t0
    j resume
second_trap:
    csrr t0, mip
    andi t0, t0, 2
    bnez t0, fail
    csrr t0, mie
    andi t0, t0, 2
    beqz t0, fail
resume:
    addi a1, a1, 4
    sd a1, 256(a3)
    li a4, -1
    li a5, -1
    li a6, -1
    li a7, -1
    li t6, -1
    ret

.global supervisor_trap
supervisor_trap:
.global m_mtime_int
m_mtime_int:
fail:
    li t0, 0x100000
    li t1, 0x13333
    sw t1, 0(t0)
2:  j 2b

#ifndef PRODUCTION_LINK_ONLY
.balign 8
.global m_exception_handlers, m_exception_handlers_end
m_exception_handlers:
    .rept 9
    .dword fail
    .endr
    .dword check_trap
m_exception_handlers_end:
#endif

.section .bss, "aw", @nobits
.balign 8
trap_count: .zero 8
zero_probe: .zero 9
