use log::{Record, Level, Metadata};
use crate::{print, println};

pub struct UartLogger;

impl log::Log for UartLogger {
    fn enabled(&self, metadata: &Metadata) -> bool {
        metadata.level() <= Level::Info
    }

    fn log(&self, record: &Record) {
        if !self.enabled(record.metadata()) {
            return;
        }

        let file = record.file().unwrap_or("UNKNOWN");
        let line = record.line();

        match line {
            Some(line_num) => println!("[{}]|[{}:{}]| {}", record.level(), file, line_num, record.args()), 
            None => println!("[{}]|[{}]| {}", record.level(), file, record.args())
        };
    }

    fn flush(&self) {}
}
