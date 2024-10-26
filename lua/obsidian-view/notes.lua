local config = require('obsidian-view.config')
local utils = require('obsidian-view.utils')

local M = {}

function M.get_client()
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

function M.get_notes()
    local client = M.get_client()
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
        if utils.should_include(file, vault_path, config.options) then
            local title = vim.fn.fnamemodify(file, ':t:r')
            local lines = {}
            local file_handle = io.open(file, "r")
            
            if file_handle then
                for i = 1, config.options.preview_lines do
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

return M
