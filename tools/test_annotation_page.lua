-- Regression for KOReader PDF annotations with page but without pageno.
-- Does not require KOReader, network access, Dropbox, or real PDF files.
package.path = "./?.lua;" .. package.path
package.preload["docsettings"] = function() return {} end
local last_position
package.preload["json"] = function()
    return {
        encode = function(value)
            if type(value) == "table" and value.pageIndex ~= nil then
                last_position = value
            end
            return "{}"
        end,
    }
end
package.preload["logger"] = function()
    return {
        info = function() end,
        warn = function() end,
        err = function() end,
        dbg = function() end,
    }
end

local Annotations = require("annotations")
local bbox = {
    width = 510.24, height = 708.66,
    bbox_x0 = 0, bbox_y0 = 0,
    bbox_x1 = 510.24, bbox_y1 = 708.66,
    bbox_width = 510.24, bbox_height = 708.66,
}
local function check(annotation, expected_page)
    annotation.drawer = "lighten"
    annotation.color = "red"
    annotation.text = "Test highlight"
    annotation.datetime = "2026-10-29 14:37:21"
    annotation.pboxes = {{x=56.69,y=653.66,w=129.03,h=10.33}}
    assert(Annotations.getAnnotationPage(annotation) == expected_page)
    local converted = Annotations.convertKOReaderToZotero(annotation, bbox, "PARENTKEY")
    assert(converted.annotationSortIndex:sub(1,5) == string.format("%05d", expected_page - 1))
    assert(last_position.pageIndex == expected_page - 1)
    assert(converted.annotationType == "highlight")
    assert(converted.annotationColor == "#ff6666")
end

check({ page = 11 }, 11)       -- Reproduces actual crash from Kindle crash.log
check({ pageno = 11 }, 11)     -- Existing standard PDF behavior
check({ pageno = 3, page = 14 }, 3)
check({ pos0 = { page = 7 } }, 7)
check({ page = "unknown" }, 1)
check({}, 1)
assert(Annotations.makeSortIndex(nil, 0, 12):sub(1,5) == "00000")
-- Regress actual HTTP 400: six blue update payloads were rejected
-- because the fork emitted #0066FF (not an accepted Zotero palette value).
local function checkAcceptedColor(k_color, expected_hex)
    local ann = {
        pageno = 11, drawer = "lighten", color = k_color,
        text = "Unchanged highlight", datetime = "2026-11-01 17:49:00",
        pboxes = {{x=12, y=20, w=80, h=9}},
    }
    local converted = Annotations.convertKOReaderToZotero(ann, bbox, "PARENTKEY")
    assert(converted.annotationColor == expected_hex,
        "Invalid Zotero palette conversion for " .. k_color)
    local remote = {data = {
        annotationType = "highlight", annotationColor = expected_hex,
        annotationText = "Unchanged highlight", annotationComment = "",
    }}
    assert(not Annotations.annotationNeedsUpdate(ann, remote),
        "Unchanged Zotero highlight should not be re-uploaded for " .. k_color)
end
checkAcceptedColor("blue", "#2ea8e5")
checkAcceptedColor("cyan", "#2ea8e5")
checkAcceptedColor("olive", "#5fb236")
checkAcceptedColor("gray", "#aaaaaa")
checkAcceptedColor("red", "#ff6666")
print("PASS: PDF page conversion and Zotero canonical palette avoid HTTP 400")
