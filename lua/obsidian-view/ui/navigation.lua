local M = {}

function M.setup_navigation(win_info, notes, title_positions)
    local buf = win_info.buf
    local win = win_info.win
    local dims = win_info.dimensions
    
    local function navigate_titles(direction)
        local cursor = vim.api.nvim_win_get_cursor(win)
        local current_line = cursor[1]
        local current_pos
        
        for line, pos in pairs(title_positions) do
            if line == current_line then
                current_pos = pos
                break
            end
        end
        
        if not current_pos then return end
        
        local next_row = current_pos.row
        local next_col = current_pos.col_index
        local total_rows = math.ceil(#notes / dims.max_boxes_per_row)
        
        if direction == 'j' and next_row < total_rows - 1 then
            next_row = next_row + 1
        elseif direction == 'k' and next_row > 0 then
            next_row = next_row - 1
        elseif direction == 'h' and next_col > 0 then
            next_col = next_col - 1
        elseif direction == 'l' and next_col < dims.max_boxes_per_row - 1 and
               (next_row * dims.max_boxes_per_row + next_col + 1) < #notes then
            next_col = next_col + 1
        end
        
        for line, pos in pairs(title_positions) do
            if pos.row == next_row and pos.col_index == next_col then
                vim.api.nvim_win_set_cursor(win, {line, 2})
                return
            end
        end
    end
    
    -- Store paths for note opening
    local paths = {}
    for i, note in ipairs(notes) do
        paths[i] = note.path
    end
    
    -- Set up keymaps
    local opts = { noremap = true, silent = true }
    
    -- Navigation
    vim.api.nvim_buf_set_keymap(buf, 'n', 'j', '', {
        noremap = true,
        callback = function() navigate_titles('j') end
    })
    vim.api.nvim_buf_set_keymap(buf, 'n', 'k', '', {
        noremap = true,
        callback = function() navigate_titles('k') end
    })
    vim.api.nvim_buf_set_keymap(buf, 'n', 'l', '', {
        noremap = true,
        callback = function() navigate_titles('l') end
    })
    vim.api.nvim_buf_set_keymap(buf, 'n', 'h', '', {
        noremap = true,
        callback = function() navigate_titles('h') end
    })
    
    -- Close window
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', opts)
    vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', opts)
    
    -- Open note
    vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', '', {
        noremap = true,
        callback = function()
            local cursor = vim.api.nvim_win_get_cursor(win)
            local line_num = cursor[1]
            local title_pos = title_positions[line_num]
            
            if title_pos and paths[title_pos.note_index] then
                vim.api.nvim_command('close')
                vim.cmd('edit ' .. paths[title_pos.note_index])
            end
        end
    })
    
    -- Set initial cursor position
    local first_title_line = vim.tbl_keys(title_positions)[1]
    if first_title_line then
        vim.schedule(function()
            vim.api.nvim_win_set_cursor(win, {first_title_line, 2})
        end)
    end
end

return M
