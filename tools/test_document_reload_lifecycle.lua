-- Execute the *actual functions* extracted from main.lua with a mocked
-- KOReader ReaderUI lifecycle, to reproduce stale onClose flush overwrites.
-- No Kindle, network, credentials or user data are used.
local f=assert(io.open("main.lua","rb"))
local src=assert(f:read("*a"));f:close()
local function segment(a,b)
    local i=assert(src:find(a,1,true),a)
    local j=assert(src:find(b,i+#a, true),b)
    return src:sub(i,j-1)
end
local function deepcopy(t)
    if type(t)~="table" then return t end
    local n={};for k,v in pairs(t) do n[k]=deepcopy(v) end;return n
end
local disk={annotations={
    {page=2,text="Zotero existing",drawer="lighten"}, -- stale keyless live copy
    {page=2,text="New Kindle",drawer="lighten"},
}}
local reader=nil
logger={info=function()end,err=function()end,warn=function()end}
JSON={encode=deepcopy,decode=deepcopy}
_=function(x)return x end
init_done=true
DocSettings={open=function(_,path)
    assert(path=="/test.pdf")
    return {
        readSetting=function(_,name,default) return disk[name] or default end,
        saveSetting=function(_,name,value) disk[name]=deepcopy(value) end,
        flush=function() end
    }
end}
UIManager={
    scheduleIn=function(_,delay,func) func() end,
    show=function()end
}
InfoMessage={new=function(_,params) return params end}
NetworkMgr={runWhenOnline=function(_,f) f() end}
local server_online=true
local calls={}
ZoteroAPI={
    findAttachmentKeyByFilePath=function(path) return "PDFKEY00" end,
    pullAnnotationsForAttachment=function(key,path)
        calls[#calls+1]="pull"
        if not server_online then return false,"offline" end
        -- Server pull links already existing keyless highlights and preserves new
        local anns=deepcopy(disk.annotations)
        for _,ann in ipairs(anns) do
            if ann.text=="Zotero existing" then
                ann.zoteroKey="OLDZOTER"
                ann.zoteroVersion=80
            end
        end
        disk.annotations=anns
        return true,true,1
    end,
    syncAnnotationsForAttachment=function(key,path)
        calls[#calls+1]="push"
        local new_count=0
        for _,ann in ipairs(disk.annotations) do
            if not ann.zoteroKey then new_count=new_count+1 end
        end
        assert(new_count==1, "Existing Zotero highlight was about to be re-uploaded")
        disk.annotations[2].zoteroKey="NEWZOTER"
        return 0,0,0
    end,
}
Plugin={}
assert(loadstring(segment(
    "function Plugin:reloadReaderAnnotations(readerui)",
    "-- Explicit manual sync of the current document:")))()
assert(loadstring(segment(
    "function Plugin:syncOpenDocumentAnnotations(readerui, opts)",
    "function Plugin:onReaderReady(readerui)")))()
reader={
    document={file="/test.pdf"},
    annotation={annotations=deepcopy(disk.annotations)},
    doc_settings=DocSettings:open("/test.pdf"),
    reloadDocument=function(self,after_close)
        -- Simulate exact KOReader ReaderUI:onClose() stale-memory write.
        disk.annotations=deepcopy(self.annotation.annotations)
        after_close("/test.pdf")
        self.annotation.annotations=deepcopy(disk.annotations)
        self.document={file="/test.pdf"}
    end
}
local p=setmetatable({}, {__index=Plugin})
p:syncOpenDocumentAnnotations(reader,{notify=true})
assert(calls[1]=="pull" and calls[2]=="push","Pull must occur before push")
assert(#disk.annotations==2)
assert(disk.annotations[1].zoteroKey=="OLDZOTER",
    "ReaderUI:onClose overwrote imported annotation; after_close did not restore")
assert(disk.annotations[2].zoteroKey=="NEWZOTER",
    "ReaderUI:onClose overwrote new Kindle upload key")
assert(reader.annotation.annotations[1].zoteroKey=="OLDZOTER",
    "ReaderUI must reopen with the linked Zotero annotation")
local before=#calls
server_online=false
p:syncOpenDocumentAnnotations(reader,{notify=true})
assert(#calls==before+1 and calls[#calls]=="pull","Failed pull must prevent all uploads")
assert(#disk.annotations==2 and disk.annotations[1].zoteroKey=="OLDZOTER")
print("PASS: actual document sync pulls before push; KOReader reload preserves both keys; offline aborts uploads")
