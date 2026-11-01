-- Use core gettext only here: _meta.lua is loaded before the plugin path
-- is always on package.path, so require("zotero_i18n") can fail and hide the plugin.
local _ = require("gettext")

return {
    -- Plugin id = folder name (zoteroatelier.koplugin → zoteroatelier).
    -- Do not rely on a "name" field here (deprecated in recent KOReader).
    fullname = _("Zotero Atelier Drop Sync"),
    description = _([[
Community fork: Zotero annotations + PDF/EPUB downloads from Dropbox storage folders.

Where to find it:
• Top menu → Search (magnifier) → Zotero Atelier
• Top menu → Tools → Zotero Atelier
• Top menu → Settings (gear) → Zotero Atelier
• Enable: Settings → Plugin management → User plugins → Zotero Atelier Drop Sync

Required folder: zoteroatelier.koplugin (with main.lua and _meta.lua at its root).
Fully restart KOReader after install.]]),
}
