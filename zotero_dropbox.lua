-- Optional read-only Dropbox attachment fetch for Zotero Atelier.
-- Zotero Atelier upstream: https://github.com/Atelier-Recherche/zoteroatelier.koplugin (GPL-3.0)
-- Feature requirements and testing: @vict0rg; AI-assisted implementation: OpenAI ChatGPT (GPT-6).
-- Architectural reference (no copied code): KOReader cloudstorage Dropbox provider
-- https://github.com/koreader/koreader/blob/master/plugins/cloudstorage.koplugin/providers/dropbox.lua (AGPL-3.0).
--
-- This module makes ONLY token-refresh and Dropbox file-download requests.
-- No Dropbox upload/delete/write endpoints are used.

local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require("json")
local lfs = require("libs/libkoreader-lfs")
local DataStorage = require("datastorage")
local logger = require("logger")

local M = {}
local token_cache, token_expiry = nil, 0
local SETTINGS = DataStorage:getDataDir() .. "/zotero/dropbox_atelier.lua"
local TOKEN_ENDPOINT = "https://api.dropbox.com/oauth2/token"
local DOWNLOAD_ENDPOINT = "https://content.dropboxapi.com/2/files/download"

local function urlencode(v)
    return (tostring(v):gsub("([^%w%-._~])", function(c)
        return string.format("%%%02X", c:byte())
    end))
end

local function get_config()
    local file = io.open(SETTINGS, "rb")
    if not file then return nil end -- Optional feature: disabled when not configured
    file:close()
    local ok, cfg = pcall(dofile, SETTINGS)
    if not ok or type(cfg) ~= "table" then
        return nil, "Invalid Dropbox settings"
    end
    if cfg.enabled ~= true then return nil end
    for _, name in ipairs({"app_key", "refresh_token", "storage_root"}) do
        if type(cfg[name]) ~= "string" or cfg[name] == "" then
            return nil, "Missing Dropbox setting: " .. name
        end
    end
    return cfg
end

local function access_token(cfg)
    if token_cache and os.time() + 120 < token_expiry then
        return token_cache
    end
    local body = "grant_type=refresh_token&refresh_token=" .. urlencode(cfg.refresh_token)
        .. "&client_id=" .. urlencode(cfg.app_key)
    local chunks = {}
    local ok_call, success, status = pcall(https.request, {
        url = TOKEN_ENDPOINT,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/x-www-form-urlencoded",
            ["Content-Length"] = tostring(#body),
        },
        source = ltn12.source.string(body),
        sink = ltn12.sink.table(chunks),
    })
    if not ok_call or success ~= 1 or tonumber(status) ~= 200 then
        return nil, "Dropbox token refresh failed (HTTP " .. tostring(status) .. ")"
    end
    local ok_json, data = pcall(json.decode, table.concat(chunks))
    if not ok_json or type(data) ~= "table" or not data.access_token then
        return nil, "Invalid Dropbox token response"
    end
    token_cache = data.access_token
    token_expiry = os.time() + (tonumber(data.expires_in) or 14400)
    return token_cache
end

local function remote_path(cfg, item)
    local key = item.key
    local filename = item.data and item.data.filename
    if type(key) ~= "string" or not key:match("^[A-Za-z0-9]+$") then
        return nil, "Invalid Zotero attachment key"
    end
    if type(filename) ~= "string" or filename == "" or filename == "." or filename == ".."
       or filename:find("/", 1, true) or filename:find("\\", 1, true) then
        return nil, "Unsupported attachment filename"
    end
    local root = cfg.storage_root:gsub("/+$", "")
    if root == "" or root:sub(1, 1) ~= "/" or root:find("..", 1, true)
        or root:find("\\", 1, true) then
        return nil, "Invalid Dropbox storage root"
    end
    return root .. "/" .. key .. "/" .. filename
end

-- Returns file_path, attempted, message.
-- A successful local file lookup must be attempted by Zotero Atelier first.
function M.tryDownload(item, dest_dir, dest_path)
    local cfg, settings_error = get_config()
    if not cfg and not settings_error then return nil, false, nil end
    if settings_error then return nil, true, settings_error end
    if not item or not item.data
       or (item.data.linkMode ~= "imported_file" and item.data.linkMode ~= "imported_url") then
        return nil, false, nil -- Remotely linked files are out of scope
    end

    local path, path_error = remote_path(cfg, item)
    if not path then return nil, true, path_error end
    if lfs.attributes(dest_path, "mode") == "file" and (lfs.attributes(dest_path, "size") or 0) > 0 then
        return dest_path, true, nil
    end

    local token, token_error = access_token(cfg)
    if not token then return nil, true, token_error end
    if lfs.attributes(dest_dir, "mode") ~= "directory" then
        local made = lfs.mkdir(dest_dir)
        if not made and lfs.attributes(dest_dir, "mode") ~= "directory" then
            return nil, true, "Cannot create cache folder"
        end
    end

    local part = dest_path .. ".dropbox-part"
    local out = io.open(part, "wb")
    if not out then return nil, true, "Cannot create cache temporary file" end
    local request_ok, success, code = pcall(https.request, {
        -- The documented `arg` query parameter keeps Unicode filenames out of
        -- HTTP headers (Dropbox requires ASCII-only JSON inside Dropbox-API-Arg).
        url = DOWNLOAD_ENDPOINT .. "?arg=" .. urlencode(json.encode({path = path})),
        method = "GET", -- Dropbox /2/files/download supports GET.
        headers = {
            ["Authorization"] = "Bearer " .. token,
        },
        sink = ltn12.sink.file(out),
    })
    -- ltn12.sink.file closes the handle upon completion. Also close if a network
    -- exception interrupted the request before completion.
    pcall(function() out:close() end)
    local bytes = lfs.attributes(part, "size") or 0
    if not request_ok or success ~= 1 or tonumber(code) ~= 200 or bytes == 0 then
        os.remove(part)
        return nil, true, "Dropbox download failed (HTTP " .. tostring(code) .. ")"
    end
    if lfs.attributes(dest_path, "mode") == "file" then
        os.remove(part)
        return dest_path, true, nil
    end
    local renamed, rename_error = os.rename(part, dest_path)
    if not renamed then
        os.remove(part)
        return nil, true, "Could not complete cache download: " .. tostring(rename_error)
    end
    logger.info("Zotero Atelier Dropbox: cached one personal-library attachment")
    return dest_path, true, nil
end

return M
