#![no_std]
#![no_main]
#![feature(panic_info_message, lang_items)]

extern crate derive_more;
extern crate lazy_static;
extern crate riscv;
extern crate spin;
extern crate tock_registers;

mod cells;
mod cpu;
mod exceptions;
mod io;
mod memory;
mod uart;
mod interrupts;

use core::arch::asm;
use interrupts::constants::*;
use riscv::asm as rasm;

// ///////////////////////////////////
// / RUST MACROS
// ///////////////////////////////////
#[macro_export]
macro_rules! print
{
	($($args:tt)+) => ({
        use core::fmt::Write;
        let _ = write!(crate::uart::Uart::new(0x1000_0000), $($args)+);

	});
}
#[macro_export]
macro_rules! println
{
	() => ({
		print!("\r\n")
	});
	($fmt:expr) => ({
		print!(concat!($fmt, "\r\n"))
	});
	($fmt:expr, $($args:tt)+) => ({
		print!(concat!($fmt, "\r\n"), $($args)+)
	});
}

// ///////////////////////////////////
// / LANGUAGE STRUCTURES / FUNCTIONS
// ///////////////////////////////////
#[no_mangle]
#[lang = "eh_personality"]
extern "C" fn eh_personality() {}

#[panic_handler]
fn panic(info: &core::panic::PanicInfo) -> ! {
    /* print!("Aborting: ");
    if let Some(p) = info.location() {
        println!(
            "line {}, file {}: {}",
            p.line(),
            p.file(),
            info.message().unwrap()
        );
    } else {
        println!("no information available.");
    } */
    abort();
}

#[no_mangle]
extern "C" fn abort() -> ! {
    unsafe {
        asm!("li a0, 1",
             "ecall");
    }
    loop {}
}

// this starts in supervisor mode 
// so we do not have access to the m* registers or wfi
#[no_mangle]
extern "C" fn kmain() -> ! {
    loop {}
}

// this starts in supervisor mode 
// so we do not have access to the m* registers or wfi
#[no_mangle]
extern "C" fn kinit_hart(_hartid: usize) {
    loop {
    }
}
