-- Offline Zotero API batch-write tests. No network or user data.
package.path = "./?.lua;" .. package.path
local requests = {}
local next_responses = {}
local function noop() end
for _, name in ipairs({
  "ffi/util", "luasettings", "libs/libkoreader-lfs", "ffi/sha2",
  "lua-ljsqlite3/init", "annotations", "zotero_dropbox",
  "zotero_file_validation", "device", "docsettings",
}) do
  package.preload[name] = function() return {} end
end
package.preload["gettext"] = function() return function(s) return s end end
package.preload["logger"] = function()
  return {info=noop, err=noop, dbg=noop, warn=noop}
end
package.preload["json"] = function()
  return {
    encode = function() return "[]" end,
    decode = function() return {
      successful = {["0"]={key="ABCDEF12",version=101}},
      unchanged = {}, failed = {}
    } end,
  }
end
package.preload["ltn12"] = function()
  return {
    sink={table=function(t) return function(chunk) if chunk then t[#t+1] = chunk end return 1 end end},
    source={string=function(s) return function() return s end end}
  }
end
package.preload["ssl.https"] = function()
  return {request=function(args)
    requests[#requests+1] = args
    local result = table.remove(next_responses,1)
    assert(result, "Unexpected HTTP request to " .. tostring(args.url))
    assert(result.method == args.method, "Unexpected request method")
    if result.expected_version then
      assert(args.headers["If-Unmodified-Since-Version"] == tostring(result.expected_version),
        "Incorrect Zotero write version")
    end
    if args.sink and result.body then args.sink(result.body) end
    return result.ok or 1, result.code, result.headers or {}
  end}
end

local API = require("zoteroapi")
API.verifyZoteroAccess = function() return nil end
API.getUserLibraryVersion = function() return 100 end
API.zoteroHeader = {["zotero-api-key"]="TEST-ONLY-NEVER-REAL"}
API.userLibraryURL = "https://example.invalid/users/1"
local function queue(result) next_responses[#next_responses+1] = result end
local function reset()
  requests = {}
  next_responses = {}
  API._writeLibraryVersion = nil
  API.lastAnnotationSyncError = nil
end

reset()
queue({method="POST",code=200,expected_version=100,body="ok",headers={["last-modified-version"]="101"}})
queue({method="POST",code=200,expected_version=101,body="ok",headers={["last-modified-version"]="102"}})
local a = API.createItems({{itemType="annotation"}})
local b = API.createItems({{itemType="annotation"}})
assert(a[1].key and b[1].key)
assert(#requests==2 and API._writeLibraryVersion==102)
assert(API.getUserLibraryVersion()==100, "Incremental sync cursor must not advance after write")

reset()
queue({method="POST",code=412,expected_version=100,body="precondition"})
queue({method="HEAD",code=200,headers={["last-modified-version"]="130"}})
queue({method="POST",code=200,expected_version=130,body="ok",headers={["last-modified-version"]="131"}})
local after = API.createItems({{itemType="annotation"}})
assert(after[1].key and #requests==3)
assert(API._writeLibraryVersion==131)

reset()
API.getZoteroData = function() return {version=9} end
queue({method="POST",code=412,expected_version=100,body="precondition"})
queue({method="HEAD",code=200,headers={["last-modified-version"]="135"}})
local updated, problem = API.updateItems({{key="OLDKEY",version=8,itemType="annotation"}})
assert(next(updated)==nil and problem and #requests==2)
assert(API.lastAnnotationSyncError and API.lastAnnotationSyncError:find("conflict"))

reset()
API.getZoteroData = function() return {version=8} end
queue({method="POST",code=412,expected_version=100,body="precondition"})
queue({method="HEAD",code=200,headers={["last-modified-version"]="135"}})
queue({method="POST",code=200,expected_version=135,body="ok",headers={["last-modified-version"]="136"}})
local updated_ok = API.updateItems({{key="OLDKEY",version=8,itemType="annotation"}})
assert(updated_ok[1].key and #requests==3)
assert(API._writeLibraryVersion==136)
print("PASS: Zotero batch writes refresh 412 without losing annotation versions")
