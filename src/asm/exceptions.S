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

m_ld_page_fault:
	mret

m_stramo_page_fault:
	mret
