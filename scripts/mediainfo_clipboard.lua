-- mediainfo_clipboard.lua
--
-- mpv script: when a keybinding is pressed, run `mediainfo` on the
-- currently playing file and copy its output to the system clipboard.
--
-- INSTALL:
--   Linux/macOS: ~/.config/mpv/scripts/mediainfo_clipboard.lua
--   Windows:     %APPDATA%\mpv\scripts\mediainfo_clipboard.lua
--
-- REQUIREMENTS:
--   - `mediainfo` CLI must be installed and on PATH
--       Linux:  sudo apt install mediainfo   (or your distro's package manager)
--       macOS:  brew install mediainfo
--       Windows: https://mediaarea.net/en/MediaInfo/Download/Windows (CLI version)
--   - A clipboard tool available on PATH:
--       macOS:   pbcopy (built-in)
--       Windows: clip (built-in)
--       Linux:   xclip, wl-copy, or xsel (install one, e.g. `sudo apt install xclip`)
--
-- USAGE:
--   Default keybinding is Ctrl+I. Change KEYBIND below if you want something else.
--   Only works for local files (mediainfo generally can't read network streams).

local mp = require 'mp'

local KEYBIND = "ctrl+i"

local function run_subprocess(args, stdin_data)
    return mp.command_native({
        name = "subprocess",
        args = args,
        capture_stdout = true,
        capture_stderr = true,
        playback_only = false,
        stdin_data = stdin_data,
    })
end

-- Try clipboard tools in order until one succeeds. Returns true + tool name on success.
local function copy_to_clipboard(text)
    local is_windows = package.config:sub(1, 1) == "\\"
    local candidates

    if is_windows then
        -- Use PowerShell with a temporary file - most reliable method on Windows
        local tmp_path = os.getenv("TEMP") .. "\\mpv_mediainfo_" .. os.time() .. ".txt"
        local f = io.open(tmp_path, "w")
        if f then
            f:write(text)
            f:close()
            
            -- Use PowerShell to read the file and copy to clipboard
            candidates = {
                { "powershell", "-NoProfile", "-Command", 
                  "Get-Content -Path '" .. tmp_path .. "' -Raw | Set-Clipboard; Remove-Item '" .. tmp_path .. "'" },
            }
        else
            mp.msg.error("Failed to create temp file for clipboard")
            return false, nil
        end
    else
        candidates = {
            { "pbcopy" },                                  -- macOS
            { "xclip", "-selection", "clipboard" },        -- Linux (X11)
            { "wl-copy" },                                 -- Linux (Wayland)
            { "xsel", "--clipboard", "--input" },           -- Linux fallback
        }
    end

    for _, cmd in ipairs(candidates) do
        local ok, result = pcall(run_subprocess, cmd, text)
        if ok and result and result.status == 0 then
            mp.msg.info("Clipboard copy succeeded using " .. cmd[1])
            return true, cmd[1]
        else
            -- Log error for debugging
            if not ok then
                mp.msg.error("pcall failed for " .. cmd[1] .. ": " .. tostring(result))
            elseif result then
                mp.msg.error("Clipboard tool " .. cmd[1] .. " failed with status " .. result.status)
                if result.stderr and result.stderr ~= "" then
                    mp.msg.error("stderr: " .. result.stderr)
                end
            end
        end
    end

    return false, nil
end

local function run_mediainfo_and_copy()
    local path = mp.get_property("path")
    local is_url = path and path:match("^%a[%w+.-]*://")

    if not path then
        mp.osd_message("No file is currently playing", 2)
        return
    end

    if is_url then
        mp.osd_message("mediainfo can't read network streams", 3)
        return
    end

    mp.osd_message("Running mediainfo...", 2)

    local result = run_subprocess({ "mediainfo", path })

    if not result or result.status ~= 0 or not result.stdout or result.stdout == "" then
        local err = (result and result.stderr) or "unknown error"
        mp.osd_message("mediainfo failed: " .. err, 3)
        mp.msg.error("mediainfo failed: " .. err)
        return
    end

    -- Remove "Complete name" line from output
    local filtered_output = ""
    for line in result.stdout:gmatch("[^\r\n]+") do
        if not line:match("^Complete name%s*:") then
            filtered_output = filtered_output .. line .. "\n"
        end
    end

    local ok, tool = copy_to_clipboard(filtered_output)
    if ok then
        mp.osd_message("mediainfo output copied to clipboard (via " .. tool .. ")", 2)
    else
        mp.osd_message("Failed to copy to clipboard", 4)
    end
end

mp.add_key_binding(KEYBIND, "mediainfo-to-clipboard", run_mediainfo_and_copy)
