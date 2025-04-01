-- m3u8-save.lua
-- This script allows you to manually save the currently playing file to an M3U8 playlist file using Ctrl+S.

-- Set the path to your playlist file.
local playlist_file = mp.command_native({"expand-path", "~~/playlist.m3u8"})

-- Function to initialize the playlist file if it doesn't exist.
local function init_playlist()
    local file = io.open(playlist_file, "r")
    if not file then
        file = io.open(playlist_file, "w")
        if file then
            mp.msg.info("Created new playlist file: " .. playlist_file)
        else
            mp.msg.error("Could not create playlist file: " .. playlist_file)
        end
    else
        file:close()
    end
end

init_playlist()

-- Function to append the current file to the playlist.
local function add_to_playlist()
    local path = mp.get_property("path")
    
    if not path then
        mp.msg.error("No file path available to add to playlist!")
        return
    end

    local f = io.open(playlist_file, "a")
    if not f then
        mp.msg.error("Could not open playlist file for appending: " .. playlist_file)
        return
    end
    f:write(path .. "\n")
    f:close()

    mp.msg.info("Appended to playlist: " .. path)
end

-- Bind Ctrl+S to the add_to_playlist function.
mp.add_key_binding("ctrl+s", "save-to-m3u8", add_to_playlist)
