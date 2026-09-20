#!/usr/bin/env python3
"""Package Umbrage as a Linux AppImage with Qt6 bundled.

Pipeline:
  1. Ensure prerequisites (cargo, patchelf, strip, rsvg-convert, curl).
  2. Download pinned linuxdeploy, linuxdeploy-plugin-qt and appimagetool.
  3. cargo build --release.
  4. Assemble AppDir and run linuxdeploy with the Qt plugin to bundle
     Qt libraries, plugins and QML modules.
  5. Package dist/Umbrage-<version>-x86_64.AppImage with appimagetool.

Run from anywhere:  python3 scripts/build_appimage.py

Flags:
  --clean          wipe the release target before building
  --no-appimage    stop after deploying the AppDir (debugging)
  --smoke-test     run the AppDir binary with the offscreen platform for a
                   few seconds to catch missing Qt libs/plugins/QML modules

The Qt libraries are taken from the host system (qmake on PATH). For an
AppImage that also runs on older distros, build inside a container based
on an older distro image instead of a rolling-release host.
"""

from __future__ import annotations

import argparse
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
TARGET = "x86_64-unknown-linux-gnu"
APP_NAME = "Umbrage"
APP_VERSION = "0.1.1"
CACHE_DIR = Path.home() / ".cache" / "umbrage-cross"
TOOLS_DIR = CACHE_DIR / "appimage-tools"
DIST_DIR = PROJECT_ROOT / "dist"
APPDIR = DIST_DIR / "umbrage.AppDir"
ICON_SRC = PROJECT_ROOT / "src" / "ui" / "Assets" / "umbrage-icon.svg"

TOOLS = {
    "linuxdeploy": "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage",
    "linuxdeploy-plugin-qt": "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage",
    "appimagetool": "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage",
}

DESKTOP_TEMPLATE = """\
[Desktop Entry]
Type=Application
Name={app_name}
Comment=Flash and explore MTK devices
Exec=umbrage
Icon=umbrage
Terminal=false
Categories=Utility;
X-AppImage-Version={app_version}
"""

# Synthetic QML file with only the system modules the app really needs.
# The real sources import the runtime-registered "umbrage" module, which
# qmlimportscanner cannot resolve and linuxdeploy-plugin-qt would reject.
QML_STUB = """\
import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Controls.Fusion
import QtQuick.Layouts
import Qt.labs.platform
Item {}
"""


def log(msg: str) -> None:
    print(f"\033[1;36m==>\033[0m {msg}", flush=True)


def die(msg: str) -> None:
    print(f"\033[1;31merror:\033[0m {msg}", file=sys.stderr)
    sys.exit(1)


def run(cmd: list[str], **kwargs) -> None:
    print("   $ " + " ".join(str(c) for c in cmd), flush=True)
    subprocess.run(cmd, check=True, **kwargs)


def env_with_path(extra: list[Path]) -> dict[str, str]:
    env = os.environ.copy()
    env["PATH"] = os.pathsep.join([str(p) for p in extra]) + os.pathsep + env.get("PATH", "")
    return env


def ensure_system_tools() -> Path:
    for tool in ("cargo", "patchelf", "strip", "rsvg-convert"):
        if shutil.which(tool) is None:
            die(f"{tool} not found on PATH")
    curl = shutil.which("curl") or shutil.which("wget")
    if curl is None:
        die("curl or wget not found on PATH")
    return Path(curl)


def download(curl: Path, url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".part")
    if curl.name == "curl":
        run([str(curl), "-fL", "--retry", "3", "-o", str(tmp), url])
    else:
        run([str(curl), "-O", "-c", str(tmp), url], cwd=dest.parent)
        tmp = dest.parent / url.rsplit("/", 1)[-1]
    tmp.rename(dest)
    dest.chmod(0o755)


def ensure_tools() -> Path:
    curl = ensure_system_tools()
    for name, url in TOOLS.items():
        tool = TOOLS_DIR / name
        if not tool.exists():
            log(f"Downloading {name}")
            download(curl, url, tool)
        else:
            log(f"Found {name}: {tool}")
    return TOOLS_DIR


def cargo_build(clean: bool) -> Path:
    if clean:
        log("cargo clean (release)")
        run(["cargo", "clean", "--release"], cwd=PROJECT_ROOT)

    log("Building release binary")
    run(["cargo", "build", "--release"], cwd=PROJECT_ROOT)

    exe = PROJECT_ROOT / "target" / "release" / "umbrage"
    if not exe.exists():
        die(f"build did not produce {exe}")
    log(f"Built {exe}")
    return exe


def prepare_appdir(exe: Path) -> tuple[Path, Path, Path]:
    if APPDIR.exists():
        shutil.rmtree(APPDIR)
    (APPDIR / "usr" / "bin").mkdir(parents=True)
    log(f"Assembling AppDir: {APPDIR}")

    shutil.copy2(exe, APPDIR / "usr" / "bin" / "umbrage")

    desktop = APPDIR / "umbrage.desktop"
    desktop.write_text(
        DESKTOP_TEMPLATE.format(app_name=APP_NAME, app_version=APP_VERSION)
    )

    icon = CACHE_DIR / "umbrage.png"
    run(["rsvg-convert", "-w", "256", "-h", "256", str(ICON_SRC), "-o", str(icon)])

    stub_dir = CACHE_DIR / "qml-stub"
    stub_dir.mkdir(parents=True, exist_ok=True)
    stub = stub_dir / "stub.qml"
    stub.write_text(QML_STUB)

    return desktop, icon, stub_dir


def find_qt6_qmake() -> str:
    for candidate in ("qmake6", "qmake"):
        qmake = shutil.which(candidate)
        if qmake is None:
            continue
        out = subprocess.run(
            [qmake, "-query", "QT_VERSION"], capture_output=True, text=True
        )
        if out.returncode == 0 and out.stdout.strip().startswith("6"):
            return qmake
    die("Qt6 qmake not found. Install Qt6 and put qmake6 on PATH.")


def qt6_query(var: str) -> str:
    out = subprocess.run(
        [find_qt6_qmake(), "-query", var], capture_output=True, text=True, check=True
    )
    return out.stdout.strip()


# Qt imageformats plugins shipped in the base modules. Everything else
# (kimg_* from kimageformats) drags in optional libraries that are not
# installed on every system and can break dependency resolution.
IMAGE_FORMAT_PLUGINS = ("libqgif.so", "libqico.so", "libqjpeg.so", "libqsvg.so")


def filtered_plugins_dir() -> Path:
    return CACHE_DIR / "qt6-plugins"


def write_qmake_shim() -> str:
    """Return a qmake shim whose QT_INSTALL_PLUGINS points at a filtered
    copy of the system plugin directory.

    linuxdeploy-plugin-qt deploys every plugin in each category it handles.
    On rolling distros the imageformats dir contains kimg_* plugins with
    broken optional dependencies, which fails the whole deployment.
    """
    shim_dir = CACHE_DIR / "qt6-shims"
    plugins_filtered = filtered_plugins_dir()
    shim_dir.mkdir(parents=True, exist_ok=True)

    src = Path(qt6_query("QT_INSTALL_PLUGINS"))
    if not src.is_dir():
        die(f"QT_INSTALL_PLUGINS does not exist: {src}")

    if plugins_filtered.exists():
        shutil.rmtree(plugins_filtered)
    for entry in src.iterdir():
        if entry.is_dir() and entry.name == "imageformats":
            dest = plugins_filtered / entry.name
            dest.mkdir(parents=True)
            for plugin in IMAGE_FORMAT_PLUGINS:
                src_file = entry / plugin
                if src_file.exists():
                    shutil.copy2(src_file, dest / plugin)
        else:
            if entry.is_dir():
                shutil.copytree(entry, plugins_filtered / entry.name)
            else:
                shutil.copy2(entry, plugins_filtered / entry.name)

    shim = shim_dir / "qmake"
    shim.write_text(
        "#!/bin/sh\n"
        f'REAL="{find_qt6_qmake()}"\n'
        f'FILTERED="{plugins_filtered}"\n'
        'if [ "$1" = "-query" ] && [ $# -eq 1 ]; then\n'
        '  "$REAL" -query | sed "s|^QT_INSTALL_PLUGINS:.*|QT_INSTALL_PLUGINS:$FILTERED|"\n'
        "  exit 0\n"
        "fi\n"
        'exec "$REAL" "$@"\n'
    )
    shim.chmod(0o755)
    return str(shim)


def run_linuxdeploy(tools: Path, desktop: Path, icon: Path, stub_dir: Path) -> None:
    env = env_with_path([tools])
    env["APPIMAGE_EXTRACT_AND_RUN"] = "1"
    env["VERSION"] = APP_VERSION
    env["QML_SOURCES_PATHS"] = str(stub_dir)
    # The strip binary bundled inside the tool AppImages is too old for
    # binaries produced on recent distros (.relr.dyn sections).
    env["NO_STRIP"] = "1"
    # linuxdeploy-plugin-qt deploys only the xcb platform plugin by
    # default. Add wayland (needed on Wayland sessions) and offscreen
    # (needed for the smoke test).
    env["EXTRA_PLATFORM_PLUGINS"] = "libqoffscreen.so;libqwayland.so"
    # Deploy the svg icon engine (iconengines/libqsvgicon.so + libQt6Svg),
    # otherwise the window icon loaded from qrc assets cannot be rendered.
    env["EXTRA_QT_MODULES"] = "svg"
    # linuxdeploy-plugin-qt prefers Qt5's qmake if both are installed,
    # which makes it ignore the Qt6 libraries in the binary. Point it at
    # a shim that reports Qt6 paths and a sanitized plugin directory.
    env["QMAKE"] = write_qmake_shim()

    log("Deploying with linuxdeploy + Qt plugin")
    run(
        [
            str(tools / "linuxdeploy"),
            "--appdir",
            str(APPDIR),
            "--executable",
            str(APPDIR / "usr" / "bin" / "umbrage"),
            "--desktop-file",
            str(desktop),
            "--icon-file",
            str(icon),
            "--plugin",
            "qt",
        ],
        cwd=PROJECT_ROOT,
        env=env,
    )


def qt_install_qml() -> Path:
    return Path(qt6_query("QT_INSTALL_QML"))


def ensure_qt_extra() -> None:
    """Guarantee qt.conf, the QtQuick Controls style dirs and the Wayland
    client buffer integrations are deployed.

    linuxdeploy-plugin-qt normally handles qt.conf and the styles, but
    versions differ in what they copy. The app forces the Fusion style,
    which itself falls back to Basic delegates, so both must be present.
    The Wayland graphics integration plugins (wayland-egl) are never
    deployed by the plugin, but are required on Wayland sessions.
    """
    qml_dest = APPDIR / "usr" / "qml"
    qt_conf = APPDIR / "usr" / "bin" / "qt.conf"
    if not qt_conf.exists():
        qt_conf.write_text("[Paths]\nPrefix = ..\nPlugins = plugins\nQml2Imports = qml\n")

    qml_src = qt_install_qml()
    for rel in ("QtQuick/Controls/Basic", "QtQuick/Controls/Fusion"):
        dest = qml_dest / rel
        if dest.is_dir():
            continue
        src = qml_src / rel
        if not src.is_dir():
            die(f"style module not found in system Qt: {src}")
        log(f"Copying missing QML style module: {rel}")
        shutil.copytree(src, dest, dirs_exist_ok=True)

    plugins_src = filtered_plugins_dir()
    for rel in ("platformthemes", "wayland-graphics-integration-client"):
        dest = APPDIR / "usr" / "plugins" / rel
        if dest.is_dir():
            continue
        src = plugins_src / rel
        if not src.is_dir():
            die(f"plugin dir not found in filtered Qt plugins: {src}")
        log(f"Copying missing Qt plugin dir: {rel}")
        shutil.copytree(src, dest, dirs_exist_ok=True)


def deploy_deps(tools: Path) -> None:
    """Second linuxdeploy pass: resolve dependencies of files added to the
    AppDir after the plugin ran (e.g. the Wayland graphics integrations).
    """
    env = env_with_path([tools])
    env["APPIMAGE_EXTRACT_AND_RUN"] = "1"
    env["NO_STRIP"] = "1"

    log("Deploying dependencies of files added after the Qt plugin")
    run(
        [str(tools / "linuxdeploy"), "--appdir", str(APPDIR)],
        cwd=PROJECT_ROOT,
        env=env,
    )


APPRUN_TEMPLATE = """\
#!/bin/sh
HERE="${APPDIR:-$(dirname "$(readlink -f "$0")")}"
if [ -z "${QT_QPA_PLATFORMTHEME:-}" ]; then
    # Route file dialogs through the XDG desktop portal
    export QT_QPA_PLATFORMTHEME=xdgdesktopportal
fi
exec "$HERE/usr/bin/umbrage" "$@"
"""


def write_apprun() -> None:
    """Replace linuxdeploy's AppRun symlink with a wrapper that forces the
    xdgdesktopportal platform theme, so Qt.labs.platform file pickers go
    through the XDG desktop portal instead of failing silently.
    """
    apprun = APPDIR / "AppRun"
    apprun.unlink(missing_ok=True)
    apprun.write_text(APPRUN_TEMPLATE)
    apprun.chmod(0o755)
    log(f"AppRun wrapper written: {apprun}")


def smoke_test() -> None:
    binary = APPDIR / "usr" / "bin" / "umbrage"
    env = os.environ.copy()
    env["QT_QPA_PLATFORM"] = "offscreen"
    log("Smoke test: launching with QT_QPA_PLATFORM=offscreen for 15s")
    proc = subprocess.run(
        ["timeout", "15", str(binary)],
        env=env,
        capture_output=True,
        text=True,
        timeout=20,
    )
    output = proc.stdout + proc.stderr
    for needle in ("failed to load component", "is not installed"):
        if needle in output:
            die(f"smoke test failed: {needle!r} found in app output:\n{output[-2000:]}")
    if proc.returncode == 124:
        log("Smoke test passed: app stayed alive for 15s without QML errors")
    elif proc.returncode == 0:
        log("Smoke test finished: app exited cleanly")
    else:
        die(f"app crashed during smoke test (exit code {proc.returncode}):\n{output[-2000:]}")


def run_appimagetool(tools: Path) -> Path:
    env = env_with_path([tools])
    env["APPIMAGE_EXTRACT_AND_RUN"] = "1"
    env["NO_STRIP"] = "1"
    env["ARCH"] = "x86_64"
    env["VERSION"] = APP_VERSION

    DIST_DIR.mkdir(parents=True, exist_ok=True)
    output = DIST_DIR / f"{APP_NAME}-{APP_VERSION}-x86_64.AppImage"
    if output.exists():
        output.unlink()

    log("Packaging AppImage")
    run(
        [str(tools / "appimagetool"), str(APPDIR), str(output)],
        cwd=PROJECT_ROOT,
        env=env,
    )
    if not output.exists():
        die("appimagetool did not produce the AppImage")
    log(f"AppImage: {output}")
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description="Build Umbrage as a Linux AppImage")
    parser.add_argument("--clean", action="store_true")
    parser.add_argument("--no-appimage", action="store_true")
    parser.add_argument("--smoke-test", action="store_true")
    args = parser.parse_args()

    if platform.machine() not in ("x86_64", "AMD64"):
        die(f"unsupported architecture: {platform.machine()}")

    tools = ensure_tools()
    exe = cargo_build(args.clean)

    desktop, icon, stub_dir = prepare_appdir(exe)
    run_linuxdeploy(tools, desktop, icon, stub_dir)
    ensure_qt_extra()
    deploy_deps(tools)
    write_apprun()

    if args.smoke_test:
        smoke_test()

    if args.no_appimage:
        log(f"AppDir ready: {APPDIR}")
        return 0

    run_appimagetool(tools)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as exc:
        die(f"command failed ({exc.returncode}): {exc.cmd}")
