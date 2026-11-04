-- Shared utility functions used across the config.
-- Avoids duplicating logic in init.lua, tabline.lua, etc.

local M = {}
local uv = vim.uv or vim.loop

local function normalize_path(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end

  if vim.fs and type(vim.fs.normalize) == "function" then
    return vim.fs.normalize(path)
  end

  return path:gsub("\\", "/")
end

local function is_dir(path)
  path = normalize_path(path)
  if not path then
    return false
  end

  local stat = uv and uv.fs_stat and uv.fs_stat(path)
  if stat then
    return stat.type == "directory"
  end

  return vim.fn.isdirectory(path) == 1
end

local function first_existing(paths, fallback)
  for _, path in ipairs(paths) do
    path = normalize_path(path)
    if is_dir(path) then
      return path
    end
  end

  return normalize_path(fallback)
end

local function compact_paths(...)
  local paths = {}

  for index = 1, select("#", ...) do
    local path = normalize_path(select(index, ...))
    if path then
      paths[#paths + 1] = path
    end
  end

  return paths
end

local function home_dir()
  local home = normalize_path(vim.env.USERPROFILE) or normalize_path(vim.env.HOME)

  if home then
    return home
  end

  if uv and type(uv.os_homedir) == "function" then
    return normalize_path(uv.os_homedir())
  end

  return normalize_path(vim.fn.expand("~")) or "."
end

--- Safely close a buffer, moving windows to an alternate buffer first.
---@param bufnr number
---@param force? boolean
function M.safe_bufdelete(bufnr, force)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local windows = vim.fn.win_findbuf(bufnr)
  for _, win in ipairs(windows) do
    if vim.api.nvim_win_is_valid(win) then
      local alt = vim.fn.bufnr("#")
      if alt > 0 and vim.api.nvim_buf_is_valid(alt) and vim.bo[alt].buflisted then
        pcall(vim.api.nvim_win_set_buf, win, alt)
      else
        local scratch = vim.api.nvim_create_buf(true, false)
        pcall(vim.api.nvim_win_set_buf, win, scratch)
      end
    end
  end

  local ok = pcall(vim.api.nvim_buf_delete, bufnr, { force = force or false })
  if not ok then
    vim.notify("Could not close buffer (unsaved changes?)", vim.log.levels.WARN)
  end
end

--- Close every listed buffer except the current one.
---@param force? boolean
function M.close_other_buffers(force)
  local current = vim.api.nvim_get_current_buf()

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= current and vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
      M.safe_bufdelete(buf, force)
    end
  end
end

--- winget installs into a versioned package directory that it does not put on
--- PATH, so a tool can be installed and still invisible to `exepath`. Searched
--- only after the cheap lookups miss, and only on Windows.
---@param name string
---@return string|nil
local function winget_path(name)
  if vim.fn.has("win32") == 0 then
    return nil
  end

  local packages = vim.fs.joinpath(vim.env.LOCALAPPDATA or "", "Microsoft", "WinGet", "Packages")
  if vim.fn.isdirectory(packages) == 0 then
    return nil
  end

  local matches = vim.fn.glob(packages .. "/*/" .. name .. ".exe", false, true)
  local exe = matches[1]

  return (exe and vim.fn.filereadable(exe) == 1) and exe or nil
end

--- Absolute path to an external tool: Mason's copy first, then anything already
--- on PATH, then winget's package store. `nil` when none exists, which is the
--- signal to skip whatever feature needed it rather than spawn a command that
--- isn't there.
---
--- Mason writes `.cmd` shims on Windows, so the extension is part of the name
--- there and `exepath` alone would miss them.
---@param name string
---@return string|nil
function M.tool_path(name)
  local mason = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin", name)
  if vim.fn.has("win32") == 1 then
    mason = mason .. ".cmd"
  end

  if vim.fn.filereadable(mason) == 1 then
    return mason
  end

  local system = vim.fn.exepath(name)
  if system ~= "" then
    return system
  end

  return winget_path(name)
end

--- Like `tool_path`, but also puts the tool's directory on PATH, for the callers
--- that spawn it by bare name rather than by the path they were handed.
---@param name string
---@return string|nil
function M.ensure_on_path(name)
  local path = M.tool_path(name)
  if not path then
    return nil
  end

  local dir = vim.fn.fnamemodify(path, ":h")
  local sep = vim.fn.has("win32") == 1 and ";" or ":"
  local current = vim.env.PATH or ""

  if not (sep .. current .. sep):lower():find(sep .. dir:lower() .. sep, 1, true) then
    vim.env.PATH = dir .. sep .. current
  end

  return path
end

-- User home / Desktop / Everything paths (portable).
M.home = home_dir()

local desktop_default = normalize_path(M.home .. "/Desktop")
local desktop_onedrive = normalize_path((vim.env.OneDrive or vim.env.ONEDRIVE or "") .. "/Desktop")
local desktop_onedrive_business = normalize_path((vim.env.OneDriveCommercial or "") .. "/Desktop")
local desktop_onedrive_personal = normalize_path((vim.env.OneDriveConsumer or "") .. "/Desktop")

M.desktop = first_existing(
  compact_paths(
    vim.env.NVIM_DESKTOP_DIR,
    desktop_default,
    desktop_onedrive,
    desktop_onedrive_business,
    desktop_onedrive_personal
  ),
  M.home
)
M.desktop_label = M.desktop == M.home and "Home" or "Desktop"

local everything_default = normalize_path(M.desktop .. "/Everything")
M.everything =
  first_existing(compact_paths(vim.env.NVIM_EVERYTHING_DIR, everything_default, M.desktop), M.home)
M.everything_label = M.everything == everything_default and "Everything" or "Search Root"

return M
