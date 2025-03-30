-- MPV Lua script to control monitor brightness using key bindings
--- This script utilizes the MonitorConfig PowerShell module , which can be installed using:
--- Install-Module MonitorConfig
--- https://github.com/MartinGC94/MonitorConfig
--- The script is designed to work with the primary monitor only.

-- Function to execute a PowerShell command and return the output
local function executePowerShell(command)
    local result = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = {"powershell", "-NoProfile", "-Command", command}
    })
    if result.status == 0 then
        return result.stdout
    else
        return "Failed to execute PowerShell command"
    end
end

-- Get the LogicalDisplay value (cached)
local logicalDisplay = executePowerShell("Get-Monitor -Primary -SkipWmiCheck | Format-Table -HideTableHeaders -Property LogicalDisplay"):match("%S+")
if not logicalDisplay then
    mp.msg.error("LogicalDisplay not found.")
    return
end

-- Get the initial brightness (cached)
local currentBrightness = tonumber(executePowerShell("Get-MonitorBrightness " .. logicalDisplay .. " | Format-Table -HideTableHeaders -Property CurrentBrightness"):match("%d+"))
if not currentBrightness then
    mp.msg.error("Unable to retrieve current brightness.")
    return
end

mp.msg.info("Current Brightness: " .. currentBrightness)

-- Function to set brightness
local function setBrightness(newBrightness)
    if newBrightness >= 0 and newBrightness <= 100 then
        -- Update brightness only if it has changed
        if newBrightness ~= currentBrightness then
            executePowerShell("Set-MonitorBrightness " .. logicalDisplay .. " " .. newBrightness)
            currentBrightness = newBrightness
            mp.osd_message("Brightness set to: " .. newBrightness)
        end
    else
        mp.osd_message("Brightness value out of range (0-100).")
    end
end

-- Function to reset custom brightness input
local function resetCustomBrightness()
    input = ""
    mp.remove_key_binding("digit-handler")
    mp.remove_key_binding("backspace-handler")
    mp.remove_key_binding("apply-brightness")
    mp.remove_key_binding("cancel-brightness")
    mp.osd_message("")
end

-- Function to input custom brightness
local input = ""
local function customBrightnessHandler(digit)
    input = input .. digit
    mp.osd_message("Enter brightness (0-100): " .. input, 999999)
end

local function backspaceHandler()
    input = input:sub(1, -2)
    mp.osd_message("Enter brightness (0-100): " .. input, 999999)
end

local function applyCustomBrightness()
    local brightness = tonumber(input)
    if brightness and brightness >= 0 and brightness <= 100 then
        setBrightness(brightness)
    else
        mp.osd_message("Invalid input. Please enter a number between 0 and 100.")
    end
    resetCustomBrightness()
end

local function startCustomBrightnessInput()
    input = ""
    mp.osd_message("Enter brightness (0-100): ", 999999)
    for i = 0, 9 do
        mp.add_forced_key_binding(tostring(i), "digit-handler-" .. i, function() customBrightnessHandler(tostring(i)) end)
    end
    mp.add_forced_key_binding("BS", "backspace-handler", backspaceHandler)
    mp.add_forced_key_binding("ENTER", "apply-brightness", applyCustomBrightness)
    mp.add_forced_key_binding("ESC", "cancel-brightness", resetCustomBrightness)
end

-- Bind keys to increase, decrease, and set custom brightness
mp.add_key_binding(";", "decrease_brightness", function() setBrightness(math.max(currentBrightness - 10, 0)) end)
mp.add_key_binding(":", "minimum_brightness", function() setBrightness(0) end)
mp.add_key_binding("'", "increase_brightness", function() setBrightness(math.min(currentBrightness + 10, 100)) end)
mp.add_key_binding("\"", "maximum_brightness", function() setBrightness(100) end)
mp.add_key_binding("B", "custom_brightness", startCustomBrightnessInput)