-- Define a function to copy the video title to the clipboard
function copy_title_to_clipboard()
    -- Get the current video title
    local title = mp.get_property("media-title")
    -- Set the clipboard text to the video title
    mp.set_property("clipboard/text", title)
    -- Notify the user
    mp.osd_message("Copied title to clipboard: " .. title)
end

-- Define a function to copy the filename to the clipboard
function copy_filename_to_clipboard()
    -- Get the current video filename
    local filename = mp.get_property("filename")
    -- Set the clipboard text to the filename
    mp.set_property("clipboard/text", filename)
    -- Notify the user
    mp.osd_message("Copied filename to clipboard: " .. filename)
end

-- Bind the function to Shift+C
mp.add_key_binding("ctrl+c", "copy-title", copy_title_to_clipboard)
mp.add_key_binding("Shift+c", "copy-filename", copy_filename_to_clipboard)
