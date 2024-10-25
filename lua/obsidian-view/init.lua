local api = vim.api
local fn = vim.fn

local M = {}

M.config = {
    width = 0.8,
    height = 0.8,
    border = "rounded",
    exclude_folders = {},
    include_folders = {},
    preview_lines = 3,
    workspace = nil
}

local function should_include(path, client_dir, config)
    local rel_path = path:sub(#client_dir + 2)
    local folder = vim.fn.fnamemodify(rel_path, ':h')
    
    -- Check exclusions
    for _, excluded in ipairs(config.exclude_folders) do
        if folder:match('^' .. excluded) then
            return false
        end
    end
    
    -- Check inclusions
    if #config.include_folders > 0 then
        for _, included in ipairs(config.include_folders) do
            if folder:match('^' .. included) then
                return true
            end
        end
        return false
    end
    
    return true
end

local function get_obsidian_config()
    local obsidian = require("obsidian")
    if not obsidian then
        vim.notify("obsidian.nvim is required but not found", vim.log.levels.ERROR)
        return nil
    end
    
    local client = obsidian.get_client()
    if not client then
        vim.notify("Failed to get obsidian client", vim.log.levels.ERROR)
        return nil
    end
    
    return client
end

local function get_notes()
    local client = get_obsidian_config()
    if not client then return {} end
    
    local notes = {}
    local scan = require("plenary.scandir")
    local vault_path = tostring(client.current_workspace.path)
    
    local files = scan.scan_dir(vault_path, {
        hidden = false,
        add_dirs = false,
        respect_gitignore = true,
        depth = 10,
        search_pattern = "%.md$"
    })
    
    for _, file in ipairs(files) do
        if should_include(file, vault_path, M.config) then
            local title = vim.fn.fnamemodify(file, ':t:r')
            local lines = {}
            local file_handle = io.open(file, "r")
            
            if file_handle then
                for i = 1, M.config.preview_lines do
                    local line = file_handle:read("*line")
                    if line then
                        if i == 1 and line:match("^%-%-%-%s*$") then
                            repeat
                                line = file_handle:read("*line")
                            until not line or line:match("^%-%-%-%)s*$")
                            line = file_handle:read("*line")
                        end
                        if line then
                            table.insert(lines, line)
                        end
                    end
                end
                file_handle:close()
            end
            
            table.insert(notes, {
                title = title,
                path = file,
                preview = table.concat(lines, "\n")
            })
        end
    end
    
    return notes
end

local function create_note_box(note, width)
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

function M.show_notes()
    local notes = get_notes()
    if #notes == 0 then
        vim.notify("No notes found in vault", vim.log.levels.WARN)
        return
    end
    
    local buf = api.nvim_create_buf(false, true)
    
    -- Расчет размеров
    local min_box_width = 40  -- Минимальная ширина для заметки
    local box_spacing = 2     -- Пространство между заметками
    local max_width = math.floor(vim.o.columns * M.config.width)
    local max_boxes_per_row = math.floor((max_width + box_spacing) / (min_box_width + box_spacing))
    max_boxes_per_row = math.max(1, math.min(max_boxes_per_row, 3))  -- Ограничиваем от 1 до 3
    
    local box_width = math.floor((max_width - (box_spacing * (max_boxes_per_row - 1))) / max_boxes_per_row)
    local max_height = math.floor(vim.o.lines * M.config.height)
    
    local win = api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = max_width,
        height = max_height,
        col = math.floor((vim.o.columns - max_width) / 2),
        row = math.floor((vim.o.lines - max_height) / 2),
        style = 'minimal',
        border = 'rounded'
    })
    
    -- Храним информацию о позициях заметок
    local note_positions = {}  -- Будет хранить [line_number] = note_index
    local lines = {}
    local current_row = {}
    local box_count = 0
    local box_height = 6  -- Примерная высота бокса (настройте в соответствии с вашими боксами)
    
    for i, note in ipairs(notes) do
        local box = create_note_box(note, box_width)
        table.insert(current_row, box)
        box_count = box_count + 1
        
        -- Запоминаем позицию начала текущей заметки
        local current_line = #lines + 1
        for j = 0, box_height - 1 do
            note_positions[current_line + j] = i
        end
        
        if box_count == max_boxes_per_row then
            -- Combine boxes in current row
            local row_lines = {}
            for j = 1, #box do
                local line = ""
                for _, b in ipairs(current_row) do
                    line = line .. b[j] .. string.rep(" ", box_spacing)
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
                line = line .. b[i] .. string.rep(" ", box_spacing)
            end
            line = line:gsub("%s+$", "")
            table.insert(row_lines, line)
        end
        vim.list_extend(lines, row_lines)
    end
    
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    api.nvim_buf_set_option(buf, 'modifiable', false)
    api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(buf, 'swapfile', false)
    api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    
    -- Отключаем горизонтальный скролл
    vim.api.nvim_win_set_option(win, 'wrap', true)
    
    local opts = { noremap = true, silent = true }
    api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', opts)
    api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', opts)
    
    -- Обработчик для открытия заметок
    local paths = {}
    for i, note in ipairs(notes) do
        paths[i] = note.path
    end
    
    api.nvim_buf_set_var(buf, 'note_paths', paths)
    
    api.nvim_buf_set_keymap(buf, 'n', '<CR>', '', {
        noremap = true,
        callback = function()
            local cursor = api.nvim_win_get_cursor(win)
            local line_num = cursor[1]
            local note_index = note_positions[line_num]
            local paths = api.nvim_buf_get_var(buf, 'note_paths')
            
            if note_index and paths[note_index] then
                api.nvim_command('close')
                vim.cmd('edit ' .. paths[note_index])
            end
        end
    })
end

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    vim.api.nvim_create_user_command('ObsidianView', function()
        M.show_notes()
    end, {})
end

return M
