use core::ops::{
    Add, AddAssign, BitAnd, BitAndAssign, BitOr, BitOrAssign, BitXor, BitXorAssign, Div, Mul, Sub,
    SubAssign, Rem
};

use core::convert::{From, Into};

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
    + Rem
    + BitAnd
    + BitAndAssign
    + BitOr
    + BitOrAssign
    + BitXor
    + BitXorAssign
    + From<usize>
    + Into<usize>
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
impl Rem for VirtAddress {
    type Output = Self;
    fn rem(self, rhs: Self) -> Self::Output {
        VirtAddress { base: self.base % rhs.base }
    }
}

impl Rem<usize> for VirtAddress {
   type Output = VirtAddress; 
   fn rem(self, rhs: usize) -> Self::Output {
       VirtAddress { base: self.base % rhs }
   }
}

impl Into<usize> for VirtAddress {
    fn into(self) -> usize {
        self.base  
    }
}

impl From<usize> for VirtAddress {
    fn from(base: usize) -> Self {
       VirtAddress { base } 
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

impl From<usize> for PhysAddress {
    fn from(base: usize) -> Self {
        PhysAddress { base } 
    }
}

impl Into<usize> for PhysAddress {
    fn into(self) -> usize {
        self.base
    }
}

impl Rem for PhysAddress {
    type Output = Self;
    fn rem(self, rhs: Self) -> Self::Output {
        PhysAddress { base: self.base % rhs.base }
    }
}

impl Rem<usize> for PhysAddress {
    type Output = Self;
    fn rem(self, rhs: usize) -> Self::Output {
        PhysAddress { base: self.base % rhs }
    }
}


