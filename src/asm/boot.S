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
	la t0, my_m_trap
	csrw mtvec, t0
3:
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
	mret


.global my_s_trap
.align 4
my_s_trap:
	sret

bitdata:
	.byte 48, 49



// print_reg: 
// 	li t0, 32 # counter
// loop_head:
// 	addi t0, t0, -1
	
// 	srlw t1, a0, t0
// 	li t2, 1
// 	and t1, t1, t2
	
// 	la t2, bitdata 
// 	add t2, t2, t1

// 	ld t2, 0(t2)

// 	li t1, (1 << 28)
// 	sb t2, 0(t1)

// 	bnez t0, loop_head
// loop_end: 
// 	li t2, 10
// 	sb t2, 0(t1)
// 	ret 

