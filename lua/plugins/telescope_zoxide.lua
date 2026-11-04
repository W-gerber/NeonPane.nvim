-- Zoxide-backed directory jump, as a Telescope picker. Frontend and theming
-- (borders, highlights, layout) are inherited from telescope.lua's own setup
-- -- this file only adds the `zoxide` extension config, the way the plugin's
-- own docs recommend (telescope.setup can be called again, additively).

return {
  "jvgrootveld/telescope-zoxide",
  dependencies = { "nvim-telescope/telescope.nvim" },
  cmd = "Telescope",
  keys = {
    {
      "<leader>fz",
      function()
        -- Bypasses vim.o.shell: on this config it's a backslash-form Windows
        -- path ("C:\Program Files\Git\bin\bash.exe") that vim.fn.executable()
        -- reports as 0 despite the file existing, which fails plenary's Job
        -- validation. zoxide needs no shell anyway -- called directly instead.
        require("telescope").extensions.zoxide.list({ cmd = { "zoxide", "query", "-ls" } })
      end,
      desc = "Zoxide (jump to directory)",
    },
  },
  config = function()
    local telescope = require("telescope")

    telescope.setup({
      extensions = {
        zoxide = {
          prompt_title = "Zoxide",
          mappings = {
            default = {
              action = function(selection) vim.cmd.cd(selection.path) end,
            },
          },
        },
      },
    })

    telescope.load_extension("zoxide")
  end,
}
