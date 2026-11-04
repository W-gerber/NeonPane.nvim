<div align="center">

# Nvim-Config

A Windows-first Neovim setup: IDE-style workspaces, a live theme switcher, and
custom pill-shaped chrome that follows whatever theme is active.

[![Neovim](https://img.shields.io/badge/Neovim-0.11+-green.svg?style=flat-square&logo=neovim)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-LuaJIT-purple.svg?style=flat-square&logo=lua)](https://www.lua.org)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

</div>

---

## Showcase

<div align="center">

![Nvim Dashboard](https://raw.githubusercontent.com/W-gerber/Nvim-Config/main/screenshots/dashboard.png)
![Nvim Dashboard](https://raw.githubusercontent.com/W-gerber/Nvim-Config/main/screenshots/dashboard1.png)

</div>

---

## Requirements

| | |
|---|---|
| **Neovim** | 0.11 or newer — the config uses `vim.lsp.config`, `vim.diagnostic.jump`, `vim.hl` and `'winborder'`, and refuses to load on older versions |
| **Font** | any [Nerd Font](https://www.nerdfonts.com) (glyphs are defined in `lua/core/icons.lua`) |
| **git** | required to bootstrap lazy.nvim |
| **C compiler** | required to build Treesitter parsers — MSYS2 + MinGW64 on Windows, `xcode-select --install` on macOS, gcc/clang on Linux |
| **ripgrep** | Telescope live grep and todo-comments search |
| **Optional** | `fd` (faster file finding), `lazygit` for `<leader>lg`, PowerShell 7 for the folder picker and media controls |

Clone into `%LOCALAPPDATA%\nvim` (Windows) or `~/.config/nvim` (Linux/macOS) and
start Neovim; lazy.nvim bootstraps itself and installs the plugin set. Then:

```vim
:checkhealth core   " verifies compiler, external tools, theme cache
:Lazy restore       " pin every plugin to the versions in lazy-lock.json
```

`:checkhealth core` is the first thing to run when something misbehaves — it
compiles a test program rather than just looking for `gcc` on `PATH`, which is
what distinguishes a missing toolchain from a shadowed one.

---

## Layout

```
init.lua                 entry point: version guard, lazy bootstrap, UI bring-up
lua/
  core/
    options.lua          editor options + PATH setup
    keymaps.lua          global keymaps
    autocmds.lua         autocommands
    ui.lua               palette derived from the active theme + color helpers
    chrome.lua           highlights for plugin UIs with no spec of their own
    icons.lua            every Nerd Font glyph, as \u{...} escapes
    transparency.lua     the "glass" background toggle
    workspace.lua        IDE-style "open folder" handling
    state.lua            persisted UI preferences (theme, glass)
    utils.lua            shared helpers (safe buffer delete, well-known paths)
    health.lua           :checkhealth core
    music.lua            Windows media-session controls
  plugins/               one lazy.nvim spec per plugin, aggregated by init.lua
  themes/                base46 theme definitions (see themes/README.md)
  theme_switcher/        theme registry + Telescope picker
  statusline.lua         lualine "bubbles" bar
  tabline.lua            pill-style buffer tabs
```

**One rule worth knowing:** UI code never hard-codes colors. Everything asks
`require("core.ui").palette()` for semantic colors (`accent`, `panel`, `red`, …).
Those are read out of the *active* theme's highlight groups — or, for themes
that declare a `ui_palette`, taken from the theme directly. That is why
switching themes restyles the statusline, tabline, explorer, pickers, Lazy,
Mason and the completion menu together.

---

## Themes

Two flagship themes are ported faithfully from their VS Code originals — the
palettes are transcribed from the upstream theme JSON, not approximated:

| Theme | Origin |
|---|---|
| **neon vommit** | [ghgofort/vscode-neon-vommit-theme](https://github.com/ghgofort/vscode-neon-vommit-theme) — lime functions, magenta keywords, cyan variables, lavender strings, yellow operators on `#222222` |
| **synthwave '84** | [robb0wen/synthwave-vscode](https://github.com/robb0wen/synthwave-vscode) — yellow keywords, cyan functions, pink variables, orange strings, mint tags on `#262335` |

Both cover syntax, Treesitter, and per-language overrides for Lua, TS/JS,
JSX/TSX, Rust, Go, Python, C#, Java, SQL, HTML, CSS/Tailwind, JSON and Markdown,
plus terminal ANSI colors and an exact chrome palette.

Also included: `neon commit` (the original house theme), `tokyonight`, `dracula`,
`default light`, and the catppuccin / onedarkpro / evergarden / bamboo / yorumi /
lavi plugins.

- `<leader>th` opens the picker; moving the selection previews live, `<Enter>`
  applies and persists, `<Esc>` reverts.
- The choice is saved to `ui_state.json` under `stdpath("data")`.
- Adding a theme: see [`lua/themes/README.md`](lua/themes/README.md).

### Transparency

The "glass" background is a **user preference, not a theme property**. Each
theme declares whether it looks right transparent (`synthwave84` does not — its
deep violet backdrop is the point), and that hint applies until you make an
explicit choice with `<leader>ub` or `:Transparency`, which is then remembered
across every theme.

### Popups (glass)

which-key, the noice cmdline and its completion menu, message toasts and the
completion popup share one look: a rim that is lit along the top edge and
shadowed along the bottom, an accent chip for the title, and colored icons.

Their **background follows the transparency setting** (`ui.pane_bg()`):

- glass **on** — no background at all, so a terminal doing its own acrylic or
  blur shows through the popup. `winblend` is 0 everywhere on purpose: it
  composites a float against the editor cells beneath it, and where those are
  transparent it resolves to the default background, i.e. a dark box painted
  over the effect the terminal was already doing properly.
- glass **off** — a neutral frosted pane, `ui.frost()`: the background lifted
  toward white (toward black on light themes), **not** the accent-tinted
  `panel` colors the statusline pills use. A word-wide pill can borrow the
  accent and look deliberate; a popup-sized sheet that borrows it reads as
  colored film, which is very obvious on themes with a vivid accent.

Telescope's windows are always `NONE`. Row markers — the selected picker row,
the previewed line, the selected completion item, the cursorline — keep a faint
neutral background in both modes, because nothing else marks them.

### Pickers and explorer

Every picker shares one layout and one border treatment: the prompt and the
result list are drawn as a single panel (the prompt's bottom edge is left open,
the results' top corners are T-junctions) with the preview as its own box
alongside. The prompt carries a solid accent title chip — one thing shouting per
picker — and the rest of the titles are plain accent text. Per-picker overrides
only change proportions: grep gives the larger half to the preview, the buffer
list has no preview and shrinks to fit.

The explorer has source tabs across the top (Files / Buffers / Git), indent
guides that end in the same `╰` as every other rim in the UI, git state and
diagnostics in their own columns, and no background of its own.

### Dashboard

The start screen comes in two styles, switched with `:Dashboard intro|classic`
(`<leader>ua` cycles) and remembered in `ui_state.json`:

- **intro** (default) — a copy of Neovim's own startup screen, down to its
  logo, rules and highlight groups, so it looks like `nvim --clean`.
- **classic** — the block-letter logo over the action buttons (find file,
  recent files, grep, workspaces, sessions, plugins, health) plus the
  plugins-loaded footer.

---

## Keymaps

Leader is `<Space>`. Press `<leader>` and wait for which-key, or hit
`<leader>fk` to search every mapping.

### Prefix map

| Prefix | Group |
|---|---|
| `<leader>a` | Claude Code |
| `<leader>b` | Buffers |
| `<leader>c` | Code (LSP, format, lint) |
| `<leader>D` | Debug (DAP) |
| `<leader>f` | Find (Telescope) |
| `<leader>g` | Git hunks |
| `<leader>l` | Lazygit |
| `<leader>m` | Music |
| `<leader>s` | Sessions |
| `<leader>t` | Tools (terminal, theme) |
| `<leader>u` | UI toggles |
| `<leader>x` | Trouble / diagnostics lists |

### Files & search

| Key | Action |
|---|---|
| `<leader>ff` / `<leader>fg` | find files / live grep in the workspace |
| `<leader>fw` / `<leader>f/` | grep word under cursor / search in current buffer |
| `<leader>fb` / `<leader>fr` | open buffers / recent files |
| `<leader>fs` / `<leader>fd` | document symbols / diagnostics |
| `<leader>fk` / `<leader>fc` | keymaps / commands |
| `<leader>fh` / `<leader>fR` | help tags / resume last picker |
| `<leader>ft` / `<leader>fT` | todo comments / todo+fix+fixme |
| `<leader>fo` | open a folder as the workspace (native dialog) |
| `<leader>e` | toggle the file explorer |

### Buffers & windows

| Key | Action |
|---|---|
| `<C-Tab>` / `<C-S-Tab>` | next / previous buffer tab |
| `<A-1>`…`<A-9>` | jump to tab *n* |
| `<A-w>` / `<A-S-w>` | close tab / close other tabs |
| `<leader>bn` `<leader>bc` `<leader>bo` | new / close / close others (add `Shift` to force) |
| `<C-h/j/k/l>` | move between windows |
| `<C-Up/Down/Left/Right>` | resize the current window |
| `<leader>vs` / `<leader>hs` | split, choosing the target window |
| `<leader>q` | close window |

Buffer pills are clickable: left-click focuses, middle-click closes.

### Code

| Key | Action |
|---|---|
| `gd` `gD` `gi` `gr` `gt` | definition, declaration, implementation, references, type |
| `K` / `gK` | hover / signature help |
| `<leader>ca` / `<leader>rn` | code action / rename |
| `<leader>cf` / `<leader>cF` | format buffer / toggle format-on-save |
| `<leader>ch` / `<leader>cl` | toggle inlay hints / lint now |
| `<leader>cs` / `<leader>cS` | swap argument with next / previous |
| `[d` / `]d` · `[e` / `]e` | previous / next diagnostic · error |
| `<leader>d` | line diagnostics |
| `<leader>xx` … | Trouble lists (diagnostics, symbols, quickfix, todos) |
| `s` / `S` | Flash jump / Flash Treesitter |

**Text objects** (Treesitter): `af`/`if` function, `ac`/`ic` class, `aa`/`ia`
argument, `ai`/`ii` conditional, `al`/`il` loop, `a/` comment.
**Motions**: `]f`/`[f` function, `]C`/`[C` class, `]a`/`[a` argument — repeat any
of them with `;` / `,`.

### Git

| Key | Action |
|---|---|
| `[c` / `]c` | previous / next hunk |
| `<leader>gs` / `<leader>gr` | stage (toggle) / reset hunk |
| `<leader>gp` / `<leader>gb` | preview hunk / blame line |
| `<leader>gd` / `<leader>gD` | diff against index / last commit |
| `<leader>lg` | Lazygit |
| `ih` | hunk text object (`dih`, `vih`) |

### Debug

| Key | Action |
|---|---|
| `<leader>Db` / `<leader>DB` | toggle breakpoint / conditional breakpoint |
| `<leader>Dc` | continue / start |
| `<leader>Di` `<leader>Do` `<leader>DO` | step into / over / out |
| `<leader>Du` / `<leader>De` | toggle debugger UI / evaluate expression |

Adapters are installed with `:Mason` (`codelldb`, `delve`, `debugpy`, …) and
picked up automatically when present.

### UI

| Key | Action |
|---|---|
| `<leader>th` | theme picker (live preview, `<Esc>` reverts) |
| `<leader>ub` | toggle background transparency |
| `<leader>uw` `<leader>un` `<leader>ud` | toggle wrap / relative numbers / diagnostics |
| `<leader>ua` | switch dashboard style (intro / classic) |
| `<leader>mm` | music panel (`mp` play-pause, `mn`/`mb` skip, `mu`/`md` volume) |
| `<leader>tt` | terminal |
| `<leader>a…` | Claude Code |

### Commands

`:OpenFolder` · `:Theme [name]` · `:Transparency [on|off]` ·
`:Dashboard [intro|classic]` · `:Music [action]` · `:MusicDebug` · `:Lazy` ·
`:Mason` · `:ConformInfo` · `:checkhealth core`

---

## Language support

Treesitter parsers, LSP settings and formatters are configured for Lua, Java,
TypeScript/JavaScript (incl. JSX/TSX), Rust, Go, Python, C#, C, SQL, HTML,
CSS/SCSS, JSON, YAML, TOML, Markdown, shell and Dockerfiles.

Only `lua_ls` and `jdtls` are installed by default — everything else has its
settings waiting in `lua/plugins/lspconfig.lua` and starts working the moment
you install it with `:Mason`. Formatters resolve from Mason, `PATH`, or a
project's own `node_modules`, and are skipped silently when absent.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Boxes instead of icons | install and select a Nerd Font in your terminal |
| Editor background looks wrong on a light theme | `<leader>ub` (or `:Transparency off`) |
| Treesitter parsers fail to build | `:checkhealth core` — it compiles a test program and reports whether the toolchain is missing or shadowed |
| `Error during compilation` for every parser | on Windows, another toolchain's DLLs are shadowing MSYS2's; the config hoists `mingw64\bin` to the front of `PATH`, so also check for leftover `tree-sitter-*` folders in `stdpath("data")` |
| `<leader>fg` finds nothing | install ripgrep and make sure `rg` is on `PATH` |
| A language server never starts | `:Mason` to install it, then `:checkhealth lsp` |
| Something looks stale after editing config | `:Lazy reload <plugin>` or restart |

---

<div align="center">

**⭐ Star this repo if you find it helpful!**

</div>
