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

-- Local deletion is opt-in: one PDF/EPUB at a time by Zotero attachment ID,
-- double-confirmed. Never remove a directory, a .sdr, DB or cloud file.
local ENABLE_LOCAL_DELETION = true
local PAGE_SIZE = 5
local PRIMARY_KINDLE_ROOT = "/mnt/us/documents/Zotero/storage"
local LEGACY_KINDLE_ROOT = "/mnt/us/koreader/zotero/storage"

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
    for root_index, root in ipairs(roots) do
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
            for root_index, root in ipairs(roots) do
                if root.usable and not root.seen[item.key] then
                    local folder = root.path .. "/" .. item.key
                    if plainDirectory(folder) then
                        local path = folder .. "/" .. item.data.filename
                        if plainFile(path) then
                            local bytes = tonumber(lfs.attributes(path, "size")) or 0
                            if bytes > 0 then
                                local sidecar_mode = lfs.symlinkattributes(path .. ".sdr", "mode")
                                table.insert(root.files, {
                                    path = path,
                                    bytes = bytes,
                                    folder = folder,
                                    key = item.key,
                                    filename = item.data.filename,
                                    modified = tonumber(lfs.attributes(path, "modification")),
                                    has_sidecar = sidecar_mode == "directory" or sidecar_mode == "file",
                                })
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
    for root_index, root in ipairs(roots) do root.seen = nil end
    return roots
end

local function freeSpace()
    -- On some Kindle environments ffi/util.df may fail for the plugin data
    -- directory even though the user storage volume is available. Prefer
    -- native statvfs, and query the actual user volume as a second choice.
    -- Never use "_" as a scratch variable: it is the gettext translator.
    local paths = { ZoteroAPI.storage_dir, "/mnt/us", ZoteroAPI.zotero_dir }
    for path_index, path in ipairs(paths) do
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


-- One immutable selection ID per specific storage root and Zotero key.
-- Only entries found again in the live local scan are counted in the preview.
local function enumerateFiles(roots)
    local files = {}
    for root_index, root in ipairs(roots) do
        for file_index, file in ipairs(root.files) do
            file.id = root.id .. ":" .. file.key
            file.storage_label = root.label
            files[#files + 1] = file
        end
    end
    table.sort(files, function(a, b)
        local left, right = a.filename:lower(), b.filename:lower()
        if left == right then return a.id < b.id end
        return left < right
    end)
    return files
end

local function selectionTotals(files, selected)
    local count, bytes, with_sidecars = 0, 0, 0
    for file_index, file in ipairs(files) do
        if selected[file.id] then
            count = count + 1
            bytes = bytes + file.bytes
            if file.has_sidecar then with_sidecars = with_sidecars + 1 end
        end
    end
    return count, bytes, with_sidecars
end

-- Trim by UTF-8 codepoint rather than arbitrary byte offset; attachment file
-- names frequently contain accented Portuguese characters.
local function shortFilename(name, limit)
    local value = name:gsub("[%c]", " ")
    local pos, n = 1, 0
    while pos <= #value and n < limit do
        local first = value:byte(pos)
        local width = (first >= 240 and 4) or (first >= 224 and 3)
            or (first >= 192 and 2) or 1
        if pos + width - 1 > #value then break end
        pos = pos + width
        n = n + 1
    end
    if pos > #value then return value end
    return value:sub(1, pos - 1) .. "..."
end

local function showError(err)
    logger.err("Zotero individual storage selection: ", tostring(err))
    UIManager:show(InfoMessage:new({
        text = _("The Zotero storage operation failed. Check the remaining local files and KOReader crash.log before retrying."),
        icon = "notice-warning",
    }))
end

local function guarded(action)
    local ok, err = xpcall(action, debug.traceback)
    if not ok then showError(err) end
end

local function canInspect(plugin)
    if plugin.zotero_sync_in_progress then
        UIManager:show(InfoMessage:new({
            text = _("Finish Zotero synchronization before inspecting local downloads."),
        }))
        return false
    end
    if plugin.ui and plugin.ui.document then
        UIManager:show(InfoMessage:new({
            text = _("Close the open book before inspecting downloads."),
        }))
        return false
    end
    return true
end

local function readLocalFiles()
    -- The local Zotero DB is never modified by this operation.
    local roots = collect()
    return roots, enumerateFiles(roots)
end

local function trustedRoot(path)
    return path == PRIMARY_KINDLE_ROOT or path == LEGACY_KINDLE_ROOT
end

local function selectedSnapshot(files, marked)
    -- Store exactly what the user saw and selected before the confirmations.
    local snapshot = {}
    local count, bytes, sidecars = 0, 0, 0
    for file_index, file in ipairs(files) do
        if marked[file.id] == true then
            snapshot[file.id] = {
                path = file.path,
                folder = file.folder,
                bytes = file.bytes,
                modified = file.modified,
                has_sidecar = file.has_sidecar,
                key = file.key,
                filename = file.filename,
                id = file.id,
            }
            count = count + 1
            bytes = bytes + file.bytes
            if file.has_sidecar then sidecars = sidecars + 1 end
        end
    end
    return snapshot, count, bytes, sidecars
end

local function removeSelectedLocalFiles(plugin, snapshot)
    -- Never enable this outside the two known, local Kindle storage roots.
    if not ENABLE_LOCAL_DELETION or not Device:isKindle() or not canInspect(plugin) then
        return nil, _("Local deletion is not available right now.")
    end
    local live_roots, live_files = readLocalFiles()
    local indexed = {}
    local roots_by_id = {}
    for root_index, root in ipairs(live_roots) do
        roots_by_id[root.id] = root
    end
    for file_index, file in ipairs(live_files) do
        indexed[file.id] = file
    end

    -- All-or-nothing preflight: if anything changed since confirmation, refuse
    -- to delete even the unchanged files. Avoid following symbolic links.
    local count, bytes = 0, 0
    for id, expected in pairs(snapshot) do
        local fresh = indexed[id]
        local root_id = id:match("^([^:]+):")
        local root = roots_by_id[root_id]
        if not root or not trustedRoot(root.path) or not plainDirectory(root.path)
            or not fresh or fresh.path ~= expected.path
            or fresh.folder ~= expected.folder
            or fresh.filename ~= expected.filename
            or fresh.key ~= expected.key
            or fresh.bytes ~= expected.bytes
            or fresh.modified ~= expected.modified
            or fresh.has_sidecar ~= expected.has_sidecar
            or not plainDirectory(fresh.folder)
            or not plainFile(fresh.path)
            or not (fresh.filename:lower():match("%.pdf$")
                 or fresh.filename:lower():match("%.epub$"))
        then
            return nil, _("The local download list changed. Nothing was deleted; refresh the list.")
        end
        count = count + 1
        bytes = bytes + fresh.bytes
    end
    if count == 0 then return nil, _("No files were selected.") end

    local removed, freed, failed = 0, 0, 0
    for id, expected in pairs(snapshot) do
        -- Re-check immediately before the irreversible operation.
        local fresh = indexed[id]
        local attrs = plainFile(fresh.path) and lfs.attributes(fresh.path)
        if attrs and tonumber(attrs.size) == expected.bytes
            and tonumber(attrs.modification) == expected.modified
            and plainDirectory(fresh.folder) and plainFile(fresh.path)
        then
            local ok = os.remove(fresh.path)
            if ok then
                removed = removed + 1
                freed = freed + fresh.bytes
            else
                failed = failed + 1
            end
        else
            failed = failed + 1
        end
    end
    -- Deliberately do not touch .sdr, annotations, database, or cache folders.
    logger.info("Zotero storage: user-confirmed local PDF/EPUB removal",
        removed, "bytes", freed, "failures", failed)
    return { removed = removed, freed = freed, failed = failed }
end

local function confirmIndividualDeletion(plugin, files, selected, page, dialog)
    if not ENABLE_LOCAL_DELETION or not Device:isKindle() then
        UIManager:show(InfoMessage:new({text = _("Local deletion is available only on Kindle.")}))
        return
    end
    if not canInspect(plugin) then return end
    local snapshot, count, bytes, sidecars = selectedSnapshot(files, selected)
    if count == 0 then
        UIManager:show(InfoMessage:new({ text = _("Mark one or more downloads first.") }))
        return
    end
    local names = {}
    for file_index, file in ipairs(files) do
        if snapshot[file.id] and #names < 3 then
            names[#names + 1] = shortFilename(file.filename, 32)
        end
    end
    local brief = table.concat(names, "\n")
    if count > #names then
        brief = brief .. "\n" .. _("...and more marked documents")
    end

    local first_confirmation = ConfirmBox:new({
        text = _("Remove the selected LOCAL Kindle copies?")
            .. "\n\n" .. count .. " " .. _("document(s)")
            .. " / " .. sizeText(bytes)
            .. "\n" .. brief
            .. "\n\n" .. _("Zotero and Dropbox originals are not deleted."),
        ok_text = _("Continue"),
        ok_callback = function()
            local second_confirmation = ConfirmBox:new({
                text = _("FINAL CONFIRMATION: permanently remove these local PDFs/EPUBs?")
                    .. "\n\n" .. count .. " / " .. sizeText(bytes)
                    .. "\n" .. _("Files with KOReader .sdr data") .. ": " .. sidecars
                    .. "\n\n" .. _("KOReader .sdr files and Zotero metadata will remain.")
                    .. "\n" .. _("IMPORTANT: annotations embedded in a local PDF, or not yet backed up/synced, may be LOST. Back them up before proceeding.")
                    .. "\n\n" .. _("This operation cannot be undone on the Kindle."),
                ok_text = _("Delete local copies"),
                ok_callback = function()
                    guarded(function()
                        local result, reason = removeSelectedLocalFiles(plugin, snapshot)
                        if not result then
                            UIManager:show(InfoMessage:new({text = reason}))
                            return
                        end
                        UIManager:close(dialog)
                        M.showIndividual(plugin, {}, page)
                        UIManager:show(InfoMessage:new({
                            text = _("Local files removed") .. ": " .. result.removed
                                .. "\n" .. _("Space recovered") .. ": " .. sizeText(result.freed)
                                .. "\n" .. _("Failed/skipped") .. ": " .. result.failed
                                .. "\n\n" .. _("Zotero, Dropbox and .sdr were not deleted."),
                        }))
                    end)
                end,
            })
            UIManager:show(second_confirmation)
        end,
    })
    UIManager:show(first_confirmation)
end

function M.showIndividual(plugin, selected, page)
    guarded(function()
        if not canInspect(plugin) then return end
        selected = selected or {}
        local roots, files = readLocalFiles()
        local count, bytes, with_sidecars = selectionTotals(files, selected)
        local total_pages = math.max(1, math.ceil(#files / PAGE_SIZE))
        page = math.max(1, math.min(tonumber(page) or 1, total_pages))

        local lines = {
            _("Tap an item to mark/unmark it; hold it to see the complete filename and details."),
            _("Page") .. " " .. page .. "/" .. total_pages
                .. " | " .. _("Documents") .. ": " .. #files,
            _("Marked") .. ": " .. count .. " / " .. sizeText(bytes),
            _("Only checked local files can be deleted after two confirmations."),
        }
        if with_sidecars > 0 then
            lines[#lines + 1] = _("Marked items with KOReader .sdr data") .. ": " .. with_sidecars
        end
        local buttons = {}
        local dialog

        if #files == 0 then
            lines[#lines + 1] = _("No downloaded Zotero PDF or EPUB files were found.")
        else
            local first_index = (page - 1) * PAGE_SIZE + 1
            local last_index = math.min(#files, page * PAGE_SIZE)
            for index = first_index, last_index do
                -- Copy the loop item into an individual callback closure.
                local file = files[index]
                local checked = selected[file.id] == true
                local mark = checked and "[x] " or "[ ] "
                local display_name = shortFilename(file.filename, 35)
                buttons[#buttons + 1] = {{
                    text = mark .. display_name .. " (" .. sizeText(file.bytes) .. ")",
                    align = "left",
                    callback = function()
                        selected[file.id] = not selected[file.id]
                        UIManager:close(dialog)
                        M.showIndividual(plugin, selected, page)
                    end,
                    hold_callback = function()
                        local modified = file.modified
                            and os.date("%d/%m/%Y %H:%M", file.modified) or _("Unknown")
                        UIManager:show(InfoMessage:new({
                            text = file.filename
                                .. "\n\n" .. _("File size") .. ": " .. sizeText(file.bytes)
                                .. "\n" .. _("File last modified") .. ": " .. modified
                                .. "\n" .. _("Zotero key") .. ": " .. file.key
                                .. "\n" .. _("Storage") .. ": " .. file.storage_label
                                .. "\n" .. _("KOReader .sdr data") .. ": "
                                    .. (file.has_sidecar and _("Present") or _("Not found"))
                                .. "\n\n" .. _("An .sdr folder does not prove that annotations have been synchronized."),
                        }))
                    end,
                }}
            end
        end

        if total_pages > 1 then
            buttons[#buttons + 1] = {
                {
                    text = _("Previous"),
                    enabled = page > 1,
                    callback = function()
                        UIManager:close(dialog)
                        M.showIndividual(plugin, selected, page - 1)
                    end,
                },
                {
                    text = _("Next"),
                    enabled = page < total_pages,
                    callback = function()
                        UIManager:close(dialog)
                        M.showIndividual(plugin, selected, page + 1)
                    end,
                },
            }
        end

        buttons[#buttons + 1] = {
            {
                text = _("Clear marks"),
                enabled = count > 0,
                callback = function()
                    UIManager:close(dialog)
                    M.showIndividual(plugin, {}, page)
                end,
            },
            {
                text = _("Preview selection"),
                enabled = count > 0,
                callback = function()
                    local message = _("Selected Zotero downloads") .. ": " .. count
                        .. "\n" .. _("Total local PDF/EPUB size") .. ": " .. sizeText(bytes)
                        .. "\n" .. _("With KOReader .sdr data") .. ": " .. with_sidecars
                        .. "\n\n" .. _("Preview only: no files have been deleted.")
                        .. "\n" .. _("Do not assume .sdr reading data or annotations are backed up or synced.")
                    UIManager:show(InfoMessage:new({ text = message }))
                end,
            },
        }
        buttons[#buttons + 1] = {{
            text = _("Delete checked local downloads"),
            enabled = ENABLE_LOCAL_DELETION and count > 0,
            callback = function()
                guarded(function()
                    confirmIndividualDeletion(plugin, files, selected, page, dialog)
                end)
            end,
        }}
        buttons[#buttons + 1] = {
            {
                text = _("Back to report"),
                callback = function()
                    UIManager:close(dialog)
                    M.show(plugin)
                end,
            },
            {
                text = _("Close"),
                callback = function() UIManager:close(dialog) end,
            },
        }

        dialog = ButtonDialog:new({
            title = _("Zotero downloads - individual selection")
                .. "\n\n" .. table.concat(lines, "\n"),
            buttons = buttons,
            width_factor = 0.94,
        })
        UIManager:show(dialog)
    end)
end

function M.show(plugin)
    if not canInspect(plugin) then return end
    local success, roots_or_error, files = pcall(readLocalFiles)
    if not success then
        showError(roots_or_error)
        return
    end

    local roots = roots_or_error
    local lines = {
        freeSpace(),
        "",
        _("Only local Zotero PDF/EPUB downloads are listed."),
    }
    for root_index, root in ipairs(roots) do
        lines[#lines + 1] = root.label .. ": " .. root.count .. " / " .. sizeText(root.bytes)
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = _("Only explicitly checked local PDFs/EPUBs can be removed.")
    lines[#lines + 1] = _("Zotero, Dropbox and .sdr stay untouched.")

    local dialog
    dialog = ButtonDialog:new({
        title = _("Zotero storage and cleanup") .. "\n\n" .. table.concat(lines, "\n"),
        buttons = {
            {{
                text = _("Select individual downloads") .. " (" .. #files .. ")",
                callback = function()
                    UIManager:close(dialog)
                    M.showIndividual(plugin, {}, 1)
                end,
            }},
            {{
                text = _("Close"),
                callback = function() UIManager:close(dialog) end,
            }},
        },
    })
    UIManager:show(dialog)
end

return M
