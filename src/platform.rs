//! Platform-specific prerequisite detection and installation.
//!
//! What penumbra needs differs per platform:
//!   * Linux — three udev rules from `mtkclient`, either under
//!     `/etc/udev/rules.d` or the distro-managed `/usr/lib/udev/rules.d`.
//!     When they are missing the app only generates them in a user-writable
//!     directory; installing them system-wide is left to the user.
//!   * macOS — the nusb backend (the default) talks straight to IOKit via
//!     USBInterfaceOpen, so no root or entitlement is needed.
//!   * Windows — a WinUSB/libusbK/libusb0 driver bound to the MediaTek USB
//!     device. No automatic install; the user adds it with Zadig.
//!
//! In debug builds, `UMBRAGE_FORCE_SETUP` fakes a missing prerequisite so you
//! can exercise the setup page on machines where nothing is actually missing.

/// The directory where udev rules are installed system-wide on Linux.
#[cfg(target_os = "linux")]
const UDEV_RULES_DIR: &str = "/etc/udev/rules.d";

/// Directories searched for installed udev rules, admin-managed first.
#[cfg(target_os = "linux")]
const UDEV_RULES_DIRS: [&str; 2] = [UDEV_RULES_DIR, "/usr/lib/udev/rules.d"];

/// The three udev rule files mtkclient ships in `Setup/Linux`.
#[cfg(target_os = "linux")]
pub const UDEV_RULE_FILES: [&str; 3] = ["50-android.rules", "51-edl.rules", "52-mtk.rules"];

/// Contents of each udev rule, keyed by file name. Kept in sync with
/// <https://github.com/bkerler/mtkclient/tree/main/Setup/Linux>
#[cfg(target_os = "linux")]
pub fn udev_rule_contents(file: &str) -> Option<&'static str> {
    match file {
        "50-android.rules" => Some(include_str!("udev/50-android.rules")),
        "51-edl.rules" => Some(include_str!("udev/51-edl.rules")),
        "52-mtk.rules" => Some(include_str!("udev/52-mtk.rules")),
        _ => None,
    }
}

/// Returns true if the current OS needs any system prerequisite setup.
pub fn need_setup() -> bool {
    !missing().is_empty()
}

/// Environment variable that fakes a missing prerequisite (debug builds only).
const FORCE_SETUP_ENV: &str = "UMBRAGE_FORCE_SETUP";

/// Returns true when the setup flow is forced through [`FORCE_SETUP_ENV`].
fn setup_forced() -> bool {
    cfg!(debug_assertions)
        && std::env::var_os(FORCE_SETUP_ENV).is_some_and(|value| !value.is_empty())
}

/// Returns the human-readable name of each missing prerequisite.
pub fn missing() -> Vec<String> {
    if setup_forced() {
        return vec![format!(
            "example prerequisite (forced by {FORCE_SETUP_ENV})"
        )];
    }
    #[cfg(target_os = "linux")]
    {
        return UDEV_RULE_FILES
            .iter()
            .filter(|name| !udev_rule_installed(name))
            .map(|name| name.to_string())
            .collect();
    }

    #[cfg(not(target_os = "linux"))]
    {
        Vec::new()
    }
}

/// Checks whether a udev rule file is installed in any known directory.
#[cfg(target_os = "linux")]
fn udev_rule_installed(name: &str) -> bool {
    UDEV_RULES_DIRS
        .iter()
        .any(|dir| std::path::Path::new(dir).join(name).exists())
}

/// Returns the directory where rule files are generated when they are not
/// installed system-wide yet. Uses `$XDG_DATA_HOME/umbrage/udev-rules`, falling
/// back to `~/.local/share/umbrage/udev-rules`.
#[cfg(target_os = "linux")]
pub fn generated_rules_dir() -> Option<std::path::PathBuf> {
    let base = match std::env::var_os("XDG_DATA_HOME") {
        Some(dir) if std::path::Path::new(&dir).is_absolute() => std::path::PathBuf::from(dir),
        _ => std::path::PathBuf::from(std::env::var_os("HOME")?).join(".local/share"),
    };
    Some(base.join("umbrage").join("udev-rules"))
}

#[cfg(target_os = "linux")]
pub fn write_udev_rules(dir: &std::path::Path) -> Vec<String> {
    if std::fs::create_dir_all(dir).is_err() {
        return UDEV_RULE_FILES
            .iter()
            .map(|name| name.to_string())
            .collect();
    }

    let mut failed = Vec::new();
    for name in UDEV_RULE_FILES {
        let Some(contents) = udev_rule_contents(name) else {
            failed.push(name.to_string());
            continue;
        };
        if std::fs::write(dir.join(name), contents).is_err() {
            failed.push(name.to_string());
        }
    }
    failed
}

/// Returns the command that installs the generated rules and reloads udev.
#[cfg(target_os = "linux")]
pub fn rules_install_command(dir: &std::path::Path) -> String {
    let dir = dir.display();
    format!("sudo cp '{dir}'/*.rules {UDEV_RULES_DIR}/ && sudo udevadm control --reload-rules")
}

/// Installs the missing udev rules system-wide through polkit (`pkexec`). The
/// rules are generated in the user's data directory first, then an elevated
/// shell copies them into `/etc/udev/rules.d` and reloads udev.
#[cfg(target_os = "linux")]
pub fn install_rules_elevated() -> Result<(), String> {
    let dir = generated_rules_dir()
        .ok_or_else(|| "Could not determine a folder to write the rule files to.".to_string())?;

    let failed = write_udev_rules(&dir);
    if !failed.is_empty() {
        return Err(format!("Could not write {}.", failed.join(", ")));
    }

    const SCRIPT: &str = concat!(
        "cp \"$1\"/*.rules /etc/udev/rules.d/ && ",
        "udevadm control --reload-rules && ",
        "udevadm trigger --subsystem-match=usb",
    );

    let status = std::process::Command::new("pkexec")
        .arg("sh")
        .arg("-c")
        .arg(SCRIPT)
        .arg("sh")
        .arg(&dir)
        .status()
        .map_err(|e| match e.kind() {
            std::io::ErrorKind::NotFound => {
                "pkexec is not available. Install the rules manually with the command below."
                    .to_string()
            }
            _ => format!("Could not start pkexec: {e}"),
        })?;

    if !status.success() {
        return Err(
            "The rules were not installed (authentication cancelled or failed). \
             Install them manually with the command below."
                .to_string(),
        );
    }

    let missing: Vec<String> = UDEV_RULE_FILES
        .iter()
        .filter(|name| !udev_rule_installed(name))
        .map(|name| name.to_string())
        .collect();
    if !missing.is_empty() {
        return Err(format!("Rules were not installed: {}", missing.join(", ")));
    }

    Ok(())
}

/// A manual instruction shown when the app cannot install a prerequisite
/// itself.
pub struct ManualInstruction {
    /// Short explanation shown above the command.
    pub hint: String,
    /// Command to run, when there is one.
    pub command: Option<String>,
}

/// Returns the manual instruction for the current platform, if any. Linux
/// installs its prerequisites itself, so only the forced-setup path returns
/// one here; the fallback for a failed install lives in `callbacks::setup`.
pub fn manual_instruction() -> Option<ManualInstruction> {
    if setup_forced() {
        return Some(ManualInstruction {
            hint: format!("Example instruction (forced by {FORCE_SETUP_ENV}):"),
            command: Some("example-install-command".to_string()),
        });
    }

    None
}

/// Returns true if the missing prerequisites can be installed automatically.
/// Linux installs the udev rules through polkit.
pub fn can_auto_install() -> bool {
    cfg!(target_os = "linux")
}

/// Installs the missing prerequisites for the current platform. Linux writes
/// the udev rules into `/etc/udev/rules.d` through polkit.
pub fn install_elevated() -> Result<(), String> {
    #[cfg(target_os = "linux")]
    {
        install_rules_elevated()
    }

    #[cfg(not(target_os = "linux"))]
    {
        Err("Automatic installation is not supported on this platform.".to_string())
    }
}
