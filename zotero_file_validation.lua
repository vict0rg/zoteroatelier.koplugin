-- Lightweight file-header checks for Zotero Atelier attachments.
-- Prevent error response bodies (e.g. "Not Found") or partial downloads
-- from being cached and reopened as PDFs/EPUBs. This is not a full parser.
local lfs = require("libs/libkoreader-lfs")

local M = {}

function M.isValid(path, item_or_type)
    if type(path) ~= "string" or path == "" or lfs.attributes(path, "mode") ~= "file" then
        return false, "Attachment file missing"
    end
    local size = tonumber(lfs.attributes(path, "size")) or 0
    if size == 0 then return false, "Attachment file is empty" end

    local mime, filename
    if type(item_or_type) == "table" then
        local data = item_or_type.data or item_or_type
        mime, filename = data.contentType, data.filename
    else
        mime = item_or_type
    end
    local lower_name = type(filename) == "string" and filename:lower() or path:lower()
    local is_pdf = mime == "application/pdf" or lower_name:match("%.pdf$") ~= nil
    local is_epub = mime == "application/epub+zip" or lower_name:match("%.epub$") ~= nil
    if not is_pdf and not is_epub then return true end

    local f, err = io.open(path, "rb")
    if not f then return false, "Cannot read downloaded attachment: " .. tostring(err) end
    local header = f:read(1024) or ""
    f:close()

    if is_pdf then
        -- PDF header may legally follow a short preamble; allow up to 1024
        -- bytes, consistent with common PDF readers.
        if size < 16 or not header:find("%%PDF%-", 1) then
            return false, "File is not a PDF (invalid PDF header)"
        end
    elseif is_epub then
        -- EPUB is a ZIP archive. Check for the local ZIP file header.
        if size < 32 or header:sub(1, 4) ~= "PK\003\004" then
            return false, "File is not an EPUB (invalid ZIP header)"
        end
    end
    return true
end

return M
