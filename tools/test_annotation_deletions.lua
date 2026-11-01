-- Tests two-way deletion safety using real zoteroapi.lua functions, a mocked
-- Zotero network, and an in-memory KOReader DocSettings.
package.path = "./?.lua;" .. package.path
local noop = function() end
local function copy(x)
    if type(x)~="table" then return x end
    local t={};for k,v in pairs(x) do t[k]=copy(v) end;return t
end
for _,name in ipairs({"ffi/util","luasettings","ffi/sha2","lua-ljsqlite3/init",
    "zotero_dropbox","zotero_file_validation","device"}) do
    package.preload[name]=function() return {} end
end
package.preload["gettext"]=function() return function(x)return x end end
package.preload["logger"]=function() return {info=noop,warn=noop,dbg=noop,err=noop} end
package.preload["libs/libkoreader-lfs"]=function()
    return {attributes=function(p) return p=="/test.pdf" and {} or nil end}
end
local disk={annotations={}}
package.preload["docsettings"]=function()
    return {open=function(_,p)
        assert(p=="/test.pdf")
        return {
            readSetting=function(_,k,d)
                if disk[k]==nil then return d end
                return copy(disk[k])
            end,
            saveSetting=function(_,k,v) disk[k]=copy(v) end,
            flush=noop,close=noop
        }
    end}
end
package.preload["json"]=function()return {encode=function()return "{}"end,decode=function()return{}end}end
package.preload["annotations"]=function() return {} end
package.preload["ltn12"]=function()return {sink={table=function()return noop end},source={string=function()return noop end}}end
local remote={}
local offline=false
local false_empty=false
local deleted_count=0
local https_calls={}
package.preload["ssl.https"]=function()return {request=function(args)
    https_calls[#https_calls+1]=args.method
    if args.method=="HEAD" then
        return 1,200,{["last-modified-version"]="101"}
    elseif args.method=="DELETE" then
        local key=args.url:match("/items/([A-Z0-9]+)$")
        assert(remote[key],"Cannot DELETE missing remote annotation")
        assert(args.headers["If-Unmodified-Since-Version"]=="101",
            "DELETE must use current library version guard")
        remote[key]=nil
        deleted_count=deleted_count+1
        return 1,204,{["last-modified-version"]="102"}
    end
    error("Unexpected network request: "..tostring(args.method))
end}end
local API=require("zoteroapi")
API.settings={readSetting=function()return"yellow"end}
API.verifyZoteroAccess=function() return nil end
API.userLibraryURL="https://example.invalid/users/123"
API.zoteroHeader={["zotero-api-key"]="FAKE",["zotero-api-version"]="3"}
API.getUserLibraryVersion=function()return 50 end
API.getZoteroData=function(url)
    if offline then return nil,"Error: simulated network 503" end
    if url:find("/children?",1,true) then
        if false_empty then return {}, {} end
        local results={}
        for _,item in pairs(remote) do results[#results+1]=copy(item) end
        return results,{}
    end
    local key=url:match("/items/([A-Z0-9]+)$")
    if key then
        if remote[key] then return copy(remote[key]),{} end
        return nil,"Error: API responded with status code 404"
    end
    error("Unexpected GET "..url)
end
local M=require("annotation_delete_state")
local function item(key)
    return {key=key,version=77,data={itemType="annotation",
        annotationType="highlight",parentItem="PDFKEY00",
        annotationText="Read"}}
end
remote.ABCDEFGH=item("ABCDEFGH")
disk.annotations={{zoteroKey="ABCDEFGH",text="Read"}}
-- First sync: even if one side is empty, no old missing keys count as DELETE.
local pre,err=API.planAnnotationDeletions("PDFKEY00","/test.pdf")
assert(pre and not pre.seeded and #pre.local_deleted==0
    and #pre.remote_deleted==0,err)
assert(API.saveConfirmedAnnotationBaseline("PDFKEY00","/test.pdf"))
assert(disk.zoteroConfirmedAnnotationKeysV1.ready
    and #disk.zoteroConfirmedAnnotationKeysV1.keys==1)
local expected,err=API.planAnnotationDeletions("PDFKEY00","/test.pdf")
assert(expected and expected.seeded and #expected.local_deleted==0
    and #expected.remote_deleted==0,err)
-- Kindle deletion: only the previous confirmed key qualifies; planning
-- never makes a destructive API request.
disk.annotations={}
local local_plan,err=API.planAnnotationDeletions("PDFKEY00","/test.pdf")
assert(local_plan and #local_plan.local_deleted==1 and #local_plan.remote_deleted==0,err)
assert(deleted_count==0 and remote.ABCDEFGH,"Preflight must be read-only")
local done,why=API.applyConfirmedAnnotationDeletions(local_plan)
assert(done and deleted_count==1 and remote.ABCDEFGH==nil,why)
assert(disk.annotations and #disk.annotations==0)
assert(API.getUserLibraryVersion()==50,"DELETE must not skip unpulled Zotero changes")
assert(API.saveConfirmedAnnotationBaseline("PDFKEY00","/test.pdf"))
local quiet=assert(API.planAnnotationDeletions("PDFKEY00","/test.pdf"))
assert(#quiet.local_deleted==0 and #quiet.remote_deleted==0)
-- Zotero desktop deletion: verify individual 404; archive before Kindle remove.
remote.BCDEFGHI=item("BCDEFGHI")
disk.annotations={{zoteroKey="BCDEFGHI",text="Read"}}
assert(API.saveConfirmedAnnotationBaseline("PDFKEY00","/test.pdf"))
remote.BCDEFGHI=nil  -- deleted on Zotero desktop
local remote_plan,err=API.planAnnotationDeletions("PDFKEY00","/test.pdf")
assert(remote_plan and #remote_plan.remote_deleted==1
    and #remote_plan.local_deleted==0,err)
assert(#disk.annotations==1,"Remote delete preflight must be non-destructive")
done,why=API.applyConfirmedAnnotationDeletions(remote_plan)
assert(done,why)
assert(#disk.annotations==0 and #disk.zoteroDeletedAnnotationArchiveV1==1,
    "Confirmed Zotero delete must remove only its paired Kindle annotation and keep backup")
assert(deleted_count==1,"Remote delete must not issue Zotero DELETE")
-- Dangerous empty-list false positives: a direct GET that still sees the
-- annotation must abort before touching local marks.
remote.CDEFGHIJ=item("CDEFGHIJ")
disk.annotations={{zoteroKey="CDEFGHIJ",text="Read"}}
assert(API.saveConfirmedAnnotationBaseline("PDFKEY00","/test.pdf"))
false_empty=true
local no_plan,fail_reason=API.planAnnotationDeletions("PDFKEY00","/test.pdf")
assert(no_plan==nil and fail_reason:find("independently verify"),"False empty Zotero listing must fail closed")
assert(#disk.annotations==1 and remote.CDEFGHIJ)
false_empty=false
offline=true
no_plan=API.planAnnotationDeletions("PDFKEY00","/test.pdf")
assert(no_plan==nil and #disk.annotations==1,"Offline preflight cannot delete anything")
offline=false
print("PASS: first sync seeds baseline; Kindle and Zotero deletes require explicit apply; invalid remote 0/offline fail closed")
