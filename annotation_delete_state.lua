-- Pure, network-free rules for conservative two-way Zotero annotation deletion.
-- Missing items are never deletions until they were observed on both devices
-- in a PREVIOUS successful manual sync and a user confirms their removal.
local M = {}

local function validKey(key)
    return type(key) == "string" and key:match("^[A-Za-z0-9]+$") ~= nil
        and #key >= 6 and #key <= 32
end

function M.localKeys(annotations)
    local keys = {}
    for _, ann in ipairs(annotations or {}) do
        if type(ann) == "table" and validKey(ann.zoteroKey) then
            keys[ann.zoteroKey] = true
        end
    end
    return keys
end

function M.knownKeys(saved)
    if type(saved) ~= "table" or saved.schema ~= 1
        or saved.ready ~= true or type(saved.keys) ~= "table" then
        return nil -- migration/first sync: no DELETE is ever inferred
    end
    local keys = {}
    for _, key in ipairs(saved.keys) do
        if validKey(key) then keys[key] = true end
    end
    return keys
end

function M.plan(saved, local_keys, remote_keys)
    local known = M.knownKeys(saved)
    local plan = { seeded = (known ~= nil), local_deleted = {},
        remote_deleted = {}, both_missing = {} }
    if not known then return plan end
    for key in pairs(known) do
        if not local_keys[key] and remote_keys[key] then
            plan.local_deleted[#plan.local_deleted+1] = key
        elseif local_keys[key] and not remote_keys[key] then
            plan.remote_deleted[#plan.remote_deleted+1] = key
        elseif not local_keys[key] and not remote_keys[key] then
            plan.both_missing[#plan.both_missing+1] = key
        end
    end
    table.sort(plan.local_deleted)
    table.sort(plan.remote_deleted)
    table.sort(plan.both_missing)
    return plan
end

function M.baseline(local_keys, remote_keys)
    local keys = {}
    for key in pairs(local_keys or {}) do
        if validKey(key) and remote_keys and remote_keys[key] then
            keys[#keys+1] = key
        end
    end
    table.sort(keys)
    return {schema=1, ready=true, keys=keys}
end

return M
