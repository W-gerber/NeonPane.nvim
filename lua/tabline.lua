-- Pill-style buffer tabline (editor-style "tabs").
--
-- Buffers are rendered as fully-rounded pills using glyph edges plus highlight
-- groups. Colors come from `core.ui`, so the bar follows the active theme.

local ui = require("core.ui")
local icons = require("core.icons")

local M = {
  state = { buffers = {} },
}

local defaults = {
  glyphs = {
    left = icons.ui.pill_left,
    right = icons.ui.pill_right,
    ellipsis = icons.ui.ellipsis,
    modified = icons.file.modified,
    folder = icons.file.folder,
    project = icons.ui.home,
  },
  max_name_len = 18,
  padding = 1, -- horizontal padding inside the main pill
  -- Inset from the screen edges. Matches the statusline's `spacer(2)`, which is
  -- what puts the first buffer pill in the same column as the mode pill.
  edge_padding = 2,
}

local function config() return M._config or defaults end

-- ---------------------------------------------------------------------------
-- Highlights
-- ---------------------------------------------------------------------------

local function setup_highlights()
  local p = ui.palette()
  local hl = vim.api.nvim_set_hl

  local active_bg = p.panel_soft
  local inactive_bg = p.panel
  local active_fg = ui.contrast(active_bg)
  local status_bg = p.panel

  -- Themes that declare `neon_glow` push the active pill's accent further, the
  -- terminal-safe stand-in for the original's bloom.
  if p.glow then
    active_fg = ui.contrast(active_bg, p.bg, p.glow_accent)
  end

  -- The bar itself is see-through; only the pills are painted.
  hl(0, "TabLine", { bg = "NONE", fg = p.muted })
  hl(0, "TabLineFill", { bg = "NONE", fg = p.muted })
  hl(0, "TabLineSel", { bg = "NONE", fg = p.fg })

  -- Active pill (edges sit on the transparent background, so they read round).
  hl(0, "TabLinePillActiveLeft", { fg = active_bg, bg = "NONE" })
  hl(0, "TabLinePillActiveText", { fg = active_fg, bg = active_bg, bold = true })
  hl(0, "TabLinePillActiveRight", { fg = active_bg, bg = "NONE" })
  hl(0, "TabLinePillActiveIndex", { fg = p.accent, bg = active_bg, bold = true })
  hl(0, "TabLinePillActiveMod", { fg = p.yellow, bg = active_bg, bold = true })

  -- Inactive pill: muted but still legible.
  hl(0, "TabLinePillInactiveLeft", { fg = inactive_bg, bg = "NONE" })
  hl(0, "TabLinePillInactiveText", { fg = p.muted, bg = inactive_bg })
  hl(0, "TabLinePillInactiveRight", { fg = inactive_bg, bg = "NONE" })
  hl(0, "TabLinePillInactiveIndex", { fg = ui.blend(p.accent, p.muted, 0.5), bg = inactive_bg })
  hl(0, "TabLinePillInactiveMod", { fg = p.orange, bg = inactive_bg })

  -- Right-hand utility pills mirror the statusline's segmented look.
  hl(0, "TabLinePillStatusLeft", { fg = status_bg, bg = "NONE" })
  hl(0, "TabLinePillStatusText", { fg = ui.contrast(status_bg), bg = status_bg, bold = true })
  hl(0, "TabLinePillStatusRight", { fg = status_bg, bg = "NONE" })

  -- Now playing, as a run inside the status pill: same background, so only the
  -- foreground says whether anything is playing. Idle recedes to muted; playing
  -- takes the green and bold. The divider is dimmer than either.
  hl(0, "TabLinePillStatusMusic", { fg = p.muted, bg = status_bg })
  hl(0, "TabLinePillStatusMusicPlaying", { fg = p.green, bg = status_bg, bold = true })
  hl(0, "TabLinePillStatusSep", { fg = ui.blend(p.muted, status_bg, 0.5), bg = status_bg })
end

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------

--- Shorten a filename, keeping its extension visible.
---
--- Measured and cut in characters rather than bytes. `#name` counts bytes, so
--- a name with an accent, an emoji or any CJK in it was both judged too long
--- too early and then sliced part-way through a codepoint — which reaches the
--- tabline as a replacement glyph.
---@param name string
---@param max_len integer
---@param ellipsis string
---@return string
local function truncate_name(name, max_len, ellipsis)
  if vim.fn.strdisplaywidth(name) <= max_len then
    return name
  end

  local base, ext = name:match("^(.+)%.([^%.]+)$")
  if base and ext then
    local room = max_len - vim.fn.strdisplaywidth(ext) - 2
    if room > 0 then
      return vim.fn.strcharpart(base, 0, room) .. ellipsis .. "." .. ext
    end
  end

  return vim.fn.strcharpart(name, 0, max_len - 1) .. ellipsis
end

local function pill_segment(left_hl, text_hl, right_hl, left_glyph, right_glyph, text)
  return string.format("%%#%s#%s%%#%s#%s%%#%s#%s", left_hl, left_glyph, text_hl, text, right_hl, right_glyph)
end

local function file_icon(name)
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if not ok then
    return ""
  end

  local icon = devicons.get_icon(name, name:match("%.([^.]+)$"), { default = true })
  return type(icon) == "string" and icon or ""
end

--- One buffer, as a rounded pill: `1  init.lua ●`.
---
--- The index used to be a pill of its own nested inside this one, which put two
--- sets of rounded caps and three background shades into a chip the width of a
--- filename. It is now just the leading glyph run, tinted rather than boxed:
--- the information is identical and there is one shape instead of two.
---
--- Order is index, icon, name, modified — fixed, so the eye can land on the
--- same spot in every pill rather than hunting for a marker whose position
--- depends on how long the name is.
local function buffer_pill(cfg, bufnr, index, is_current)
  local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
  if name == "" then
    name = "[No Name]"
  end

  local icon = file_icon(name)
  if icon ~= "" then
    icon = icon .. " "
  end
  name = truncate_name(name, cfg.max_name_len, cfg.glyphs.ellipsis)

  local modified = vim.bo[bufnr].modified
  local pad = string.rep(" ", cfg.padding)
  local prefix = is_current and "TabLinePillActive" or "TabLinePillInactive"

  -- A dot, and only when dirty. The slot is not reserved: a column of mostly
  -- blank space between every name and the pill's edge reads as a rendering
  -- fault rather than as an absent marker.
  local modified_mark = modified and string.format("%%#%sMod# %s", prefix, cfg.glyphs.modified) or ""

  local text = string.format("%%#%sIndex#", prefix)
    .. pad
    .. tostring(index)
    .. "  "
    .. string.format("%%#%sText#", prefix)
    .. icon
    .. name
    .. modified_mark
    .. string.format("%%#%sText#", prefix)
    .. pad

  -- `%<n>@fn@ ... %X` makes the pill clickable (left = focus, middle = close).
  return string.format("%%%d@v:lua.TablineOnClick@", bufnr)
    .. pill_segment(
      prefix .. "Left",
      prefix .. "Text",
      prefix .. "Right",
      cfg.glyphs.left,
      cfg.glyphs.right,
      text
    )
    .. "%X"
end

--- Now playing, as a run of text *inside* the workspace pill.
---
--- Not a pill of its own: two adjacent chips with two sets of rounded caps for
--- what is really one status readout made the right-hand end of the bar busier
--- the moment anything started playing. This returns bare text on the
--- workspace pill's own background, so the pill simply grows to hold it and
--- the shape of the bar never changes.
---@return string
local function music_run()
  local ok, music = pcall(require, "core.music")
  if not ok then
    return ""
  end

  local ok_text, text = pcall(music.statusline)
  if not ok_text or type(text) ~= "string" or text == "" then
    return ""
  end

  local status = nil
  if type(music.statusline_status) == "function" then
    local ok_status, value = pcall(music.statusline_status)
    status = ok_status and value or nil
  end

  -- Playing is lit; paused and stopped recede. Both sit on the status pill's
  -- background so the run reads as part of it rather than as an inlay.
  local group = status == "Playing" and "TabLinePillStatusMusicPlaying" or "TabLinePillStatusMusic"

  return string.format("%%#%s#%s  %%#TabLinePillStatusSep#%s  ", group, text, icons.ui.separator)
end

local function status_pills(cfg)
  local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
  local filetype = vim.bo.filetype
  local status_icon = filetype == "alpha" and cfg.glyphs.project or cfg.glyphs.folder

  -- One pill holding everything on the right: now playing (when there is any),
  -- then a thin divider, then the workspace icon and name.
  return pill_segment(
    "TabLinePillStatusLeft",
    "TabLinePillStatusText",
    "TabLinePillStatusRight",
    cfg.glyphs.left,
    cfg.glyphs.right,
    " " .. music_run() .. "%#TabLinePillStatusText#" .. status_icon .. " " .. cwd .. " "
  )
end

--- Handles clicks on a buffer pill (see the `%@` item above).
---@param bufnr integer
---@param _clicks integer
---@param button string "l", "m" or "r"
function _G.TablineOnClick(bufnr, _clicks, button)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  if button == "m" then
    require("core.utils").safe_bufdelete(bufnr, false)
  else
    vim.api.nvim_set_current_buf(bufnr)
  end
end

function _G.CustomBufferTabline()
  local cfg = config()
  local current = vim.api.nvim_get_current_buf()

  local buffers = vim.tbl_filter(
    function(buf) return vim.bo[buf].buflisted and vim.api.nvim_buf_is_loaded(buf) end,
    vim.api.nvim_list_bufs()
  )

  -- Stable ordering for <A-1>..<A-9> and <C-Tab>.
  M.state.buffers = buffers

  -- Both ends are inset by the same amount the statusline uses (its lualine_a
  -- and lualine_z are each a `spacer(2)`), so the first buffer pill starts in
  -- the same column as the NORMAL/INSERT mode pill below it and the workspace
  -- pill ends in the same column as the one at the far right. Without this the
  -- tabline sits flush against the edge while the statusline floats, and the
  -- two bars read as belonging to different UIs.
  local parts = { "%#TabLineFill#" .. string.rep(" ", cfg.edge_padding) }

  for index, bufnr in ipairs(buffers) do
    parts[#parts + 1] = buffer_pill(cfg, bufnr, index, bufnr == current)
    parts[#parts + 1] = "%#TabLineFill# "
  end

  parts[#parts + 1] = "%#TabLineFill#%="
  parts[#parts + 1] = status_pills(cfg)
  parts[#parts + 1] = "%#TabLineFill#" .. string.rep(" ", cfg.edge_padding)

  return table.concat(parts)
end

-- ---------------------------------------------------------------------------
-- Navigation
-- ---------------------------------------------------------------------------

local function current_index()
  local current = vim.api.nvim_get_current_buf()
  for index, buf in ipairs(M.state.buffers or {}) do
    if buf == current then
      return index
    end
  end
end

function M.go_to(index)
  local buf = (M.state.buffers or {})[index]
  if buf and vim.api.nvim_buf_is_loaded(buf) then
    vim.api.nvim_set_current_buf(buf)
  end
end

function M.next()
  local count = #(M.state.buffers or {})
  if count == 0 then
    return
  end

  M.go_to(((current_index() or 1) % count) + 1)
end

function M.prev()
  local count = #(M.state.buffers or {})
  if count == 0 then
    return
  end

  local index = (current_index() or 1) - 1
  M.go_to(index < 1 and count or index)
end

-- ---------------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------------

local function close_current(force)
  require("core.utils").safe_bufdelete(vim.api.nvim_get_current_buf(), force)
end

function M.setup(opts)
  M._config = vim.tbl_deep_extend("force", {}, defaults, opts or {})

  setup_highlights()
  vim.o.showtabline = 2
  vim.o.tabline = "%!v:lua.CustomBufferTabline()"

  local function map(lhs, rhs, desc) vim.keymap.set("n", lhs, rhs, { desc = desc, silent = true }) end

  map("<C-Tab>", M.next, "Next tab")
  map("<C-S-Tab>", M.prev, "Previous tab")
  map("<C-t>", "<cmd>enew<cr>", "New tab (buffer)")
  map("<A-w>", function() close_current(false) end, "Close tab (buffer)")
  map("<C-S-w>", function() close_current(false) end, "Close tab (buffer)")
  map(
    "<A-S-w>",
    function() require("core.utils").close_other_buffers(false) end,
    "Close other tabs"
  )

  for index = 1, 9 do
    map("<A-" .. index .. ">", function() M.go_to(index) end, "Go to tab " .. index)
  end

  local group = ui.create_augroup("CustomTabline")
  vim.api.nvim_create_autocmd({ "BufEnter", "BufDelete", "BufWipeout", "BufModifiedSet", "TabEnter" }, {
    group = group,
    callback = function() vim.cmd("redrawtabline") end,
  })

  ui.on_theme_change(group, function()
    setup_highlights()
    vim.cmd("redrawtabline")
  end)

  -- The now-playing pill is the one part of this bar that changes without a
  -- buffer event to announce it, so it needs a tick of its own.
  --
  -- 5s is cheap: the tick only rebuilds a string. It does not talk to Windows —
  -- `music.statusline()` rate-limits its own PowerShell polling to between 10s
  -- and 60s depending on whether anything is playing, and this only reads the
  -- cache that fills. Redrawing only when the rendered text actually changed
  -- keeps an idle editor from repainting the tabline every five seconds.
  if vim.fn.has("win32") == 1 then
    local last = nil

    M._music_timer = vim.uv.new_timer()
    M._music_timer:start(
      5000,
      5000,
      vim.schedule_wrap(function()
        local ok, music = pcall(require, "core.music")
        local text = ok and select(2, pcall(music.statusline)) or ""

        if text ~= last then
          last = text
          vim.cmd("redrawtabline")
        end
      end)
    )

    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = group,
      callback = function()
        if M._music_timer then
          pcall(function()
            M._music_timer:stop()
            M._music_timer:close()
          end)
          M._music_timer = nil
        end
      end,
    })
  end
end

return M
