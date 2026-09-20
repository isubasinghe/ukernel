use core::arch::asm;

/// Matches the 288-byte RV64 frame in asm/strap.S.
/// Floating point is disabled; nested supervisor traps halt in assembly.
#[repr(C)]
pub struct SupervisorTrapFrame {
    pub regs: [usize; 32],
    pub sepc: usize,
    pub sstatus: usize,
    pub scause: usize,
    pub stval: usize,
}

// Fail at compile time if Rust and the assembly disagree about the layout.
const _: [(); 288] = [(); core::mem::size_of::<SupervisorTrapFrame>()];

/// Called only by the assembly wrapper, with exclusive access to its saved frame.
/// Do not enable interrupts here: this entry path does not support nested traps.
#[no_mangle]
pub extern "C" fn supervisor_trap(frame: &mut SupervisorTrapFrame) {
    let interrupt_bit = 1usize << 63;
    let is_interrupt = frame.scause & interrupt_bit != 0;
    let cause = frame.scause & !interrupt_bit;

    match (is_interrupt, cause) {
        (true, 1) => handle_software_interrupt(frame),
        (true, 5) => handle_timer_interrupt(frame),
        (true, 9) => handle_external_interrupt(frame),
        (false, 0) => handle_instruction_address_misaligned(frame),
        (false, 1) => handle_instruction_access_fault(frame),
        (false, 2) => handle_illegal_instruction(frame),
        (false, 3) => handle_breakpoint(frame),
        (false, 4) => handle_load_address_misaligned(frame),
        (false, 5) => handle_load_access_fault(frame),
        (false, 6) => handle_store_address_misaligned(frame),
        (false, 7) => handle_store_access_fault(frame),
        (false, 8) => handle_user_ecall(frame),
        (false, 12) => handle_instruction_page_fault(frame),
        (false, 13) => handle_load_page_fault(frame),
        (false, 15) => handle_store_page_fault(frame),
        _ => handle_unknown_trap(frame),
    }
}

// These are ordinary Rust functions: the assembly wrapper handles trap return.
// Recovery handlers may update frame.sepc and frame.regs before returning.
// Fault handlers must not blindly advance sepc: retry or skip only after recovery.
fn handle_software_interrupt(_frame: &mut SupervisorTrapFrame) {
    // Acknowledge SSIP before returning, or it will immediately trap again.
    unsafe { asm!("csrci sip, 2", options(nomem, nostack)); }
}

fn handle_timer_interrupt(frame: &mut SupervisorTrapFrame) {
    // Rearm the timer through the timer driver before allowing this to return.
    unhandled_trap("supervisor timer interrupt", frame);
}

fn handle_external_interrupt(frame: &mut SupervisorTrapFrame) {
    // Claim, service, and complete the interrupt through the device driver.
    unhandled_trap("supervisor external interrupt", frame);
}

fn handle_instruction_address_misaligned(frame: &mut SupervisorTrapFrame) {
    unhandled_trap("instruction address misaligned", frame);
}

fn handle_instruction_access_fault(frame: &mut SupervisorTrapFrame) {
    unhandled_trap("instruction access fault", frame);
}

fn handle_illegal_instruction(frame: &mut SupervisorTrapFrame) {
    unhandled_trap("illegal instruction", frame);
}

fn handle_breakpoint(frame: &mut SupervisorTrapFrame) {
    unhandled_trap("breakpoint", frame);
}

fn handle_load_address_misaligned(frame: &mut SupervisorTrapFrame) {
    unhandled_trap("load address misaligned", frame);
}

fn handle_load_access_fault(frame: &mut SupervisorTrapFrame) {
    unhandled_trap("load access fault", frame);
}

fn handle_store_address_misaligned(frame: &mut SupervisorTrapFrame) {
    unhandled_trap("store/AMO address misaligned", frame);
}

fn handle_store_access_fault(frame: &mut SupervisorTrapFrame) {
    unhandled_trap("store/AMO access fault", frame);
}

fn handle_user_ecall(frame: &mut SupervisorTrapFrame) {
    // Add syscall dispatch here; advance sepc by 4 only after handling the call.
    unhandled_trap("user ecall", frame);
}

fn handle_instruction_page_fault(frame: &mut SupervisorTrapFrame) {
    unhandled_trap("instruction page fault", frame);
}

fn handle_load_page_fault(frame: &mut SupervisorTrapFrame) {
    unhandled_trap("load page fault", frame);
}

fn handle_store_page_fault(frame: &mut SupervisorTrapFrame) {
    unhandled_trap("store/AMO page fault", frame);
}

fn handle_unknown_trap(frame: &mut SupervisorTrapFrame) {
    unhandled_trap("unknown cause", frame);
}

fn unhandled_trap(reason: &str, frame: &SupervisorTrapFrame) -> ! {
    panic!(
        "Unhandled supervisor trap ({}): scause={:#x}, sepc={:#x}, stval={:#x}",
        reason, frame.scause, frame.sepc, frame.stval
    );
}
