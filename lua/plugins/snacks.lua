-- Animated indentation guides and current-scope line (replaces
-- indent-blankline, which cannot animate).
--
-- snacks.nvim is a collection of independent modules; every one not listed in
-- `opts` stays off, so this loads the indent renderer and nothing else. It used
-- to arrive as a dependency of claudecode.nvim — that plugin is gone, so the
-- spec is declared directly here.
--
-- `BufReadPre`/`BufNewFile` rather than snacks' usual `VeryLazy`: guides are a
-- property of a loaded buffer, and this keeps it off the startup path.

return {
  "folke/snacks.nvim",
  priority = 1000,
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    indent = {
      indent = {
        char = "\u{2502}", -- │
        hl = "SnacksIndent",
      },

      -- The scope line: which block the cursor is actually inside.
      scope = {
        enabled = true,
        char = "\u{2502}", -- │
        underline = false,
        only_current = false,
        hl = "SnacksIndentScope",
      },

      -- The animation. `step` is ms per row drawn, `total` the ceiling for the
      -- whole sweep however deep the scope is.
      --
      -- `outCubic` decelerates harder than `outQuad`, so the line arrives and
      -- settles rather than stopping dead — which is most of what makes a
      -- short animation read as smooth instead of abrupt.
      animate = {
        enabled = true,
        style = "out",
        easing = "outCubic",
        duration = { step = 28, total = 400 },
      },

      -- Guides only in real file buffers. `buftype == ""` is the whole rule:
      -- the dashboard, neo-tree, Trouble, Telescope, Lazy, Mason, notify and
      -- the music panel are all `nofile`/`prompt`/`terminal`, so enumerating
      -- their filetypes (which is what the indent-blankline config did) only
      -- restates it and goes stale as plugins are added.
      --
      -- `vim.g`/`vim.b.snacks_indent` are snacks' own opt-out flags, kept so
      -- guides can be turned off globally or per buffer.
      filter = function(buf)
        return vim.g.snacks_indent ~= false
          and vim.b[buf].snacks_indent ~= false
          and vim.bo[buf].buftype == ""
      end,
    },
  },
  config = function(_, opts)
    local ui = require("core.ui")

    -- Guides sit just above the background; the active scope picks up the theme
    -- accent so "which block am I in" is answerable at a glance. Same two
    -- levels indent-blankline used, under snacks' group names.
    local function apply_indent_highlights()
      local p = ui.palette()
      vim.api.nvim_set_hl(0, "SnacksIndent", { fg = ui.blend(p.muted, p.bg, 0.35) })
      vim.api.nvim_set_hl(0, "SnacksIndentScope", { fg = ui.blend(p.accent, p.bg, 0.75) })
      vim.api.nvim_set_hl(0, "SnacksIndentChunk", { fg = ui.blend(p.accent, p.bg, 0.75) })
    end

    apply_indent_highlights()
    require("snacks").setup(opts)

    -- ColorScheme alone misses every base46 theme switch; on_theme_change also
    -- listens for `User ThemeSwitched`.
    ui.on_theme_change(ui.create_augroup("SnacksIndentHighlights"), apply_indent_highlights)
  end,
}
