use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;
use std::{path::Path, path::PathBuf};

use sha2::{Digest, Sha256};

pub mod model;

const ENDPOINT: &str = "https://progzone122.github.io/umbrage-repo";

/// Requests must not hang forever. A stalled connection would leave the
/// templates page stuck spinning.
const HTTP_TIMEOUT: Duration = Duration::from_secs(20);

fn http_client() -> Result<reqwest::Client, String> {
    reqwest::Client::builder()
        .timeout(HTTP_TIMEOUT)
        .build()
        .map_err(|e| format!("Failed to create the HTTP client: {e}"))
}

/// Marker returned when the user cancels an operation. Callers compare against
/// it to tell a cancellation apart from a real failure.
pub const CANCELLED: &str = "Cancelled by the user";

/// Resolves as soon as `cancel` is set. Used with `tokio::select!` to drop an
/// in-flight request instead of waiting for it to finish.
pub async fn wait_cancelled(cancel: &AtomicBool) {
    while !cancel.load(Ordering::SeqCst) {
        tokio::time::sleep(Duration::from_millis(50)).await;
    }
}

pub async fn fetch_meta_json() -> Result<String, String> {
    let body = http_client()?
        .get(format!("{ENDPOINT}/meta.json"))
        .send()
        .await
        .map_err(|e| format!("Failed to fetch meta.json: {e}"))?
        .error_for_status()
        .map_err(|e| format!("HTTP error: {e}"))?
        .text()
        .await
        .map_err(|e| format!("Failed to read meta.json body: {e}"))?;

    // Reject bad metadata before it reaches QML. Parsing into `Meta` instead
    // of a bare `serde_json::Value` also catches a missing field or wrong shape
    // early.
    serde_json::from_str::<model::Meta>(&body).map_err(|e| format!("Invalid meta.json: {e}"))?;

    Ok(body)
}

pub async fn download_file(
    file: &model::TemplateFileData,
    dest: &Path,
    progress: &impl Fn(u64, u64),
) -> Result<(), String> {
    let url = format!("{ENDPOINT}/{}", file.path);

    let mut response = http_client()?
        .get(&url)
        .send()
        .await
        .map_err(|e| format!("Failed to download {url}: {e}"))?
        .error_for_status()
        .map_err(|e| format!("HTTP error for {url}: {e}"))?;

    // Read in chunks so progress can be reported as it arrives. `content_length`
    // is a hint and can be 0 for chunked responses.
    let total = response.content_length().unwrap_or(0);
    let mut bytes = Vec::new();
    let mut downloaded = 0u64;

    while let Some(chunk) = response
        .chunk()
        .await
        .map_err(|e| format!("Failed to read response body for {url}: {e}"))?
    {
        bytes.extend_from_slice(&chunk);
        downloaded += chunk.len() as u64;
        progress(downloaded, total);
    }

    let hash: String = Sha256::digest(&bytes)
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect();
    if hash != file.sha256 {
        return Err(format!(
            "SHA256 mismatch for {url}: expected {}, got {}",
            file.sha256, hash
        ));
    }

    tokio::fs::write(dest, &bytes)
        .await
        .map_err(|e| format!("Failed to write {}: {e}", dest.display()))
}

#[derive(Debug, Default)]
pub struct ResolvedFiles {
    pub da: Option<PathBuf>,
    pub auth: Option<PathBuf>,
    pub preloader: Option<PathBuf>,
}

// Downloads every file in `files` into the temp dir, then maps the da, auth,
// and preloader files onto their local paths. Aborts with `CANCELLED` when the
// user cancels.
pub async fn resolve_template_files(
    files: &model::TemplateFile,
    cancel: &AtomicBool,
    progress: impl Fn(&str, usize, usize, u64, u64),
) -> Result<ResolvedFiles, String> {
    let mut resolved = ResolvedFiles::default();
    let count = files.0.len();

    for (index, (file, data)) in files.0.iter().enumerate() {
        if cancel.load(Ordering::SeqCst) {
            return Err(CANCELLED.to_string());
        }

        let dest = std::env::temp_dir().join(&data.name);
        let on_chunk = |done: u64, total: u64| progress(&data.name, index, count, done, total);

        tokio::select! {
            result = download_file(data, &dest, &on_chunk) => result?,
            () = wait_cancelled(cancel) => return Err(CANCELLED.to_string()),
        }

        match file.as_str() {
            "da" => resolved.da = Some(dest),
            "auth" => resolved.auth = Some(dest),
            "preloader" => resolved.preloader = Some(dest),
            _ => {}
        }
    }

    Ok(resolved)
}
