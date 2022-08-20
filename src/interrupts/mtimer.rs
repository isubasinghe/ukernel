
#[no_mangle]
#[repr(align(4))]
extern "C" fn m_mtime_int(mcause: usize, mepc: usize, mtval: usize) {
    loop {}
}
