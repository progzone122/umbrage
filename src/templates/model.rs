use std::collections::HashMap;

use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct TemplateFile(pub HashMap<String, TemplateFileData>);

#[derive(Debug, Deserialize, Clone)]
pub struct TemplateFileData {
    pub name: String,
    pub path: String,
    pub sha256: String,
}
