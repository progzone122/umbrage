use std::path::PathBuf;

use umbrage::templates::export::{
    ExportFile, ExportFiles, ExportPayload, ExportVersion, build_yaml,
};

/// Writes `content` to a unique temp file and returns its path. The basename
/// is what ends up in the YAML, so the directory can be anything.
fn temp_file(name: &str, content: &[u8]) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("umbrage-export-test-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join(name);
    std::fs::write(&path, content).unwrap();
    path
}

#[test]
fn exports_yaml_with_computed_checksums() {
    let da = temp_file("MT6769_USER.bin", b"da-content");
    let auth = temp_file("auth.bin", b"auth-content");
    let preloader = temp_file("preloader.bin", b"preloader-content");

    let payload = ExportPayload {
        vendor: "Motorola".into(),
        model: "G13/G23".into(),
        codename: "penangf".into(),
        versions: vec![
            ExportVersion {
                default: true,
                name: "Carbonara Exploit or Unlocked BL".into(),
                description:
                    "Works with an unlocked bootloader. Vulnerable to the Carbonara exploit.".into(),
                files: ExportFiles {
                    da: ExportFile::Path(da.to_string_lossy().into_owned()),
                    auth: ExportFile::Path(auth.to_string_lossy().into_owned()),
                    preloader: ExportFile::Path(String::new()),
                },
            },
            ExportVersion {
                default: false,
                name: "Official Signed Flashing (Locked BL)".into(),
                description:
                    "Works on a locked bootloader via a flash tool. The flashing is highly limited."
                        .into(),
                files: ExportFiles {
                    da: ExportFile::Path(String::new()),
                    auth: ExportFile::Path(String::new()),
                    preloader: ExportFile::Path(preloader.to_string_lossy().into_owned()),
                },
            },
        ],
    };

    let yaml = build_yaml(&payload).unwrap();

    assert_eq!(
        yaml,
        r#"vendor: Motorola
model: G13/G23
codename: penangf
versions:
  - id: 0
    default: true
    name: "Carbonara Exploit or Unlocked BL"
    description: "Works with an unlocked bootloader. Vulnerable to the Carbonara exploit."
    files:
      da: MT6769_USER.bin
      auth: auth.bin
      # preloader:
    checksums:
      da: 6c4aca13a53829ae3108519acd450cdbdfa808ed06e3d7f1b59354969413bffb
      auth: b6799d5531c2cd10f4b5ccdd5a953c2d6c5f52915a561cd16a0a0c38cce3e174
      # preloader:
  - id: 1
    name: "Official Signed Flashing (Locked BL)"
    description: "Works on a locked bootloader via a flash tool. The flashing is highly limited."
    files:
      # da:
      # auth:
      preloader: preloader.bin
    checksums:
      # da:
      # auth:
      preloader: 4a492fadef86732b7736311ceaa067a0ca159ea3ba520719a603fad8ec623b4c
"#
    );
}

#[test]
fn exports_named_files_without_reading_disk() {
    let payload = ExportPayload {
        vendor: "Motorola".into(),
        model: "G13/G23".into(),
        codename: "penangf".into(),
        versions: vec![ExportVersion {
            default: true,
            name: "Carbonara Exploit or Unlocked BL".into(),
            description: "Works with an unlocked bootloader.".into(),
            files: ExportFiles {
                da: ExportFile::Named {
                    name: "MT6769_USER.bin".into(),
                    sha256: "5fce44cc54451997159d3fd78564d1ddafdfda02341fedcadeee8780004258a9"
                        .into(),
                },
                auth: ExportFile::Path(String::new()),
                preloader: ExportFile::Path(String::new()),
            },
        }],
    };

    let yaml = build_yaml(&payload).unwrap();

    assert_eq!(
        yaml,
        r#"vendor: Motorola
model: G13/G23
codename: penangf
versions:
  - id: 0
    default: true
    name: "Carbonara Exploit or Unlocked BL"
    description: "Works with an unlocked bootloader."
    files:
      da: MT6769_USER.bin
      # auth:
      # preloader:
    checksums:
      da: 5fce44cc54451997159d3fd78564d1ddafdfda02341fedcadeee8780004258a9
      # auth:
      # preloader:
"#
    );
}

#[test]
fn quotes_unsafe_scalars() {
    let payload = ExportPayload {
        vendor: "Tecno".into(),
        model: "Pova 4".into(),
        codename: "pova".into(),
        versions: vec![ExportVersion {
            default: false,
            name: "He said \"hi\"".into(),
            description: "Contains # a hash".into(),
            files: ExportFiles::default(),
        }],
    };

    let yaml = build_yaml(&payload).unwrap();

    assert!(yaml.contains("model: \"Pova 4\""));
    assert!(yaml.contains(r#"name: "He said \"hi\"""#));
    assert!(yaml.contains("description: \"Contains # a hash\""));
}
