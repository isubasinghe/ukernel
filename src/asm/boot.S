# Disable generation of compressed instructions.
.option norvc

# Define a .text.init section. The .text.init is put at the
# starting address so that the entry _start is put at the RISC-V
# address 0x8000_0000.
.section .text.init

# Execution starts here.
.global _start
_start:

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
	# Any hardware threads (hart) that are not bootstrapping
	# need to wait for an IPI
	csrr	t0, mhartid
	bnez	t0, 4f

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
	# Setting `mstatus` register:
	# 0b01 << 11: Machine's previous protection mode is 2 (MPP=2).
	li		t0, 0b11 << 11
	# SIE = 1
	ori	t0, t0, 0b10
	# MIE = 1 
	ori t0, t0, 1 << 3
	
	csrw	mstatus, t0
	
	li t0, ~0

	# delegate machine interrupts and exceptions to supervisor mode
	# (This doesn't actually seem to work or perhaps I am misunderstanding what is going on?)
	csrw mideleg, t0
	csrw medeleg, t0

	la t0, my_m_trap
	csrw mtvec, t0

	la t0, my_s_trap 
	csrw stvec, t0


	# Do not allow interrupts while running kinit
	csrw	mie, zero

	# Machine's exception program counter (MEPC) is set to `kinit`.
	la		t1, kinit
	csrw	mepc, t1
	# Set the return address to get us into supervisor mode
	la		ra, 3f
	# We use mret here so that the mstatus register is properly updated.
	mret
3:
	li t0, 0b111011
	csrr t1, mie
	or t0, t0, t1	
	csrw mie, t0 

	j kmain
4:
	# wfi = wait for interrupt. This is a hint to the harts to shut everything needed
	# down. However, the RISC-V specification allows for wfi to do nothing. Anyway,
	# with QEMU, this will save some CPU!
	wfi
	j		4b

.global my_m_trap
.align 4
my_m_trap:

	csrr t0, mcause 
	csrr t1, mepc 
	csrr t2, mtval 

	csrr a0, mcause
	call print_reg
	

	li t1, (1 << 28)
	li t2, 46
	sb t2, 0(t1)
	
	li t2, 10
	sb t2, 0(t1)

	
	# put 0x0200_0000 in t0
	li t0, 1
	slli t0,t0, 25

	
	# put 0x0000_4000 in t1
	li t1, 0x00004000

	# put 0x0200_4000 in t1
	or t1, t1, t0

	# put 0x0000_bff8 in t2
	li t2, 0x0000bff8

	# put 0x0200_bff8 in t2
	or t2, t2, t0

	# 10_000_000 
	li t4, 9998336
	addi t4, t4, 1664

	ld t3, 0(t2)
	add t5, t4, t3
	sw t5, 0(t1)


	mret


.global my_s_trap
.align 4
my_s_trap:
	li t1, (1 << 28)
	li t2, 97
	sb t2, 0(t1)
	li t2, 10
	sb t2, 0(t1)	
	sret

bitdata:
	.byte 48, 49


print_reg: 
	li t0, 32 # counter
loop_head:
	addi t0, t0, -1
	
	srlw t1, a0, t0
	li t2, 1
	and t1, t1, t2
	
	la t2, bitdata 
	add t2, t2, t1

	ld t2, 0(t2)

	li t1, (1 << 28)
	sb t2, 0(t1)

	bnez t0, loop_head
loop_end: 
	li t2, 10
	sb t2, 0(t1)
	ret 


