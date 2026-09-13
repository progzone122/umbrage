use std::env;
use std::path::{Path, PathBuf};
use std::process::Command;

fn find_qmake() -> PathBuf {
    if let Ok(p) = env::var("QMAKE") {
        return PathBuf::from(p);
    }
    for var in ["QTDIR", "QT_DIR", "QT6_DIR"] {
        if let Ok(dir) = env::var(var) {
            for sub in ["bin/qmake", "bin/qmake.exe"] {
                let candidate = PathBuf::from(&dir).join(sub);
                if candidate.exists() {
                    return candidate;
                }
            }
        }
    }
    if let Ok(path) = env::var("PATH") {
        for name in ["qmake6", "qmake"] {
            for dir in env::split_paths(&path) {
                let candidate = dir.join(name);
                if candidate.exists() {
                    return candidate;
                }
            }
        }
    }
    panic!("qmake not found. Set QMAKE=/path/to/qmake or add qmake6 to PATH.");
}

fn qt_query(qmake: &Path, var: &str) -> PathBuf {
    let out = Command::new(qmake)
        .arg("-query")
        .arg(var)
        .output()
        .expect("failed to run qmake -query");
    let value = String::from_utf8_lossy(&out.stdout).trim().to_string();
    if value.is_empty() {
        panic!("qmake -query {var} returned nothing");
    }
    PathBuf::from(value)
}

fn find_rcc() -> PathBuf {
    // 1. Explicit override: RCC=/path/to/rcc cargo build
    if let Ok(p) = env::var("RCC") {
        return PathBuf::from(p);
    }

    // 2. QTDIR / QT_DIR / QT6_DIR. Official Qt installs on macOS and Linux
    //    keep rcc in libexec/, not bin/.
    for var in ["QTDIR", "QT_DIR", "QT6_DIR"] {
        if let Ok(dir) = env::var(var) {
            for sub in ["bin/rcc", "bin/rcc.exe", "libexec/rcc"] {
                let candidate = PathBuf::from(&dir).join(sub);
                if candidate.exists() {
                    return candidate;
                }
            }
        }
    }

    // 3. PATH
    if let Ok(path) = env::var("PATH") {
        for dir in env::split_paths(&path) {
            let candidate = dir.join("rcc");
            if candidate.exists() {
                return candidate;
            }
        }
    }

    // 4. Standard macOS Homebrew locations (arm64 + x86_64). Homebrew puts
    //    rcc under the formula's share/qt/libexec, not bin/.
    let homebrew = [
        "/opt/homebrew/opt/qt/share/qt/libexec/rcc",
        "/usr/local/opt/qt/share/qt/libexec/rcc",
    ];
    for p in homebrew {
        if Path::new(p).exists() {
            return PathBuf::from(p);
        }
    }

    // 5. Official installer: ~/Qt/<version>/<kit>/bin/rcc
    if let Ok(home) = env::var("HOME") {
        let qt_root = PathBuf::from(&home).join("Qt");
        if let Ok(entries) = std::fs::read_dir(&qt_root) {
            for ver in entries.flatten() {
                let kit = ver.path();
                if !kit.is_dir() {
                    continue;
                }
                for sub in ["macos", "clang_64", "gcc_64"] {
                    for bin in ["bin", "libexec"] {
                        let candidate = kit.join(sub).join(bin).join("rcc");
                        if candidate.exists() {
                            return candidate;
                        }
                    }
                }
            }
        }
    }

    panic!("rcc not found. Set RCC=/path/to/rcc or add rcc to PATH.");
}

fn main() {
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let qrc = manifest_dir.join("src/ui/resources.qrc");
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let rcc_out = out_dir.join("resources.rcc");

    println!("cargo:rerun-if-changed={}", qrc.display());
    println!("cargo:rerun-if-changed=src/ui/Assets");
    println!("cargo:rerun-if-changed=src/ui/Pages");
    println!("cargo:rerun-if-changed=src/ui/Components");
    println!("cargo:rerun-if-changed=src/ui/UmbrageStyles");
    println!("cargo:rerun-if-changed=src/ui/UmbrageUtils");

    let status = Command::new(find_rcc())
        .arg("-binary")
        .arg(&qrc)
        .arg("-o")
        .arg(&rcc_out)
        .status()
        .expect("failed to run rcc");

    assert!(status.success(), "rcc exited with an error: {status}");

    let qt_headers = qt_query(&find_qmake(), "QT_INSTALL_HEADERS");
    let qt_libs = qt_query(&find_qmake(), "QT_INSTALL_LIBS");
    println!("cargo:rerun-if-changed=src/icon_bridge.rs");
    println!("cargo:rerun-if-changed=src/icon_bridge.h");
    println!("cargo:rerun-if-changed=src/icon_bridge.cpp");
    let mut build = cxx_build::bridge("src/icon_bridge.rs");
    build
        .file("src/icon_bridge.cpp")
        .include(&manifest_dir)
        .include(&qt_headers)
        .include(qt_headers.join("QtGui"))
        .include(qt_headers.join("QtCore"))
        // Qt 6 headers require C++17. Use .std() so MSVC gets /std:c++17;
        // "-std=c++17" is silently ignored by cl.exe.
        .std("c++17");
    // Homebrew installs Qt as macOS frameworks, where headers sit under
    // <libs>/QtGui.framework/Headers instead of <headers>/QtGui. The framework
    // search path is also required to resolve the `QtGui/...` includes emitted
    // by Qt's forwarding headers.
    let mut frameworks = false;
    for module in ["QtGui", "QtCore"] {
        let framework_headers = qt_libs.join(format!("{module}.framework/Headers"));
        if framework_headers.is_dir() {
            build.include(framework_headers);
            frameworks = true;
        }
    }
    if frameworks {
        build.flag(&format!("-F{}", qt_libs.display()));
    }
    build.compile("umbrage-icon-bridge");
}
