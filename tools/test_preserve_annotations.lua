-- Guard against the destructive synchronization bug exposed in 2026-11-01.
-- These assertions run without Zotero credentials, Kindle storage or network.
local function source(path)
    local f = assert(io.open(path, "rb"))
    local s = assert(f:read("*a"))
    f:close()
    return s
end
local api = source("zoteroapi.lua")
local main = source("main.lua")
local function between(s, start_mark, end_mark)
    local start_pos = assert(s:find(start_mark, 1, true), start_mark)
    local end_pos = assert(s:find(end_mark, start_pos + #start_mark, true), end_mark)
    return s:sub(start_pos, end_pos - 1)
end
local attachment_sync = between(api,
    "function API.syncAnnotationsForAttachment(key, file_path)",
    "-- Keep the server write version separate")
assert(not attachment_sync:find("API.deleteItems(", 1, true),
    "Unsafe: absent SDR highlights may not trigger Zotero DELETE")
assert(attachment_sync:find("Remote annotation is absent from this SDR; preserving item",1,true))
local attach = between(api,
    "function API.attachItemAnnotations(item, annotation_callback, filePathOverride, force, allowed_keys)",
    "-- Search annotations across the local library")
assert(not attach:find("table.remove(koreaderAnnotations",1,true),
    "Unsafe: stale Zotero cache may not delete Kindle highlights")
local fetch = between(api,
    "function API.fetchZoteroItems(since, progress_callback)",
    "-- Fetch (new) collections from Zotero server")
assert(fetch:find("Remote annotation is trashed; preserving cached annotation",1,true),
    "Unsafe: cached annotation recovery data is missing")
local open_sync = between(main,
    "function Plugin:syncOpenDocumentAnnotations(readerui, opts)",
    "function Plugin:onReaderReady(readerui)")
assert(open_sync:find("error_message",1,true)
    and open_sync:find("failures",1,true),
    "Unsafe: upload errors must not display success")
assert(open_sync:find("ZoteroAPI.planAnnotationDeletions",1,true)
    and open_sync:find("ConfirmBox:new",1,true)
    and open_sync:find("ZoteroAPI.applyConfirmedAnnotationDeletions",1,true),
    "Unsafe: destructive sync must require explicit user confirmation and a verified plan")
local pull_pos = assert(open_sync:find("ZoteroAPI.pullAnnotationsForAttachment", 1, true))
local push_pos = assert(open_sync:find("ZoteroAPI.syncAnnotationsForAttachment", 1, true))
assert(pull_pos < push_pos,
    "Unsafe: remote keys must be pulled and linked BEFORE creating local annotations")
local reload_sync = between(main,
    "function Plugin:reloadReaderAnnotations(readerui)",
    "function Plugin:syncOpenDocumentAnnotations(readerui, opts)")
assert(reload_sync:find("readerui:reloadDocument(function(closed_file)", 1, true)
    and reload_sync:find('fresh:saveSetting("annotations", annotation_snapshot)', 1, true),
    "Unsafe: KOReader reload must preserve the imported sidecar after onClose")
assert(reload_sync:find('fresh:saveSetting("zoteroConfirmedAnnotationKeysV1", baseline_snapshot)',1,true),
    "Unsafe: KOReader close must not wipe the deletion baseline")
local catalogue = between(api,
    "function API.syncAllItems(progress_callback)",
    "-- Check (local) library items")
assert(not catalogue:find("API.syncAnnotations()", 1, true),
    "Unsafe: catalogue sync must not silently create duplicates in bulk")
local open_close = between(main, "function Plugin:onReaderReady(readerui)", "function Plugin:init()")
assert(not open_close:find("self:syncOpenDocumentAnnotations(",1,true),
    "Unsafe: document close/open hooks must not race remote imports")
print("PASS: missing sidecars cannot delete remote/local highlights; sync failure is visible")
