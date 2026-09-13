# Contributing

Thanks for wanting to help. Before you start, read the "Using AI" section in the [README](README.md). Use AI as an assistant if you like, but understand every line you submit. Unverified "vibe coded" PRs get closed.

## Native build

You need Rust and Qt 6.10 or newer with development files.

The build script finds `rcc` via the `RCC` environment variable, then `QTDIR`/`QT_DIR`/`QT6_DIR`, then `PATH`, then the standard Homebrew and Qt installer locations. Set `RCC=/path/to/rcc` if yours lives somewhere else.

## Cross-compiling for Windows

If you want to have a little sex, check this out [CROSSCOMPILE.md](./CROSSCOMPILE.md)

## Building an AppImage

Linux users who want a single runnable file instead of installing Qt can build an AppImage with:

```
python3 scripts/build_appimage.py
```

The script needs `cargo`, `patchelf`, `strip`, `rsvg-convert`, and `curl` (or `wget`) on PATH.
It downloads pinned copies of `linuxdeploy`, its Qt plugin, and `appimagetool` into `~/.cache/umbrage-cross`, builds the release binary, assembles an AppDir, bundles Qt and its plugins, and writes `dist/Umbrage-0.1.0-x86_64.AppImage`.

Things to know before you run it:

- It only targets x86_64. The script refuses to run on arm64 or anything else.
- The Qt libraries come from your host system via `qmake`. If you build on a rolling-release distro, the resulting AppImage likely won't run on older distros. For wider compatibility, build inside a container based on an older distro image.
- `--smoke-test` launches the AppDir binary with the offscreen Qt platform for 15 seconds to catch missing libs, plugins, or QML modules. Run it before bothering to package.
- `--no-appimage` stops after the AppDir is assembled so you can inspect it. `--clean` wipes the release target first.

The packaged AppImage runs with no Qt installed on the target machine. It sets `QT_QPA_PLATFORMTHEME=xdgdesktopportal` unless you override it, so the file pickers route through the XDG desktop portal.

## Pull requests

- Keep changes focused. One fix or feature per PR.
- Match the existing code style.
- Build for the platform you touched and describe how you tested it.
