-- Floating terminal.
--
-- Floating rather than docked at the bottom: the terminal is something you
-- summon, read and dismiss, so it gets the screen while it is open and gives
-- all of it back when it closes — no permanent horizontal split eating rows
-- from the buffer underneath.
--
-- The window is a dedicated `Terminal` instance rather than the anonymous one
-- `:ToggleTerm` opens, because toggleterm only draws a border title when the
-- terminal carries a `display_name` (see `float_config.title` in its ui.lua).
-- That title is the whole reason the panel reads as a window rather than a
-- rectangle of text.

--- Windows PowerShell, falling back to the configured shell everywhere else.
---
--- `-NoLogo` drops the copyright banner that would otherwise be the first
--- thing in every new terminal. Deliberately `powershell.exe` (Windows
--- PowerShell 5.1) and not `pwsh` — swap the name below for PowerShell 7.
---@return string
local function shell_command()
  if vim.fn.has("win32") == 1 and vim.fn.executable("powershell.exe") == 1 then
    return "powershell.exe -NoLogo"
  end

  return vim.o.shell
end

---@return string
local function shell_title()
  if vim.fn.has("win32") == 1 and vim.fn.executable("powershell.exe") == 1 then
    return "  PowerShell "
  end

  return "  " .. vim.fn.fnamemodify(vim.o.shell, ":t:r") .. " "
end

-- Several terminals, one float. Only one is ever on screen, so the "tabs" are
-- drawn into the float's *border title* rather than a winbar: the title is the
-- one strip toggleterm already reserves at the top of the panel, and it needs no
-- second window to live in.
--
-- Built on first use, then reused: constructing them at config time would spawn
-- a shell during startup.
local terminals = {}
local current = 1

--- The tab strip: `[1] 2 3`, active one accented.
---
--- Border titles take `{ text, highlight }` chunks, which is what lets the
--- active tab be a filled chip while the rest stay dim.
---@return table[]
local function title_chunks()
  local chunks = { { shell_title(), "ToggleTermTitle" } }

  for index = 1, #terminals do
    chunks[#chunks + 1] = {
      " " .. index .. " ",
      index == current and "ToggleTermTabActive" or "ToggleTermTabInactive",
    }
  end

  return chunks
end

--- Redraw the strip on the float that is currently open, if any.
local function refresh_title()
  local term = terminals[current]
  local window = term and term.window

  if not (window and vim.api.nvim_win_is_valid(window)) then
    return
  end

  -- A float's config has to be set whole — `nvim_win_set_config` rejects a
  -- partial table that leaves out `relative`.
  local config = vim.api.nvim_win_get_config(window)
  config.title = title_chunks()
  config.title_pos = "center"
  vim.api.nvim_win_set_config(window, config)
end

---@param index integer
local function get_terminal(index)
  if not terminals[index] then
    terminals[index] = require("toggleterm.terminal").Terminal:new({
      count = index,
      direction = "float",
      display_name = shell_title(),
      -- Kept out of the numbered terminal list, so `1<C-\>` and friends still
      -- address ordinary terminals without colliding with these.
      hidden = true,
      -- toggleterm builds the title from `display_name` when it opens the
      -- window, so the strip has to be painted back on after every open.
      on_open = refresh_title,
    })
  end

  return terminals[index]
end

--- Bring terminal `index` to the front, closing whichever one is showing.
---@param index integer
local function show(index)
  local previous = terminals[current]

  current = index
  local term = get_terminal(index)

  if previous and previous ~= term and previous:is_open() then
    previous:close()
  end

  term:open()
end

local function toggle()
  local term = get_terminal(current)

  if term:is_open() then
    term:close()
  else
    term:open()
  end
end

local function new_terminal() show(#terminals + 1) end

--- Step `delta` tabs, wrapping.
---@param delta integer
---@return fun()
local function cycle(delta)
  return function()
    if #terminals > 1 then
      show((current - 1 + delta) % #terminals + 1)
    end
  end
end

return {
  "akinsho/toggleterm.nvim",
  version = "*",
  cmd = { "ToggleTerm", "TermExec" },
  keys = {
    { "<leader>ut", toggle, desc = "Toggle terminal" },
    -- The leader route to a new tab. `<A-t>` below is the same thing from
    -- inside a terminal, where the leader is being typed at the shell.
    { "<leader>uT", new_terminal, desc = "New terminal tab" },
    { [[<c-\>]], toggle, desc = "Toggle terminal", mode = { "n", "t" } },
    -- Alt, like the window motions above them, so they work from terminal mode
    -- without being swallowed by the shell running inside.
    { "<A-t>", new_terminal, desc = "New terminal tab", mode = { "n", "t" } },
    { "<A-.>", cycle(1), desc = "Next terminal tab", mode = { "n", "t" } },
    { "<A-,>", cycle(-1), desc = "Previous terminal tab", mode = { "n", "t" } },
  },
  config = function()
    local ui = require("core.ui")

    -- Named groups rather than colors written straight into toggleterm's
    -- config: the spec's `highlights` are read once at setup, so restyling on
    -- a theme switch means owning the groups they point at.
    local function apply_terminal_highlights()
      local p = ui.palette()
      local set = vim.api.nvim_set_hl

      set(0, "ToggleTermNormal", { fg = p.fg, bg = ui.pane_bg(0.1) })
      set(0, "ToggleTermBorder", { fg = ui.blend(p.accent, p.bg, 0.55), bg = ui.pane_bg(0.1) })
      set(0, "ToggleTermTitle", { fg = p.accent, bold = true })

      -- The active tab is a filled chip; the rest are the border's own dim tone,
      -- so the strip reads as one selected thing rather than a row of buttons.
      set(0, "ToggleTermTabActive", { fg = ui.contrast(p.accent), bg = p.accent, bold = true })
      set(0, "ToggleTermTabInactive", { fg = p.muted, bg = ui.pane_bg(0.1) })
    end

    apply_terminal_highlights()
    ui.on_theme_change(ui.create_augroup("ToggleTermHighlights"), apply_terminal_highlights)

    require("toggleterm").setup({
      insert_mappings = false, -- we handle mappings via keys above
      terminal_mappings = false,
      start_in_insert = true,
      -- Off: always reopen ready to type. On, leaving terminal mode once meant
      -- every later reopen landed in normal mode where keystrokes do nothing.
      persist_mode = false,
      persist_size = true,
      shade_terminals = false,
      shell = shell_command(),
      direction = "float",
      -- Only consulted for the horizontal/vertical directions; kept so
      -- switching back with `:ToggleTerm direction=horizontal` still behaves.
      size = 15,
      float_opts = {
        border = "rounded",
        title_pos = "center",
        -- Functions, not constants: these are re-evaluated on each open, so the
        -- terminal re-fits after the window is resized instead of keeping the
        -- dimensions it happened to launch with.
        --
        -- 78%/72% rather than near-fullscreen: enough of the buffer stays
        -- visible around the edges that the terminal reads as a panel floating
        -- over the code rather than as a mode you switched into.
        width = function() return math.floor(vim.o.columns * 0.78) end,
        height = function() return math.floor(vim.o.lines * 0.72) end,
        -- 0, like every other float here. See the note on `core.ui.pane_bg()`:
        -- a blended pane over a transparent editor composites against the
        -- default background and comes out as a dark sheet.
        winblend = 0,
      },
      highlights = {
        Normal = { link = "ToggleTermNormal" },
        NormalFloat = { link = "ToggleTermNormal" },
        FloatBorder = { link = "ToggleTermBorder" },
        FloatTitle = { link = "ToggleTermTitle" },
      },
    })
    -- The terminal-mode escape (<A-q>) is global; see lua/core/keymaps.lua.
  end,
}
