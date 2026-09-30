--[[
move-to-folder.lua

Press ctrl+g (configurable below) to enter "move mode".
While in move mode:
  1  -> move current file into a "trash" subfolder next to it
  2  -> move current file into a "keep" subfolder next to it
  3  -> move current file into a "favorites" subfolder next to it
  ESC -> cancel move mode without doing anything

Example:
  Playing D:/video/something.mp4, press ctrl+g then 1
  -> file is moved to D:/video/trash/something.mp4
  The subfolder is created automatically if it doesn't exist,
  and mpv automatically advances to the next item in the playlist.

INSTALL:
  Windows:  %APPDATA%/mpv/scripts/move-to-folder.lua
  Linux/Mac: ~/.config/mpv/scripts/move-to-folder.lua
  (or <mpv portable dir>/portable_config/scripts/move-to-folder.lua)

CONFIG: edit the two tables below to change the trigger key or the
folder names / number of slots.
--]]

local mp = require 'mp'
local utils = require 'mp.utils'
local msg = require 'mp.msg'

-- ===================== CONFIG =====================
local ACTIVATE_KEY = "ctrl+g"   -- key combo that opens move mode

local FOLDERS = {
    ["1"] = "trash",
    ["2"] = "good",
    ["3"] = "meme",
}
-- ===================================================

local mode_active = false
local bound_keys = {}

local function osd(text, duration)
    mp.osd_message(text, duration or 3)
end

local function is_windows()
    return package.config:sub(1, 1) == '\\'
end

local function exit_mode(silent)
    if not mode_active then return end
    mode_active = false
    for _, name in ipairs(bound_keys) do
        mp.remove_key_binding(name)
    end
    bound_keys = {}
    if not silent then
        osd("Move mode cancelled")
    end
end

-- create target_dir if it doesn't already exist (ignores errors, e.g. if
-- it already exists)
local function ensure_dir(path)
    local args
    if is_windows() then
        args = { "cmd", "/c", "mkdir", path }
    else
        args = { "mkdir", "-p", path }
    end
    utils.subprocess({ args = args, cancellable = false })
end

-- On Windows, build a tiny helper .ps1 script once and reuse it for every
-- move. It's invoked via `-File` with the paths passed as plain arguments,
-- rather than building a `-Command "..."` string. This matters because
-- filenames can contain "smart quotes" (curly " " ' '), which PowerShell's
-- own parser treats as equivalent to straight quotes when tokenizing a
-- -Command string -- so a filename containing one could prematurely
-- terminate a quoted path and corrupt the command. Arguments passed via
-- -File are plain strings and are never re-parsed that way.
local helper_script_path = nil
local function ensure_helper_script()
    if helper_script_path then return helper_script_path end
    local temp_dir = os.getenv("TEMP") or os.getenv("TMP") or "."
    local script_path = temp_dir .. "\\mpv_move_to_folder_helper.ps1"
    local f = io.open(script_path, "r")
    if f then
        f:close()
    else
        local content = "param(\n"
            .. "    [Parameter(Mandatory=$true)][string]$Source,\n"
            .. "    [Parameter(Mandatory=$true)][string]$DestinationDir\n"
            .. ")\n"
            .. "Move-Item -LiteralPath $Source -Destination $DestinationDir -Force\n"
        local out = io.open(script_path, "w")
        if out then
            out:write(content)
            out:close()
        end
    end
    helper_script_path = script_path
    return script_path
end

local function do_move(folder_name)
    local path = mp.get_property("path")

    if not path then
        osd("No file playing")
        return
    end

    if path:match("^%a[%w+.-]*://") then
        osd("Can't move a network stream")
        return
    end

    local SEP = is_windows() and "\\" or "/"

    local dir, filename = utils.split_path(path)
    if dir == "" then dir = "." .. SEP end
    local dir_clean = dir:gsub("[/\\]+$", "")

    local target_dir = dir_clean .. SEP .. folder_name
    local target_path = target_dir .. SEP .. filename

    ensure_dir(target_dir)
    osd("Moving to " .. folder_name .. "...")

    -- Detach mpv from the current file first so the OS releases the file
    -- handle/lock before we try to move it (important on Windows), and so
    -- it's removed from the playlist. If it's the only item, the playlist
    -- becomes empty and playback stops naturally.
    mp.commandv("playlist-remove", "current")

    -- Actually move the file on disk. On Windows we shell out to a small
    -- helper PowerShell script (see ensure_helper_script above) instead of
    -- Lua's os.rename, because os.rename goes through the ANSI code page
    -- and chokes on filenames with characters outside it.
    local function move_file()
        if is_windows() then
            local helper = ensure_helper_script()
            local res = utils.subprocess({
                args = {
                    "powershell", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
                    "-File", helper, "-Source", path, "-DestinationDir", target_dir,
                },
                cancellable = false,
            })
            if res.status == 0 then
                return true, nil
            else
                return false, (res.stderr or res.stdout or ("exit code " .. tostring(res.status)))
            end
        else
            return os.rename(path, target_path)
        end
    end

    local function attempt_move(retries_left)
        local ok, err = move_file()
        if ok then
            osd("Moved to: " .. target_path)
        elseif retries_left > 0 then
            mp.add_timeout(0.5, function() attempt_move(retries_left - 1) end)
        else
            osd("Move FAILED: " .. tostring(err))
            msg.error("Failed moving '" .. path .. "' -> '" .. target_path .. "': " .. tostring(err))
        end
    end

    -- small initial delay, then retry a couple times if the file is briefly locked
    mp.add_timeout(0.3, function() attempt_move(2) end)

    -- move mode stays active after a move — press the activate key again
    -- (or ESC) to leave it. This lets you keep hammering 1/2/3 through a
    -- whole playlist without re-entering the mode each time.
end

local function enter_mode()
    if mode_active then return end
    mode_active = true

    -- sort keys for a stable, readable OSD message (1, 2, 3, ...)
    local keys = {}
    for k in pairs(FOLDERS) do table.insert(keys, k) end
    table.sort(keys)

    local labels = {}
    for _, key in ipairs(keys) do
        local folder = FOLDERS[key]
        local binding_name = "move-mode-" .. key
        mp.add_forced_key_binding(key, binding_name, function()
            do_move(folder)
        end)
        table.insert(bound_keys, binding_name)
        table.insert(labels, key .. "=" .. folder)
    end

    mp.add_forced_key_binding("ESC", "move-mode-esc", function()
        exit_mode()
    end)
    table.insert(bound_keys, "move-mode-esc")

    osd("Move file:  " .. table.concat(labels, "   ") .. "   (ESC to cancel)", 5)
end

mp.add_key_binding(ACTIVATE_KEY, "toggle-move-mode", function()
    if mode_active then
        exit_mode()
    else
        enter_mode()
    end
end)