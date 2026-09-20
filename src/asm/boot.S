# Disable generation of compressed instructions.
.option norvc

# Define a .text.init section. The .text.init is put at the
# starting address so that the entry _start is put at the RISC-V
# address 0x8000_0000.
.section .text.init

# Execution starts here.
.global _start
_start:
.option push
.option norelax # gp is still owned by the bootloader during mode detection.
	# Boot ABI: a0=hart ID, a1=DTB. Preserve both while clearing BSS.
	mv s0, a0
	mv s1, a1
	csrci sstatus, 2
	la t0, .Lmode_probe_trap
	csrw stvec, t0
	li s2, 3 # M-mode unless the CSR probe faults.
.Lmode_probe:
	csrr t0, mstatus
	j .Lmachine_entry

.align 2
.Lmode_probe_trap:
	# Firmware must delegate/reflect illegal instructions to S-mode.
	# Only the exact probe instruction is recoverable here.
	csrr t0, scause
	li t1, 2
	bne t0, t1, error
	csrr t0, sepc
	la t1, .Lmode_probe
	bne t0, t1, error
	li s2, 1
	la t0, .Lsupervisor_entry
	csrw sepc, t0
	sret

# Optional known-S-mode entry: avoids probing firmware's exception policy.
.global _start_s
_start_s:
	mv s0, a0
	mv s1, a1
	li s2, 1
	csrci sstatus, 2
.Lsupervisor_entry:
	la t0, error
	csrw stvec, t0
	csrw sie, zero
	j .Lcommon_entry

.Lmachine_entry:
	# Keep machine interrupts disabled until their stack and vector are ready.
	csrci mstatus, 8
	csrw mie, zero
	la t0, error
	csrw mtvec, t0
	csrr s0, mhartid
	# Bare M-mode boots start all harts; only hart 0 initializes shared state.
	bnez s0, 4f

.Lcommon_entry:
.option pop
	# Disable linker instruction relaxation for the `la` instruction below.
	# This disallows the assembler from assuming that `gp` is already initialized.
	# This causes the value stored in `gp` to be calculated from `pc`.
	# The job of the global pointer is to give the linker the ability to address
	# memory relative to GP instead of as an absolute address.
.option push
.option norelax
	la		gp, _global_pointer
.option pop
	# SATP should be zero, but let's make sure. Each HART has its own
	# SATP register.
	csrw	satp, zero
	sfence.vma zero, zero

	# Set all bytes in the BSS section to zero.
	la 		a0, _bss_start
	la		a1, _bss_end
	bgeu	a0, a1, 2f
1:
	sd		zero, (a0)
	addi	a0, a0, 8
	bltu	a0, a1, 1b
2:
	la		sp, _stack_end
	la t0, _s_trap_stack_end
	csrw sscratch, t0

	# Both entry modes need our supervisor stack and trap vector.
	# FP remains disabled because trap frames only save integer registers.
	li t0, (3 << 13) | (1 << 1)
	csrc sstatus, t0
	la t0, my_s_trap
	csrw stvec, t0
	csrr t1, stvec
	bne t0, t1, error
	li t0, 1
	beq s2, t0, .Lsupervisor_ready

	# Only M-mode may configure the machine trap stack, PMP, and delegation.
	la t0, _trap_stack_end
	csrw mscratch, t0

	# Reset delegation before configuring the machine path.
	csrw medeleg, zero
	csrw mideleg, zero

	# Allow S-mode access to physical memory during initial bring-up.
	li t0, -1
	csrw pmpaddr0, t0
	li t0, 0x1f # NAPOT, read/write/execute
	csrw pmpcfg0, t0

	# set and test mtvec
	la t0, my_m_trap
	csrw mtvec, t0

	csrr t0, mtvec 
	la t1, my_m_trap
	bne t0, t1, error

	# set and test mstatus: MPP=01 (supervisor), interrupts and FP off.
	li t0, (3 << 11) | (1 << 3) | (1 << 7) | (1 << 1) | (3 << 13) | (1 << 17)
	csrc mstatus, t0
	li t0, (1 << 11)
	csrs mstatus, t0
	csrr t1, mstatus
	li t2, (3 << 11)
	and t1, t1, t2
	bne t0, t1, error

	# set and test mie
	li t0, 0b10
	csrw mie, t0

	csrr t0, mie
	li t1, 0b10
	bne t1, t0, error

	# set and test mepc	
	la t0, 3f
	csrw mepc, t0 
	csrr t0, mepc 
	la t1, 3f 
	bne t0, t1, error

	# set and test satp
	li t0, 0 
	csrw satp, t0
	csrr t1, satp
	bne t0, t1, error
	
	# Delegate standard faults and U-mode ecall, but keep S-mode ecall in M.
	# Causes 0-8, 12, 13, 15; reserved causes and M-mode ecall stay in M.
	li t0, 0x1ff | (1 << 12) | (1 << 13) | (1 << 15)
	csrw medeleg, t0
	csrr t1, medeleg
	and t1, t1, t0
	bne t0, t1, error

	# Delegate supervisor software, timer, and external interrupts.
	li t0, (1 << 1) | (1 << 5) | (1 << 9)
	csrw mideleg, t0
	csrr t1, mideleg
	and t1, t1, t0
	bne t0, t1, error
	# Routing does not enable delivery: Rust enables SIE when ready.

	# switch to supervisor mode
	mret
.Lsupervisor_ready:
	# Firmware owns mtvec, PMP, and delegation on an S-mode boot.
	# Enable only the implemented supervisor software source; SIE stays off.
	li t0, 2
	csrw sie, t0
3:
	mv a0, s0
	mv a1, s1
	mv a2, s2 # entry privilege: 1=S, 3=M
	j kmain

# set up stack later
4:
	wfi 
	j 4b

.global error
error: 
	j error 

.global my_m_trap
.align 4
my_m_trap:
	# Save interrupted registers on the machine trap stack (16-byte aligned).
	# Frame: xN at 8*N, mepc at 256, mstatus at 264; x0 is unused.
	# Nested traps are fatal; handlers must not enable interrupts or FP.
	csrrw sp, mscratch, sp
	addi sp, sp, -272
	sd t0, 40(sp)
	la t0, error
	csrw mtvec, t0
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
	csrr t0, mscratch
	sd t0, 16(sp)
	csrr t0, mepc
	sd t0, 256(sp)
	csrr t0, mstatus
	sd t0, 264(sp)
	csrr t6, mie

	# for debugging only
	la t0, m_ssoft_int
	la t1, m_interrupt_handlers

	# do not touch t0-t2 or t6
	csrr t0, mcause 
	csrr t1, mepc 
	csrr t2, mtval

	# load last bit to t3
	srli t3, t0, 63

	# 0 or 8 in t4
	li t4, 8
	mul t3, t3, t4
	# t4 dies
	
	# load address of handlers
	# t4 alive
	la t4, handlers

	# increment by a dword or 0  and store in t3
	# address of correct exception handler is now in t3
	add t3, t4, t3
	ld t3, 0(t3)
	# t4 dies

	# masking bit to clear mode value
	#0b0111....111 in t4 
	li t4, 1
	slli t4, t4, 63
	not t4, t4
	
	# mcause code in t0
	# mask out the mode (last) bit and 
	# write it back to t0 
	and t0, t4, t0 
	# t4 dies
	
	# Reject causes outside the selected handler table.
	csrr t4, mcause
	bltz t4, 5f
	la t5, m_exception_handlers_end
	j 6f
5:
	la t5, m_interrupt_handlers_end
6:
	sub t5, t5, t3
	srli t5, t5, 3
	bgeu t0, t5, error

	# multiply by 8 (implemented via 3 shifts)
	# this containts the offset for our address
	slli t4, t0, 3
	
	# hopefully the correct address to jump to, in this case m_ssoft_int
	add t3, t3, t4

	ld t3, 0(t3)

	# C ABI arguments; handlers return here with ret, not mret.
	mv a0, t0
	mv a1, t1
	mv a2, t2
	mv a3, sp # handlers may update saved mepc for handled exceptions
	jalr ra, 0(t3)

	ld t0, 256(sp)
	csrw mepc, t0
	ld t0, 264(sp)
	csrw mstatus, t0
	la t0, my_m_trap
	csrw mtvec, t0
	addi t0, sp, 272
	csrw mscratch, t0
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
	mret

.align 4
handlers:
	.dword m_exception_handlers, m_interrupt_handlers


.global my_s_trap
.align 4
my_s_trap:
	j s_trap_entry

bitdata:
	.byte 48, 49


.balign 4
print_reg: 
	li t0, 32 # counter
loop_head:
	addi t0, t0, -1
	
	srlw t1, a0, t0
	li t2, 1
	and t1, t1, t2
	
	la t2, bitdata 
	add t2, t2, t1

	lbu t2, 0(t2)

	li t1, (1 << 28)
	sb t2, 0(t1)

	bnez t0, loop_head
loop_end: 
	li t2, 10
	sb t2, 0(t1)
	ret 

