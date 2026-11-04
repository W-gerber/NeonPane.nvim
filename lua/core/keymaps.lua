-- Global keymaps.
--
-- Plugin-specific mappings live with their plugin spec (so lazy.nvim can use
-- them as load triggers). Only editor-wide bindings belong here.

local utils = require("core.utils")

local function map(mode, lhs, rhs, desc, opts)
  opts = vim.tbl_extend("force", { desc = desc, silent = true }, opts or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end

-- Neovim 0.11 ships `grn`/`gra`/`grr`/`gri`/`grt` LSP defaults. This config maps
-- bare `gd`/`gr`/`gi` instead, and leaving both in place makes every `gr` wait
-- out 'timeoutlen' to see if a longer sequence follows.
for _, lhs in ipairs({ "grn", "gra", "grr", "gri", "grt" }) do
  pcall(vim.keymap.del, "n", lhs)
end
pcall(vim.keymap.del, "x", "gra")

-- Windows -------------------------------------------------------------------
map("n", "<C-h>", "<C-w>h", "Window: left")
map("n", "<C-j>", "<C-w>j", "Window: down")
map("n", "<C-k>", "<C-w>k", "Window: up")
map("n", "<C-l>", "<C-w>l", "Window: right")

-- Alt+hjkl does the same, and also works from a terminal buffer — <C-h> and
-- friends are what a shell or TUI running inside `:terminal` expects to receive
-- itself, so they cannot be stolen there.
map("n", "<A-h>", "<C-w>h", "Window: left")
map("n", "<A-j>", "<C-w>j", "Window: down")
map("n", "<A-k>", "<C-w>k", "Window: up")
map("n", "<A-l>", "<C-w>l", "Window: right")

map("t", "<A-h>", [[<C-\><C-n><C-w>h]], "Window: left")
map("t", "<A-j>", [[<C-\><C-n><C-w>j]], "Window: down")
map("t", "<A-k>", [[<C-\><C-n><C-w>k]], "Window: up")
map("t", "<A-l>", [[<C-\><C-n><C-w>l]], "Window: right")

map("n", "<C-Up>", "<cmd>resize +2<cr>", "Window: taller")
map("n", "<C-Down>", "<cmd>resize -2<cr>", "Window: shorter")
map("n", "<C-Left>", "<cmd>vertical resize -4<cr>", "Window: narrower")
map("n", "<C-Right>", "<cmd>vertical resize +4<cr>", "Window: wider")

map("n", "<leader>q", "<cmd>close<cr>", "Close window")

-- Buffers -------------------------------------------------------------------
local function close_buffer(force) utils.safe_bufdelete(vim.api.nvim_get_current_buf(), force) end

map("n", "<leader>bn", "<cmd>enew<cr>", "New buffer")
map("n", "<leader>bc", function() close_buffer(false) end, "Close buffer")
map("n", "<leader>bC", function() close_buffer(true) end, "Force close buffer")
map("n", "<leader>bo", function() utils.close_other_buffers(false) end, "Close other buffers")
map("n", "<leader>bO", function() utils.close_other_buffers(true) end, "Force close other buffers")

map("n", "<leader>bs", "<cmd>Telescope buffers<cr>", "Search buffers")

map("n", "]b", function() require("tabline").next() end, "Next buffer")
map("n", "[b", function() require("tabline").prev() end, "Previous buffer")

-- Leader, the other way round ------------------------------------------------
--
-- Space is still the leader and still runs every `<leader>x` sequence — it just
-- does it silently now, because which-key has no trigger left (see
-- plugins/which_key.lua). Tab is the only thing that opens the popup, and it
-- opens it *on* the leader tree, so the two keys reach the same mappings by
-- different routes: Space when you know the sequence, Tab when you don't.
--
-- `loop` keeps the popup up as you descend into a group instead of closing it
-- after the first key.
map(
  { "n", "v" },
  "<Tab>",
  function() require("which-key").show({ keys = "<leader>", loop = true }) end,
  "which-key (leader)"
)

-- The one thing that costs. A terminal sends the same byte for `<Tab>` and
-- `<C-i>`, so mapping one takes the other with it; jumplist-forward moves a
-- modifier over. (Inside a Telescope picker `<A-i>` is still the picker's own.)
map("n", "<A-i>", "<C-i>", "Jump forward (jumplist)")

-- Editing -------------------------------------------------------------------
map({ "n", "i", "v" }, "<C-s>", "<cmd>w<cr><esc>", "Save file")
map("n", "<Esc>", "<cmd>nohlsearch<cr>", "Clear search highlight")

-- Alt+Shift+hjkl reshapes the line or selection: j/k move it, h/l indent it.
-- Plain Alt+hjkl navigates windows (above), so the shifted pair keeps the same
-- mental model — same fingers, one modifier deeper to act on the text instead.
--
-- Written as <A-J> rather than <A-S-j>: terminals send the shifted key as its
-- uppercase form, and the <A-S-...> spelling does not match what arrives.
map("n", "<A-J>", "<cmd>m .+1<cr>==", "Move line down")
map("n", "<A-K>", "<cmd>m .-2<cr>==", "Move line up")
map("n", "<A-H>", "<<", "Indent line left")
map("n", "<A-L>", ">>", "Indent line right")

map("v", "<A-J>", ":m '>+1<cr>gv=gv", "Move selection down")
map("v", "<A-K>", ":m '<-2<cr>gv=gv", "Move selection up")
map("v", "<A-H>", "<gv", "Indent selection left")
map("v", "<A-L>", ">gv", "Indent selection right")

-- Stay in visual mode after shifting, so indenting is repeatable.
map("v", "<", "<gv", "Indent left")
map("v", ">", ">gv", "Indent right")

-- Leave terminal-insert from any terminal (Claude, toggleterm, lazygit...).
-- Alt, like the other terminal maps: Esc must reach the app untouched — Claude
-- uses Esc to interrupt and Esc Esc to rewind, and a <Esc><Esc> map here both
-- delayed the first by 'timeoutlen' and swallowed the second.
map("t", "<A-q>", [[<C-\><C-n>]], "Exit terminal mode")

-- Diagnostics ---------------------------------------------------------------
--
-- Global, not buffer-local on LspAttach. `vim.diagnostic` is a namespace, not an
-- LSP feature: nvim-lint publishes into it as well, so a file linted by
-- shellcheck or ruff with no language server behind it still has diagnostics to
-- jump between. Bound on attach, these keys quietly did not exist there while
-- which-key went on advertising them.
map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, "Previous diagnostic")
map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, "Next diagnostic")
map("n", "[e", function()
  vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.ERROR })
end, "Previous error")
map("n", "]e", function()
  vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR })
end, "Next error")

-- Grouped with the rest of the diagnostics UI under <leader>x* rather than
-- sitting alone on <leader>d.
map("n", "<leader>xd", vim.diagnostic.open_float, "Diagnostic: line float")

-- Workspace -----------------------------------------------------------------
map("n", "<leader>fo", function() require("core.workspace").open_dialog() end, "Open folder (workspace)")

-- UI toggles ----------------------------------------------------------------
map("n", "<leader>ub", function() require("core.transparency").toggle() end, "Toggle transparency")

map("n", "<leader>uw", function()
  vim.opt.wrap = not vim.o.wrap
  vim.notify("Wrap " .. (vim.o.wrap and "on" or "off"), vim.log.levels.INFO)
end, "Toggle line wrap")

map("n", "<leader>un", function()
  vim.opt.relativenumber = not vim.o.relativenumber
  vim.notify("Relative numbers " .. (vim.o.relativenumber and "on" or "off"), vim.log.levels.INFO)
end, "Toggle relative numbers")

map("n", "<leader>ud", function()
  local enabled = not vim.diagnostic.is_enabled()
  vim.diagnostic.enable(enabled)
  vim.notify("Diagnostics " .. (enabled and "on" or "off"), vim.log.levels.INFO)
end, "Toggle diagnostics")

-- Show the diagnostic under the cursor automatically after 'updatetime'. Off by
-- default — see the note in core/diagnostics.lua.
map("n", "<leader>uf", function() require("core.diagnostics").toggle_hover_float() end, "Toggle diagnostic float")

map("n", "<leader>uV", function()
  local shown = not vim.diagnostic.config().virtual_lines
  -- Virtual lines put the full message under the offending line, wrapped. Worth
  -- turning on for a Rust or TypeScript error that doesn't fit end-of-line.
  vim.diagnostic.config({ virtual_lines = shown and { current_line = true } or false })
  vim.notify("Diagnostic virtual lines " .. (shown and "on" or "off"), vim.log.levels.INFO)
end, "Toggle diagnostic virtual lines")

-- Cycles the dashboard between the Neovim-intro look and the classic logo
-- (see lua/plugins/alpha.lua); `:Dashboard intro|classic` picks one directly.
map("n", "<leader>ua", "<cmd>Dashboard<cr>", "Dashboard style picker")

-- Music (core/music.lua — Windows media session via PowerShell) --------------
local function music() return require("core.music") end

map("n", "<leader>mm", function() music().toggle_panel() end, "Music: toggle panel")
map("n", "<leader>mp", function() music().playpause() end, "Music: play/pause")
map("n", "<leader>mn", function() music().next() end, "Music: next track")
map("n", "<leader>mb", function() music().prev() end, "Music: previous track")
map("n", "<leader>mS", function() music().stop() end, "Music: stop")

-- One volume control, not three: it asks for the level you want. Nudging up and
-- down a step at a time is what the keyboard's own media keys are for.
map("n", "<leader>mv", function() music().set_volume_prompt() end, "Music: set volume")
