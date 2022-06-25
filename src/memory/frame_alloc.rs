use super::constants::*;
use super::types::MemoryAddress;
use core::mem::size_of;
use core::ptr::null_mut;

use core::convert::{Into};

extern "C" {
    static HEAP_START: usize;
    static HEAP_SIZE: usize;
}

pub fn align<T>(addr: T, order: usize) -> T
where
    T: MemoryAddress,
{
    let one:T = 1.into();
    let order:T = order.into();
    let o:T = (one << order) - one;
    (addr + o) & !o
}

#[repr(u8)]
pub enum PageBits {
    Empty = 0, 
    Taken = 1 << 0, 
    Last = 1 << 1,
}

impl Into<u8> for PageBits {
    fn into(self) -> u8 {
        self as u8
    }
}


pub struct Page {
    flags: u8
}
