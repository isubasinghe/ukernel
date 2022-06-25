use super::constants::*;
use super::types::MemoryAddress;
use core::mem::size_of;
use core::ptr::null_mut;

extern "C" {
    static HEAP_START: usize;
    static HEAP_SIZE: usize;
}

pub fn align<T>(addr: T)
where
    T: MemoryAddress,
{
}
