-- Isolated integration regression for the per-PDF Zotero-to-KOReader flow.
-- No credentials, Kindle, PDF, network or user's Zotero DB are involved.
package.path = "./?.lua;" .. package.path
local noop = function() end
local local_sidecar = {annotations={}}
local remote = {
    key="ABCDEFGH", version=52,
    data={itemType="annotation",parentItem="PDFKEY00",
        annotationType="underline", annotationColor="#2ea8e5",
        annotationText="Test Zotero underline", annotationComment="",
        annotationPosition='{"pageIndex":0,"rects":[[12,15,80,24]]}'}
}
local cache = {PDFKEY00={
    key="PDFKEY00",data={itemType="attachment",contentType="application/pdf",filename="test.pdf"}
}}
local relation = {}
local network_ok = true
local methods = {"ffi/util","luasettings","ffi/sha2","lua-ljsqlite3/init","zotero_dropbox","zotero_file_validation","device"}
for _, name in ipairs(methods) do package.preload[name]=function() return {} end end
package.preload["gettext"]=function() return function(x) return x end end
package.preload["logger"]=function() return {info=noop,warn=noop,dbg=noop,err=noop} end
package.preload["libs/libkoreader-lfs"]=function()
    return {attributes=function(path) return path=="/tmp/test.pdf" and {} or nil end}
end
package.preload["docsettings"]=function()
    return {open=function(_, path)
        assert(path=="/tmp/test.pdf")
        return {
            readSetting=function(_,k,d) return local_sidecar[k] or d end,
            saveSetting=function(_,k,v) local_sidecar[k]=v end,
            flush=noop,close=noop,
        }
    end}
end
package.preload["json"]=function()
    return {
        encode=function(x) return "{}" end,
        decode=function(x)
            if x==remote.data.annotationPosition then
                return {pageIndex=0,rects={{12,15,80,24}}}
            end
            return {}
        end,
    }
end
package.preload["annotations"]=function()
    local A = {}
    A.fingerprint=function(x)
        return table.concat({x.drawer or "",x.text or "",x.color or "",x.note or ""},"/")
    end
    A.annotationNeedsUpdate=function(a,b) return (a.text or "") ~= (b.data.annotationText or "") end
    A.getPageDimensions=function(path,pages)
        return {[1]={height=700,width=500,bbox_x0=0,bbox_y0=0,
            bbox_x1=500,bbox_y1=700,bbox_width=500,bbox_height=700}}
    end
    A.convertZoteroToKOReader=function(item,bbox)
        local ann={page=1,pageno=1,zoteroKey=item.key,zoteroVersion=item.version,
          text=item.data.annotationText,drawer="underscore",color="blue",
          datetime="2026-11-01 18:00:00",pboxes={{x=12,y=676,w=68,h=9}}}
        ann.zoteroSyncedFingerprint=A.fingerprint(ann)
        return ann
    end
    A.findEquivalentAnnotation=function(list, incoming, allow_linked)
        for i, ann in ipairs(list) do
            if (allow_linked or not ann.zoteroKey)
                and ann.page==incoming.page
                and ann.text==incoming.text
                and ann.drawer==incoming.drawer
                and ann.color==incoming.color
                and ann.pboxes and incoming.pboxes
                and ann.pboxes[1].x==incoming.pboxes[1].x
                and ann.pboxes[1].y==incoming.pboxes[1].y then
                return i
            end
        end
        return nil
    end
    A.convertZoteroToKOReaderEpub=function(item) error("PDF test invoked EPUB") end
    A.setDefaultColor=noop
    A.supportedZoteroTypes=function() return {"highlight","underline"} end
    return A
end
package.preload["ltn12"]=function()
    return {sink={table=function() return noop end},source={string=function() return noop end}}
end
package.preload["ssl.https"]=function() return {request=function() error("Unexpected live network!") end} end
local API = require("zoteroapi")
API.settings={readSetting=function() return "yellow" end}
API.verifyZoteroAccess=function() return nil end
API.userLibraryURL="https://example.invalid/users/123"
API.getUserLibraryVersion=function() return 99 end
API.getItem=function(key) return cache[key] end
API.setAnnotations=function(map)
    for k,p in pairs(map) do relation[k]=p end
end
API.getZoteroData=function(url)
    assert(url:find("/items/PDFKEY00/children?",1,true))
    if not network_ok then return nil,"simulated network failure" end
    return {remote},{}
end
local db={}
function db:prepare(sql)
    local stmt={count=0,query=sql}
    function stmt:reset() self.count=0;return self end
    function stmt:bind(...) self.args={...};return self end
    function stmt:close() end
    function stmt:step()
        if self.query:find("FROM%W+itemAnnotations INNER JOIN items") then
            self.count=self.count+1
            if self.count==1 and relation[remote.key]=="PDFKEY00" then
                return {remote.key,remote.version,remote.version}
            end
        elseif self.query:find("INSERT INTO items",1,true) then
            cache[remote.key]=remote
        end
        return nil
    end
    return stmt
end
API.openDB=function() return db end
API.getDirAndPath=function(item) return "/tmp","/tmp/test.pdf" end

local ok, changed, count=API.pullAnnotationsForAttachment("PDFKEY00","/tmp/test.pdf")
assert(ok==true and changed==true and count==1,"First server pull should import exactly one")
assert(#local_sidecar.annotations==1,"Remote Zotero annotation must appear in KOReader sidecar")
assert(local_sidecar.annotations[1].drawer=="underscore", "Underline must stay underline")
assert(local_sidecar.annotations[1].zoteroKey=="ABCDEFGH")
assert(local_sidecar.annotations[1].zoteroSyncedFingerprint, "Imported mark needs fingerprint")
local ok2, changed2, count2=API.pullAnnotationsForAttachment("PDFKEY00","/tmp/test.pdf")
assert(ok2 and changed2==false and count2==1,"Second pull should be idempotent")
assert(#local_sidecar.annotations==1,"Second pull must not duplicate a highlight")
-- Emulate the actual failure: KOReader live annotations had previously
-- overwritten the sidecar and lost the Zotero key of an imported underline.
local_sidecar.annotations[1].zoteroKey=nil
local_sidecar.annotations[1].zoteroVersion=nil
local_sidecar.annotations[1].zoteroSyncedFingerprint=nil
local relink_ok, relink_changed, relink_count =
    API.pullAnnotationsForAttachment("PDFKEY00","/tmp/test.pdf")
assert(relink_ok and relink_changed and relink_count==1)
assert(#local_sidecar.annotations==1, "Re-import must RELINK, not duplicate old highlight")
assert(local_sidecar.annotations[1].zoteroKey=="ABCDEFGH",
    "Previously imported highlight must regain Zotero identity")

local_sidecar.annotations[#local_sidecar.annotations+1]={page=1,drawer="lighten",
    color="red",text="Kindle local mark, must survive"}
network_ok=false
local failed, reason=API.pullAnnotationsForAttachment("PDFKEY00","/tmp/test.pdf")
assert(failed==false and reason:find("simulated network failure"))
assert(#local_sidecar.annotations==2,"Network failure must preserve annotations")
print("PASS: Zotero->Kindle underlines, idempotent pull, and safe network failure")
