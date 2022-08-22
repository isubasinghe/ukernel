use core::marker::PhantomData;

use crate::memory::types::{MemoryRange, PhysAddress};

pub trait Capability {}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct Frame{
    mem: MemoryRange<PhysAddress>
}
impl Capability for Frame {}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct LMPEndpoint {

}
impl Capability for LMPEndpoint {}


#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct NullCap {}
impl Capability for NullCap {}

#[derive(Debug, Clone, Copy)]
pub struct L2Cap {

}
impl Capability for L2Cap {}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct L1Cap {
    nodes: [CapRef<L2Cap>; 32], 
    active: u32
}
impl Capability for L1Cap {}


#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct CapType<T: Capability> {
    marker: PhantomData<T>, 
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct CapRef<T: Capability> {
    pub typ: CapType<T>
}

