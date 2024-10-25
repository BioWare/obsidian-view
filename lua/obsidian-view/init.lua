-- plugin/obsidian_view.lua
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

-- Вспомогательные функции для проверки и получения заметок
local function should_include(path, client_dir, config)
    local rel_path = path:sub(#client_dir + 2)
    local folder = vim.fn.fnamemodify(rel_path, ':h')
    
    for _, excluded in ipairs(config.exclude_folders) do
        if folder:match('^' .. excluded) then
            return false
        end
    end
    
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
    local min_box_width = 40
    local box_spacing = 2
    local max_width = math.floor(vim.o.columns * M.config.width)
    local max_boxes_per_row = math.floor((max_width + box_spacing) / (min_box_width + box_spacing))
    max_boxes_per_row = math.max(1, math.min(max_boxes_per_row, 3))
    
    local box_width = math.floor((max_width - (box_spacing * (max_boxes_per_row - 1))) / max_boxes_per_row)
    local max_height = math.floor(vim.o.lines * M.config.height)
    local box_height = 7
    
    local win = api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = max_width,
        height = max_height,
        col = math.floor((vim.o.columns - max_width) / 2),
        row = math.floor((vim.o.lines - max_height) / 2),
        style = 'minimal',
        border = 'rounded'
    })
    
    -- Структуры данных для хранения информации
    local title_positions = {}  -- [row_number] = { col = column, note_index = index, row = row_num, col_index = col_num }
    local lines = {}
    local current_row = {}
    local box_count = 0
    local title_line_offset = 1
    local total_width = box_width + box_spacing
    
    for i, note in ipairs(notes) do
        local box = create_note_box(note, box_width)
        table.insert(current_row, box)
        box_count = box_count + 1
        
        -- Сохраняем информацию о позиции заголовка
        local current_line = #lines + title_line_offset
        title_positions[current_line] = {
            col = 2,  -- Всегда ставим курсор на начало заголовка
            note_index = i,
            row = math.floor((i-1) / max_boxes_per_row),
            col_index = (i-1) % max_boxes_per_row
        }
        
        if box_count == max_boxes_per_row then
            -- Обработка строки заметок
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
    
    -- Обработка оставшихся заметок
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
    
    -- Настройка буфера
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    api.nvim_buf_set_option(buf, 'modifiable', false)
    api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(buf, 'swapfile', false)
    api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    vim.api.nvim_win_set_option(win, 'wrap', true)
    
    -- Сохраняем пути к заметкам
    local paths = {}
    for i, note in ipairs(notes) do
        paths[i] = note.path
    end
    
    api.nvim_buf_set_var(buf, 'note_paths', paths)
    api.nvim_buf_set_var(buf, 'title_positions', title_positions)

    -- Функция навигации
    local function navigate_titles(direction)
        local cursor = api.nvim_win_get_cursor(win)
        local current_line = cursor[1]
        local current_pos
        
        -- Находим текущую позицию
        for line, pos in pairs(title_positions) do
            if line == current_line then
                current_pos = pos
                break
            end
        end
        
        if not current_pos then return end
        
        local next_row = current_pos.row
        local next_col = current_pos.col_index
        local total_rows = math.ceil(#paths / max_boxes_per_row)
        
        -- Определяем следующую позицию на основе направления
        if direction == 'j' and next_row < total_rows - 1 then
            next_row = next_row + 1
        elseif direction == 'k' and next_row > 0 then
            next_row = next_row - 1
        elseif direction == 'h' and next_col > 0 then
            next_col = next_col - 1
        elseif direction == 'l' and next_col < max_boxes_per_row - 1 and
               (next_row * max_boxes_per_row + next_col + 1) < #paths then
            next_col = next_col + 1
        end
        
        -- Находим новую позицию и перемещаем курсор
        for line, pos in pairs(title_positions) do
            if pos.row == next_row and pos.col_index == next_col then
                api.nvim_win_set_cursor(win, {line, 2})
                return
            end
        end
    end
    
    -- Устанавливаем маппинги
    local opts = { noremap = true, silent = true }
    
    -- Базовые маппинги
    api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', opts)
    api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', opts)
    
    -- Маппинги навигации
    api.nvim_buf_set_keymap(buf, 'n', 'j', '', {
        noremap = true,
        callback = function() navigate_titles('j') end
    })
    api.nvim_buf_set_keymap(buf, 'n', 'k', '', {
        noremap = true,
        callback = function() navigate_titles('k') end
    })
    api.nvim_buf_set_keymap(buf, 'n', 'l', '', {
        noremap = true,
        callback = function() navigate_titles('l') end
    })
    api.nvim_buf_set_keymap(buf, 'n', 'h', '', {
        noremap = true,
        callback = function() navigate_titles('h') end
    })
    
    -- Обработчик для открытия заметок
    api.nvim_buf_set_keymap(buf, 'n', '<CR>', '', {
        noremap = true,
        callback = function()
            local cursor = api.nvim_win_get_cursor(win)
            local line_num = cursor[1]
            local title_pos = title_positions[line_num]
            
            if title_pos and paths[title_pos.note_index] then
                api.nvim_command('close')
                vim.cmd('edit ' .. paths[title_pos.note_index])
            end
        end
    })
    
    -- Устанавливаем начальную позицию курсора
    local first_title_line = vim.tbl_keys(title_positions)[1]
    if first_title_line then
        vim.schedule(function()
            api.nvim_win_set_cursor(win, {first_title_line, 2})
        end)
    end
end

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    vim.api.nvim_create_user_command('ObsidianView', function()
        M.show_notes()
    end, {})
end

return M
