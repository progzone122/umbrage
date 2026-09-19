use std::path::Path;

use serde::Deserialize;
use sha2::{Digest, Sha256};

/// Payload passed from QML for `exportTemplate`.
#[derive(Debug, Default, Deserialize)]
pub struct ExportPayload {
    pub vendor: String,
    pub model: String,
    pub codename: String,
    #[serde(default)]
    pub versions: Vec<ExportVersion>,
}

#[derive(Debug, Default, Deserialize)]
pub struct ExportVersion {
    #[serde(default)]
    pub default: bool,
    pub name: String,
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub files: ExportFiles,
}

/// File paths picked for one version. Empty means the slot is unused.
#[derive(Debug, Default, Deserialize)]
pub struct ExportFiles {
    #[serde(default)]
    pub da: String,
    #[serde(default)]
    pub auth: String,
    #[serde(default)]
    pub preloader: String,
}

/// A file with its checksum computed from disk.
struct ResolvedFile {
    name: String,
    sha256: String,
}

/// Reads the file at `value` (a `file://` URL or plain path) and returns its
/// basename plus SHA-256. The YAML stores only the basename, never the path.
fn resolve_file(value: &str) -> Result<ResolvedFile, String> {
    let path = value.trim_start_matches("file://");
    let name = Path::new(path)
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_default();

    let bytes = std::fs::read(path).map_err(|e| format!("Failed to read {path}: {e}"))?;
    let sha256: String = Sha256::digest(&bytes)
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect();

    Ok(ResolvedFile { name, sha256 })
}

/// Builds the meta.yml document for `payload`, computing checksums from the
/// picked files.
pub fn build_yaml(payload: &ExportPayload) -> Result<String, String> {
    let mut out = String::new();

    out.push_str(&format!("vendor: {}\n", yaml_scalar(&payload.vendor)));
    out.push_str(&format!("model: {}\n", yaml_scalar(&payload.model)));
    out.push_str(&format!("codename: {}\n", yaml_scalar(&payload.codename)));
    out.push_str("versions:\n");

    for (index, version) in payload.versions.iter().enumerate() {
        let da = resolve_if_set(&version.files.da)?;
        let auth = resolve_if_set(&version.files.auth)?;
        let preloader = resolve_if_set(&version.files.preloader)?;

        out.push_str(&format!("  - id: {index}\n"));
        if version.default {
            out.push_str("    default: true\n");
        }
        out.push_str(&format!("    name: {}\n", yaml_scalar(&version.name)));
        out.push_str(&format!(
            "    description: {}\n",
            yaml_scalar(&version.description)
        ));

        out.push_str("    files:\n");
        write_file_entry(&mut out, "da", da.as_ref());
        write_file_entry(&mut out, "auth", auth.as_ref());
        write_file_entry(&mut out, "preloader", preloader.as_ref());

        out.push_str("    checksums:\n");
        write_checksum_entry(&mut out, "da", da.as_ref());
        write_checksum_entry(&mut out, "auth", auth.as_ref());
        write_checksum_entry(&mut out, "preloader", preloader.as_ref());
    }

    Ok(out)
}

fn resolve_if_set(value: &str) -> Result<Option<ResolvedFile>, String> {
    if value.is_empty() {
        Ok(None)
    } else {
        resolve_file(value).map(Some)
    }
}

fn write_file_entry(out: &mut String, key: &str, file: Option<&ResolvedFile>) {
    match file {
        Some(file) => out.push_str(&format!("      {key}: {}\n", yaml_scalar(&file.name))),
        None => out.push_str(&format!("      # {key}:\n")),
    }
}

fn write_checksum_entry(out: &mut String, key: &str, file: Option<&ResolvedFile>) {
    match file {
        Some(file) => out.push_str(&format!("      {key}: {}\n", file.sha256)),
        None => out.push_str(&format!("      # {key}:\n")),
    }
}

/// Quotes a scalar when it is not safe as a bare YAML token.
fn yaml_scalar(value: &str) -> String {
    if is_plain_safe(value) {
        value.to_string()
    } else {
        format!("\"{}\"", value.replace('\\', "\\\\").replace('"', "\\\""))
    }
}

fn is_plain_safe(value: &str) -> bool {
    if value.is_empty() {
        return false;
    }

    let lower = value.to_ascii_lowercase();
    if matches!(lower.as_str(), "true" | "false" | "null" | "~") || value.parse::<f64>().is_ok() {
        return false;
    }

    let first = value.chars().next().unwrap();
    if first.is_whitespace() || "-?:,[]{}#&*!|>'\"%@`".contains(first) {
        return false;
    }

    value
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || matches!(c, '.' | '_' | '/' | '-'))
}
