#![no_std]

use core::arch::asm;
use core::fmt::{self, Write};

#[path = "../src/exceptions/supervisor.rs"]
mod supervisor;

struct Uart;
impl Write for Uart {
    fn write_str(&mut self, text: &str) -> fmt::Result {
        for byte in text.bytes() {
            unsafe { (0x10000000 as *mut u8).write_volatile(byte); }
        }
        Ok(())
    }
}

fn exit(success: bool) -> ! {
    unsafe { (0x100000 as *mut u32).write_volatile(if success { 0x5555 } else { 0x13333 }); }
    loop { core::hint::spin_loop(); }
}

#[no_mangle]
pub extern "C" fn test_fail() -> ! { exit(false) }
#[no_mangle]
pub extern "C" fn m_mtime_int() -> ! { exit(false) }

#[panic_handler]
fn panic(info: &core::panic::PanicInfo) -> ! {
    let (cause, epc, status): (usize, usize, usize);
    unsafe {
        asm!("csrr {}, scause", out(reg) cause);
        asm!("csrr {}, sepc", out(reg) epc);
        asm!("csrr {}, sstatus", out(reg) status);
    }
    extern "C" { static expected_fault: u8; }
    let expected_epc = unsafe { &expected_fault as *const u8 as usize };
    let expected_cause = if cfg!(user_ecall_test) { 8 } else { 2 };
    let expected_spp = if cfg!(user_ecall_test) { 0 } else { 1 << 8 };
    let _ = writeln!(Uart, "{}", info);
    // A panic is expected only after the assembly register/interrupt checks pass.
    exit(cause == expected_cause && epc == expected_epc && status & (1 << 8) == expected_spp);
}
