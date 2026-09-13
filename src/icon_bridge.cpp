#include "icon_bridge.h"

void set_window_icon(rust::Str path) {
    QGuiApplication::setWindowIcon(
        QIcon(QString::fromUtf8(path.data(), static_cast<int>(path.size())))
    );
}
