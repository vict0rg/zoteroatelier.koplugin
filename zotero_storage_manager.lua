-- Zotero Atelier: conservative local storage report and optional cleanup.
-- Scope: Zotero-managed PDF/EPUB attachments only, in this plugin's primary
-- or legacy cache roots. Never deletes SQLite metadata, OAuth keys,
-- KOReader .sdr reading progress, or the global cr3cache.

local ZoteroAPI = require("zoteroapi")
local UIManager = require("ui/uimanager")
local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local lfs = require("libs/libkoreader-lfs")
local util = require("ffi/util")
local Device = require("device")
local JSON = require("json")
local logger = require("logger")
local _ = require("gettext")

local M = {}

-- First on-device diagnostic release: report sizes without permitting removal.
-- Re-enable deletion only after a device test and audit of annotation safety.
local SAFE_READ_ONLY = true

local function sizeText(bytes)
    local mib = (tonumber(bytes) or 0) / (1024 * 1024)
    if mib < 0.1 and bytes > 0 then
        return string.format("%.1f KiB", bytes / 1024)
    end
    if mib >= 1024 then
        return string.format("%.2f GiB", mib / 1024)
    end
    return string.format("%.1f MiB", mib)
end

local function plainDirectory(path)
    -- Refuse symlinked roots; these are managed plugin directories only.
    return type(path) == "string" and type(lfs.symlinkattributes) == "function"
        and lfs.symlinkattributes(path, "mode") == "directory"
end

local function plainFile(path)
    return type(lfs.symlinkattributes) == "function"
        and lfs.symlinkattributes(path, "mode") == "file"
end

local function validAttachment(entry)
    if type(entry) ~= "table" or type(entry.data) ~= "table" then return false end
    local data = entry.data
    if type(entry.key) ~= "string" or not entry.key:match("^[A-Za-z0-9]+$") then
        return false
    end
    if data.linkMode ~= "imported_file" and data.linkMode ~= "imported_url" then
        return false
    end
    local filename = data.filename
    if type(filename) ~= "string" or filename == "" or filename == "."
        or filename == ".." or filename:find("/", 1, true)
        or filename:find("\\", 1, true) or filename:find("%z") then
        return false
    end
    -- Do not delete arbitrary files that happen to share a Zotero key folder.
    local suffix = filename:lower()
    return suffix:match("%.pdf$") ~= nil or suffix:match("%.epub$") ~= nil
end

local function getRoots()
    local roots = {}
    local primary = ZoteroAPI.storage_dir
    local legacy = ZoteroAPI.legacy_storage_dir
    if type(primary) == "string" and primary ~= "" then
        table.insert(roots, {
            id = "primary",
            path = primary,
            label = primary:find("/documents/Zotero/", 1, true)
                and _("Zotero books in Documents") or _("Zotero attachment downloads"),
        })
    end
    if type(legacy) == "string" and legacy ~= "" and legacy ~= primary then
        table.insert(roots, {
            id = "legacy",
            path = legacy,
            label = _("Old Zotero storage folder"),
        })
    end
    return roots
end

local function collect()
    local roots = getRoots()
    for _, root in ipairs(roots) do
        root.files = {}
        root.bytes = 0
        root.count = 0
        root.usable = plainDirectory(root.path)
        root.seen = {}
    end

    local db = ZoteroAPI.openDB()
    local stmt = db:prepare([[
        SELECT itemData.value
        FROM itemData INNER JOIN items ON items.itemID = itemData.itemID
        WHERE items.itemTypeID = 3;
    ]])
    local row = stmt:reset():step()
    while row do
        local valid_json, item = pcall(JSON.decode, row[1])
        if valid_json and validAttachment(item) then
            for _, root in ipairs(roots) do
                if root.usable and not root.seen[item.key] then
                    local folder = root.path .. "/" .. item.key
                    if plainDirectory(folder) then
                        local path = folder .. "/" .. item.data.filename
                        if plainFile(path) then
                            local bytes = tonumber(lfs.attributes(path, "size")) or 0
                            if bytes > 0 then
                                table.insert(root.files, { path = path, bytes = bytes, folder = folder })
                                root.bytes = root.bytes + bytes
                                root.count = root.count + 1
                                root.seen[item.key] = true
                            end
                        end
                    end
                end
            end
        end
        row = stmt:step(row)
    end
    stmt:close()
    for _, root in ipairs(roots) do root.seen = nil end
    return roots
end

local function freeSpace()
    -- On some Kindle environments ffi/util.df may fail for the plugin data
    -- directory even though the user storage volume is available. Prefer
    -- native statvfs, and query the actual user volume as a second choice.
    -- Never use "_" as a scratch variable: it is the gettext translator.
    local paths = { ZoteroAPI.storage_dir, "/mnt/us", ZoteroAPI.zotero_dir }
    for _, path in ipairs(paths) do
        if type(path) == "string" and lfs.attributes(path, "mode") == "directory" then
            local ok, total_bytes, free_bytes, available_bytes = pcall(util.df, path)
            local total = tonumber(total_bytes)
            local available = tonumber(available_bytes)
            if ok and total and available and total > 0 and available >= 0 then
                return _("Device storage") .. ": " .. sizeText(total) .. "\n"
                    .. _("Available") .. ": " .. sizeText(available)
            end
        end
    end

    -- BusyBox's df is available on many Kindles even when ffi statvfs is
    -- unavailable. Run ONLY the fixed /mnt/us command, never a user path.
    -- Parse the 1K-blocks, Used, Available and Use% columns; fail closed.
    if Device:isKindle() and type(io.popen) == "function" then
        local ok_pipe, pipe = pcall(io.popen, "df -k /mnt/us 2>/dev/null", "r")
        if ok_pipe and pipe then
            local ok_read, output = pcall(function() return pipe:read("*a") end)
            pcall(function() pipe:close() end)
            if ok_read and type(output) == "string" then
                for line in output:gmatch("[^\r\n]+") do
                    local blocks, available_blocks = line:match(
                        "%s+(%d+)%s+%d+%s+(%d+)%s+%d+%%"
                    )
                    local total = tonumber(blocks)
                    local available = tonumber(available_blocks)
                    if total and available and total > 0 and available >= 0 then
                        return _("Device storage") .. ": " .. sizeText(total * 1024) .. "\n"
                            .. _("Available") .. ": " .. sizeText(available * 1024)
                    end
                end
            end
        end
    end
    return _("Free disk space not available")
end

local function selectedTotals(roots, selected)
    local count, bytes = 0, 0
    for _, root in ipairs(roots) do
        if selected[root.id] then
            count = count + root.count
            bytes = bytes + root.bytes
        end
    end
    return count, bytes
end

local function cleanSelected(selected)
    -- Re-enumerate from the local Zotero metadata. Do not accept file paths
    -- from the UI state, and never recurse-delete whole folders.
    local roots = collect()
    local deleted, bytes, failed = 0, 0, 0
    for _, root in ipairs(roots) do
        if selected[root.id] and root.usable then
            for _, file in ipairs(root.files) do
                -- Check path components again, immediately before removal.
                if plainDirectory(root.path) and plainDirectory(file.folder)
                    and plainFile(file.path) then
                    local ok = os.remove(file.path)
                    if ok then
                        deleted = deleted + 1
                        bytes = bytes + file.bytes
                    else
                        failed = failed + 1
                    end
                else
                    failed = failed + 1
                end
            end
        end
    end
    -- Intentionally keep .sdr/sidecar files: reading progress, annotations,
    -- display preferences and other auxiliary data remain intact.
    logger.info("Zotero storage cleanup: removed local attachments", deleted,
        "bytes", bytes, "failures", failed)
    return deleted, bytes, failed
end

function M.show(plugin, selected)
    selected = selected or { primary = false, legacy = false }
    if plugin.zotero_sync_in_progress then
        UIManager:show(InfoMessage:new({
            text = _("Finish Zotero synchronization before cleaning local downloads."),
        }))
        return
    end
    if plugin.ui and plugin.ui.document then
        UIManager:show(InfoMessage:new({
            text = _("Close the current book before cleaning Zotero downloads."),
        }))
        return
    end
    local success, roots = pcall(collect)
    if not success then
        logger.err("Zotero storage manager: failed to scan: ", roots)
        UIManager:show(InfoMessage:new({
            text = _("Unable to inspect Zotero local downloads. Check crash.log."),
            icon = "notice-warning",
        }))
        return
    end

    local lines = { freeSpace(), "", _("Only managed Zotero PDF/EPUB downloads are selectable.") }
    local buttons = {}
    local count, bytes = selectedTotals(roots, selected)
    local dialog
    for _, root in ipairs(roots) do
        table.insert(lines, root.label .. ": " .. root.count .. " / " .. sizeText(root.bytes))
        local which = root.id
        local marker = selected[which] and "[x] " or "[ ] "
        table.insert(buttons, {
            {
                text = marker .. root.label .. " (" .. sizeText(root.bytes) .. ")",
                callback = function()
                    UIManager:close(dialog)
                    selected[which] = not selected[which]
                    M.show(plugin, selected)
                end,
            },
        })
    end
    table.insert(lines, "")
    table.insert(lines, _("Selected, estimated recovery") .. ": " .. count .. " / " .. sizeText(bytes))
    if SAFE_READ_ONLY then
        table.insert(lines, _("READ-ONLY TEST: deletion is temporarily disabled."))
    end
    table.insert(lines, _("No metadata, credentials, reading progress or shared KOReader cache will be erased."))
    table.insert(buttons, {
        {
            text = _("Close"),
            callback = function() UIManager:close(dialog) end,
        },
        {
            text = SAFE_READ_ONLY and _("Delete disabled (read-only test)") or _("Delete selected downloads"),
            callback = function()
                if SAFE_READ_ONLY then
                    UIManager:show(InfoMessage:new({
                        text = _("No documents can be deleted in this test version."),
                        icon = "notice-info",
                    }))
                    return
                end
                UIManager:close(dialog)
                if count == 0 then
                    UIManager:show(InfoMessage:new({ text = _("No downloads selected.") }))
                    return
                end
                local confirm = ConfirmBox:new({
                    text = _("Remove local Zotero PDF/EPUB files?")
                        .. "\n\n" .. count .. " " .. _("file(s)")
                        .. "\n" .. _("Estimated space") .. ": " .. sizeText(bytes)
                        .. "\n\n" .. _("This cannot be undone locally. Zotero metadata and reading progress remain. Files can be downloaded again when online."),
                    ok_text = _("Delete"),
                    ok_callback = function()
                        local ok, removed, freed, failed = pcall(cleanSelected, selected)
                        if not ok then
                            logger.err("Zotero storage manager: cleanup error: ", removed)
                            UIManager:show(InfoMessage:new({
                                text = _("Cleanup interrupted; check KOReader crash.log."),
                                icon = "notice-warning",
                            }))
                            return
                        end
                        UIManager:show(InfoMessage:new({
                            text = _("Removed") .. ": " .. removed
                                .. "\n" .. _("Estimated space recovered") .. ": " .. sizeText(freed)
                                .. "\n" .. _("Failed") .. ": " .. failed
                                .. "\n" .. _("The SQLite library and reading settings were preserved."),
                        }))
                    end,
                })
                UIManager:show(confirm)
            end,
        },
    })
    dialog = ButtonDialog:new({
        title = _("Zotero storage report (read-only)") .. "\n\n" .. table.concat(lines, "\n"),
        buttons = buttons,
    })
    UIManager:show(dialog)
end

return M
