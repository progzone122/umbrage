use std::fs;
use std::path::Path;

use penumbra_mtk::da::ScatterFile;

use crate::state::AppState;

/// One partition from a scatter file, serialized for QML.
#[derive(serde::Serialize)]
struct ScatterEntry {
    name: String,
    file: String,
    download: bool,
}

/// Parses a scatter file at `path` and reports each partition's file back to QML.
///
/// `.xml` goes through `ScatterFile::from_xml`, anything else through
/// `ScatterFile::from_yaml`. Relative `file_name` entries resolve against the
/// scatter file's own directory, so `preloader_lamu.bin` becomes a path the
/// write stage can open.
///
/// On failure this emits `scatter_file_failed` and leaves the partition table
/// unchanged.
pub fn load_scatter_file(state: &mut AppState, path: String) {
    let path = path.trim_start_matches("file://").to_string();

    let content = match fs::read_to_string(&path) {
        Ok(content) => content,
        Err(e) => {
            state.scatter_file_failed(format!("Failed to read scatter file: {e}"));
            return;
        }
    };

    let is_xml = path.to_ascii_lowercase().ends_with(".xml");

    let parsed = if is_xml {
        ScatterFile::from_xml(&content)
    } else {
        ScatterFile::from_yaml(&content)
    };

    let scatter = match parsed {
        Ok(scatter) => scatter,
        Err(e) => {
            let kind = if is_xml { "XML" } else { "YAML" };
            state.scatter_file_failed(format!("Failed to parse {kind} scatter file: {e}"));
            return;
        }
    };

    // Refuse a scatter file whose platform doesn't match the connected device,
    // so nobody flashes a layout built for another chipset. Skipped when no
    // device is connected or the scatter file omits platform.
    if let Some(platform) = extract_platform(&content, is_xml) {
        if !state.chip_platform.is_empty()
            && !state.chip_platform.eq_ignore_ascii_case(platform.trim())
        {
            state.scatter_file_failed(format!(
                "Scatter file platform ({}) does not match the connected device ({})",
                platform.trim(),
                state.chip_platform
            ));
            return;
        }
    }

    let base_dir = Path::new(&path)
        .parent()
        .map(Path::to_path_buf)
        .unwrap_or_default();

    let entries: Vec<ScatterEntry> = scatter
        .parts
        .iter()
        .map(|part| {
            let file = match &part.path {
                Some(p) => {
                    // `file_name == "NONE"` comes through as `None`; a real path
                    // resolves against the scatter file's directory.
                    let resolved = if p.is_absolute() {
                        p.clone()
                    } else {
                        base_dir.join(p)
                    };
                    resolved.to_string_lossy().into_owned()
                }
                None => String::new(),
            };

            ScatterEntry {
                name: part.part.name.clone(),
                file,
                download: part.download,
            }
        })
        .collect();

    match serde_json::to_string(&entries) {
        Ok(json) => state.scatter_file_loaded(json),
        Err(e) => state.scatter_file_failed(format!("Failed to encode scatter file: {e}")),
    }
}

/// Returns the platform string (like "MT6768") from raw scatter content, or
/// `None` when the field is absent or empty.
fn extract_platform(content: &str, is_xml: bool) -> Option<String> {
    if is_xml {
        let start = content.find("<platform>")? + "<platform>".len();
        let rest = &content[start..];
        let end = rest.find("</platform>")?;
        let value = rest[..end].trim();
        return (!value.is_empty()).then(|| value.to_string());
    }

    for line in content.lines() {
        let line = line.trim();
        if let Some(value) = line.strip_prefix("platform:") {
            let value = value.trim();
            return (!value.is_empty()).then(|| value.to_string());
        }
    }

    None
}
