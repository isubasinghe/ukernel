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
	csrw	satp, zero # Any hardware threads (hart) that are not bootstrapping
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

	# set and test mtvec
	la t0, my_m_trap
	csrw mtvec, t0

	csrr t0, mtvec 
	la t1, my_m_trap
	bne t0, t1, error

	# set and test mstatus
	li t0, 0b1100010101010
	mv t2, t0
	csrr t1, mstatus
	or t2, t2, t1
	csrw mstatus, t2
	csrr t0, mstatus 
	bne t0, t2, error	

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
	
	# set and test sepc
	la t0, my_s_trap 
	csrw sepc, t0 

	csrr t1, sepc
	bne t0, t1, error

	# switch to supervisor mode
	mret
3:

	la a0, SOFTWARE_VAL_ENABLE_MIE
	lw a0, 0(a0)

	csrr t0, mip
	ori t0, t0, 0b10
	csrw mip, t0 
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
csrr t6, mie
	csrw mie, zero 
	
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
	
	# multiply by 8 (implemented via 3 shifts)
	# this containts the offset for our address
	slli t4, t0, 3
	
	# hopefully the correct address to jump to, in this case m_ssoft_int
	add t3, t3, t4

	ld t3, 0(t3)

	jalr zero, 0(t3)

.align 4
handlers:
	.dword m_exception_handlers, m_interrupt_handlers


.global my_s_trap
.align 4
my_s_trap:
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

