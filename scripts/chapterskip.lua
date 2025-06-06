-- chapterskip.lua
--
-- Ain't Nobody Got Time for That
--
-- This script skips chapters based on their title.

local categories = {
    prologue = "^Prologue/^Intro",
    opening = "^OP/ OP$/^Opening",
    ending = "^ED/ ED$/^Ending",
    preview = "Preview$"
}

local options = {
    enabled = true,
    skip_once = true,
    categories = "",
    skip = ""
}

mp.options = require "mp.options"

function matches(i, title)
    for category in string.gmatch(options.skip, " *([^;]*[^; ]) *") do
        if categories[category:lower()] then
            if string.find(category:lower(), "^idx%-") == nil then
                if title then
                    for pattern in string.gmatch(categories[category:lower()], "([^/]+)") do
                        if string.match(title, pattern) then
                            return true
                        end
                    end
                end
            else
                for pattern in string.gmatch(categories[category:lower()], "([^/]+)") do
                    if tonumber(pattern) == i then
                        return true
                    end
                end
            end
        end
    end
end

local skipped = {}
local parsed = {}

function chapterskip(_, current)
    mp.options.read_options(options, "chapterskip")
    if not options.enabled then return end
    for category in string.gmatch(options.categories, "([^;]+)") do
        name, patterns = string.match(category, " *([^+>]*[^+> ]) *[+>](.*)")
        if name then
            categories[name:lower()] = patterns
        elseif not parsed[category] then
            mp.msg.warn("Improper category definition: " .. category)
        end
        parsed[category] = true
    end
    local chapters = mp.get_property_native("chapter-list")
    local skip = false
    for i, chapter in ipairs(chapters) do
        if (not options.skip_once or not skipped[i]) and matches(i, chapter.title) then
            if i == current + 1 or skip == i - 1 then
                if skip then
                    skipped[skip] = true
                end
                skip = i
            end
        elseif skip then
            mp.set_property("time-pos", chapter.time)
            skipped[skip] = true
            return
        end
    end
        if skip then
        -- This block runs ONLY if the last chapter(s) were skippable,
        -- because the loop finished without finding a non-skippable chapter to jump to.

        -- Check mpv's setting for looping the current file.
        local loop_status = mp.get_property("loop-file")

        if loop_status ~= "no" then
            -- If looping is enabled ("inf" or a number), repeat the file.
            -- We do this by seeking to the very beginning.
            mp.set_property("time-pos", 0)
            -- Mark the final chapter as skipped for this play-through so it doesn't trigger again immediately.
            skipped[skip] = true
        else
            -- If looping is disabled, end the file by seeking to its duration.
            -- This lets mpv handle moving to the next playlist item naturally,
            -- respecting any other settings like loop-playlist.
            mp.set_property("time-pos", mp.get_property("duration"))
        end
    end
end

mp.observe_property("chapter", "number", chapterskip)
mp.register_event("playback-restart", function() skipped = {} end)
