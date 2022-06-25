use core::ops::{
    Add, AddAssign, BitAnd, BitAndAssign, BitOr, BitOrAssign, BitXor, BitXorAssign, Div, Mul, Sub,
    SubAssign,
};
use derive_more::*;

#[derive(
    Add,
    AddAssign,
    Sub,
    SubAssign,
    BitAnd,
    BitAndAssign,
    BitOr,
    BitOrAssign,
    BitXor,
    BitXorAssign,
    Copy,
    Clone,
    Debug,
)]
pub struct VirtAddress {
    base: usize,
}

#[derive(
    Add,
    AddAssign,
    Sub,
    SubAssign,
    BitAnd,
    BitAndAssign,
    BitOr,
    BitOrAssign,
    BitXor,
    BitXorAssign,
    Copy,
    Clone,
    Debug,
)]
pub struct PhysAddress {
    base: usize,
}

pub trait MemoryAddress:
    Add
    + AddAssign
    + Sub
    + SubAssign
    + Mul 
    + Div
    + BitAnd
    + BitAndAssign
    + BitOr
    + BitOrAssign
    + BitXor
    + BitXorAssign
    + Sized
{
}

impl MemoryAddress for VirtAddress {}

impl Mul for VirtAddress {
    type Output = Self;
    fn mul(self, rhs: Self) -> Self::Output {
        VirtAddress {
            base: self.base * rhs.base,
        }
    }
}

impl Div for VirtAddress {
    type Output = Self;
    fn div(self, rhs: Self) -> Self::Output {
        VirtAddress {
            base: self.base / rhs.base,
        }
    }
}

impl MemoryAddress for PhysAddress {}

impl Mul for PhysAddress {
    type Output = Self;
    fn mul(self, rhs: Self) -> Self::Output {
        PhysAddress { base: self.base * rhs.base }
    }
}

impl Div for PhysAddress {
    type Output = Self;
    fn div(self, rhs: Self) -> Self::Output {
        PhysAddress { base: self.base / rhs.base }
    }
}

fn x(x: VirtAddress) {
    let y = x * x;
}

