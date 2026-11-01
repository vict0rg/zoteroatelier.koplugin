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
local pending_local_deletes=false
local deletion_dialog
ConfirmBox={new=function(_,options) return options end}
UIManager.show=function(_,dialog)
    if dialog.ok_callback then deletion_dialog=dialog end
end
ZoteroAPI={
    findAttachmentKeyByFilePath=function(path) return "PDFKEY00" end,
    planAnnotationDeletions=function(key,path)
        calls[#calls+1]="plan"
        if not server_online then return nil,"simulated network offline" end
        return {local_deleted=pending_local_deletes and {"OLDZOTER"} or {},
            remote_deleted={}}
    end,
    applyConfirmedAnnotationDeletions=function(plan)
        calls[#calls+1]="delete"
        assert(#plan.local_deleted==1)
        pending_local_deletes=false
        return true
    end,
    saveConfirmedAnnotationBaseline=function(key,path)
        calls[#calls+1]="baseline"
        disk.zoteroConfirmedAnnotationKeysV1={
            schema=1,ready=true,keys={"OLDZOTER","NEWZOTER"}}
        return true,2
    end,
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
        local expected = disk.annotations[2].zoteroKey and 0 or 1
        assert(new_count==expected,
            "Existing Zotero highlights must not be re-uploaded")
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
assert(calls[1]=="plan" and calls[2]=="pull" and calls[3]=="push"
    and calls[4]=="baseline","Preflight → pull → push → baseline is required")
assert(#disk.annotations==2)
assert(disk.zoteroConfirmedAnnotationKeysV1.ready,
    "Paired deletion baseline must survive KOReader reload")
assert(disk.annotations[1].zoteroKey=="OLDZOTER",
    "ReaderUI:onClose overwrote imported annotation; after_close did not restore")
assert(disk.annotations[2].zoteroKey=="NEWZOTER",
    "ReaderUI:onClose overwrote new Kindle upload key")
assert(reader.annotation.annotations[1].zoteroKey=="OLDZOTER",
    "ReaderUI must reopen with the linked Zotero annotation")
local before=#calls
server_online=false
p:syncOpenDocumentAnnotations(reader,{notify=true})
assert(#calls==before+1 and calls[#calls]=="plan",
    "Failed preflight must prevent all uploads and remote pulls")
assert(#disk.annotations==2 and disk.annotations[1].zoteroKey=="OLDZOTER")
-- Destructive actions MUST wait until a real affirmative ConfirmBox callback.
server_online=true
pending_local_deletes=true
deletion_dialog=nil
local start=#calls
p:syncOpenDocumentAnnotations(reader,{notify=true})
assert(deletion_dialog and deletion_dialog.ok_callback and deletion_dialog.cancel_callback,
    "Missing explicit deletion approval dialog")
assert(#calls==start+1 and calls[#calls]=="plan",
    "Planning must not implicitly delete or upload")
deletion_dialog.cancel_callback()
assert(#calls==start+1 and p._zotero_document_sync_busy==false,
    "Cancel must be side-effect free and release busy state")
deletion_dialog=nil
p:syncOpenDocumentAnnotations(reader,{notify=true})
assert(#calls==start+2 and calls[#calls]=="plan")
deletion_dialog.ok_callback()
assert(calls[start+3]=="delete" and calls[start+4]=="pull"
    and calls[start+5]=="push" and calls[start+6]=="baseline",
    "Only explicit confirmation may trigger DELETE; then pull/push/baseline")
assert(p._zotero_document_sync_busy==false)
print("PASS: actual document sync pulls before push; KOReader reload preserves both keys; offline aborts uploads")
