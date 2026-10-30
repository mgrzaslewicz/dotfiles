-- Autosave for project files: the buffer is written 1000ms after the last change (insert mode left or text changed).
-- `<leader>ta` toggles it; it starts on unless nvim was started on a file.
--
-- Only files inside a project (git repo, Gradle or Maven build) are saved, and only when nvim was started without a
-- specific file: `nvim` or `nvim <dir>` yes, `vi <file>` no, so a file opened on its own is never written behind the
-- user's back. The session decision is taken once at setup from the startup arguments. Tests: tests/test_autosave.lua.

local M = {}

local project_markers = {
  '.git',
  'gradlew',
  'mvnw',
  'settings.gradle.kts',
  'settings.gradle',
  'build.gradle.kts',
  'build.gradle',
  'pom.xml',
}

--- Whether autosave applies to the session started with `args`: no arguments, or directories only.
---@param args string[]
---@return boolean
function M.session_enabled(args)
  for _, arg in ipairs(args) do
    if vim.fn.isdirectory(arg) == 0 then return false end
  end
  return true
end

--- Whether `path` lies inside a project root.
---@param path string
---@return boolean
function M.is_project_file(path)
  if path == '' then return false end
  return vim.fs.root(vim.fs.dirname(path), project_markers) ~= nil
end

--- Writes `buf` if it is a modified, writable project file on disk.
---@param buf integer
function M.save(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local bo = vim.bo[buf]
  if bo.buftype ~= '' or not bo.modifiable or bo.readonly or not bo.modified then return end
  if not M.is_project_file(vim.api.nvim_buf_get_name(buf)) then return end
  vim.api.nvim_buf_call(buf, function() vim.cmd 'silent! update' end)
end

local debounce_ms = 1000
local timer

-- Whether saves happen. Starts as the session decides; `<leader>ta` flips it.
M.enabled = false

--- Saves `buf` once no change has come for `debounce_ms`. Each change restarts the wait.
---@param buf integer
function M.schedule_save(buf)
  if not M.enabled then return end
  timer = timer or assert(vim.uv.new_timer())
  timer:stop()
  timer:start(debounce_ms, 0, vim.schedule_wrap(function() M.save(buf) end))
end

--- Flips autosave and returns the new state. Turning it off drops a save that is waiting.
---@return boolean
function M.toggle()
  M.enabled = not M.enabled
  if not M.enabled and timer then timer:stop() end
  vim.notify('Autosave ' .. (M.enabled and 'on' or 'off'))
  return M.enabled
end

--- Installs the autocmds and `<leader>ta`, and sets `enabled` from the startup arguments. Call once from init.lua.
function M.setup()
  M.enabled = M.session_enabled(vim.fn.argv() --[[@as string[] ]])
  vim.api.nvim_create_autocmd({ 'InsertLeave', 'TextChanged' }, {
    group = vim.api.nvim_create_augroup('custom-autosave', { clear = true }),
    callback = function() M.schedule_save(vim.api.nvim_get_current_buf()) end,
  })
  vim.keymap.set('n', '<leader>ta', M.toggle, { desc = '[T]oggle [A]utosave' })
end

return M
