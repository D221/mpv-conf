local mp = require 'mp'

-- path to nircmd (put full path if not in PATH)
local nircmd = "nircmd.exe"

-- your default desktop refresh
local default_hz = 170

-- mapping logic
local function get_target_hz(fps)
    if not fps then return default_hz end

    -- normalize a bit
    if fps > 23 and fps < 25 then
        return 120   -- 24fps → 120Hz (5:5)
    elseif fps > 29 and fps < 31 then
        return 120   -- 30fps → 120Hz (4:4)
    elseif fps > 59 and fps < 61 then
        return 120   -- 60fps → 120Hz (2:2, safer than 170)
    else
        return default_hz
    end
end

local current_hz = nil

local function set_refresh(hz)
    if current_hz == hz then return end

    current_hz = hz

    mp.msg.info("Switching to " .. hz .. "Hz")

    mp.command_native({
        name = "subprocess",
        playback_only = false,
        args = {
            nircmd,
            "setdisplay",
            "2560",
            "1440",
            "32",
            tostring(hz)
        }
    })
end

local function detect_and_apply()
    local fps = mp.get_property_number("container-fps")
    if not fps then
        fps = mp.get_property_number("estimated-vf-fps")
    end

    if not fps then
        mp.msg.warn("No FPS detected")
        return
    end

    mp.msg.info("Detected FPS: " .. fps)

    local target = get_target_hz(fps)
    set_refresh(target)
end

-- run when file loads
mp.register_event("file-loaded", function()
    -- delay a bit so fps is available
    mp.add_timeout(0.5, detect_and_apply)
end)

-- restore on exit
mp.register_event("shutdown", function()
    mp.msg.info("Restoring default refresh: " .. default_hz)

    mp.command_native({
        name = "subprocess",
        playback_only = false,
        args = {
            nircmd,
            "setdisplay",
            "2560",
            "1440",
            "32",
            tostring(default_hz)
        }
    })
end)