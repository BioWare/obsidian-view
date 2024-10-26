if vim.fn.has('nvim-0.7.0') == 0 then
    vim.api.nvim_err_writeln('obsidian-view requires at least nvim-0.7.0')
    return
end

-- Prevent loading twice
if vim.g.loaded_obsidian_view == 1 then
    return
end
vim.g.loaded_obsidian_view = 1

-- Plugin can be required and setup manually
-- Auto setup with default configuration can be disabled with:
-- vim.g.obsidian_view_disable_auto_setup = 1
if vim.g.obsidian_view_disable_auto_setup ~= 1 then
    require('obsidian-view').setup()
end
