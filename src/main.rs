mod callbacks;
mod icon_bridge;
mod logs;
mod platform;
mod state;
mod templates;

use std::env;

use qtbridge::QApp;

use state::AppState;

fn main() {
    init_logger();

    unsafe {
        std::env::set_var("QT_QUICK_CONTROLS_STYLE", "Fusion");
    }

    qtbridge::qresource::register_bytes(include_bytes!(concat!(env!("OUT_DIR"), "/resources.rcc")));

    let mut app = QApp::new();
    icon_bridge::set_window_icon(":/assets/umbrage-icon.svg");
    app.register::<AppState>()
        .add_import_path("qrc:/qml")
        .load_qml(include_bytes!("ui/Main.qml"))
        .run();
}

fn init_logger() {
    let verbose = env::args().any(|arg| arg == "-v" || arg == "--verbose");
    let level = if verbose {
        log::LevelFilter::Trace
    } else {
        log::LevelFilter::Info
    };

    env_logger::Builder::new()
        .filter_level(level)
        .filter_module("nusb", log::LevelFilter::Off)
        .target(env_logger::Target::Stdout)
        .init();
}
