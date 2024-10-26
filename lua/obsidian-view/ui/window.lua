local config = require('obsidian-view.config')
local box = require('obsidian-view.ui.box')

local M = {}

function M.calculate_dimensions()
    local min_box_width = 40
    local box_spacing = 2
    local max_width = math.floor(vim.o.columns * config.options.width)
    local max_boxes_per_row = math.floor((max_width + box_spacing) / (min_box_width + box_spacing))
    max_boxes_per_row = math.max(1, math.min(max_boxes_per_row, 3))
    
    local box_width = math.floor((max_width - (box_spacing * (max_boxes_per_row - 1))) / max_boxes_per_row)
    local max_height = math.floor(vim.o.lines * config.options.height)
    
    return {
        max_width = max_width,
        max_height = max_height,
        box_width = box_width,
        box_spacing = box_spacing,
        max_boxes_per_row = max_boxes_per_row
    }
end

function M.create_window(notes)
    local dims = M.calculate_dimensions()
    local buf = vim.api.nvim_create_buf(false, true)
    
    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = dims.max_width,
        height = dims.max_height,
        col = math.floor((vim.o.columns - dims.max_width) / 2),
        row = math.floor((vim.o.lines - dims.max_height) / 2),
        style = 'minimal',
        border = config.options.border
    })
    
    -- Set buffer options
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    vim.api.nvim_win_set_option(win, 'wrap', true)
    
    return {
        buf = buf,
        win = win,
        dimensions = dims
    }
end

function M.render_notes(win_info, notes, title_positions)
    local dims = win_info.dimensions
    local lines = {}
    local current_row = {}
    local box_count = 0
    
    for i, note in ipairs(notes) do
        local note_box = box.create_note_box(note, dims.box_width)
        table.insert(current_row, note_box)
        box_count = box_count + 1
        
        if box_count == dims.max_boxes_per_row then
            -- Combine boxes in current row
            local row_lines = {}
            for j = 1, #note_box do
                local line = ""
                for _, b in ipairs(current_row) do
                    line = line .. b[j] .. string.rep(" ", dims.box_spacing)
                end
                line = line:gsub("%s+$", "")
                table.insert(row_lines, line)
            end
            
            vim.list_extend(lines, row_lines)
            table.insert(lines, "")
            
            current_row = {}
            box_count = 0
        end
    end
    
    -- Handle remaining boxes
    if #current_row > 0 then
        local row_lines = {}
        for i = 1, #current_row[1] do
            local line = ""
            for _, b in ipairs(current_row) do
                line = line .. b[i] .. string.rep(" ", dims.box_spacing)
            end
            line = line:gsub("%s+$", "")
            table.insert(row_lines, line)
        end
        vim.list_extend(lines, row_lines)
    end
    
    vim.api.nvim_buf_set_option(win_info.buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(win_info.buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(win_info.buf, 'modifiable', false)
end

return M
