# expcetion handlers for 'M' mode code. 
# There is a certain "ABI" to be followed here 
# a0 is the argument register
# a1 will contain mcause with the mode bit cleared #a1
# a2 will contain mepc #a2 
# a3 will contain mtval #a3
# a4 will contain the previous mie #a4
# you must restore the mie before you "mret" unless you really know what 
# you are doing. 

.global m_usoft_int
.align 4
m_usoft_int:
	mret

.global m_ssoft_int 
.align 4
m_ssoft_int:
	
	li t0, 1 
	bne a0, t0, end 
	
	# a0 == 1
	csrr t0, mie 
	li t1, 0b10101010
	or t0, t1, t0

	csrw mie, t0
	csrr t1, mie 
	bne t0, t1, error

	end: 
	# clear the mip register
	csrr t1, mip
	li t2, ~(1 << 1)

	and t1, t1, t2
	csrw mip, t1

	mret

.global m_nop_int
.align 4 
m_nop_int:
	mret

.global m_msoft_int
.align 4
m_msoft_int:
	mret

.global m_utime_int
.align 4
m_utime_int:
	mret

.global m_stime_int
.align 4
m_stime_int:
	mret


// this is now a rust function
// .global m_mtime_int
// .align 4
// m_mtime_int:
// 	la t3, 0x2000000

// 	li t4, 0x4000	
// 	add t3, t3, t4 # mtimecmp address is now in t3
	
// 	li t5, 0x7FF8
// 	add t4, t3, t5

// 	ld t1, 0(t4) # value of mtime in t1

// 	li t0, 0x989680
// 	add t0, t0, t1 #*mtime + 10_000_000
	
// 	sd t0, 0(t3)

// 	mret

.global m_uext_int
.align 4
m_uext_int:
	mret

.global m_sexit_int
.align 4
m_sexit_int:
	mret

.global m_mexit_int
.align 4
m_mexit_int:
	mret

.global m_interrupt_handlers
.align 4
m_interrupt_handlers:
	.dword m_usoft_int, m_ssoft_int, m_nop_int, m_msoft_int, m_utime_int, m_stime_int, m_nop_int, m_mtime_int, m_uext_int, m_sexit_int, m_nop_int, m_mexit_int
