use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::mpsc::{self, Receiver, Sender};

use qtbridge::{QObjectHolder, QmlMethodInvoker, invoke_method};

use penumbra_mtk::hacc::LockState;
use penumbra_mtk::port::{MtkPort, PortBackend, PortType};

use crate::logs;
use crate::state::{AppState, Page};

/// A command sent to the worker thread that owns the `Device`.
///
/// `Device` isn't `Send`, so it stays on the thread that created it and every
/// operation is routed there over an mpsc channel.
pub(crate) enum DeviceCommand {
    Connect {
        da: &'static [u8],
        auth: Option<&'static [u8]>,
        preloader: Option<&'static [u8]>,
        invoker: QmlMethodInvoker,
    },
    Disconnect,
    SetBootloaderLock {
        unlock: bool,
        invoker: QmlMethodInvoker,
    },
    ReadPartitions {
        targets: Vec<PartitionTarget>,
        directory: String,
        log_invoker: QmlMethodInvoker,
        progress_invokers: Vec<QmlMethodInvoker>,
    },
    WritePartitions {
        targets: Vec<PartitionTarget>,
        log_invoker: QmlMethodInvoker,
        progress_invokers: Vec<QmlMethodInvoker>,
    },
    RequestPartitions {
        invoker: QmlMethodInvoker,
    },
}

/// Spawns the device worker thread and returns the command sender. The worker
/// owns `Option<Device>` and processes commands one at a time, keeping the
/// connection alive between operations.
pub(crate) fn spawn_device_worker() -> Sender<DeviceCommand> {
    let (tx, rx) = mpsc::channel::<DeviceCommand>();

    std::thread::spawn(move || {
        worker_loop(rx);
    });

    tx
}

fn worker_loop(rx: Receiver<DeviceCommand>) {
    // The device lives only on this thread.
    let mut device: Option<penumbra_mtk::Device<'static, PortType>> = None;

    while let Ok(cmd) = rx.recv() {
        match cmd {
            DeviceCommand::Connect {
                da,
                auth,
                preloader,
                invoker,
            } => {
                connect_on_worker(&mut device, da, auth, preloader, &invoker);
            }
            DeviceCommand::Disconnect => {
                device = None;
            }
            DeviceCommand::SetBootloaderLock { unlock, invoker } => {
                if let Some(dev) = device.as_mut() {
                    set_bootloader_lock_on_worker(dev, unlock, &invoker);
                } else {
                    invoke_method!(
                        invoker,
                        "bootloaderLockFinished",
                        false,
                        "No device connected".to_string()
                    );
                }
            }
            DeviceCommand::ReadPartitions {
                targets,
                directory,
                log_invoker,
                progress_invokers,
            } => {
                if let Some(dev) = device.as_mut() {
                    run_partitions_on_worker(
                        dev,
                        targets,
                        true,
                        &directory,
                        &log_invoker,
                        progress_invokers,
                    );
                } else {
                    invoke_method!(log_invoker, "partitionsLoaded", "[]".to_string());
                }
            }
            DeviceCommand::WritePartitions {
                targets,
                log_invoker,
                progress_invokers,
            } => {
                if let Some(dev) = device.as_mut() {
                    run_partitions_on_worker(
                        dev,
                        targets,
                        false,
                        "",
                        &log_invoker,
                        progress_invokers,
                    );
                }
            }
            DeviceCommand::RequestPartitions { invoker } => {
                if let Some(dev) = device.as_mut() {
                    let partitions = dev.partitions();
                    let json: serde_json::Value = partitions
                        .iter()
                        .map(|p| {
                            serde_json::json!({
                                "name": p.name,
                                "size": format_size(p.size),
                            })
                        })
                        .collect();
                    invoke_method!(invoker, "partitionsLoaded", json.to_string());
                } else {
                    invoke_method!(invoker, "partitionsLoaded", "[]".to_string());
                }
            }
        }
    }
}

/// Waits for an MTK device, connects, handshakes and enters DA mode.
fn connect_on_worker(
    device: &mut Option<penumbra_mtk::Device<'static, PortType>>,
    da: &'static [u8],
    auth: Option<&'static [u8]>,
    preloader: Option<&'static [u8]>,
    invoker: &QmlMethodInvoker,
) {
    let log = |msg: String| {
        invoke_method!(invoker, "appendLog", msg);
    };

    log("Waiting for MTK USB device...".to_string());
    let port = loop {
        match PortType::find_and_open(None, None, PortBackend::Auto) {
            Ok(Some(p)) => {
                log(format!("Port found: {}", p.get_port_name()));
                break p;
            }
            Ok(None) => {}
            Err(e) => log(format!("Port scan error: {e}")),
        }
        std::thread::sleep(std::time::Duration::from_millis(500));
    };

    let mut builder = penumbra_mtk::DeviceBuilder::new(port).with_da_data(da);
    if let Some(auth) = auth {
        builder = builder.with_auth(auth);
    }
    if let Some(preloader) = preloader {
        builder = builder.with_preloader(preloader);
    }

    log("Building Device...".to_string());
    let mut dev = match builder.build() {
        Ok(d) => {
            log("Device built successfully".to_string());
            d
        }
        Err(e) => {
            invoke_method!(
                invoker,
                "connectionFinished",
                false,
                format!("Build failed: {e}"),
                "".to_string(),
                "".to_string()
            );
            return;
        }
    };

    log("Initializing device (handshake)...".to_string());
    if let Err(e) = dev.init() {
        invoke_method!(
            invoker,
            "connectionFinished",
            false,
            format!("Init failed: {e}"),
            "".to_string(),
            "".to_string()
        );
        return;
    }
    log("Handshake complete".to_string());
    let chip_label = dev
        .devinfo()
        .chip()
        .map(|c| c.to_string())
        .unwrap_or_default();
    log(format!(
        "Device info: HW=0x{:04X}, Chip={}, Mode={:?}",
        dev.devinfo().hw_code(),
        chip_label,
        dev.get_connection_type(),
    ));

    log("Entering DA mode...".to_string());
    if let Err(e) = dev.enter_da_mode() {
        invoke_method!(
            invoker,
            "connectionFinished",
            false,
            format!("DA mode failed: {e}"),
            "".to_string(),
            "".to_string()
        );
        return;
    }
    log("DA mode OK".to_string());

    let chip = dev.devinfo().chip();
    // Clean platform identifier (like "MT6768") used to match the scatter
    // file's `platform` field. `Debug` on SoC prints the variant name.
    let chip_platform = chip.map(|c| format!("{c:?}")).unwrap_or_default();
    let chip_name = chip.map(|c| c.to_string()).unwrap_or_default();

    *device = Some(dev);
    log("Device stored in App state".to_string());

    invoke_method!(
        invoker,
        "connectionFinished",
        true,
        "".to_string(),
        chip_name,
        chip_platform
    );
}

fn set_bootloader_lock_on_worker(
    dev: &mut penumbra_mtk::Device<'static, PortType>,
    unlock: bool,
    invoker: &QmlMethodInvoker,
) {
    let action = if unlock { "Unlock" } else { "Lock" };
    let label = action.to_lowercase();
    let log = |msg: String| {
        invoke_method!(invoker, "appendLog", msg.clone());
        invoke_method!(invoker, "bootloaderLockProgress", msg);
    };

    log(format!("[{action}] Acquiring device handle..."));
    log(format!(
        "[{action}] Device acquired: HW=0x{:04X}",
        dev.devinfo().hw_code(),
    ));

    let flag = if unlock {
        LockState::Unlock
    } else {
        LockState::Lock
    };

    log(format!(
        "[{action}] Preparing to {label} bootloader (seccfg) — flag={label}..."
    ));

    match dev.set_seccfg_lock_state(flag) {
        Ok(()) => {
            log(format!("[{action}] Bootloader {label}ed successfully."));
            log("[NOTE] Reboot the device to apply the new lock state.".to_string());
            invoke_method!(
                invoker,
                "bootloaderLockFinished",
                true,
                format!("Bootloader {label}ed successfully.")
            );
        }
        Err(e) => {
            let msg = format!(
                "Failed to {label} the bootloader: {e}. The device may not support this operation, DA may be protected, or seccfg could not be parsed/written. No changes were applied."
            );
            log(format!("[{action}] ERROR: {msg}"));
            invoke_method!(invoker, "bootloaderLockFinished", false, msg);
        }
    }
}

#[derive(serde::Deserialize, Clone)]
pub(crate) struct PartitionTarget {
    name: String,
    #[serde(default)]
    file: String,
}

// Reports the progress of the whole operation, not just the current
// partition: partition 2 of 4 at 50% is 37%. Fires only on a whole-percent
// change.
fn report_progress(
    invoker: &QmlMethodInvoker,
    name: &str,
    index: usize,
    count: usize,
    pct_cell: &AtomicI64,
    done: usize,
    total: usize,
) {
    let fraction = if total == 0 {
        1.0
    } else {
        done as f64 / total as f64
    };
    let pct = (((index as f64 + fraction) / count.max(1) as f64) * 100.0).round() as i64;

    if pct == pct_cell.load(Ordering::Relaxed) {
        return;
    }
    pct_cell.store(pct, Ordering::Relaxed);

    invoke_method!(
        invoker,
        "partitionProgress",
        format!("{name}: {} / {}", format_size(done), format_size(total)),
        pct as i32
    );
}

// Replaces path separators so a partition name can't escape the output dir.
fn sanitize_file_name(name: &str) -> String {
    name.chars()
        .map(|c| {
            if c == '/' || c == '\\' || c == ':' {
                '_'
            } else {
                c
            }
        })
        .collect()
}

fn run_partitions_on_worker(
    dev: &mut penumbra_mtk::Device<'static, PortType>,
    targets: Vec<PartitionTarget>,
    read: bool,
    directory: &str,
    log_invoker: &QmlMethodInvoker,
    progress_invokers: Vec<QmlMethodInvoker>,
) {
    let log = |msg: String| {
        invoke_method!(log_invoker, "appendLog", msg.clone());
        invoke_method!(log_invoker, "partitionLog", msg);
    };

    let verb = if read { "Reading" } else { "Writing" };
    let count = targets.len();
    let mut failures = 0usize;

    for (index, (target, progress_invoker)) in targets
        .into_iter()
        .zip(progress_invokers.into_iter())
        .enumerate()
    {
        let name = target.name.clone();

        if read {
            let file_name = sanitize_file_name(&name);
            let path = format!("{directory}/{file_name}.img");
            log(format!("{verb} partition '{name}' -> {path}..."));

            let mut file = match std::fs::File::create(&path) {
                Ok(f) => f,
                Err(e) => {
                    log(format!("ERROR: Failed to create {path}: {e}"));
                    failures += 1;
                    continue;
                }
            };

            let pct_cell = AtomicI64::new(-1);
            let inv = progress_invoker;
            let n = name.clone();
            let res = dev.read_partition(&name, &mut file, move |done, total| {
                report_progress(&inv, &n, index, count, &pct_cell, done, total);
            });

            if let Err(e) = res {
                log(format!("ERROR: Failed to read '{name}': {e}"));
                failures += 1;
            } else {
                log(format!("Finished reading '{name}'."));
            }
        } else {
            if target.file.is_empty() {
                log(format!("ERROR: No file chosen for partition '{name}'."));
                failures += 1;
                continue;
            }

            let src_path = target.file.trim_start_matches("file://").to_string();
            log(format!("{verb} partition '{name}' <- {src_path}..."));

            let mut file = match std::fs::File::open(&src_path) {
                Ok(f) => f,
                Err(e) => {
                    log(format!("ERROR: Failed to open {src_path}: {e}"));
                    failures += 1;
                    continue;
                }
            };

            let size = match file.metadata() {
                Ok(m) => m.len() as usize,
                Err(e) => {
                    log(format!("ERROR: Failed to stat {src_path}: {e}"));
                    failures += 1;
                    continue;
                }
            };

            let pct_cell = AtomicI64::new(-1);
            let inv = progress_invoker;
            let n = name.clone();
            let res = dev.write_partition(&name, size, &mut file, move |done, total| {
                report_progress(&inv, &n, index, count, &pct_cell, done, total);
            });

            if let Err(e) = res {
                log(format!("ERROR: Failed to write '{name}': {e}"));
                failures += 1;
            } else {
                log(format!("Finished writing '{name}'."));
            }
        }
    }

    if failures == 0 {
        invoke_method!(
            log_invoker,
            "partitionFinished",
            true,
            format!("{verb} completed for {n} partition(s).", n = count)
        );
    } else {
        invoke_method!(
            log_invoker,
            "partitionFinished",
            false,
            format!(
                "{verb} finished with {failures} error(s) out of {n} partition(s).",
                n = count
            )
        );
    }
}

// Formats a byte count as a compact string (e.g. `3.5GB`).
pub(crate) fn format_size(bytes: usize) -> String {
    const UNITS: [&str; 5] = ["B", "KB", "MB", "GB", "TB"];

    let mut value = bytes as f64;
    let mut unit = 0usize;

    while value >= 1024.0 && unit < UNITS.len() - 1 {
        value /= 1024.0;
        unit += 1;
    }

    if unit == 0 {
        format!("{bytes}{}", UNITS[unit])
    } else {
        format!("{value:.1}{}", UNITS[unit])
    }
}

// ---------------------------------------------------------------------------
// Public entry points (QObject slots). These only enqueue commands to the
// worker; actual device I/O happens there.
// ---------------------------------------------------------------------------

pub fn connect_device(state: &mut AppState) {
    if state.connecting || state.connected {
        return;
    }

    state.connecting = true;
    state.connecting_changed();
    state.connection_error.clear();
    state.connection_error_changed();

    let da_path = state.da_file.trim_start_matches("file://").to_string();
    let auth_path = state.auth_file.trim_start_matches("file://").to_string();
    let preloader_path = state
        .preloader_file
        .trim_start_matches("file://")
        .to_string();

    state.append_log(format!("DA path: {da_path}"));
    state.append_log(format!("AUTH path: {auth_path}"));
    state.append_log(format!("PRELOADER path: {preloader_path}"));

    let da_data = std::fs::read(&da_path).ok();
    let auth_data = if auth_path.is_empty() {
        None
    } else {
        std::fs::read(&auth_path).ok()
    };
    let preloader_data = if preloader_path.is_empty() {
        None
    } else {
        std::fs::read(&preloader_path).ok()
    };

    state.append_log(format!(
        "Files loaded: DA={}, AUTH={}, PRELOADER={}",
        da_data.as_ref().map_or("no", |_| "yes"),
        auth_data.as_ref().map_or("skipped", |_| "yes"),
        preloader_data.as_ref().map_or("skipped", |_| "yes"),
    ));

    // The worker owns the Device for its whole life, so the file buffers
    // must outlive the worker: leak them into 'static slices.
    let da = da_data
        .as_ref()
        .map(|v| Box::leak(v.clone().into_boxed_slice()));
    let auth = auth_data
        .as_ref()
        .map(|v| Box::leak(v.clone().into_boxed_slice()));
    let preloader = preloader_data
        .as_ref()
        .map(|v| Box::leak(v.clone().into_boxed_slice()));

    let invoker = state.get_qml_method_invoker();

    let tx = {
        let mut slot = state.device_tx.lock().unwrap();
        if slot.is_none() {
            *slot = Some(spawn_device_worker());
        }
        slot.as_ref().unwrap().clone()
    };

    let da: &'static [u8] = da.map(|s| &*s).unwrap_or(&[]);
    let auth: Option<&'static [u8]> = auth.map(|s| &*s);
    let preloader: Option<&'static [u8]> = preloader.map(|s| &*s);

    let _ = tx.send(DeviceCommand::Connect {
        da,
        auth,
        preloader,
        invoker,
    });
}

pub fn connection_finished(
    state: &mut AppState,
    success: bool,
    message: String,
    chip_name: String,
    chip_platform: String,
) {
    state.connecting = false;
    state.connecting_changed();

    if success {
        state.connected = true;
        state.connected_changed();
        state.chip_name = chip_name;
        state.chip_name_changed();
        state.chip_platform = chip_platform;
        state.page = Page::Main as u8;
        state.page_changed();
    } else {
        logs::error(&mut state.logs, &message);
        state.logs_changed();
        state.connection_error = message;
        state.connection_error_changed();
    }
}

pub fn disconnect_device(state: &mut AppState) {
    if let Some(tx) = state.device_tx.lock().unwrap().as_ref() {
        let _ = tx.send(DeviceCommand::Disconnect);
    }

    state.connected = false;
    state.connected_changed();
    state.connecting = false;
    state.connecting_changed();

    state.chip_name.clear();
    state.chip_name_changed();
    state.chip_platform.clear();
    state.device_name.clear();
    state.device_name_changed();

    state.da_file.clear();
    state.da_file_changed();
    state.auth_file.clear();
    state.auth_file_changed();
    state.preloader_file.clear();
    state.preloader_file_changed();

    state.connection_error.clear();
    state.connection_error_changed();

    logs::info(&mut state.logs, "Device disconnected");
    state.logs_changed();

    state.page = Page::Steps as u8;
    state.page_changed();
}

pub fn append_log(state: &mut AppState, message: String) {
    logs::info(&mut state.logs, &message);
    state.logs_changed();
}

pub fn set_bootloader_lock(state: &mut AppState, unlock: bool) {
    if !state.connected {
        state.bootloader_lock_progress("ERROR: No device connected".to_string());
        state.append_log("ERROR: No device connected".to_string());
        return;
    }

    let invoker = state.get_qml_method_invoker();

    let tx = match state.device_tx.lock().unwrap().as_ref() {
        Some(tx) => tx.clone(),
        None => {
            invoke_method!(
                invoker,
                "bootloaderLockFinished",
                false,
                "No device connection available".to_string()
            );
            return;
        }
    };

    let _ = tx.send(DeviceCommand::SetBootloaderLock { unlock, invoker });
}

pub fn read_partitions(state: &mut AppState, partitions_json: String, directory: String) {
    let targets: Vec<PartitionTarget> = match serde_json::from_str(&partitions_json) {
        Ok(t) => t,
        Err(e) => {
            state.partition_progress(format!("ERROR: Failed to parse partitions: {e}"), -1);
            state.append_log(format!("ERROR: Failed to parse partitions: {e}"));
            return;
        }
    };

    let directory = directory.trim_start_matches("file://").to_string();

    if !state.connected {
        state.partition_progress("ERROR: No device connected".to_string(), -1);
        state.append_log("ERROR: No device connected".to_string());
        return;
    }

    if targets.is_empty() {
        state.partition_progress("ERROR: No partitions selected".to_string(), -1);
        state.append_log("ERROR: No partitions selected".to_string());
        return;
    }

    let log_invoker = state.get_qml_method_invoker();
    let progress_invokers: Vec<QmlMethodInvoker> = (0..targets.len())
        .map(|_| state.get_qml_method_invoker())
        .collect();

    let tx = { state.device_tx.lock().unwrap().clone() };
    let Some(tx) = tx else {
        state.partition_progress("ERROR: No device connection available".to_string(), -1);
        return;
    };

    let _ = tx.send(DeviceCommand::ReadPartitions {
        targets,
        directory,
        log_invoker,
        progress_invokers,
    });
}

pub fn write_partitions(state: &mut AppState, partitions_json: String) {
    let targets: Vec<PartitionTarget> = match serde_json::from_str(&partitions_json) {
        Ok(t) => t,
        Err(e) => {
            state.partition_progress(format!("ERROR: Failed to parse partitions: {e}"), -1);
            state.append_log(format!("ERROR: Failed to parse partitions: {e}"));
            return;
        }
    };

    if !state.connected {
        state.partition_progress("ERROR: No device connected".to_string(), -1);
        state.append_log("ERROR: No device connected".to_string());
        return;
    }

    if targets.is_empty() {
        state.partition_progress("ERROR: No partitions selected".to_string(), -1);
        state.append_log("ERROR: No partitions selected".to_string());
        return;
    }

    let log_invoker = state.get_qml_method_invoker();
    let progress_invokers: Vec<QmlMethodInvoker> = (0..targets.len())
        .map(|_| state.get_qml_method_invoker())
        .collect();

    let tx = { state.device_tx.lock().unwrap().clone() };
    let Some(tx) = tx else {
        state.partition_progress("ERROR: No device connection available".to_string(), -1);
        return;
    };

    let _ = tx.send(DeviceCommand::WritePartitions {
        targets,
        log_invoker,
        progress_invokers,
    });
}

pub fn request_partitions(state: &mut AppState) {
    if !state.connected {
        state.partitions_loaded("[]".to_string());
        return;
    }

    let invoker = state.get_qml_method_invoker();

    let tx = match state.device_tx.lock().unwrap().as_ref() {
        Some(tx) => tx.clone(),
        None => {
            invoke_method!(invoker, "partitionsLoaded", "[]".to_string());
            return;
        }
    };

    let _ = tx.send(DeviceCommand::RequestPartitions { invoker });
}
