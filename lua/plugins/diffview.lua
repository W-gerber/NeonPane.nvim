-- Side-by-side diffs of everything changed, and per-file / repo history.
-- lazygit is for staging and committing; this is for reading a change.

return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
  keys = {
    { "<leader>gv", "<cmd>DiffviewOpen<cr>", desc = "Diff view (working tree)" },
    { "<leader>gV", "<cmd>DiffviewClose<cr>", desc = "Close diff view" },
    { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
    { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Repo history" },
  },
  opts = {},
}
