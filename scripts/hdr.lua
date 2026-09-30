require "mp.msg"
require "mp.options"

local HDR_enabled = false
local HDRCmd_path = mp.command_native({"expand-path", "~~/HDRCmd.exe"})

local function executePowerShell(args)
    local result = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = type(args) == "table" and args or {"powershell", "-NoProfile", "-Command", args}
    })
    if result.status == 0 then
        return result.stdout
    else
        return nil
    end
end

local function disableHDR()
    if HDR_enabled then
        executePowerShell({HDRCmd_path, 'off'})
        HDR_enabled = false
    end
end

-- Only turn HDR off when mpv actually has nothing left to play (end of
-- playlist, stopped, or quitting). This is what gives us the "look ahead":
-- during an HDR -> HDR transition in a playlist, mpv goes straight from one
-- file to the next without ever becoming idle, so this never fires and the
-- video-params observer below just leaves HDR on, avoiding the off/on flash.
-- A transition to SDR content is still handled instantly by the
-- video-params observer below, since that's a real content change.
mp.observe_property("idle-active", "bool", function(_, idle)
    if idle then
        disableHDR()
    end
end)

-- Safety net in case mpv exits without idle-active ever firing (e.g. hard quit).
mp.register_event("shutdown", disableHDR)

mp.observe_property("video-params", "native", function(_, params)
    if not params or not params.primaries or not params.gamma then
        return
    end

    if params.primaries == "bt.2020" and (params.gamma == "pq" or params.gamma == "hlg") then
        if not HDR_enabled then
            local result = executePowerShell({HDRCmd_path, 'status'})
            if not result or not result:match("on$") then
                executePowerShell({HDRCmd_path, 'on'})
                HDR_enabled = true
            end
        end
    elseif HDR_enabled then
        disableHDR()
    end
end)