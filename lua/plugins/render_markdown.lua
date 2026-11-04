-- Markdown rendered in place: headings, tables, checkboxes, code blocks.
-- The raw text comes back on the cursor line, so editing is unaffected.

return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown" },
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  opts = {},
  keys = {
    { "<leader>um", "<cmd>RenderMarkdown toggle<cr>", desc = "Toggle markdown rendering", ft = "markdown" },
  },
}
