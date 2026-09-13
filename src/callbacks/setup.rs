use qtbridge::{QObjectHolder, invoke_method};

use crate::platform;
use crate::state::AppState;

/// Returns true if the missing prerequisites can be installed automatically.
pub fn can_auto_install() -> bool {
    platform::can_auto_install()
}

/// Refresh the `need_setup`/`missing_setup` state and manual instruction, and
/// clear any previous error.
pub fn refresh(state: &mut AppState) {
    state.need_setup = platform::need_setup();
    state.missing_setup = platform::missing().join("\n");
    state.setup_error.clear();

    let instruction = if state.need_setup {
        platform::manual_instruction()
    } else {
        None
    };
    state.setup_hint = instruction
        .as_ref()
        .map(|i| i.hint.clone())
        .unwrap_or_default();
    state.setup_command = instruction.and_then(|i| i.command).unwrap_or_default();

    state.need_setup_changed();
    state.missing_setup_changed();
    state.setup_error_changed();
    state.setup_hint_changed();
    state.setup_command_changed();
}

/// Install the missing prerequisites. Runs on a worker thread: `pkexec` shows
/// its own authentication dialog, so it must not block the UI.
pub fn install(state: &mut AppState) {
    if !can_auto_install() {
        refresh(state);
        return;
    }

    if state.setup_installing {
        return;
    }

    state.setup_installing = true;
    state.setup_installing_changed();
    state.setup_error.clear();
    state.setup_error_changed();

    let invoker = state.get_qml_method_invoker();
    std::thread::spawn(move || match platform::install_elevated() {
        Ok(()) => invoke_method!(invoker, "setupInstallFinished", true, String::new()),
        Err(error) => invoke_method!(invoker, "setupInstallFinished", false, error),
    });
}

/// Called on the UI thread once [`install`] finishes.
pub fn install_finished(state: &mut AppState, success: bool, message: String) {
    state.setup_installing = false;
    state.setup_installing_changed();

    refresh(state);

    if success {
        return;
    }

    state.setup_error = message;
    state.setup_error_changed();

    // Offer a manual fallback.
    #[cfg(target_os = "linux")]
    if let Some(dir) = platform::generated_rules_dir() {
        state.setup_hint = format!(
            "If that did not work, install the rules from {} manually:",
            dir.display()
        );
        state.setup_command = platform::rules_install_command(&dir);
        state.setup_hint_changed();
        state.setup_command_changed();
    }
}
