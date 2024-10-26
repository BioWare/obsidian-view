local window = require('obsidian-view.ui.window')
local navigation = require('obsidian-view.ui.navigation')

local M = {}

function M.show_notes(notes)
    if #notes == 0 then
        vim.notify("No notes found in vault", vim.log.levels.WARN)
        return
    end
    
    local win_info = window.create_window(notes)
    local title_positions = {}
    local box_height = 7  -- Примерная высота бокса
    
    -- Calculate title positions
    local current_line = 1
    for i, _ in ipairs(notes) do
        local row = math.floor((i-1) / win_info.dimensions.max_boxes_per_row)
        local col = (i-1) % win_info.dimensions.max_boxes_per_row
        
        title_positions[current_line] = {
            col = 2,
            note_index = i,
            row = row,
            col_index = col
        }
        
        current_line = current_line + box_height + 1
    end
    
    window.render_notes(win_info, notes, title_positions)
    navigation.setup_navigation(win_info, notes, title_positions)
end

return M
