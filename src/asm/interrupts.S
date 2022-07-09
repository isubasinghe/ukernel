# expcetion handlers for 'M' mode code. 
# There is a certain "ABI" to be followed here 
# t0 will contain mcause with the mode bit cleared 
# t1 will contain mepc 
# t2 will contain mtval 
# t6 will contain the previous mie 
# you must restore the mie before you "mret" unless you really know what 
# you are doing. 

.global m_usoft_int
.align 4
m_usoft_int:
	mret

.global m_ssoft_int 
.align 4
m_ssoft_int:
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

.global m_mtime_int
.align 4
m_mtime_int:
	mret

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
