pub trait Read {
    fn read(&mut self, buf: &mut [u8]) -> super::Result<usize> {
        Ok(0)
    }
    fn one(&mut self) -> Option<u8> {
        None
    }
}
