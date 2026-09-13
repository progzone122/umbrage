//! Single logging entry point: every line is printed to the console and
//! appended to the `Vec<String>` used by QML.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[allow(dead_code)]
pub enum Level {
    Debug,
    Info,
    Warn,
    Error,
}

impl Level {
    fn tag(self) -> &'static str {
        match self {
            Level::Debug => "DEBUG",
            Level::Info => "INFO",
            Level::Warn => "WARN",
            Level::Error => "ERROR",
        }
    }
}

pub fn record(logs: &mut Vec<String>, level: Level, message: &str) {
    let line = format!("[PENUMBRA] [{}] {}", level.tag(), message);
    println!("{line}");
    logs.push(line);
}

#[allow(dead_code)]
pub fn debug(logs: &mut Vec<String>, message: &str) {
    record(logs, Level::Debug, message);
}

pub fn info(logs: &mut Vec<String>, message: &str) {
    record(logs, Level::Info, message);
}

#[allow(dead_code)]
pub fn warn(logs: &mut Vec<String>, message: &str) {
    record(logs, Level::Warn, message);
}

pub fn error(logs: &mut Vec<String>, message: &str) {
    record(logs, Level::Error, message);
}
