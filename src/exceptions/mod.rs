
use crate::cpu::TrapFrame;

#[no_mangle]
extern "C" 
fn m_trap(epc: usize, tval: usize, cause: usize, hart: usize, status: usize, frame: &mut TrapFrame) -> usize {
    0
}
