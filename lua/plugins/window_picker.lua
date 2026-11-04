-- Pick a target window before splitting, instead of guessing.
--
-- This spec previously had no load trigger at all. With `defaults.lazy = true`
-- in init.lua that meant it was never loaded, so the split mappings simply did
-- nothing. The `keys` below both declare the mappings and load the plugin.
--
-- Splits live under <leader>s* to match the verb-then-direction shape of the
-- rest of the config; jumping to a window is <leader>w, the most frequent of
-- the three and the one worth the shortest binding.

local function pick()
  local ok, picker = pcall(require, "window-picker")
  if not ok or not picker.pick_window then
    return nil
  end

  return picker.pick_window()
end

local function split_with_picker(command)
  local win = pick()
  if win then
    pcall(vim.api.nvim_set_current_win, win)
  end

  vim.cmd(command)
end

return {
  "s1n7ax/nvim-window-picker",
  name = "window-picker",
  main = "window-picker",
  version = "*",
  keys = {
    { "<leader>sv", function() split_with_picker("vsplit") end, desc = "Vertical split (pick window)" },
    { "<leader>sh", function() split_with_picker("split") end, desc = "Horizontal split (pick window)" },
    {
      "<leader>w",
      function()
        local win = pick()
        if win then
          pcall(vim.api.nvim_set_current_win, win)
        end
      end,
      desc = "Jump to window",
    },
  },
  opts = {
    -- "floating-letter", not "floating-big-letter": the big variant renders the
    -- letter as multi-row ASCII art (the `ansi-shadow` font), which on a split
    -- only a few lines tall covers the window it is labelling. This one is a
    -- single centred character.
    hint = "floating-letter",
    show_prompt = true,

    -- Why the picker looked broken: `autoselect_one = true` skips the whole UI
    -- whenever exactly one window is eligible, and the filter below used to
    -- throw out neo-tree *and* every terminal, quickfix and help window. In the
    -- ordinary layout — one file plus the file tree — that left a single
    -- candidate, so it jumped instantly and no letters were ever drawn. With
    -- the tree focused it left none, and nothing happened at all.
    --
    -- So: always show the hint, and treat the sidebar and terminals as real
    -- jump targets, because they are.
    filter_rules = {
      include_current_win = false,
      autoselect_one = false,
      bo = {
        -- Transient overlays only. These are not windows you navigate *to*.
        filetype = { "neo-tree-popup", "notify", "noice" },
        buftype = { "prompt" },
      },
    },

    -- The letter you press. Home-row first, so the common case is a single
    -- keystroke without moving your hands.
    selection_chars = "FJDKSLAGHRUEIWOQP",
  },
}
