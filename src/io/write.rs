pub trait Write {
    fn write(&mut self, buf: &[u8]) -> super::Result<usize> {
        Ok(0)
    }
}

