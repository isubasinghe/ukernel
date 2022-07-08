.global m_usoft_int
.align 4
m_usoft_int:
	mret

.global m_ssoft_int 
.align 4
m_ssoft_int:
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
