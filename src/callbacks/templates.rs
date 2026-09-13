use std::cell::Cell;
use std::sync::Arc;
use std::sync::atomic::Ordering;

use crate::callbacks::device::format_size;
use crate::logs;
use crate::state::AppState;

use qtbridge::{QObjectHolder, invoke_method};

use crate::templates::model::TemplateFile;
use crate::templates::{CANCELLED, fetch_meta_json, resolve_template_files, wait_cancelled};

pub fn request_get_templates(state: &mut AppState) {
    let invoker = state.get_qml_method_invoker();
    let cancel = Arc::clone(&state.templates_cancel);
    cancel.store(false, Ordering::SeqCst);

    std::thread::spawn(move || {
        // The runtime build can fail too, so fold both it and the fetch into
        // one result instead of panicking on expect().
        let result = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .map_err(|e| format!("Failed to start the network runtime: {e}"))
            .and_then(|runtime| {
                runtime.block_on(async {
                    // select! drops the fetch future on cancel, aborting the
                    // HTTP request instead of waiting for it.
                    tokio::select! {
                        result = fetch_meta_json() => result,
                        () = wait_cancelled(&cancel) => Err(CANCELLED.to_string()),
                    }
                })
            });

        match result {
            Ok(json) => invoke_method!(invoker, "templatesReady", json),
            Err(message) if message == CANCELLED => {
                invoke_method!(invoker, "templatesFetchCancelled")
            }
            Err(message) => invoke_method!(invoker, "templatesFetchFailed", message),
        }
    });
}

/// Sets the cancellation flag for whichever template operation is running.
pub fn cancel_loading(state: &mut AppState) {
    state.templates_cancel.store(true, Ordering::SeqCst);
}

pub fn templates_ready(state: &mut AppState, json: String) {
    state.repo = json;
    state.repo_changed();
}

/// Called on the UI thread when fetching or parsing meta.json failed.
pub fn templates_fetch_failed(state: &mut AppState, message: String) {
    logs::error(&mut state.logs, &message);
    state.logs_changed();
    state.templates_failed(message);
}

/// Called on the UI thread when the user aborted the meta.json fetch.
pub fn templates_fetch_cancelled(state: &mut AppState) {
    state.templates_load_cancelled();
}

/// Called on the UI thread when the user aborted the file downloads.
pub fn template_download_cancelled(state: &mut AppState) {
    state.template_files_cancelled();
}

/// Called on the UI thread for each whole percent of the file downloads.
pub fn template_download_progress(state: &mut AppState, message: String, percent: i32) {
    state.template_progress(message, percent);
}

pub fn download_template_files(state: &mut AppState, files_json: String) {
    let files: TemplateFile = match serde_json::from_str(&files_json) {
        Ok(f) => f,
        Err(e) => {
            state.append_log(format!("ERROR: Failed to parse template files: {e}"));
            return;
        }
    };

    let invoker = state.get_qml_method_invoker();
    let progress_invoker = state.get_qml_method_invoker();
    let cancel = Arc::clone(&state.templates_cancel);
    cancel.store(false, Ordering::SeqCst);

    std::thread::spawn(move || {
        let runtime = match tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
        {
            Ok(runtime) => runtime,
            Err(e) => {
                invoke_method!(
                    invoker,
                    "appendLog",
                    format!("ERROR: Failed to start the network runtime: {e}")
                );
                invoke_method!(invoker, "templateDownloadFailed", files_json);
                return;
            }
        };

        // Overall download progress: file 2 of 3 at 50% is 50%.
        let last_pct = Cell::new(-1i64);
        let progress = |name: &str, index: usize, count: usize, done: u64, total: u64| {
            let fraction = if total == 0 {
                0.0
            } else {
                done as f64 / total as f64
            };
            let pct = (((index as f64 + fraction) / count.max(1) as f64) * 100.0).round() as i64;
            if pct == last_pct.get() {
                return;
            }
            last_pct.set(pct);

            let text = if total == 0 {
                format!("{name}: {}", format_size(done as usize))
            } else {
                format!(
                    "{name}: {} / {}",
                    format_size(done as usize),
                    format_size(total as usize)
                )
            };
            invoke_method!(
                progress_invoker,
                "templateDownloadProgress",
                text,
                pct as i32
            );
        };

        let paths = match runtime.block_on(resolve_template_files(&files, &cancel, progress)) {
            Ok(p) => p,
            Err(message) if message == CANCELLED => {
                invoke_method!(invoker, "templateDownloadCancelled");
                return;
            }
            Err(e) => {
                invoke_method!(invoker, "appendLog", format!("ERROR: {e}"));
                invoke_method!(invoker, "templateDownloadFailed", files_json);
                return;
            }
        };

        invoke_method!(
            invoker,
            "applyDownloadedFiles",
            paths
                .da
                .map(|p| p.to_string_lossy().to_string())
                .unwrap_or_default(),
            paths
                .auth
                .map(|p| p.to_string_lossy().to_string())
                .unwrap_or_default(),
            paths
                .preloader
                .map(|p| p.to_string_lossy().to_string())
                .unwrap_or_default(),
        );
    });
}

pub fn apply_downloaded_files(state: &mut AppState, da: String, auth: String, preloader: String) {
    state.da_file = da;
    state.auth_file = auth;
    state.preloader_file = preloader;

    state.da_file_changed();
    state.auth_file_changed();
    state.preloader_file_changed();

    state.append_log("Template files ready".to_string());

    state.template_files_ready();
}

pub fn template_download_failed(state: &mut AppState, _files_json: String) {
    state.template_files_failed();
}
