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

	# set and test mtvec
	la t0, my_m_trap
	csrw mtvec, t0

	csrr t0, mtvec 
	la t1, my_m_trap
	bne t0, t1, error

	# set and test mstatus
	la t0, 0b1100010101010
	mv t2, t0
	csrr t1, mstatus
	or t2, t2, t1
	csrw mstatus, t2
	csrr t0, mstatus 
	bne t0, t2, error	

	# set and test mie
	li t0, 0
	csrw mie, t0

	csrr t0, mie
	li t1, 0 
	bne t1, t0, error

	# set and test mepc	
	la t0, 3f
	csrw mepc, t0 
	csrr t0, mepc 
	la t1, 3f 
	bne t0, t1, error

	# set and test satp
	la t0, 0 
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
	j kmain

# set up stack later
4:
	wfi 
	j 4b

error: 
	wfi 
	j error 

.global my_m_trap
.align 4
my_m_trap:
	csrr t0, mcause 
	csrr t1, mepc 
	csrr t2, mtval

	mret


.global my_s_trap
.align 4
my_s_trap:
	sret


m_usoft_int:
	mret

m_ssoft_int:
	mret

m_nop:
	mret

m_msoft_int:
	mret

m_utime_int:
	mret

m_stime_int:
	mret

m_mtime_int:
	mret

m_uext_int:
	mret

m_sexit_int:
	mret

m_mexit_int:
	mret

m_instr_addr_mis:
	mret

m_instr_access_fault:
	mret

m_illegal_instr:
	mret

m_breakpoint:
	mret

m_ld_addr_mis:
	mret

m_ld_addr_fault:
	mret

m_stramo_addr_mis:
	mret

m_stramo_access_fault:
	mret

m_uecall:
	csrr t0, mepc
	addi t0, t0, 4
	mret

m_secall:
	csrr t0, mepc
	addi t0, t0, 4
	mret

m_mecall:
	csrr t0, mepc
	addi t0, t0, 4
	mret

m_instr_page_fault:
	mret

m_trap_handlers:
	.dword m_usoft_int, m_ssoft_int, m_nop

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

