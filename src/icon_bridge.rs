// Copyright (C) 2026 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR LGPL-3.0-only

/// Sets the default icon for all windows of the application.
///
/// qtbridge does not expose QGuiApplication::setWindowIcon and QML
/// `Window` has no `icon` property, so this tiny C++ bridge handles it.
#[cxx::bridge]
mod ffi {
    unsafe extern "C++" {
        include!("src/icon_bridge.h");

        fn set_window_icon(path: &str);
    }
}

pub fn set_window_icon(path: &str) {
    ffi::set_window_icon(path);
}
