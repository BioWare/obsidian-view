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
    if not client then return {} end
    
    local notes = {}
    local scan = require("plenary.scandir")
    
    -- Get the current workspace path
    local vault_path = client.dir
    if not vault_path then
        vim.notify("No valid vault path found", vim.log.levels.ERROR)
        return {}
    end
    
    -- Debug print
    print("Scanning vault path:", vault_path)
    
    -- Handle notes subdirectory if configured
    local notes_subdir = client.notes_subdir
    if notes_subdir then
        vault_path = fn.expand(fn.joinpath(vault_path, notes_subdir))
    end
    
    -- Helper function to check if path should be included
    local function should_include(path)
        -- Convert path to relative path from vault root
        local rel_path = path:sub(#client.dir + 2)
        local folder = vim.fn.fnamemodify(rel_path, ':h')
        
        -- Check exclusions
        for _, excluded in ipairs(M.config.exclude_folders) do
            if folder:match('^' .. excluded) then
                return false
            end
        end
        
        -- Check inclusions
        if #M.config.include_folders > 0 then
            for _, included in ipairs(M.config.include_folders) do
                if folder:match('^' .. included) then
                    return true
                end
            end
            return false
        end
        
        return true
    end
    
    -- Scan vault directory
    local files = scan.scan_dir(vault_path, {
        hidden = false,
        add_dirs = false,
        respect_gitignore = true,
        depth = 10,
        search_pattern = "%.md$"
    })
    
    -- Debug print
    print("Found files:", #files)
    
    for _, file in ipairs(files) do
        if should_include(file) then
            -- Read file contents for preview
            local lines = {}
            local title = vim.fn.fnamemodify(file, ':t:r')
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
        end
    end
    
    return notes
end

-- [Rest of the code remains the same as in the previous version...]
-- Including create_note_box(), show_notes(), and setup() functions

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    
    -- Create user commands
    vim.api.nvim_create_user_command('ObsidianView', function()
        M.show_notes()
    end, {})
end

return M
