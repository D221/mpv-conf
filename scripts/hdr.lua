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

mp.register_event("end-file", function()
    if HDR_enabled then
        executePowerShell({HDRCmd_path, 'off'})
        HDR_enabled = false
    end
end)

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
        executePowerShell({HDRCmd_path, 'off'})
        HDR_enabled = false
    end
end)
