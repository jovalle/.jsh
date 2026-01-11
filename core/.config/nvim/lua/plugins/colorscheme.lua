-- VS Code Dark+ theme configuration
return {
  -- VS Code colorscheme
  {
    "Mofiqul/vscode.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "dark",
      transparent = false,
      italic_comments = true,
      underline_links = true,
      disable_nvimtree_bg = true,
    },
  },

  -- Configure LazyVim to use vscode theme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "vscode",
    },
  },

  -- Telescope search highlighting (optional customization)
  {
    "nvim-telescope/telescope.nvim",
    opts = {
      defaults = {
        -- VS Code Dark+ inspired selection colors
        selection_caret = " ",
        prompt_prefix = " ",
      },
    },
  },
}
