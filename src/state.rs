use std::env;
use std::sync::atomic::AtomicBool;
use std::sync::mpsc::Sender;
use std::sync::{Arc, Mutex};

use qtbridge::qobject;

use crate::callbacks;
use crate::callbacks::device::DeviceCommand;

// Keep in sync with the page constants in Main.qml.
#[repr(u8)]
#[allow(dead_code)]
pub enum Page {
    Steps = 0,
    WaitConnection = 1,
    Main = 2,
    Templates = 3,
    Setup = 4,
}

pub struct AppState {
    pub(crate) page: u8,
    pub(crate) skip_conn_page: bool,
    pub(crate) da_file: String,
    pub(crate) auth_file: String,
    pub(crate) preloader_file: String,
    pub(crate) logs: Vec<String>,
    pub(crate) repo: serde_json::Value,
    pub(crate) connected: bool,
    pub(crate) connecting: bool,
    pub(crate) chip_name: String,
    pub(crate) chip_platform: String,
    pub(crate) device_name: String,
    pub(crate) selected_codename: String,
    pub(crate) connection_error: String,
    pub(crate) device_tx: Arc<Mutex<Option<Sender<DeviceCommand>>>>,
    pub(crate) need_setup: bool,
    pub(crate) missing_setup: String,
    pub(crate) setup_error: String,
    pub(crate) setup_hint: String,
    pub(crate) setup_command: String,
    pub(crate) setup_installing: bool,
    pub(crate) templates_cancel: Arc<AtomicBool>,
}

#[qobject(Singleton, ConvertToCamelCase)]
impl AppState {
    qproperty!("page", Member = page, Notify = page_changed);
    qproperty!(
        "skip_conn_page",
        Member = skip_conn_page,
        Notify = skip_conn_page_changed
    );
    qproperty!("da_file", Member = da_file, Notify = da_file_changed);
    qproperty!("auth_file", Member = auth_file, Notify = auth_file_changed);
    qproperty!(
        "preloader_file",
        Member = preloader_file,
        Notify = preloader_file_changed
    );
    qproperty!("logs", Member = logs, Notify = logs_changed);
    qproperty!("repo", Member = repo, Notify = repo_changed);
    qproperty!("connected", Member = connected, Notify = connected_changed);
    qproperty!(
        "connecting",
        Member = connecting,
        Notify = connecting_changed
    );
    qproperty!("chip_name", Member = chip_name, Notify = chip_name_changed);
    qproperty!(
        "device_name",
        Member = device_name,
        Notify = device_name_changed
    );
    qproperty!(
        "selected_codename",
        Member = selected_codename,
        Notify = selected_codename_changed
    );
    qproperty!(
        "connection_error",
        Member = connection_error,
        Notify = connection_error_changed
    );
    qproperty!(
        "need_setup",
        Member = need_setup,
        Notify = need_setup_changed
    );
    qproperty!(
        "missing_setup",
        Member = missing_setup,
        Notify = missing_setup_changed
    );
    qproperty!(
        "setup_error",
        Member = setup_error,
        Notify = setup_error_changed
    );
    qproperty!(
        "setup_hint",
        Member = setup_hint,
        Notify = setup_hint_changed
    );
    qproperty!(
        "setup_command",
        Member = setup_command,
        Notify = setup_command_changed
    );
    qproperty!(
        "setup_installing",
        Member = setup_installing,
        Notify = setup_installing_changed
    );

    #[qsignal]
    pub(crate) fn page_changed(&mut self);

    #[qsignal]
    pub(crate) fn skip_conn_page_changed(&mut self);

    #[qsignal]
    pub(crate) fn da_file_changed(&mut self);

    #[qsignal]
    pub(crate) fn auth_file_changed(&mut self);

    #[qsignal]
    pub(crate) fn preloader_file_changed(&mut self);

    #[qsignal]
    pub(crate) fn logs_changed(&mut self);

    #[qsignal]
    pub(crate) fn repo_changed(&mut self);

    #[qsignal]
    pub(crate) fn connected_changed(&mut self);

    #[qsignal]
    pub(crate) fn connecting_changed(&mut self);

    #[qsignal]
    pub(crate) fn chip_name_changed(&mut self);

    #[qsignal]
    pub(crate) fn device_name_changed(&mut self);

    #[qsignal]
    pub(crate) fn selected_codename_changed(&mut self);

    #[qsignal]
    pub(crate) fn connection_error_changed(&mut self);

    #[qsignal]
    pub(crate) fn need_setup_changed(&mut self);

    #[qsignal]
    pub(crate) fn missing_setup_changed(&mut self);

    #[qsignal]
    pub(crate) fn setup_error_changed(&mut self);

    #[qsignal]
    pub(crate) fn setup_hint_changed(&mut self);

    #[qsignal]
    pub(crate) fn setup_command_changed(&mut self);

    #[qsignal]
    pub(crate) fn setup_installing_changed(&mut self);

    #[qsignal]
    pub(crate) fn template_files_ready(&mut self);

    #[qsignal]
    pub(crate) fn template_files_failed(&mut self);

    #[qsignal]
    pub(crate) fn templates_failed(&mut self, message: String);

    #[qsignal]
    pub(crate) fn templates_load_cancelled(&mut self);

    #[qsignal]
    pub(crate) fn template_files_cancelled(&mut self);

    #[qsignal]
    pub(crate) fn template_progress(&mut self, message: String, percent: i32);

    #[qsignal]
    pub(crate) fn export_finished(&mut self, success: bool, message: String);

    #[qsignal]
    pub(crate) fn bootloader_lock_finished(&mut self, success: bool, message: String);

    #[qsignal]
    pub(crate) fn action_progress(&mut self, message: String);

    #[qsignal]
    pub(crate) fn reboot_to_mode_finished(&mut self, success: bool, message: String);

    #[qsignal]
    pub(crate) fn partition_progress(&mut self, message: String, percent: i32);

    #[qsignal]
    pub(crate) fn partition_log(&mut self, message: String);

    #[qsignal]
    pub(crate) fn partition_finished(&mut self, success: bool, message: String);

    #[qsignal]
    pub(crate) fn partitions_loaded(&mut self, partitions: Vec<serde_json::Value>);

    #[qsignal]
    pub(crate) fn scatter_file_loaded(&mut self, entries: Vec<serde_json::Value>);

    #[qsignal]
    pub(crate) fn scatter_file_failed(&mut self, message: String);

    #[qsignal]
    pub(crate) fn active_slot_loaded(&mut self, slot: String);

    #[qslot]
    fn request_get_templates(&mut self) {
        callbacks::templates::request_get_templates(self);
    }

    #[qslot]
    fn templates_ready(&mut self, repo: serde_json::Value) {
        callbacks::templates::templates_ready(self, repo);
    }

    #[qslot]
    fn templates_fetch_failed(&mut self, message: String) {
        callbacks::templates::templates_fetch_failed(self, message);
    }

    #[qslot]
    fn templates_fetch_cancelled(&mut self) {
        callbacks::templates::templates_fetch_cancelled(self);
    }

    #[qslot]
    fn template_download_cancelled(&mut self) {
        callbacks::templates::template_download_cancelled(self);
    }

    #[qslot]
    fn template_download_progress(&mut self, message: String, percent: i32) {
        callbacks::templates::template_download_progress(self, message, percent);
    }

    #[qslot]
    fn cancel_templates_loading(&mut self) {
        callbacks::templates::cancel_loading(self);
    }

    #[qslot]
    fn download_template_files(&mut self, files: serde_json::Value) {
        callbacks::templates::download_template_files(self, files);
    }

    #[qslot]
    fn apply_downloaded_files(&mut self, da: String, auth: String, preloader: String) {
        callbacks::templates::apply_downloaded_files(self, da, auth, preloader);
    }

    #[qslot]
    fn template_download_failed(&mut self) {
        callbacks::templates::template_download_failed(self);
    }

    #[qslot]
    fn export_template(&mut self, payload: serde_json::Value, dest: String) {
        callbacks::export::export_template(self, payload, dest);
    }

    #[qslot]
    fn export_result(&mut self, success: bool, message: String) {
        callbacks::export::export_result(self, success, message);
    }

    #[qslot]
    fn connect_device(&mut self) {
        callbacks::device::connect_device(self);
    }

    #[qslot]
    pub(crate) fn append_log(&mut self, message: String) {
        callbacks::device::append_log(self, message);
    }

    #[qslot]
    fn connection_finished(
        &mut self,
        success: bool,
        message: String,
        chip_name: String,
        chip_platform: String,
    ) {
        callbacks::device::connection_finished(self, success, message, chip_name, chip_platform);
    }

    #[qslot]
    fn disconnect_device(&mut self) {
        callbacks::device::disconnect_device(self);
    }

    #[qslot]
    fn unlock_bootloader(&mut self) {
        callbacks::device::set_bootloader_lock(self, true);
    }

    #[qslot]
    fn lock_bootloader(&mut self) {
        callbacks::device::set_bootloader_lock(self, false);
    }

    #[qslot]
    fn read_partitions(&mut self, partitions: serde_json::Value, directory: String) {
        callbacks::device::read_partitions(self, partitions, directory);
    }

    #[qslot]
    fn write_partitions(&mut self, partitions: serde_json::Value) {
        callbacks::device::write_partitions(self, partitions);
    }

    #[qslot]
    fn request_partitions(&mut self) {
        callbacks::device::request_partitions(self);
    }

    #[qslot]
    fn load_scatter_file(&mut self, path: String) {
        callbacks::scatter::load_scatter_file(self, path);
    }

    #[qslot]
    fn setup_can_auto_install(&mut self) -> bool {
        callbacks::setup::can_auto_install()
    }

    #[qslot]
    fn refresh_setup(&mut self) {
        callbacks::setup::refresh(self);
    }

    #[qslot]
    fn install_missing(&mut self) {
        callbacks::setup::install(self);
    }

    #[qslot]
    fn setup_install_finished(&mut self, success: bool, message: String) {
        callbacks::setup::install_finished(self, success, message);
    }

    #[qslot]
    fn reboot_to_mode(&mut self, mode: String) {
        let mode = match mode.as_str() {
            "normal" => penumbra_mtk::BootMode::Normal,
            "home_screen" => penumbra_mtk::BootMode::HomeScreen,
            "fastboot" => penumbra_mtk::BootMode::Fastboot,
            "test" => penumbra_mtk::BootMode::Test,
            "meta" => penumbra_mtk::BootMode::Meta,
            _ => panic!("unknown boot mode: {mode}"),
        };

        callbacks::device::reboot_to_mode(self, mode);
    }

    #[qslot]
    fn request_get_active_slot(&mut self) {
        callbacks::device::get_active_slot(self);
    }
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            da_file: String::new(),
            auth_file: String::new(),
            preloader_file: String::new(),
            page: Page::Steps as u8,
            skip_conn_page: env::args().any(|arg| arg == "--skip-conn"),
            logs: Vec::new(),
            repo: serde_json::Value::Null,
            connected: false,
            connecting: false,
            chip_name: String::new(),
            chip_platform: String::new(),
            device_name: String::new(),
            selected_codename: String::new(),
            connection_error: String::new(),
            device_tx: Arc::new(Mutex::new(None)),
            need_setup: false,
            missing_setup: String::new(),
            setup_error: String::new(),
            setup_hint: String::new(),
            setup_command: String::new(),
            setup_installing: false,
            templates_cancel: Arc::new(AtomicBool::new(false)),
        }
    }
}
