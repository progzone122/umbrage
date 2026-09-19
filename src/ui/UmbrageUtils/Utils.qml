pragma Singleton
import QtQuick

// Small, side-effect-free helpers shared across pages and components.
// Import with `import UmbrageUtils 1.0`, then call e.g. `Utils.elideMiddle(...)`.
QtObject {

    // --- Text truncation ---------------------------------------------------

    // Shortens `value` to at most `max` characters, keeping the middle so the
    // start and end (often the meaningful parts of a path) stay visible.
    function elideMiddle(value, max) {
        if (typeof value !== "string" || value.length <= max)
            return value;
        var keep = Math.max(1, Math.floor((max - 3) / 2));
        return value.substring(0, keep) + "…" + value.substring(value.length - keep);
    }

    // Shortens `value` to at most `max` characters with a trailing ellipsis.
    function elideRight(value, max) {
        if (typeof value !== "string" || value.length <= max)
            return value;
        return value.substring(0, max - 3) + "…";
    }

    // Returns the final path segment (file/folder name) without any directory
    // prefix or trailing slash, e.g. "file:///a/b/c.txt" -> "c.txt".
    function baseName(value) {
        if (typeof value !== "string")
            return value;
        var trimmed = value.replace(/[\/\\]+$/, "");
        var idx = Math.max(trimmed.lastIndexOf("/"), trimmed.lastIndexOf("\\"));
        return idx >= 0 ? trimmed.substring(idx + 1) : trimmed;
    }

    // --- Asset icons -------------------------------------------------------

    // Maps a logical file/type key to its asset path. Returns "" for unknown
    // keys, matching how callers treat an empty `icon.source`.
    function iconFor(key) {
        switch (key) {
        case "da":
            return "qrc:/assets/da_icon.svg";
        case "auth":
            return "qrc:/assets/auth_icon.svg";
        case "preloader":
            return "qrc:/assets/preloader_icon.svg";
        case "vendor":
            return "qrc:/assets/vendor-icon.svg";
        case "device":
            return "qrc:/assets/device-icon.svg";
        case "template":
            return "qrc:/assets/template-icon.svg";
        }
        return "";
    }

    // --- Collection helpers ------------------------------------------------

    // Returns a shallow copy of `list` with `mutator` applied to the entry at
    // `index`. Useful for the "re-assign a fresh array so bindings re-evaluate"
    // pattern used by partition lists.
    function updateAt(list, index, mutator) {
        return list.map(function (entry, i) {
            var copy = JSON.parse(JSON.stringify(entry));
            if (i === index)
                mutator(copy);
            return copy;
        });
    }
}
