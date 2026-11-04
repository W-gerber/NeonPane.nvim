-- Lazygit, in a floating window. Provides :LazyGit and friends.

--- Make sure `lazygit` is reachable. The winget lookup that used to live here
--- is `core.utils.ensure_on_path` now — `:checkhealth core` needs the same
--- answer, and two copies of it disagreed: health reported lazygit missing on a
--- machine where this function found it and opened it fine.
---@return boolean available
local function ensure_lazygit()
  if require("core.utils").ensure_on_path("lazygit") then
    return true
  end

  vim.notify(
    "lazygit not found on PATH.\nInstall it and restart Neovim:\n"
      .. "  winget install JesseDuffield.lazygit\n"
      .. "  brew install lazygit",
    vim.log.levels.ERROR,
    { title = "Lazygit" }
  )

  return false
end

-- Lazygit paints its own TUI from its own config, so matching it to the Neovim
-- theme means writing that config — there is no highlight group to override
-- from this side.
--
-- Written to a file of our own under `stdpath("data")` rather than into
-- `%APPDATA%/lazygit/config.yml`: `LG_CONFIG_FILE` takes a comma-separated list
-- where later files win, so ours goes first and anything hand-written in the
-- real config still overrides it. Nothing the user owns is ever rewritten.
local THEME_FILE = vim.fs.joinpath(vim.fn.stdpath("data"), "lazygit-theme.yml")

--- The user's own lazygit config, if they have one.
---@return string|nil
local function user_config()
  local dir = vim.fn.has("win32") == 1 and vim.env.APPDATA
    or vim.fs.joinpath(vim.env.HOME or "", ".config")
  local path = dir and vim.fs.joinpath(dir, "lazygit", "config.yml")

  -- Size, not just existence: lazygit ships an empty `config.yml` on first run
  -- and listing an empty file buys nothing.
  return (path and vim.fn.getfsize(path) > 0) and path or nil
end

--- Write the theme file from the palette in force right now, and point lazygit
--- at it. Regenerated on every launch, so a theme switch is picked up without
--- anything having to watch for one.
local function sync_theme()
  local ui = require("core.ui")
  local p = ui.palette()

  local yaml = table.concat({
    "gui:",
    '  nerdFontsVersion: "3"',
    "  border: rounded",
    "  showRandomTip: false",
    "  showFileTree: true",
    "  filterMode: fuzzy",
    "  theme:",
    ('    activeBorderColor: ["%s", bold]'):format(p.accent),
    ('    inactiveBorderColor: ["%s"]'):format(ui.blend(p.muted, p.bg, 0.6)),
    ('    searchingActiveBorderColor: ["%s", bold]'):format(p.yellow),
    ('    optionsTextColor: ["%s"]'):format(p.muted),
    ('    selectedLineBgColor: ["%s"]'):format(ui.blend(p.accent, p.bg, 0.22)),
    ('    cherryPickedCommitBgColor: ["%s"]'):format(ui.blend(p.purple, p.bg, 0.25)),
    ('    cherryPickedCommitFgColor: ["%s"]'):format(p.purple),
    ('    unstagedChangesColor: ["%s"]'):format(p.red),
    ('    defaultFgColor: ["%s"]'):format(p.fg),
    "git:",
    "  paging:",
    "    colorArg: always",
    "",
  }, "\n")

  if not pcall(vim.fn.writefile, vim.split(yaml, "\n"), THEME_FILE) then
    return -- a missing theme is cosmetic; lazygit still opens on its defaults
  end

  local own = user_config()
  vim.env.LG_CONFIG_FILE = own and (THEME_FILE .. "," .. own) or THEME_FILE
end

--- Run a Lazygit command, but only once the binary is known to exist.
---@param command string
---@return fun()
local function guarded(command)
  return function()
    if ensure_lazygit() then
      sync_theme()
      vim.cmd(command)
    end
  end
end

return {
  "kdheepak/lazygit.nvim",
  cmd = {
    "LazyGit",
    "LazyGitConfig",
    "LazyGitCurrentFile",
    "LazyGitFilter",
    "LazyGitFilterCurrentDirectory",
  },
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    -- Under <leader>g* with the rest of the git tooling rather than a prefix of
    -- its own: which tool opens the diff is an implementation detail.
    { "<leader>gl", guarded("LazyGit"), desc = "Open Lazygit" },
    { "<leader>gL", guarded("LazyGitCurrentFile"), desc = "Lazygit: current file" },
  },
  init = function()
    vim.g.lazygit_floating_window_use_plenary = 1
    vim.g.lazygit_floating_window_border_chars =
      { "\u{256d}", "\u{2500}", "\u{256e}", "\u{2502}", "\u{256f}", "\u{2500}", "\u{2570}", "\u{2502}" }

    -- Give it the screen. Lazygit is a four-pane TUI; at the plugin's default
    -- 0.9/0.8 the panels are cramped enough that commit messages and diffs
    -- wrap constantly.
    vim.g.lazygit_floating_window_scaling_factor = 0.95

    -- Lazygit draws its own chrome, so the Neovim side should contribute
    -- nothing: no line numbers, no sign column, no cursorline bleeding through
    -- the TUI. `lazygit.nvim` opens a terminal buffer, and these are the window
    -- options that would otherwise sit on top of it.
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("LazygitChrome", { clear = true }),
      pattern = "lazygit",
      callback = function()
        local ui = require("core.ui")
        local p = ui.palette()

        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
        vim.opt_local.signcolumn = "no"
        vim.opt_local.cursorline = false
        vim.opt_local.spell = false
        vim.opt_local.list = false

        -- Match the border to the other floats in this config instead of
        -- inheriting whatever `FloatBorder` happens to be under the theme.
        vim.api.nvim_set_hl(0, "LazyGitBorder", { fg = ui.blend(p.accent, p.bg, 0.55), bg = ui.pane_bg(0.1) })
        vim.api.nvim_set_hl(0, "LazyGitFloat", { fg = p.fg, bg = ui.pane_bg(0.1) })

        vim.opt_local.winhighlight = "NormalFloat:LazyGitFloat,FloatBorder:LazyGitBorder"
      end,
    })
  end,
}
