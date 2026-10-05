"""Read the application version from Cargo.toml.

build_appimage.py and build_windows.py both name their output after the
application version. It lives in Cargo.toml's [package] table.
"""

from __future__ import annotations

import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
CARGO_TOML = PROJECT_ROOT / "Cargo.toml"


def _table(text: str, name: str) -> str | None:
    """Return the body of a `[name]` TOML table, up to the next table."""
    match = re.search(
        rf"^\[{re.escape(name)}\][ \t]*$(?P<body>.*?)(?=^\[|\Z)",
        text,
        re.MULTILINE | re.DOTALL,
    )
    return match.group("body") if match else None


def _string_key(body: str, key: str) -> str | None:
    match = re.search(
        rf'^[ \t]*{re.escape(key)}[ \t]*=[ \t]*"([^"]*)"',
        body,
        re.MULTILINE,
    )
    return match.group(1) if match else None


def read_app_version(cargo_toml: Path = CARGO_TOML) -> str:
    """Return the application version from Cargo.toml.

    Cargo allows a literal `version = "..."` under `[package]`, or
    `version.workspace = true` to inherit from `[workspace.package]`.
    Handles both.
    """
    cargo_toml = Path(cargo_toml)
    text = cargo_toml.read_text(encoding="utf-8")

    package = _table(text, "package")
    if package is None:
        raise ValueError(f"no [package] table in {cargo_toml}")

    version = _string_key(package, "version")
    if version is not None:
        return version

    if re.search(r"^[ \t]*version\.workspace[ \t]*=[ \t]*true", package, re.MULTILINE):
        workspace = _table(text, "workspace.package")
        inherited = _string_key(workspace, "version") if workspace else None
        if inherited is not None:
            return inherited
        raise ValueError(
            f"[package] inherits version but [workspace.package] has none "
            f"in {cargo_toml}"
        )

    raise ValueError(f"no version found in [package] of {cargo_toml}")
