-- Dashboard (alpha-nvim), in three switchable styles:
--
--   intro     a faithful copy of Neovim's own startup screen — same logo, same
--             lines, same highlight rules, so it reads like `nvim --clean`
--   classic   the block-letter logo this config used before, above the action
--             buttons (find file, recent files, sessions, ...)
--   startify  vim-startify's layout: a boxed fortune and a cow above
--             left-aligned lists of recent files, sessions and bookmarks, each
--             row prefixed with the key that opens it
--
-- `:Dashboard <style>` switches directly; `:Dashboard` with no argument (and
-- <leader>ua) opens a picker. The choice is persisted in core.state, next to
-- the theme and glass settings.

local DEFAULT_STYLE = "intro"
local STYLES = { "intro", "classic", "startify" }

-- ---------------------------------------------------------------------------
-- Style "intro": Neovim's own startup screen
-- ---------------------------------------------------------------------------
--
-- Transcribed from `intro_message()` in src/nvim/version.c. Neovim paints that
-- screen straight onto the grid rather than into a buffer, so there is nothing
-- for alpha to reuse — the lines and their highlights have to be rebuilt here.

local INTRO_LOGO = {
  "│ ╲ ││",
  "││╲╲││",
  "││ ╲ │",
}

-- Every non-logo line in the real intro is 44 columns wide at most, and the
-- rules are exactly that wide.
local INTRO_RULE = string.rep("─", 44)

-- Named groups rather than direct links so a theme can restyle the intro on its
-- own; `apply_highlights()` links them to the groups Neovim itself uses.
local INTRO_HL = {
  logo = "AlphaIntroLogo", -- up to the diagonal
  logo_alt = "AlphaIntroLogoAlt", -- from the diagonal on
  version = "AlphaIntroVersion",
  rule = "AlphaIntroRule",
  key = "AlphaIntroKey", -- ":" and "<Enter>"
  command = "AlphaIntroCommand",
}

--- The version string Neovim prints in its intro (`NVIM_VERSION_LONG`).
---
--- Taken from `:version` itself, whose first line *is* that string — building
--- it from `vim.version()` would drop the "-dev" suffix on nightly builds.
---@return string
local function version_line()
  local ok, result = pcall(vim.api.nvim_exec2, "version", { output = true })
  local first = ok and type(result.output) == "string" and result.output:match("^[^\r\n]+")

  if first and vim.startswith(first, "NVIM") then
    return first
  end

  local v = vim.version()
  return string.format("NVIM v%d.%d.%d", v.major, v.minor, v.patch)
end

-- Neovim's intro ends with a fixed two-line appeal for Kuwasha. Rotating it
-- keeps that slot worth reading: charities Vim and Neovim have pointed at,
-- plus lines worth seeing at the start of a session.
--
-- Every entry is exactly two lines so the block's height never jitters, and
-- each stays within the 44 columns the rules are wide so the centering does
-- not shift either.
local APPEALS = {
  { "Help poor children in Uganda!", "type  :help Kuwasha<Enter>  for information " },
  { "Vim's charity: a children's home in Kibaale", "iccf-holland.org" },
  { "Neovim runs on donations, not on ads.", "github.com/sponsors/neovim" },
  { "A mosquito net costs about two dollars.", "againstmalaria.com" },
  { "Cash, straight to people who need it.", "givedirectly.org" },
  { "Deworming: pennies per child, per year.", "evidenceaction.org" },
  { "Clean water is the cheapest medicine.", "givewell.org" },
  { "Give blood. One hour, up to three lives.", "Someone's week depends on it." },

  { "Make it work, then make it right.", "-- Kent Beck" },
  { "Talk is cheap. Show me the code.", "-- Linus Torvalds" },
  { "Simplicity is a prerequisite for", "reliability.  -- Dijkstra" },
  { "Premature optimization is the root of all", "evil.  -- Knuth" },
  { "First, solve the problem. Then write code.", "-- John Johnson" },
  { "Perfection is achieved when there is", "nothing left to take away." },
  { "The best code is the code never written.", "Delete something today." },
  { "Weeks of coding save hours of planning.", "-- every codebase, eventually" },
  { "You are not stuck, you are gathering data.", "Read the error message again." },
  { "Slow is smooth. Smooth is fast.", "Ship the small thing." },
}

local last_appeal = nil

--- A random appeal, never the one from the previous draw.
---
--- Safe to call without seeding here: `math.randomseed` runs once further down
--- at module load, and nothing draws the dashboard before that.
---@return string[]
local function appeal()
  local index = math.random(#APPEALS)
  while #APPEALS > 1 and index == last_appeal do
    index = math.random(#APPEALS)
  end

  last_appeal = index
  return APPEALS[index]
end

--- The intro screen's lines, in order.
---@return string[]
local function intro_lines()
  local v = vim.version()

  local lines = vim.list_extend({}, INTRO_LOGO)

  vim.list_extend(lines, {
    "",
    version_line(),
    INTRO_RULE,
    "Nvim is open source and freely distributable",
    "https://neovim.io/#chat",
    INTRO_RULE,
    "type  :help nvim<Enter>     if you are new! ",
    "type  :checkhealth<Enter>   to optimize Nvim",
    "type  :q<Enter>             to exit         ",
    "type  :help<Enter>          for help        ",
    INTRO_RULE,
  })

  -- Appeal above the news line, swapping the two blocks Neovim ships in the
  -- other order; the rules stay put, so the screen still ends on a text line
  -- rather than a dangling divider.
  vim.list_extend(lines, appeal())

  return vim.list_extend(lines, {
    INTRO_RULE,
    string.format("type  :help news<Enter>     for v%d.%d notes ", v.major, v.minor),
  })
end

--- Highlight spans for one intro line, as `{ group, start_byte, end_byte }`.
---
--- Mirrors `do_intro_line()`: the logo's box-drawing characters switch color at
--- the "╲" diagonal, the version line and the rules are highlighted whole, and
--- in the "type ..." lines the `:`, the command name and the `<key>` each get
--- their own color while the prose stays Normal.
---@param line string un-padded
---@param is_logo boolean
---@return table[]
local function intro_spans(line, is_logo)
  local spans = {}

  if is_logo then
    -- Only the multi-byte characters are highlighted; the ASCII spacers keep
    -- the background, which is what makes the strokes read as separate.
    local past_diagonal = false
    local col = 0

    for char in line:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
      if #char > 1 then
        past_diagonal = past_diagonal or char == "╲"
        spans[#spans + 1] = { past_diagonal and INTRO_HL.logo_alt or INTRO_HL.logo, col, col + #char }
      end
      col = col + #char
    end

    return spans
  end

  if vim.startswith(line, "NVIM") then
    return { { INTRO_HL.version, 0, #line } }
  end

  if vim.startswith(line, "─") then
    return { { INTRO_HL.rule, 0, #line } }
  end

  local pos = 1
  while pos <= #line do
    if line:sub(pos, pos) == "<" then
      local close = line:find(">", pos, true) or #line
      spans[#spans + 1] = { INTRO_HL.key, pos - 1, close }
      pos = close + 1
    else
      -- Text run up to the next `<key>`. A colon inside it only counts as a
      -- command prompt when such a key follows, so "https://neovim.io" stays
      -- plain.
      local next_key = line:find("<", pos, true)
      local stop = (next_key or #line + 1) - 1
      local colon = line:find(":", pos, true)

      if next_key and colon and colon <= stop then
        spans[#spans + 1] = { INTRO_HL.key, colon - 1, colon }
        spans[#spans + 1] = { INTRO_HL.command, colon, stop }
      end

      pos = stop + 1
    end
  end

  return spans
end

--- The intro screen as an alpha text element.
---
--- alpha centers a text block by its longest line, which would left-align
--- everything shorter; Neovim centers each line on its own. Padding every line
--- into a field as wide as the widest one reproduces that, at the cost of
--- having to shift the highlight columns by the same amount.
---@return table
local function intro_element()
  local lines = intro_lines()

  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end

  local text, highlights = {}, {}

  for index, line in ipairs(lines) do
    local offset = math.max(math.floor((width - vim.fn.strdisplaywidth(line)) / 2), 0)
    local spans = intro_spans(line, index <= #INTRO_LOGO)

    for _, span in ipairs(spans) do
      span[2] = span[2] + offset
      span[3] = span[3] + offset
    end

    text[index] = string.rep(" ", offset) .. line
    highlights[index] = spans
  end

  -- alpha decides between "one highlight list" and "one per line" by looking at
  -- the first entry, so the first line has to carry at least one span — the
  -- logo always does.
  return { type = "text", val = text, opts = { position = "center", hl = highlights } }
end

-- ---------------------------------------------------------------------------
-- Style "classic": block logo + action buttons
-- ---------------------------------------------------------------------------
--
-- The rows are deliberately ragged, so each one is highlighted across its own
-- length (in bytes — every block is three of them) instead of to a fixed
-- column. That is what the gradient below needs, and it cannot run off the end
-- of a line the way a hard-coded width table can.

local CLASSIC_LOGO = {
      "                                          ",
      "       ███████████           █████      ██",
      "      ███████████             █████ ",
      "      ████████████████ ███████████ ███   ███████",
      "     ████████████████ ████████████ █████ ██████████████",
      "    █████████████████████████████ █████ █████ ████ █████",
      "  ██████████████████████████████████ █████ █████ ████ █████",
      " ██████  ███ █████████████████ ████ █████ █████ ████ ██████",
      " ██████   ██  ███████████████   ██ █████████████████",
    }

-- ---------------------------------------------------------------------------
-- Style "startify": quote box, cow, and lists of things to open
-- ---------------------------------------------------------------------------
--
-- Modelled on vim-startify: a boxed fortune above a cow, then left-aligned
-- sections of recent files, sessions and bookmarks, each row prefixed with the
-- key that opens it. Unlike the other two styles this one is *data* — the rows
-- are whatever is in `v:oldfiles` and the session store right now — so the
-- layout is rebuilt every time it is drawn rather than being a constant.

local FORTUNES = {
  { "Almost every programming language is overrated by", "its practitioners.", "", "- Larry Wall" },
  { "Controlling complexity is the essence of computer", "programming.", "", "- Brian Kernighan" },
  { "Simplicity is prerequisite for reliability.", "", "- Edsger W. Dijkstra" },
  {
    "Programs must be written for people to read, and",
    "only incidentally for machines to execute.",
    "",
    "- Harold Abelson",
  },
  {
    "The most damaging phrase in the language is:",
    "'We've always done it this way.'",
    "",
    "- Grace Hopper",
  },
  { "Premature optimization is the root of all evil.", "", "- Donald Knuth" },
  { "Talk is cheap. Show me the code.", "", "- Linus Torvalds" },
}

local COW = {
  "        o",
  "     o",
  "   o   ^__^",
  "    (oo)\\_______",
  "    (__)\\       )\\/\\",
  "        ||----w |",
  "        ||     ||",
}

--- Wrap the chosen fortune in a box, sized to its widest line.
---@param lines string[]
---@return string[]
local function box(lines)
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end

  local out = { "\u{256d}" .. string.rep("\u{2500}", width + 2) .. "\u{256e}" }
  for _, line in ipairs(lines) do
    local pad = width - vim.fn.strdisplaywidth(line)
    out[#out + 1] = "\u{2502} " .. line .. string.rep(" ", pad) .. " \u{2502}"
  end
  out[#out + 1] = "\u{2570}" .. string.rep("\u{2500}", width + 2) .. "\u{256f}"

  return out
end

-- A fresh quote on every draw, never the same one twice running.
--
-- `math.randomseed` is called once here rather than per pick: LuaJIT's
-- generator returns the same first value for the same seed, and seeding from
-- the clock on each call would hand back an identical quote for every draw
-- inside the same second.
math.randomseed(os.time())

local last_fortune = nil

--- A random fortune, excluding the one currently on screen.
---@return string[]
local function fortune()
  if #FORTUNES < 2 then
    return FORTUNES[1]
  end

  local index = math.random(#FORTUNES)
  while index == last_fortune do
    index = math.random(#FORTUNES)
  end

  last_fortune = index
  return FORTUNES[index]
end

return {
  "goolord/alpha-nvim",
  event = "VimEnter",
  config = function()
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.dashboard")
    local ui = require("core.ui")
    local state = require("core.state")
    local utils = require("core.utils")

    local logo_groups = {}
    for index = 1, #CLASSIC_LOGO do
      logo_groups[index] = "AlphaLogo" .. index
    end

    -- One highlight per row, spanning the whole row.
    local function logo_highlights()
      local highlights = {}
      for index, line in ipairs(CLASSIC_LOGO) do
        highlights[index] = { { logo_groups[index], 0, #line } }
      end
      return highlights
    end

    -- The logo fades from the theme's accent toward its secondary glow, so the
    -- dashboard picks up whatever theme is active instead of being a fixed
    -- gradient that clashes with everything but one palette.
    local function apply_highlights()
      local p = ui.palette()
      local hl = vim.api.nvim_set_hl
      local steps = math.max(#logo_groups - 1, 1)

      for index, group in ipairs(logo_groups) do
        local depth = (index - 1) / steps
        hl(0, group, {
          fg = ui.blend(p.accent, p.glow_secondary or p.accent, 1 - depth),
          bold = p.glow,
        })
      end

      hl(0, "AlphaButtons", { fg = p.fg })
      hl(0, "AlphaShortcut", { fg = p.accent, bold = true })
      hl(0, "AlphaHeader", { fg = p.accent })
      hl(0, "AlphaFooter", { fg = p.muted, italic = true })

      -- startify style.
      --
      -- Four hues (green box, green cow, purple headings, yellow keys) was one
      -- palette too many for a screen that is mostly a list of file paths: the
      -- decoration ended up louder than the content. This is the same ordering
      -- the rest of this config uses — accent marks structure, muted carries
      -- anything secondary, and full-strength foreground is reserved for the
      -- thing you actually came to read, which here is the filename.
      hl(0, "AlphaStartifyQuote", { fg = ui.blend(p.accent, p.bg, 0.55), italic = true })
      hl(0, "AlphaStartifyCow", { fg = ui.blend(p.muted, p.bg, 0.75) })
      hl(0, "AlphaStartifyHeader", { fg = p.accent, bold = true })
      hl(0, "AlphaStartifyKey", { fg = ui.blend(p.accent, p.muted, 0.55) })
      hl(0, "AlphaStartifyPath", { fg = ui.blend(p.muted, p.bg, 0.85) })
      hl(0, "AlphaStartifyFile", { fg = p.fg })

      -- The intro style borrows the groups Neovim highlights its own intro
      -- with, which is what keeps it recognizable under every theme. `:colorscheme`
      -- clears links, hence re-linking on each theme change.
      for group, target in pairs({
        [INTRO_HL.logo] = "Special",
        [INTRO_HL.logo_alt] = "String",
        [INTRO_HL.version] = "String",
        [INTRO_HL.rule] = "NonText",
        [INTRO_HL.key] = "SpecialKey",
        [INTRO_HL.command] = "Identifier",
      }) do
        hl(0, group, { link = target })
      end
    end

    --- One dashboard row: shortcut, icon, label, and the command it runs.
    ---@param shortcut string
    ---@param icon string
    ---@param label string
    ---@param command string|function
    local function button(shortcut, icon, label, command)
      local entry = dashboard.button(shortcut, icon .. "  " .. label, command)

      -- alpha's stock <CR> handler replays the command as keystrokes, which
      -- only works for strings and throws on the callbacks below. Running it
      -- directly makes Enter behave like the shortcut key.
      entry.on_press = function()
        if type(command) == "function" then
          command()
        else
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(command, true, false, true), "t", false)
        end
      end

      entry.opts.hl = "AlphaButtons"
      entry.opts.hl_shortcut = "AlphaShortcut"
      return entry
    end

    -- Alpha's buttons take a command string or a callback; using callbacks
    -- directly keeps these out of the global namespace, which is where they
    -- previously had to live as `_G._alpha_*` to be reachable from `:lua`.
    local function open_recent_files()
      require("telescope.builtin").oldfiles({ prompt_title = "Recent Files" })
    end

    local function find_files_in_root()
      local workspace = require("core.workspace")
      require("telescope.builtin").find_files({
        cwd = workspace.root(),
        hidden = true,
        no_ignore = true,
        prompt_title = "Find Files \u{2022} " .. workspace.label(),
      })
    end

    local header = {
      type = "text",
      val = CLASSIC_LOGO,
      opts = { position = "center", hl = logo_highlights() },
    }

    local buttons = {
      type = "group",
      val = {
        button("f", "\u{f0e1e}", "Find File", find_files_in_root),
        button("r", "\u{f0954}", "Recent Files", open_recent_files),
        button("g", "\u{f002c}", "Grep", function()
          local workspace = require("core.workspace")
          require("telescope.builtin").live_grep({
            cwd = workspace.root(),
            prompt_title = "Grep \u{2022} " .. workspace.label(),
          })
        end),
        button("e", "\u{f0224}", "New File", "<cmd>ene | startinsert<cr>"),
        { type = "padding", val = 1 },
        button("o", "\u{f0770}", "Open Folder", function() require("core.workspace").open_dialog() end),
        button(
          "d",
          "\u{f0184}",
          utils.desktop_label,
          function() require("core.workspace").open(utils.desktop) end
        ),
        button(
          "x",
          "\u{f04ce}",
          utils.everything_label,
          function() require("core.workspace").open(utils.everything) end
        ),
        button("s", "\u{f09db}", "Restore Session", "<cmd>SessionManager load_session<cr>"),
        { type = "padding", val = 1 },
        button("c", "\u{f0493}", "Configuration", "<cmd>edit $MYVIMRC | cd %:p:h<cr>"),
        button("l", "\u{f0cb2}", "Plugins", "<cmd>Lazy<cr>"),
        button("h", "\u{f02fc}", "Health", "<cmd>checkhealth<cr>"),
        button("q", "\u{f0a48}", "Quit", "<cmd>qa<cr>"),
      },
      opts = { spacing = 1, position = "center" },
    }

    -- Filled in once lazy.nvim knows its own startup time. The intro style
    -- leaves it out: the whole point of that one is to look untouched.
    local footer = { type = "text", val = "", opts = { position = "center", hl = "AlphaFooter" } }

    -- -- startify ------------------------------------------------------------

    -- Headings sit at the outer edge and their rows step in from it, so the
    -- shape of the page is readable before any of the text is.
    local STARTIFY_INDENT = "  "
    local STARTIFY_ROW_INDENT = "     "

    --- Fit a path into `width` columns, cutting from the *left*.
    ---
    --- The tail is the part that identifies a file; the head is boilerplate
    --- shared by everything under the same tree. Truncating the other way
    --- around would leave a column of identical prefixes.
    ---@param path string
    ---@param width integer
    ---@return string
    local function fit_path(path, width)
      if vim.fn.strdisplaywidth(path) <= width then
        return path
      end

      local ellipsis = "\u{2026}"
      local chars = vim.fn.strchars(path)
      local keep = width - 1

      while keep > 0 do
        local tail = vim.fn.strcharpart(path, chars - keep, keep)
        -- Prefer cutting at a separator, so the result is still a path.
        local aligned = tail:match("^[^/]*/(.*)$") or tail
        if vim.fn.strdisplaywidth(ellipsis .. aligned) <= width then
          return ellipsis .. aligned
        end
        keep = keep - 1
      end

      return ellipsis
    end

    --- A block of text, padded to `width` and centred as a unit.
    ---
    --- alpha centres each element by its *own* width, which would centre the
    --- quote box, the cow and every row independently and leave the page
    --- ragged. Padding every line to one shared width first means they all
    --- centre to the same left edge, so the block moves as one and stays
    --- left-aligned inside itself.
    ---@param text string|string[]
    ---@param hl string
    ---@param width integer
    ---@return table
    local function startify_text(text, hl, width)
      local lines = type(text) == "table" and text or { text }
      local padded = {}

      for index, line in ipairs(lines) do
        local pad = math.max(0, width - vim.fn.strdisplaywidth(line))
        padded[index] = line .. string.rep(" ", pad)
      end

      return { type = "text", val = padded, opts = { position = "center", hl = hl } }
    end

    --- A section heading ("MRU", "Sessions", ...).
    ---@param label string
    ---@param width integer
    ---@return table
    local function startify_header(label, width)
      return startify_text(STARTIFY_INDENT .. label, "AlphaStartifyHeader", width)
    end

    --- One openable row: `[key] dir/filename`.
    ---
    --- The directory is dimmed and the filename is not, which is what makes a
    --- long list of paths scannable — the part that differs is the part that
    --- stands out. Highlights are per-byte ranges, so the split is measured on
    --- the encoded string rather than on display columns.
    ---@param key string
    ---@param display string text after the key
    ---@param split integer byte offset where the dimmed prefix ends
    ---@param action fun()
    ---@return table
    local function startify_entry(key, display, split, action, width)
      local prefix = STARTIFY_ROW_INDENT .. "[" .. key .. "] "
      local entry = dashboard.button(key, prefix .. display, action)

      entry.on_press = action
      entry.opts.position = "center"
      entry.opts.shortcut = ""
      entry.opts.cursor = 0
      entry.opts.align_shortcut = "left"
      entry.opts.hl_shortcut = "AlphaStartifyKey"
      -- Every row is padded to the same block width before being centred, so
      -- the rows share one left edge instead of each centring on its own
      -- length. (alpha's own default here is a flat `width = 50`, which both
      -- trails whitespace past short rows and truncates long ones.)
      entry.opts.width = width

      -- `[n]` is coloured as the key; then the dimmed directory; then the name.
      local key_start = #STARTIFY_ROW_INDENT
      local text_start = #prefix

      entry.opts.hl = {
        { "AlphaStartifyKey", key_start, text_start },
        { "AlphaStartifyPath", text_start, text_start + split },
        { "AlphaStartifyFile", text_start + split, #prefix + #display },
      }

      return entry
    end

    --- Split a path into (dimmed directory, filename) for `startify_entry`.
    ---@param path string
    ---@param relative_to? string
    ---@return string display, integer split
    --- `C:/Users/you/x` as `~/x`.
    ---
    --- `fnamemodify(path, ":~")` is the usual way and it does nothing here: it
    --- resolves the tilde against `$HOME`, which Windows does not set. Hence
    --- matching `core.utils.home` (USERPROFILE, then HOME, then uv) directly.
    ---@param path string
    ---@return string
    local function tildify(path)
      local home = utils.home and vim.fs.normalize(utils.home):gsub("[\\/]+$", "") or nil
      local normalized = vim.fs.normalize(path)

      if home and home ~= "" and normalized:sub(1, #home + 1):lower() == (home .. "/"):lower() then
        return "~/" .. normalized:sub(#home + 2)
      end

      return normalized
    end

    local function path_parts(path, relative_to)
      local shown = path
      if relative_to and relative_to ~= "" then
        local prefix = relative_to:gsub("[\\/]+$", "") .. "/"
        local normalized = vim.fs.normalize(path)
        if normalized:sub(1, #prefix):lower() == prefix:lower() then
          shown = normalized:sub(#prefix + 1)
        else
          shown = tildify(path)
        end
      else
        shown = tildify(path)
      end

      -- Deliberately *not* re-normalized here: `vim.fs.normalize` expands a
      -- leading "~" back to the full home path, which would undo `tildify`
      -- immediately above. Both branches already produce a normalized string.
      shown = fit_path(shown, 58)
      local name = shown:match("([^/]+)$") or shown

      return shown, #shown - #name
    end

    --- Readable files from `v:oldfiles`, newest first, de-duplicated.
    ---@param limit integer
    ---@param within? string only files under this directory
    ---@return string[]
    local function recent_files(limit, within)
      local seen, out = {}, {}
      local prefix = within and (vim.fs.normalize(within):gsub("[\\/]+$", "") .. "/"):lower() or nil

      for _, path in ipairs(vim.v.oldfiles or {}) do
        if #out >= limit then
          break
        end

        local normalized = vim.fs.normalize(path)
        local key = normalized:lower()

        if
          not seen[key]
          and vim.fn.filereadable(path) == 1
          and (not prefix or key:sub(1, #prefix) == prefix)
        then
          seen[key] = true
          out[#out + 1] = path
        end
      end

      return out
    end

    --- Saved sessions, newest first. Empty when session_manager is absent.
    ---
    --- `silent` matters: `get_sessions()` notifies when it finds nothing, and
    --- building a dashboard is not a moment to tell someone they have no
    --- sessions — the section simply does not appear.
    ---@return { filename: string, label: string }[]
    local function saved_sessions()
      local ok, sessions = pcall(
        function() return require("session_manager.utils").get_sessions({ silent = true }) end
      )
      if not ok or type(sessions) ~= "table" then
        return {}
      end

      local out = {}
      for _, session in ipairs(sessions) do
        -- `dir` is a plenary Path; `filename` is what `load_session` wants.
        local path = tostring(session.dir or "")
        if path ~= "" and session.filename then
          out[#out + 1] = { filename = session.filename, label = vim.fn.fnamemodify(path, ":t") }
        end
      end

      return out
    end

    local BOOKMARK_KEYS = { "c", "p", "d", "x" }

    --- Fixed destinations, always in the same place so they can be muscle memory.
    ---@return { key: string, label: string, action: fun() }[]
    local function bookmarks()
      local workspace = require("core.workspace")

      return {
        {
          key = BOOKMARK_KEYS[1],
          label = "config",
          action = function() vim.cmd("edit $MYVIMRC | cd %:p:h") end,
        },
        { key = BOOKMARK_KEYS[2], label = "plugins", action = function() vim.cmd("Lazy") end },
        {
          key = BOOKMARK_KEYS[3],
          label = utils.desktop_label,
          action = function() workspace.open(utils.desktop) end,
        },
        {
          key = BOOKMARK_KEYS[4],
          label = utils.everything_label,
          action = function() workspace.open(utils.everything) end,
        },
      }
    end

    -- Keys used for the rows. Every set here must stay disjoint from the
    -- others *and* from BOOKMARK_KEYS: each row installs a buffer-local
    -- mapping, so a key used twice silently resolves to whichever row was
    -- registered last. "d" is absent from the home-row run below because
    -- Bookmarks claims it for Desktop.
    local MRU_KEYS = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }
    local CWD_KEYS = { "a", "s", "f", "g", "h", "j", "k", "l", "z" }
    local SESSION_KEYS = { "F1", "F2", "F3", "F4", "F5" }

    local function startify_layout()
      local workspace = require("core.workspace")
      local root = workspace.root()

      -- Pass one: gather every section as data, so the block can be measured
      -- before any of it is turned into elements. Centring needs a width, and
      -- the width is not knowable until the longest row exists.
      local function collect(keys, paths, relative_to, make_action)
        local rows = {}
        for index, item in ipairs(paths) do
          if index > #keys then
            break
          end
          local display, split = path_parts(item, relative_to)
          rows[#rows + 1] = {
            key = keys[index],
            display = display,
            split = split,
            action = make_action(item),
          }
        end
        return rows
      end

      local sections = {}

      local function push(title, rows)
        if #rows > 0 then
          sections[#sections + 1] = { title = title, rows = rows }
        end
      end

      local function edit_action(path)
        return function() vim.cmd.edit(vim.fn.fnameescape(path)) end
      end

      push("MRU", collect(MRU_KEYS, recent_files(#MRU_KEYS), nil, edit_action))
      push(
        "MRU " .. fit_path(tildify(root), 58),
        collect(CWD_KEYS, recent_files(#CWD_KEYS, root), root, edit_action)
      )

      local sessions = {}
      for index, session in ipairs(saved_sessions()) do
        if index > #SESSION_KEYS then
          break
        end
        local filename = session.filename
        sessions[#sessions + 1] = {
          key = SESSION_KEYS[index],
          display = session.label,
          split = 0,
          -- Load *this* session. Falling back to the picker would make every
          -- row do the same thing while appearing to name a specific one.
          action = function() require("session_manager.utils").load_session(filename, false) end,
        }
      end
      push("Sessions", sessions)

      local marks = {}
      for _, mark in ipairs(bookmarks()) do
        marks[#marks + 1] = { key = mark.key, display = mark.label, split = 0, action = mark.action }
      end
      push("Bookmarks", marks)

      local quote = box(fortune())

      -- Pass two: the widest thing on the page sets the block width, and
      -- everything is padded to it.
      local width = 0
      local function measure(line) width = math.max(width, vim.fn.strdisplaywidth(line)) end

      for _, line in ipairs(quote) do
        measure(line)
      end
      for _, line in ipairs(COW) do
        measure(line)
      end
      for _, section in ipairs(sections) do
        measure(STARTIFY_INDENT .. section.title)
        for _, row in ipairs(section.rows) do
          measure(STARTIFY_ROW_INDENT .. "[" .. row.key .. "] " .. row.display)
        end
      end

      local elements = {
        { type = "padding", val = 1 },
        startify_text(quote, "AlphaStartifyQuote", width),
        { type = "padding", val = 1 },
        startify_text(COW, "AlphaStartifyCow", width),
        { type = "padding", val = 1 },
      }

      local function add(element) elements[#elements + 1] = element end

      for _, section in ipairs(sections) do
        add(startify_header(section.title, width))
        add({ type = "padding", val = 1 })

        local buttons = {}
        for _, row in ipairs(section.rows) do
          buttons[#buttons + 1] = startify_entry(row.key, row.display, row.split, row.action, width)
        end

        add({ type = "group", val = buttons, opts = { spacing = 0 } })
        add({ type = "padding", val = 1 })
      end

      add(footer)

      return elements
    end

    local layouts = {
      -- A `v_center` group centers the block in the window the way Neovim
      -- centers its intro on the screen.
      intro = function()
        return { { type = "group", val = { intro_element() }, opts = { position = "v_center" } } }
      end,

      startify = startify_layout,

      classic = function()
        return {
          { type = "padding", val = 3 },
          header,
          { type = "padding", val = 2 },
          buttons,
          footer,
        }
      end,
    }

    --- The style to draw: the persisted choice, or the default when there is
    --- none (or the saved name no longer exists).
    ---@return string
    local function current_style()
      local saved = state.get("dashboard")
      return (type(saved) == "string" and layouts[saved]) and saved or DEFAULT_STYLE
    end

    local function redraw()
      if vim.bo.filetype == "alpha" then
        pcall(alpha.redraw)
      end
    end

    --- Draw `style` from now on.
    ---@param style string
    ---@param opts? { persist?: boolean, notify?: boolean }
    local function set_style(style, opts)
      opts = opts or {}

      if not layouts[style] then
        vim.notify("Unknown dashboard style: " .. style, vim.log.levels.ERROR)
        return
      end

      -- Persisted before the layout is built, not after. `layouts[style]()`
      -- reaches into telescope, session_manager and the workspace to assemble
      -- its rows; if any of that throws, the choice the user just made would be
      -- lost along with the draw — the style would apply to nothing and be gone
      -- by the next start.
      if opts.persist ~= false then
        state.set("dashboard", style)
      end

      local config = { layout = layouts[style](), opts = { margin = 5 } }
      alpha.setup(config)

      -- Buttons install buffer-local keymaps, so a style switch has to start
      -- from a fresh buffer or the previous style's shortcuts stay live.
      -- `alpha.start()` builds one for any buffer that is not already a
      -- dashboard — hence dropping the filetype first; the old buffer is wiped
      -- by the swap, taking its keymaps with it.
      if vim.bo.filetype == "alpha" then
        vim.bo.filetype = ""
        alpha.start(false, config)
      end

      if opts.notify ~= false then
        vim.notify("Dashboard style: " .. style, vim.log.levels.INFO)
      end
    end

    apply_highlights()
    set_style(current_style(), { persist = false, notify = false })

    ui.on_theme_change(ui.create_augroup("AlphaThemeHighlights"), function()
      apply_highlights()
      redraw()
    end)

    -- One line about each style, so the picker says what you are choosing
    -- rather than making you cycle through all three to find out.
    local STYLE_DESCRIPTIONS = {
      intro = "Neovim's own startup screen",
      classic = "Block logo and action buttons",
      startify = "Fortune, recent files, sessions and bookmarks",
    }

    --- Choose a style from a list instead of cycling blind.
    ---
    --- A Telescope dropdown styled like the theme picker, so the two "pick a
    --- look" dialogs in this config are the same dialog. `vim.ui.select` was
    --- the first cut and looked out of place: it inherits whatever the handler
    --- of the day is, and none of them match the pickers everything else uses.
    --- Falls back to `vim.ui.select` when Telescope is not installed.
    local function pick_style()
      local current = current_style()

      local ok, pickers = pcall(require, "telescope.pickers")
      local ok_finders, finders = pcall(require, "telescope.finders")
      local ok_conf, conf = pcall(require, "telescope.config")
      local ok_themes, tele_themes = pcall(require, "telescope.themes")
      local ok_actions, actions = pcall(require, "telescope.actions")
      local ok_state, action_state = pcall(require, "telescope.actions.state")

      if not (ok and ok_finders and ok_conf and ok_themes and ok_actions and ok_state) then
        vim.ui.select(STYLES, {
          prompt = "Dashboard style",
          format_item = function(style) return (style == current and "\u{25cf} " or "  ") .. style end,
        }, function(choice)
          if choice then
            set_style(choice)
          end
        end)
        return
      end

      pickers
        .new(
          tele_themes.get_dropdown({
            prompt_title = "Dashboard",
            results_title = false,
            previewer = false,
            sorting_strategy = "ascending",
            initial_mode = "insert",
            selection_caret = "\u{25b8} ",
            prompt_prefix = "Filter: ",
            entry_prefix = "  ",
            winblend = 0,
            borderchars = {
              "\u{2500}",
              "\u{2502}",
              "\u{2500}",
              "\u{2502}",
              "\u{256d}",
              "\u{256e}",
              "\u{256f}",
              "\u{2570}",
            },
            layout_config = {
              width = function(_, max_columns)
                return math.min(max_columns, math.max(58, math.floor(max_columns * 0.5)))
              end,
              height = #STYLES + 4,
              prompt_position = "top",
            },
          }),
          {
            finder = finders.new_table({
              results = STYLES,
              entry_maker = function(style)
                local marker = style == current and "\u{25cf}" or " "
                return {
                  value = style,
                  ordinal = style .. " " .. (STYLE_DESCRIPTIONS[style] or ""),
                  display = string.format("%s %-9s %s", marker, style, STYLE_DESCRIPTIONS[style] or ""),
                }
              end,
            }),
            sorter = conf.values.generic_sorter({}),
            attach_mappings = function(bufnr)
              actions.select_default:replace(function()
                local entry = action_state.get_selected_entry()
                actions.close(bufnr)
                if entry then
                  set_style(entry.value)
                end
              end)
              return true
            end,
          }
        )
        :find()
    end

    vim.api.nvim_create_user_command("Dashboard", function(cmd)
      -- No argument opens the picker, which is what <leader>ua rides on.
      if cmd.args == "" then
        pick_style()
        return
      end

      set_style(cmd.args)
    end, {
      nargs = "?",
      complete = function() return STYLES end,
      desc = "Switch dashboard style (no argument cycles)",
    })

    --- Plugin load stats, once lazy.nvim has finished starting up.
    ---@return boolean ready
    local function set_footer()
      local ok, lazy = pcall(require, "lazy")
      if not ok then
        return false
      end

      local stats = lazy.stats()
      if stats.startuptime == 0 then
        return false -- not measured yet
      end

      footer.val =
        string.format("\u{f0e7}  %d plugins loaded in %.0f ms", stats.loaded, stats.startuptime)
      redraw()

      return true
    end

    -- The event may already have fired by the time alpha configures itself.
    if not set_footer() then
      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyVimStarted",
        once = true,
        callback = set_footer,
      })
    end
  end,
}
