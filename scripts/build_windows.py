#!/usr/bin/env python3
"""Cross-compile Umbrage for Windows (x86_64-pc-windows-msvc) from macOS/Linux
and package a portable payload + NSIS installer.

Pipeline:
  1. Ensure prerequisites (cargo-xwin, LLVM clang-cl/lld-link, makensis, aqt).
  2. Download matching Windows Qt (target) and host Qt (for rcc/moc) via aqt.
  3. Generate qmake/qtpaths shims so qtbridge uses target Qt libs and host tools.
  4. cargo xwin build --release.
  5. Assemble dist/umbrage-windows (exe + Qt DLLs + plugins + qml + qt.conf).
  6. Build dist/umbrage-setup.exe with makensis.

Run from anywhere:  python3 scripts/build_windows.py
"""

from __future__ import annotations

import argparse
import os
import platform
import shutil
import subprocess
import sys
import textwrap
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
TARGET = "x86_64-pc-windows-msvc"
QT_VERSION = "6.10.3"
WIN_QT_ARCH = "win64_msvc2022_64"
WIN_QT_DIRNAME = "msvc2022_64"
CACHE_DIR = Path.home() / ".cache" / "umbrage-cross"
DIST_DIR = PROJECT_ROOT / "dist"
PAYLOAD_DIR = DIST_DIR / "umbrage-windows"
APP_NAME = "Umbrage"
APP_VERSION = "0.1.0"


def log(msg: str) -> None:
    print(f"\033[1;36m==>\033[0m {msg}", flush=True)


def die(msg: str) -> None:
    print(f"\033[1;31merror:\033[0m {msg}", file=sys.stderr)
    sys.exit(1)


def run(cmd: list[str], **kwargs) -> None:
    print("   $ " + " ".join(str(c) for c in cmd), flush=True)
    subprocess.run(cmd, check=True, **kwargs)


def find_llvm_bin() -> Path:
    candidates = [
        Path("/opt/homebrew/opt/llvm/bin"),
        Path("/usr/local/opt/llvm/bin"),
        Path("/usr/lib/llvm/bin"),
    ]
    for c in candidates:
        if (c / "clang-cl").exists():
            return c
    which = shutil.which("clang-cl")
    if which:
        return Path(which).parent
    die("clang-cl not found. Install LLVM: brew install llvm")


def find_lld_link() -> Path:
    for c in [Path("/opt/homebrew/bin/lld-link"), Path("/usr/local/bin/lld-link")]:
        if c.exists():
            return c
    which = shutil.which("lld-link")
    if which:
        return Path(which)
    die("lld-link not found. Install LLD: brew install lld")


def ensure_cargo_xwin() -> None:
    if shutil.which("cargo-xwin") is None:
        die("cargo-xwin not found. Install it: cargo install cargo-xwin --locked")


def ensure_makensis() -> None:
    if shutil.which("makensis") is None:
        die("makensis not found. Install NSIS: brew install makensis")


def aqt_platform() -> str:
    system = platform.system()
    if system == "Darwin":
        return "mac"
    if system == "Linux":
        return "linux"
    die(f"unsupported host platform: {system}")


def aqt_command() -> list[str]:
    aqt = shutil.which("aqt")
    if aqt:
        return [aqt]
    venv = CACHE_DIR / "venv"
    aqt_bin = venv / "bin" / "aqt"
    if not aqt_bin.exists():
        log(f"Creating aqtinstall venv at {venv}")
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        run([sys.executable, "-m", "venv", str(venv)])
        run([str(venv / "bin" / "pip"), "install", "-q", "aqtinstall"])
    return [str(aqt_bin)]


def ensure_qt(qt_root: Path, host_arch: str) -> tuple[Path, Path]:
    """Returns (windows_qt_dir, host_qt_dir)."""
    win_qt = qt_root / QT_VERSION / WIN_QT_DIRNAME
    host_qt = qt_root / QT_VERSION / host_arch
    aqt = aqt_command()

    if not (win_qt / "lib" / "Qt6Core.prl").exists():
        log(f"Installing Windows Qt {QT_VERSION} ({WIN_QT_ARCH}) -> {win_qt}")
        run(
            aqt
            + [
                "install-qt",
                "windows",
                "desktop",
                QT_VERSION,
                WIN_QT_ARCH,
                "-O",
                str(qt_root),
            ]
        )
    else:
        log(f"Windows Qt found: {win_qt}")

    if (
        not (host_qt / "libexec" / "rcc").exists()
        and not (host_qt / "bin" / "rcc").exists()
    ):
        log(f"Installing host Qt {QT_VERSION} ({host_arch}) -> {host_qt}")
        run(
            aqt
            + [
                "install-qt",
                aqt_platform(),
                "desktop",
                QT_VERSION,
                host_arch,
                "-O",
                str(qt_root),
            ]
        )
    else:
        log(f"Host Qt found: {host_qt}")

    return win_qt, host_qt


def host_tool_dir(host_qt: Path) -> Path:
    for sub in ("libexec", "bin"):
        if (host_qt / sub / "rcc").exists():
            return host_qt / sub
    die(f"rcc not found under {host_qt}")


def write_shims(shim_dir: Path, win_qt: Path, host_tools: Path) -> Path:
    shim_dir.mkdir(parents=True, exist_ok=True)
    qmake = shim_dir / "qmake"
    qtpaths = shim_dir / "qtpaths"

    qmake.write_text(
        textwrap.dedent(
            f"""\
            #!/bin/sh
            QT="{win_qt}"
            HOST_LIBEXECS="{host_tools}"
            HOST_BINS="{shim_dir}"

            if [ "$1" = "-query" ]; then
              case "$2" in
                QT_VERSION) echo "{QT_VERSION}" ;;
                QT_INSTALL_HEADERS) echo "$QT/include" ;;
                QT_INSTALL_LIBS) echo "$QT/lib" ;;
                QT_INSTALL_PREFIX) echo "$QT" ;;
                QT_INSTALL_PLUGINS) echo "$QT/plugins" ;;
                QT_INSTALL_BINS) echo "$QT/bin" ;;
                QT_INSTALL_LIBEXECS) echo "$QT/bin" ;;
                QT_INSTALL_BINS/get) echo "$QT/bin" ;;
                QT_INSTALL_LIBEXECS/get) echo "$QT/bin" ;;
                QT_HOST_LIBEXECS|QT_HOST_LIBEXECS/get) echo "$HOST_LIBEXECS" ;;
                QT_HOST_BINS|QT_HOST_BINS/get) echo "$HOST_BINS" ;;
                *) echo "" ;;
              esac
            fi
            exit 0
            """
        )
    )
    qtpaths.write_text(
        textwrap.dedent(
            f"""\
            #!/bin/sh
            QT="{win_qt}"

            key=""
            while [ $# -gt 0 ]; do
              case "$1" in
                --query) key="$2"; shift 2 ;;
                *) shift ;;
              esac
            done

            case "$key" in
              QT_VERSION) echo "{QT_VERSION}" ;;
              QT_INSTALL_HEADERS) echo "$QT/include" ;;
              QT_INSTALL_LIBS) echo "$QT/lib" ;;
              QT_INSTALL_PREFIX) echo "$QT" ;;
              QT_INSTALL_PLUGINS) echo "$QT/plugins" ;;
              QT_INSTALL_BINS) echo "$QT/bin" ;;
              *) echo "" ;;
            esac
            exit 0
            """
        )
    )
    for f in (qmake, qtpaths):
        f.chmod(0o755)
    log(f"Shims written to {shim_dir}")
    return qmake


def cargo_build(win_qt: Path, host_tools: Path, qmake: Path, clean: bool) -> Path:
    llvm_bin = find_llvm_bin()
    find_lld_link()

    env = os.environ.copy()
    env["PATH"] = f"{llvm_bin}:{env.get('PATH', '')}"
    env["QMAKE"] = str(qmake)
    env["RCC"] = str(host_tools / "rcc")

    if clean:
        log("cargo clean (windows target)")
        run(["cargo", "clean", "--target", TARGET], cwd=PROJECT_ROOT)

    log(f"Building {TARGET} (release)")
    run(
        ["cargo", "xwin", "build", "--release", "--target", TARGET],
        cwd=PROJECT_ROOT,
        env=env,
    )

    exe = PROJECT_ROOT / "target" / TARGET / "release" / "umbrage.exe"
    if not exe.exists():
        die(f"build did not produce {exe}")
    log(f"Built {exe}")
    return exe


def assemble_payload(exe: Path, win_qt: Path) -> None:
    if PAYLOAD_DIR.exists():
        shutil.rmtree(PAYLOAD_DIR)
    PAYLOAD_DIR.mkdir(parents=True)
    log(f"Assembling payload: {PAYLOAD_DIR}")

    shutil.copy2(exe, PAYLOAD_DIR / "umbrage.exe")

    bin_dir = win_qt / "bin"
    for dll in sorted(bin_dir.glob("*.dll")):
        if dll.stem.endswith("d"):
            continue
        shutil.copy2(dll, PAYLOAD_DIR / dll.name)

    shutil.copytree(win_qt / "plugins", PAYLOAD_DIR / "plugins")
    shutil.copytree(win_qt / "qml", PAYLOAD_DIR / "qml")

    for dbg in PAYLOAD_DIR.rglob("*d.dll"):
        dbg.unlink()

    (PAYLOAD_DIR / "qt.conf").write_text(
        "[Paths]\nPrefix = .\nPlugins = plugins\nQml2Imports = qml\n"
    )


NSIS_TEMPLATE = r"""Unicode true

!include "MUI2.nsh"

!define APP_NAME "%(app_name)s"
!define APP_EXE "umbrage.exe"
!define APP_VERSION "%(app_version)s"
!define APP_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\%(app_name)s"

Name "${APP_NAME}"
OutFile "umbrage-setup.exe"
InstallDir "$PROGRAMFILES64\${APP_NAME}"
InstallDirRegKey HKLM "${APP_KEY}" "InstallLocation"
RequestExecutionLevel admin
SetCompressor /SOLID lzma

!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Russian"

Section "Install" SecInstall
    SetOutPath "$INSTDIR"
    File /r "umbrage-windows/*"

    CreateDirectory "$SMPROGRAMS\${APP_NAME}"
    CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
    CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"

    ; Always launch elevated (WinUSB / device access needs admin).
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\AppCompatFlags\Layers" "$INSTDIR\${APP_EXE}" "~ RUNASADMIN"

    WriteUninstaller "$INSTDIR\uninstall.exe"

    WriteRegStr HKLM "${APP_KEY}" "DisplayName" "${APP_NAME}"
    WriteRegStr HKLM "${APP_KEY}" "DisplayIcon" "$INSTDIR\${APP_EXE}"
    WriteRegStr HKLM "${APP_KEY}" "DisplayVersion" "${APP_VERSION}"
    WriteRegStr HKLM "${APP_KEY}" "InstallLocation" "$INSTDIR"
    WriteRegStr HKLM "${APP_KEY}" "UninstallString" "$INSTDIR\uninstall.exe"
    WriteRegDWORD HKLM "${APP_KEY}" "NoModify" 1
    WriteRegDWORD HKLM "${APP_KEY}" "NoRepair" 1
SectionEnd

Section "Uninstall"
    Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
    RMDir "$SMPROGRAMS\${APP_NAME}"
    Delete "$DESKTOP\${APP_NAME}.lnk"

    DeleteRegValue HKLM "Software\Microsoft\Windows\CurrentVersion\AppCompatFlags\Layers" "$INSTDIR\${APP_EXE}"
    DeleteRegKey HKLM "${APP_KEY}"

    RMDir /r "$INSTDIR"
SectionEnd
"""


def build_installer() -> Path:
    nsi = DIST_DIR / "umbrage.nsi"
    nsi.write_text(NSIS_TEMPLATE % {"app_name": APP_NAME, "app_version": APP_VERSION})
    log("Running makensis")
    run(["makensis", "-V2", "umbrage.nsi"], cwd=DIST_DIR)
    setup = DIST_DIR / "umbrage-setup.exe"
    if not setup.exists():
        die("installer was not produced")
    log(f"Installer: {setup}")
    return setup


def main() -> int:
    global QT_VERSION

    parser = argparse.ArgumentParser(description="Cross-compile Umbrage for Windows")
    parser.add_argument("--qt-root", type=Path, default=Path.home() / "Qt")
    parser.add_argument("--qt-version", default=QT_VERSION)
    parser.add_argument("--skip-installer", action="store_true")
    parser.add_argument("--skip-payload", action="store_true")
    parser.add_argument("--clean", action="store_true")
    args = parser.parse_args()

    QT_VERSION = args.qt_version

    ensure_cargo_xwin()

    host_arch = "macos" if platform.system() == "Darwin" else "gcc_64"
    win_qt, host_qt = ensure_qt(args.qt_root, host_arch)
    host_tools = host_tool_dir(host_qt)
    qmake = write_shims(CACHE_DIR / "shims", win_qt, host_tools)

    exe = cargo_build(win_qt, host_tools, qmake, args.clean)

    if args.skip_payload and args.skip_installer:
        return 0

    assemble_payload(exe, win_qt)
    if args.skip_installer:
        return 0

    ensure_makensis()
    build_installer()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as exc:
        die(f"command failed ({exc.returncode}): {exc.cmd}")
