use umbrage::templates::model::{DeviceBuilder, Meta, TemplateFile, TemplateFileData};

const SAMPLE_JSON: &str = r#"{
    "vendors": {
        "Motorola": ["penangf"]
    },
    "devices": {
        "penangf": {
            "vendor": "Motorola",
            "model": "G13/G23",
            "name": "Motorola G13/G23",
            "versions": [
                {
                    "id": 0,
                    "default": true,
                    "name": "Carbonara Exploit or Unlocked BL",
                    "description": "Works with an unlocked bootloader.",
                    "files": {
                        "da": {
                            "name": "MT6769_USER.bin",
                            "path": "files/MT6769_USER.bin",
                            "sha256": "5fce44cc54451997159d3fd78564d1ddafdfda02341fedcadeee8780004258a9"
                        }
                    }
                }
            ]
        }
    }
}"#;

#[test]
fn roundtrips_meta() {
    let meta: Meta = serde_json::from_str(SAMPLE_JSON).unwrap();
    assert_eq!(meta.devices["penangf"].vendor, "Motorola");

    let version = &meta.devices["penangf"].versions[0];
    assert!(version.default);
    assert_eq!(version.files.da().unwrap().name, "MT6769_USER.bin");

    let re_encoded = serde_json::to_string(&meta).unwrap();
    let parsed_again: Meta = serde_json::from_str(&re_encoded).unwrap();
    assert_eq!(
        parsed_again.devices["penangf"].versions[0]
            .files
            .da()
            .unwrap()
            .sha256,
        "5fce44cc54451997159d3fd78564d1ddafdfda02341fedcadeee8780004258a9"
    );
}

#[test]
fn builder_defaults_display_name() {
    let device = DeviceBuilder::new("Tecno", "Pova 4").build();
    assert_eq!(device.name, "Tecno Pova 4");
}

#[test]
fn file_accessors() {
    let mut files = TemplateFile::default();
    files.insert(
        "da",
        TemplateFileData {
            name: "da.bin".into(),
            path: "files/da.bin".into(),
            sha256: String::new(),
        },
    );

    assert!(files.da().is_some());
    assert!(files.auth().is_none());
    assert!(files.preloader().is_none());
}
