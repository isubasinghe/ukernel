.global m_instr_addr_mis
.align 4
m_instr_addr_mis:
	mret

.global m_instr_access_fault
.align 4
m_instr_access_fault:
	mret

.global m_illegal_instr
.align 4
m_illegal_instr:
	mret

.global m_breakpoint
.align 4
m_breakpoint:
	mret

.global m_ld_addr_mis
.align 4
m_ld_addr_mis:
	mret

.global m_ld_access_fault
.align 4
m_ld_access_fault:
	mret

.global m_stramo_addr_mis
.align 4
m_stramo_addr_mis:
	mret

.global m_stramo_access_fault
.align 4
m_stramo_access_fault:
	mret

.global m_uecall
.align 4
m_uecall:
	mret

.global m_secall
.align 4
m_secall:
	mret

.global m_mecall
.align 4
m_mecall:
	mret

.global m_instr_page_fault
.align 4
m_instr_page_fault:
	mret

.global m_ld_page_fault
.align 4
m_ld_page_fault:
	mret

.global m_stramo_page_fault
.align 4
m_stramo_page_fault:
	mret


.global m_nop_exc
.align 4 
m_nop_exc:
	mret

.global m_exception_handlers 
.align 4 
m_exception_handlers:
	.dword m_instr_addr_mis, m_instr_access_fault, m_illegal_instr, m_breakpoint, m_ld_addr_mis, m_ld_access_fault, m_stramo_addr_mis, m_stramo_access_fault, m_uecall, m_secall, m_nop_exc, m_mecall, m_instr_page_fault, m_ld_page_fault, m_nop_exc, m_stramo_page_fault
