use riscv::register::*;

#[repr(usize)]
pub enum SatpMode {
    Bare = 0, 
    Sv39 = 8, 
    Sv48 = 9
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct TrapFrame {
    pub regs: [usize; 32], 
    pub fregs: [usize; 32], 
    pub satp: usize, 
    pub trap_stack: *mut u8, 
    pub hartid: usize
}

pub fn setup_no_vm() {
    satp::write((SatpMode::Bare as usize) << 60);
}

pub fn get_core() -> usize {
    mhartid::read()
}
