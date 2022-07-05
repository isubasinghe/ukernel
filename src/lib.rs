#![no_std]
#![no_main]
#![feature(panic_info_message, lang_items)]

extern crate tock_registers;
extern crate spin; 
extern crate lazy_static;
extern crate derive_more;
extern crate riscv;

mod uart;
mod cells;
mod io;
mod memory;
mod cpu;
mod exceptions;

use core::arch::asm;

use crate::cpu::setup_no_vm;


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
#[lang="eh_personality"]
extern "C" fn eh_personality() {}

#[panic_handler]
fn panic(info: &core::panic::PanicInfo) -> ! {
	print!("Aborting: ");
	if let Some(p) = info.location() {
		println!(
		         "line {}, file {}: {}",
		         p.line(),
		         p.file(),
		         info.message().unwrap()
		);
	}
	else {
		println!("no information available.");
	}
	abort();
}

#[no_mangle]
extern "C"
fn abort() -> ! {
	loop {
		unsafe {
			asm!("wfi");
		}
	}
}


#[no_mangle]
extern "C"
fn kmain() -> ! {
    uart::Uart::new(0x1000_0000).init(); 
    println!("[log] started");
    loop {
        // println!("blah");
    }
    loop {}
}

#[no_mangle]
extern "C" 
fn kinit() {
    uart::Uart::new(0x1000_0000).init(); 
    println!("[log] kinit started");
    setup_no_vm();
    println!("[log] setup sapt with bare mode");
}

#[no_mangle]
extern "C" 
fn kinit_hart() { 
}




