# obsidian-view.nvim

A Neovim plugin for visualizing Obsidian vault notes in a floating window.

## Requirements
- Neovim >= 0.8.0
- [epwalsh/obsidian.nvim](https://github.com/epwalsh/obsidian.nvim)
- [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

## Installation

Using packer.nvim:
```lua
use({
    'BioWare/obsidian-view',
    requires = {
        'epwalsh/obsidian.nvim',
        'nvim-lua/plenary.nvim',
    },
    config = function()
        require('obsidian-view').setup({
            -- By default it will show all notes
            -- Optional: exclude specific folders
            exclude_folders = {"templates", "Daily"},  -- This will exclude your templates and daily notes
            -- Optional: include only specific folders
            include_folders = {},  -- Empty means include all except excluded
            preview_lines = 3,
        })
    end,
})
