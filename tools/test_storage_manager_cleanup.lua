-- Lua 5.1 mocked regression: storage UI + STRICT local-only deletion safeguards.
-- No real Zotero database, Kindle files, .sdr or Dropbox account is accessed.
-- Run: lua5.1 tools/test_storage_manager_cleanup.lua

local windows, removed = {}, {}
local fs = {}
local root = "/mnt/us/documents/Zotero/storage"
local legacy = "/mnt/us/koreader/zotero/storage"
fs[root], fs[legacy] = { mode = "directory" }, { mode = "directory" }
local originals, items = {}, {}
for index = 1, 12 do
    local key = string.format("ABCD%04d", index)
    local name = string.format("Paper %02d - Testing agent-based models.pdf", index)
    local folder = root .. "/" .. key
    local path = folder .. "/" .. name
    fs[folder] = { mode = "directory" }
    fs[path] = { mode = "file", size = index * 1024 * 1024, modification = 1700000000 }
    originals[index] = path
    items[index] = {
        key = key,
        data = { itemType = "attachment", linkMode = "imported_file",
            filename = name, contentType = "application/pdf" },
    }
    if index == 1 then fs[path .. ".sdr"] = {mode = "directory"} end
end

local expected_removable = {}
local native_remove = os.remove
os.remove = function(path)
    assert(expected_removable[path], "unapproved os.remove path: " .. tostring(path))
    assert(fs[path] and fs[path].mode == "file", "invalid file deletion")
    removed[#removed + 1] = path
    fs[path] = nil
    return true
end
package.preload["gettext"] = function() return function(text) return text end end
package.preload["logger"] = function() return {
    info = function() end,
    err = function(...) error("unexpected logger.err: " .. tostring(select(1, ...))) end,
} end
package.preload["device"] = function() return {isKindle = function() return true end} end
package.preload["ffi/util"] = function() return {
    df = function() return 6 * 1024^3, 5 * 1024^3, 5 * 1024^3 end,
} end
package.preload["libs/libkoreader-lfs"] = function()
    local function attr(path, key)
        local entry = fs[path]
        return entry and (key and entry[key] or entry) or nil
    end
    return {attributes = attr, symlinkattributes = attr}
end
package.preload["json"] = function() return {
    decode = function(value)
        local n = tonumber(value:match("^entry(%d+)$"))
        return assert(items[n], "unknown entry")
    end,
} end
local scanned_count = 0
package.preload["zoteroapi"] = function() return {
    storage_dir = root,
    legacy_storage_dir = legacy,
    zotero_dir = "/mnt/us/koreader/zotero",
    openDB = function()
        scanned_count = scanned_count + 1
        return {prepare = function()
            local stmt = {position = 0}
            function stmt:reset() self.position = 0; return self end
            function stmt:step()
                self.position = self.position + 1
                if self.position > #items then return nil end
                return {"entry" .. self.position}
            end
            function stmt:close() end
            return stmt
        end}
    end,
} end
local function widget() return {new = function(self, args) return args end} end
package.preload["ui/widget/buttondialog"] = widget
package.preload["ui/widget/confirmbox"] = widget
package.preload["ui/widget/infomessage"] = widget
package.preload["ui/uimanager"] = function() return {
    show = function(self, window) windows[#windows + 1] = window end,
    close = function() end,
} end

local manager = assert(loadfile("zotero_storage_manager.lua"))()
local plugin = {zotero_sync_in_progress = false, ui = {document = nil}}
local function current() return assert(windows[#windows]) end
local function expect(value, excerpt)
    assert(type(value) == "string" and value:find(excerpt, 1, true),
        "expected [" .. excerpt .. "] in [" .. tostring(value) .. "]")
end

manager.show(plugin)
expect(current().title, "12 / 78.0 MiB")
expect(current().title, "Available")
current().buttons[1][1].callback()

local list = current()
expect(list.title, "Page 1/3")
expect(list.title, "Marked: 0 / 0.0 MiB")
assert(not list.buttons[8][1].enabled, "delete button must be disabled with empty selection")
list.buttons[1][1].hold_callback()
expect(current().text, "KOReader .sdr data: Present")

list.buttons[1][1].callback() -- select first with .sdr
list = current()
expect(list.title, "Marked: 1 / 1.0 MiB")
list.buttons[6][2].callback() -- next page
list = current()
expect(list.title, "Page 2/3")
list.buttons[1][1].callback() -- select sixth
list = current()
expect(list.title, "Marked: 2 / 7.0 MiB")

-- Preview is informational; no deletion side effects.
list.buttons[7][2].callback()
expect(current().text, "Preview only: no files have been deleted.")
assert(#removed == 0, "preview unexpectedly removed files")

-- Stage 1 and stage 2 each require an actual explicit confirmation.
expected_removable[originals[1]] = true
expected_removable[originals[6]] = true
list.buttons[8][1].callback()
local step1 = current()
expect(step1.text, "Remove the selected LOCAL Kindle copies?")
assert(#removed == 0)
step1.ok_callback()
local step2 = current()
expect(step2.text, "FINAL CONFIRMATION")
expect(step2.text, "annotations embedded in a local PDF")
assert(#removed == 0)
step2.ok_callback()
expect(current().text, "Local files removed: 2")
assert(#removed == 2, "expected two deleted local PDFs")
assert(fs[originals[1]] == nil and fs[originals[6]] == nil)
assert(fs[originals[1] .. ".sdr"].mode == "directory", ".sdr data must be retained")
for i = 2, 12 do
    if i ~= 6 then
        assert(fs[originals[i]].mode == "file", "unselected PDF was removed: " .. i)
    end
end
assert(scanned_count > 0, "Zotero DB should have been queried read-only")

-- Change a second selection after confirmation; the preflight must abort
-- before deleting anything, including unchanged files.
local after_list = windows[#windows - 1]
expect(after_list.title, "Documents: 10")
-- Return to page 1, where the first remaining document is Paper 02.
after_list.buttons[6][1].callback()
local page_one = current()
expect(page_one.title, "Page 1/2")
page_one.buttons[1][1].callback()
local new_list = current()
expect(new_list.title, "Marked: 1 / 2.0 MiB")
new_list.buttons[8][1].callback()
local changed_step1 = current()
changed_step1.ok_callback()
local changed_step2 = current()
fs[originals[2]].size = 3 * 1024 * 1024 -- simulated new attachment version
changed_step2.ok_callback()
expect(current().text, "Nothing was deleted")
assert(#removed == 2 and fs[originals[2]] ~= nil, "preflight must not remove changed files")

os.remove = native_remove
print("PASS: 12 files; 3 pages; explicit 2-step confirmation; only 2 selected local PDFs deleted; .sdr kept; changed-file preflight refused deletion")
