local mp_options = require "mp.options"

local options = {
    enabled = true,
    skip_once = true,
    categories = "",
    skip = ""
}

-- These tables are now at the top level to store our loaded config.
local categories = {}
local skipped = {}

-- This function now ONLY reads and parses the config.
-- It's called once at startup.
function load_configuration()
    mp_options.read_options(options, "chapterskip")

    -- Clear old categories in case this is re-run.
    categories = {}
    
    for definition in string.gmatch(options.categories, "([^;]+)") do
        local name, patterns = string.match(definition, " *([^+>]*[^+> ]) *[+>](.*)")
        if name and patterns then
            categories[name:lower()] = patterns
        end
    end
end

-- The main function is now much lighter. It only does the matching.
function chapterskip(_, current_chapter)
    if not options.enabled then return end

    local chapters = mp.get_property_native("chapter-list")
    if not chapters then return end

    local skip_target = false
    for i, chapter in ipairs(chapters) do
        local should_skip = false
        if chapter.title then
            -- Check for a match directly inside the loop.
            for category_name in string.gmatch(options.skip, "[^;]+") do
                -- Trim whitespace from category name.
                category_name = category_name:lower():match("^%s*(.-)%s*$")
                if categories[category_name] then
                    for pattern in string.gmatch(categories[category_name], "([^|]+)") do
                        if string.match(chapter.title, pattern) then
                            should_skip = true
                            break
                        end
                    end
                end
                if should_skip then break end
            end
        end

        if (not options.skip_once or not skipped[i]) and should_skip then
            if i == current_chapter + 1 or skip_target == i - 1 then
                if skip_target then skipped[skip_target] = true end
                skip_target = i
            end
        elseif skip_target then
            mp.set_property("time-pos", chapter.time)
            skipped[skip_target] = true
            return
        end
    end

    -- This part runs if the last chapter(s) were skippable.
    if skip_target then
        skipped[skip_target] = true
        if mp.get_property("loop-file") ~= "no" then
            mp.set_property("time-pos", 0)
        else
            mp.set_property("time-pos", mp.get_property("duration"))
        end
    end
end

-- SCRIPT INITIALIZATION --

-- 1. Read the config file when the script is first loaded.
load_configuration()

-- 2. Set up the main event listener.
mp.observe_property("chapter", "number", chapterskip)

-- 3. Set up the listener for restarting playback.
mp.register_event("playback-restart", function() skipped = {} end)