# RV64 integer trap frame; offsets must match SupervisorTrapFrame in Rust.
# Only hart 0 is active. Paging, floating point, and nested S traps are not enabled.
.option norvc
.section .text, "ax", @progbits
.global s_trap_entry
.align 4
s_trap_entry:
	csrrw sp, sscratch, sp
	addi sp, sp, -288
	sd t0, 40(sp)
	# A fault inside the handler must not reuse the occupied trap stack.
	la t0, s_trap_fatal
	csrw stvec, t0
	sd zero, 0(sp)
	sd ra, 8(sp)
	sd gp, 24(sp)
	sd tp, 32(sp)
	sd t1, 48(sp)
	sd t2, 56(sp)
	sd s0, 64(sp)
	sd s1, 72(sp)
	sd a0, 80(sp)
	sd a1, 88(sp)
	sd a2, 96(sp)
	sd a3, 104(sp)
	sd a4, 112(sp)
	sd a5, 120(sp)
	sd a6, 128(sp)
	sd a7, 136(sp)
	sd s2, 144(sp)
	sd s3, 152(sp)
	sd s4, 160(sp)
	sd s5, 168(sp)
	sd s6, 176(sp)
	sd s7, 184(sp)
	sd s8, 192(sp)
	sd s9, 200(sp)
	sd s10, 208(sp)
	sd s11, 216(sp)
	sd t3, 224(sp)
	sd t4, 232(sp)
	sd t5, 240(sp)
	sd t6, 248(sp)
	csrr t0, sscratch
	sd t0, 16(sp)
	csrr t0, sepc
	sd t0, 256(sp)
	csrr t0, sstatus
	sd t0, 264(sp)
	csrr t0, scause
	sd t0, 272(sp)
	csrr t0, stval
	sd t0, 280(sp)

	# User code may have a different gp; Rust must use the kernel's gp.
.option push
.option norelax
	la gp, _global_pointer
.option pop
	mv a0, sp
	call supervisor_trap

	# Rust may change saved sepc or registers after handling a trap.
	ld t0, 256(sp)
	csrw sepc, t0
	ld t0, 264(sp)
	# Never enable interrupts halfway through restoring the frame.
	andi t0, t0, -3
	csrw sstatus, t0
	la t0, my_s_trap
	csrw stvec, t0
	addi t0, sp, 288
	csrw sscratch, t0
	ld ra, 8(sp)
	ld gp, 24(sp)
	ld tp, 32(sp)
	ld t0, 40(sp)
	ld t1, 48(sp)
	ld t2, 56(sp)
	ld s0, 64(sp)
	ld s1, 72(sp)
	ld a0, 80(sp)
	ld a1, 88(sp)
	ld a2, 96(sp)
	ld a3, 104(sp)
	ld a4, 112(sp)
	ld a5, 120(sp)
	ld a6, 128(sp)
	ld a7, 136(sp)
	ld s2, 144(sp)
	ld s3, 152(sp)
	ld s4, 160(sp)
	ld s5, 168(sp)
	ld s6, 176(sp)
	ld s7, 184(sp)
	ld s8, 192(sp)
	ld s9, 200(sp)
	ld s10, 208(sp)
	ld s11, 216(sp)
	ld t3, 224(sp)
	ld t4, 232(sp)
	ld t5, 240(sp)
	ld t6, 248(sp)
	ld sp, 16(sp)
	sret

.align 4
s_trap_fatal:
	csrci sstatus, 2
	j s_trap_fatal
