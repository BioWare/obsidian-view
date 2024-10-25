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
    -- Default to first workspace if none specified
    workspace = nil
}

-- Function to get obsidian configuration
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

-- Function to get all notes from the vault
local function get_notes()
    local client = get_obsidian_config()
    if not client then 
        print("Failed to get obsidian client")
        return {} 
    end
    
    local notes = {}
    local scan = require("plenary.scandir")
    
    -- Get the current workspace path
    local vault_path
    if client.current_workspace and client.current_workspace.path then
        -- Convert Path object to string using its __tostring metamethod
        vault_path = tostring(client.current_workspace.path)
    end
    
    if not vault_path then
        print("No valid vault path found")
        return {}
    end
    
    -- Expand the path (resolve ~/ if present)
    vault_path = vim.fn.expand(vault_path)
    
    -- Debug prints
    print("Scanning vault path:", vault_path)
    
    -- Try plenary scan with recursive search
    local files = scan.scan_dir(vault_path, {
        hidden = false,
        add_dirs = false,
        respect_gitignore = true,
        depth = 10,  -- Увеличиваем глубину поиска
        search_pattern = "%.md$"
    })
    
    print("Found files:", vim.inspect(files))
    
    for _, file in ipairs(files) do
        print("Processing file:", file)
        if should_include(file) then
            local title = vim.fn.fnamemodify(file, ':t:r')
            print("Including file:", title)
            
            -- Read file contents for preview
            local lines = {}
            local file_handle = io.open(file, "r")
            
            if file_handle then
                -- Read first few lines for preview
                for i = 1, M.config.preview_lines do
                    local line = file_handle:read("*line")
                    if line then
                        -- Skip YAML frontmatter
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
        else
            print("File excluded:", file)
        end
    end
    
    print("Total notes found:", #notes)
    return notes
end

-- Create ASCII box for a note
local function create_note_box(note)
    local box_width = 30
    local top = "┌" .. string.rep("─", box_width - 2) .. "┐"
    local bottom = "└" .. string.rep("─", box_width - 2) .. "┘"
    local empty = "│" .. string.rep(" ", box_width - 2) .. "│"
    
    -- Format title
    local title = note.title:sub(1, box_width - 4)
    local title_line = "│ " .. title .. string.rep(" ", box_width - 4 - #title) .. " │"
    
    -- Format preview (first few lines of content)
    local preview_lines = {}
    for line in note.preview:gmatch("[^\n]+") do
        local formatted = line:sub(1, box_width - 4)
        table.insert(preview_lines, "│ " .. formatted .. string.rep(" ", box_width - 4 - #formatted) .. " │")
    end
    
    local box = {top, title_line, empty}
    vim.list_extend(box, preview_lines)
    table.insert(box, bottom)
    
    return box
end

function M.show_notes()
    local notes = get_notes()
    if #notes == 0 then
        vim.notify("No notes found in vault", vim.log.levels.WARN)
        return
    end
    
    -- Create buffer and window
    local buf = api.nvim_create_buf(false, true)
    local width = math.floor(vim.o.columns * M.config.width)
    local height = math.floor(vim.o.lines * M.config.height)
    
    local win = api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        col = math.floor((vim.o.columns - width) / 2),
        row = math.floor((vim.o.lines - height) / 2),
        style = 'minimal',
        border = M.config.border
    })
    
    -- Generate layout
    local lines = {}
    local current_row = {}
    local max_boxes_per_row = 3
    local box_count = 0
    local note_positions = {}  -- Store note positions for navigation
    
    for i, note in ipairs(notes) do
        local box = create_note_box(note)
        table.insert(current_row, box)
        box_count = box_count + 1
        
        -- Store note position for navigation
        note_positions[#lines + 1] = note.path
        
        if box_count == max_boxes_per_row then
            -- Combine boxes in current row
            local row_lines = {}
            for j = 1, #box do
                local line = ""
                for _, b in ipairs(current_row) do
                    line = line .. b[j] .. "  "
                end
                table.insert(row_lines, line)
            end
            
            -- Add row lines to output
            vim.list_extend(lines, row_lines)
            table.insert(lines, "")  -- Empty line between rows
            
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
                line = line .. b[i] .. "  "
            end
            table.insert(row_lines, line)
        end
        vim.list_extend(lines, row_lines)
    end
    
    -- Set buffer content
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    api.nvim_buf_set_option(buf, 'modifiable', false)
    
    -- Set buffer options
    api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(buf, 'swapfile', false)
    api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    
    -- Set keymaps
    local opts = { noremap = true, silent = true }
    api.nvim_buf_set_keymap(buf, 'n', 'q', ':close<CR>', opts)
    api.nvim_buf_set_keymap(buf, 'n', '<Esc>', ':close<CR>', opts)
    
    -- Open note under cursor
    api.nvim_buf_set_keymap(buf, 'n', '<CR>', '', {
        noremap = true,
        callback = function()
            local cursor = api.nvim_win_get_cursor(win)
            local line_num = cursor[1]
            local note_path = note_positions[line_num]
            if note_path then
                api.nvim_command('close')  -- Close the float window
                vim.cmd('edit ' .. note_path)
            end
        end
    })
    
    -- Store note positions in buffer variable for navigation
    api.nvim_buf_set_var(buf, 'note_positions', note_positions)
end

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    
    -- Create user commands
    vim.api.nvim_create_user_command('ObsidianView', function()
        M.show_notes()
    end, {})
end

return M
