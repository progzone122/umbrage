use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};

/// Repository metadata (`meta.json`). Parsed from the server and serialized on
/// export.
#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct Meta {
    pub vendors: BTreeMap<String, Vec<String>>,
    pub devices: BTreeMap<String, Device>,
}

/// One device, keyed by codename.
#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct Device {
    pub vendor: String,
    pub model: String,
    pub name: String,
    pub versions: Vec<Version>,
}

/// A flashing method. `id` is unique within a device.
#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct Version {
    pub id: u32,
    #[serde(default)]
    pub default: bool,
    pub name: String,
    #[serde(default)]
    pub description: String,
    pub files: TemplateFile,
}

/// A version's files, keyed by file type (`da`, `auth`, `preloader`).
///
/// `BTreeMap` keeps iteration order fixed so exported JSON is stable.
#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct TemplateFile(pub BTreeMap<String, TemplateFileData>);

impl TemplateFile {
    pub fn da(&self) -> Option<&TemplateFileData> {
        self.0.get("da")
    }

    pub fn auth(&self) -> Option<&TemplateFileData> {
        self.0.get("auth")
    }

    pub fn preloader(&self) -> Option<&TemplateFileData> {
        self.0.get("preloader")
    }

    pub fn insert(&mut self, file: impl Into<String>, data: TemplateFileData) {
        self.0.insert(file.into(), data);
    }
}

impl FromIterator<(String, TemplateFileData)> for TemplateFile {
    fn from_iter<T: IntoIterator<Item = (String, TemplateFileData)>>(iter: T) -> Self {
        Self(iter.into_iter().collect())
    }
}

/// A file referenced by a version. `path` is relative to the repo base URL,
/// `sha256` is checked after download.
#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct TemplateFileData {
    pub name: String,
    pub path: String,
    pub sha256: String,
}

#[derive(Debug, Default)]
pub struct DeviceBuilder {
    vendor: String,
    model: String,
    name: String,
    versions: Vec<Version>,
}

impl DeviceBuilder {
    pub fn new(vendor: impl Into<String>, model: impl Into<String>) -> Self {
        Self {
            vendor: vendor.into(),
            model: model.into(),
            ..Self::default()
        }
    }

    pub fn name(mut self, name: impl Into<String>) -> Self {
        self.name = name.into();
        self
    }

    pub fn version(mut self, version: Version) -> Self {
        self.versions.push(version);
        self
    }

    pub fn build(self) -> Device {
        let name = if self.name.is_empty() {
            format!("{} {}", self.vendor, self.model)
        } else {
            self.name
        };

        Device {
            vendor: self.vendor,
            model: self.model,
            name,
            versions: self.versions,
        }
    }
}
