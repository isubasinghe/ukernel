pub mod read;
pub mod write;
pub mod error;

pub type Result<T> = core::result::Result<T, error::Error>;
