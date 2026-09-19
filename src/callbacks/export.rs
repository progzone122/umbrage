use qtbridge::{QObjectHolder, invoke_method};

use crate::state::AppState;
use crate::templates::export::{ExportPayload, build_yaml};

/// Runs the export on a worker thread so hashing large DA files doesn't freeze
/// the UI, then reports the result back to QML.
pub fn export_template(state: &mut AppState, payload_json: String, dest: String) {
    let invoker = state.get_qml_method_invoker();

    std::thread::spawn(move || match build_export(&payload_json, &dest) {
        Ok(path) => invoke_method!(invoker, "exportResult", true, path),
        Err(message) => invoke_method!(invoker, "exportResult", false, message),
    });
}

fn build_export(payload_json: &str, dest: &str) -> Result<String, String> {
    let payload: ExportPayload = serde_json::from_str(payload_json)
        .map_err(|e| format!("Failed to parse export payload: {e}"))?;

    let yaml = build_yaml(&payload)?;

    let path = dest.trim_start_matches("file://");
    std::fs::write(path, yaml).map_err(|e| format!("Failed to write {path}: {e}"))?;

    Ok(path.to_string())
}

/// Runs on the UI thread once the worker finishes and forwards the result to
/// QML through a signal.
pub fn export_result(state: &mut AppState, success: bool, message: String) {
    if success {
        state.append_log(format!("Exported template: {message}"));
    } else {
        state.append_log(format!("ERROR: {message}"));
    }
    state.export_finished(success, message);
}
