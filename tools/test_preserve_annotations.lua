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
    "function API.attachItemAnnotations(item, annotation_callback, filePathOverride)",
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
assert(open_sync:find("total_fails",1,true),
    "Unsafe: upload errors must not display success")
assert(open_sync:find("opts.pull",1,true)
    and open_sync:find("ZoteroAPI.pullAnnotationsForAttachment",1,true),
    "Unsafe: two-way sync must actually fetch remote annotations before reporting success")
print("PASS: missing sidecars cannot delete remote/local highlights; sync failure is visible")
