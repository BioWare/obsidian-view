local config = require('obsidian-view.config')
local notes = require('obsidian-view.notes')
local ui = require('obsidian-view.ui')

local M = {}

function M.setup(opts)
    config.setup(opts)
    
    vim.api.nvim_create_user_command('ObsidianView', function()
        local note_list = notes.get_notes()
        ui.show_notes(note_list)
    end, {})
end

return M
