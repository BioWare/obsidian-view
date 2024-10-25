# obsidian-view.nvim

A Neovim plugin for visualizing Obsidian vault notes in a floating window.

## Requirements
- Neovim >= 0.8.0
- [epwalsh/obsidian.nvim](https://github.com/epwalsh/obsidian.nvim)
- [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

## Installation

Using packer.nvim:
```lua
use {
    'your-username/obsidian-view.nvim',
    requires = {
        'epwalsh/obsidian.nvim',
        'nvim-lua/plenary.nvim',
    },
    config = function()
        require('obsidian-view').setup({
            -- your configuration here
        })
    end
}
