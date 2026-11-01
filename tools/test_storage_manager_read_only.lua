-- Standalone Lua 5.1 smoke test of the Zotero Atelier read-only viewer.
-- No KOReader runtime, real filesystem, Zotero DB or Dropbox credentials.
-- Run from repository root: lua5.1 tools/test_storage_manager_read_only.lua

local windows = {}
local actual_remove = os.remove
os.remove = function()
    error("READ-ONLY TEST: a file deletion was attempted!")
end

package.preload["gettext"] = function() return function(value) return value end end
package.preload["logger"] = function()
    return { err = function(...) error("Unexpected KOReader error dialog: " .. tostring(select(1, ...))) end }
end
package.preload["device"] = function()
    return { isKindle = function() return true end }
end
package.preload["ffi/util"] = function()
    return { df = function()
        return 6 * 1024^3, 5 * 1024^3, 5 * 1024^3
    end }
end

local root = "/mnt/us/documents/Zotero/storage"
local old_root = "/mnt/us/koreader/zotero/storage"
local raw = {}
local paths = {
    [root] = { mode = "directory" },
    [old_root] = { mode = "directory" },
}
for i = 1, 12 do
    local key = string.format("ABCD%04d", i)
    local name = string.format("Paper %02d - Test agent-based modeling.pdf", i)
    local folder = root .. "/" .. key
    local filename = folder .. "/" .. name
    raw[i] = {
        key = key,
        data = {
            itemType = "attachment",
            linkMode = "imported_file",
            filename = name,
            contentType = "application/pdf",
        },
    }
    paths[folder] = { mode = "directory" }
    paths[filename] = { mode = "file", size = i * 1024 * 1024, modification = 1700000000 }
    if i == 1 then paths[filename .. ".sdr"] = { mode = "directory" } end
end

package.preload["libs/libkoreader-lfs"] = function()
    local function attr(path, what)
        local p = paths[path]
        if not p then return nil end
        return what and p[what] or p
    end
    return { attributes = attr, symlinkattributes = attr }
end
package.preload["json"] = function()
    return { decode = function(value)
        local i = tonumber(value:match("^entry(%d+)$"))
        assert(i and raw[i], "unexpected Zotero JSON mock")
        return raw[i]
    end }
end
package.preload["zoteroapi"] = function()
    return {
        storage_dir = root,
        legacy_storage_dir = old_root,
        zotero_dir = "/mnt/us/koreader/zotero",
        openDB = function()
            return {
                prepare = function()
                    local stmt = { index = 0 }
                    function stmt:reset()
                        self.index = 0
                        return self
                    end
                    function stmt:step()
                        self.index = self.index + 1
                        if self.index > 12 then return nil end
                        return { "entry" .. self.index }
                    end
                    function stmt:close() end
                    return stmt
                end,
            }
        end,
    }
end

local function widget()
    return { new = function(self, config) return config end }
end
package.preload["ui/widget/buttondialog"] = widget
package.preload["ui/widget/infomessage"] = widget
package.preload["ui/uimanager"] = function()
    return {
        show = function(self, value) windows[#windows + 1] = value end,
        close = function(self, value) end,
    }
end

local M = assert(loadfile("zotero_storage_manager.lua"))()
local plugin = { zotero_sync_in_progress = false, ui = { document = nil } }

local function current()
    assert(#windows > 0, "no UI displayed")
    return windows[#windows]
end
local function assertContains(value, part)
    assert(type(value) == "string" and value:find(part, 1, true),
        "missing " .. part .. " in " .. tostring(value))
end

-- The original report must show 12 local downloads and the free space.
M.show(plugin)
local report = current()
assertContains(report.title, "12 / 78.0 MiB")
assertContains(report.title, "Available")
assertContains(report.buttons[1][1].text, "Select individual downloads")

-- Enter first of three pages (five items each).
report.buttons[1][1].callback()
local list = current()
assertContains(list.title, "Page 1/3")
assertContains(list.title, "Marked: 0 / 0.0 MiB")
assertContains(list.buttons[1][1].text, "[ ]")
assert(type(list.buttons[1][1].hold_callback) == "function")
list.buttons[1][1].hold_callback()
assertContains(current().text, "KOReader .sdr data: Present")

-- Mark first book; open page 2; mark sixth book; go back.
list.buttons[1][1].callback()
list = current()
assertContains(list.title, "Marked: 1 / 1.0 MiB")
assertContains(list.buttons[1][1].text, "[x]")

list.buttons[6][2].callback() -- Next
list = current()
assertContains(list.title, "Page 2/3")
list.buttons[1][1].callback()
list = current()
assertContains(list.title, "Marked: 2 / 7.0 MiB")

list.buttons[6][1].callback() -- Previous
list = current()
assertContains(list.title, "Page 1/3")
assertContains(list.buttons[1][1].text, "[x]")

-- "Preview" is informational only; it never invokes os.remove.
list.buttons[7][2].callback()
assertContains(current().text, "Selected Zotero downloads: 2")
assertContains(current().text, "READ-ONLY: no files were deleted.")

-- Clear marks; verify totals return to zero.
list.buttons[7][1].callback()
list = current()
assertContains(list.title, "Marked: 0 / 0.0 MiB")

-- All source paths retain their original metadata.
for i = 1, 12 do
    local folder = root .. "/" .. raw[i].key
    local name = raw[i].data.filename
    assert(paths[folder .. "/" .. name].mode == "file")
end

os.remove = actual_remove
print("PASS: 12 files; 3-page selection; .sdr details; preview; clear; no file deletion")
