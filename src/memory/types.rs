use core::ops::{
    Add, AddAssign, BitAnd, BitAndAssign, BitOr, BitOrAssign, BitXor, BitXorAssign, Div, Mul, Sub,
    SubAssign, Rem, Shl, Shr, Not
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
    Not,
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
    Not,
    Copy,
    Clone,
    Debug,
)]

#[repr(C)]
pub struct PhysAddress {
    base: usize,
}

pub trait MemoryAddress:
    Add<Output=Self>
    + AddAssign
    + Sub<Output=Self>
    + SubAssign
    + Mul 
    + Div
    + Rem
    + Shl<Output=Self>
    + Shr<Output=Self>
    + BitAnd<Output=Self>
    + BitAndAssign
    + BitOr<Output=Self>
    + BitOrAssign
    + BitXor<Output=Self>
    + BitXorAssign
    + Not<Output=Self>
    + From<usize>
    + Into<usize>
    + Sized
    + Copy 
    + Clone
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



impl Shl<usize> for VirtAddress {
    type Output = VirtAddress;
    fn shl(self, rhs: usize) -> Self::Output {
       VirtAddress { base: self.base.shl(rhs) } 
    }
}

impl Shl for VirtAddress {
    type Output = VirtAddress;
    fn shl(self, rhs: Self) -> Self::Output {
        VirtAddress { base: self.base.shl(rhs.base) }
    }
}

impl Shr<usize> for VirtAddress {
    type Output = Self;
    fn shr(self, rhs: usize) -> Self::Output {
        VirtAddress { base: self.base.shr(rhs) }
    }
}

impl Shr for VirtAddress {
    type Output = Self;
    fn shr(self, rhs: Self) -> Self::Output {
        VirtAddress { base: self.base.shr(rhs.base) }
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

impl Shl<usize> for PhysAddress {
    type Output = PhysAddress;
    fn shl(self, rhs: usize) -> Self::Output {
       PhysAddress { base: self.base.shl(rhs) } 
    }
}

impl Shl for PhysAddress {
    type Output = PhysAddress;
    fn shl(self, rhs: Self) -> Self::Output {
        PhysAddress { base: self.base.shl(rhs.base) }
    }
}

impl Shr<usize> for PhysAddress {
    type Output = Self;
    fn shr(self, rhs: usize) -> Self::Output {
        PhysAddress { base: self.base.shr(rhs) }
    }
}

impl Shr for PhysAddress {
    type Output = Self;
    fn shr(self, rhs: Self) -> Self::Output {
        PhysAddress { base: self.base.shr(rhs.base) }
    }
}

#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub struct MemoryRange<T: MemoryAddress> {
    pub start: T, 
    pub end: T
}
