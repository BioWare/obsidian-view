local M = {}

function M.should_include(path, client_dir, config)
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

return M
