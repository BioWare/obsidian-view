local M = {}

function M.create_note_box(note, width)
    local top = "╭" .. string.rep("─", width - 2) .. "╮"
    local bottom = "╰" .. string.rep("─", width - 2) .. "╯"
    local empty = "│" .. string.rep(" ", width - 2) .. "│"
    
    local title = note.title:sub(1, width - 4)
    local title_line = "│ " .. title .. string.rep(" ", width - 4 - #title) .. " │"
    
    local preview_lines = {}
    for line in note.preview:gmatch("[^\n]+") do
        local formatted = line:sub(1, width - 4)
        if #line > width - 4 then
            formatted = formatted:sub(1, width - 7) .. "..."
        end
        table.insert(preview_lines, "│ " .. formatted .. string.rep(" ", width - 4 - #formatted) .. " │")
    end
    
    local box = {top, title_line, "│" .. string.rep("─", width - 2) .. "│"}
    vim.list_extend(box, preview_lines)
    if #preview_lines < 3 then
        for i = 1, 3 - #preview_lines do
            table.insert(box, empty)
        end
    end
    table.insert(box, bottom)
    
    return box
end

return M
