-- Project-wide search and replace with a live preview (ripgrep underneath).
-- Telescope's grep finds; this is the one that also replaces.

return {
  "MagicDuck/grug-far.nvim",
  cmd = "GrugFar",
  opts = { headerMaxWidth = 80 },
  keys = {
    { "<leader>fx", function() require("grug-far").open() end, desc = "Search & replace (project)" },
    {
      "<leader>fx",
      function() require("grug-far").with_visual_selection() end,
      mode = "v",
      desc = "Search & replace selection",
    },
    {
      "<leader>fX",
      function() require("grug-far").open({ prefills = { paths = vim.fn.expand("%") } }) end,
      desc = "Search & replace (this file)",
    },
  },
}
