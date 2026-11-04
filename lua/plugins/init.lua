-- Aggregated lazy.nvim plugin specs.
--
-- One module per plugin; each returns a spec table or a list of them. Adding a
-- plugin means adding a file under lua/plugins/ and one line here — lazy.nvim
-- receives the flattened list from init.lua.

local modules = {
  -- Theme engine + icons
  "base46",
  "web_devicons",

  -- Syntax / editing
  "treesitter",
  "treesitter_context",
  "rainbow_delimiters",
  "snacks", -- animated indent guides + scope line
  "autopairs",
  "flash",
  "mini", -- mini.icons + mini.surround (returns a list)

  -- Language tooling
  "mason",
  "lspconfig",
  "lazydev",
  "conform",
  "lint",
  "cmp",
  "trouble",
  "todo_comments",
  "dap",

  -- UI / chrome
  "alpha",
  "lualine",
  "noice",
  "notify",
  "smear_cursor",
  "which_key",
  "vimade", -- dim inactive windows
  "scrolleof", -- keep 'scrolloff' honoured at end of buffer

  -- Navigation
  "neo_tree",
  "telescope",
  "telescope_zoxide",
  "window_picker",
  "session_manager",

  -- Terminals / git
  "toggleterm",
  "grug_far", -- project search & replace
  "diffview",
  "render_markdown",
  "gitsigns",
  "lazygit",

  -- Colorscheme plugins (this one returns a list)
  "colorschemes",
}

local specs = {}

for _, name in ipairs(modules) do
  local spec = require("plugins." .. name)

  -- A module may return either a single spec or a list of them. A single spec
  -- is identifiable by its `[1]` repo string; anything else is a list.
  if type(spec[1]) == "string" then
    specs[#specs + 1] = spec
  else
    vim.list_extend(specs, spec)
  end
end

return specs
