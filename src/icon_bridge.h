#pragma once

#include "umbrage/src/icon_bridge.rs.h"

#include <QGuiApplication>
#include <QIcon>
#include <QString>

void set_window_icon(rust::Str path);
