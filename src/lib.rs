#![no_std]
#![no_main]
#![feature(panic_info_message, lang_items, fn_align)]

extern crate derive_more;
extern crate lazy_static;
extern crate riscv;
extern crate spin;
extern crate tock_registers;
extern crate log; 
extern crate bit_field;

mod cells;
mod cpu;
mod exceptions;
mod io;
mod memory;
mod uart;
mod interrupts;
mod userspace;
mod capability;
mod lrpc;
use interrupts::constants::SOFTWARE_VAL_ENABLE_MIE;


use core::arch::asm;
use interrupts::constants::*;
use memory::types::PhysAddress;
use riscv::asm as rasm;
use riscv::register::*;
use uart::logger::UartLogger;
use userspace::constants::USERSPACE_INIT;
use bit_field::BitField;

extern crate fdt_rs;

use fdt_rs::prelude::*;
use fdt_rs::base::*;

// Place a device tree image into the rust binary and
// align it to a 32-byte boundary by using a wrapper struct.
#[repr(align(4))] struct _Wrapper<T>(T);
pub const FDT: &[u8] = &_Wrapper(*include_bytes!("../riscv64-virt.dtb")).0;

static LOGGER: UartLogger = UartLogger{};

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
#[lang = "eh_personality"]
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
    } else {
        println!("no information available.");
    }
    abort();
}

fn abort() -> ! {
    loop {}
}

// this starts in supervisor mode 
// so we do not have access to the m* registers or wfi
#[no_mangle]
extern "C" fn kmain() -> ! {
    /* uart::Uart::new(0x1000_0000).init();
    log::set_logger(&LOGGER).map(|()|log::set_max_level(log::LevelFilter::Debug)).unwrap();
    log::info!("kmain initialising");
    log::warn!("init process is not ready yet");
    let devtree = unsafe {
        let size = DevTree::read_totalsize(FDT).unwrap();
        let buf = &FDT[..size];
        DevTree::new(buf).unwrap()
    };

    log::info!("read dtb");

    for item in devtree.items().iterator() {
        match item {
            Ok(item) => {
                match item {
                    DevTreeItem::Node(n)=> {
                        log::info!("got {:?}", n.name().unwrap());
                        if n.name().unwrap().starts_with("plic") {
                            log::info!("found the plic");
                        }
                    },
                    DevTreeItem::Prop(p) => {   
                    },
                };
            }, 
            Err(e) => {
                log::warn!("got error {}", e);
            }
        };
    }

    unsafe {
        let m = mie::read();
        let s = sie::read();
        mie::set_mext();
        log::info!("mie {:#066b}", m.bits());
        log::info!("sie {:#066b}", s.bits());
        let m = mip::read();
        let s = sip::read();
        log::info!("mip {:#066b}", m.bits());
        log::info!("sip {:#066b}", s.bits());

        let mst = mstatus::read();

        log::info!("xs {:?}", mst.xs());
        log::info!("fs {:?}", mst.fs());
        log::info!("mpp {:?}", mst.mpp());
        log::info!("mie {:?}", mst.mie());
        log::info!("{:#034b}", SOFTWARE_VAL_ENABLE_MIE);
        
    }  */

    loop {}
}

// switch to the userspace init process
#[no_mangle]
extern "C" fn switch_to_user_init(addr: PhysAddress) {
}

// this starts in supervisor mode 
// so we do not have access to the m* registers or wfi
#[no_mangle]
extern "C" fn kinit_hart(_hartid: usize) {
    loop {
    }
}
