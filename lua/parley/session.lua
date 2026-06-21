local M = {}

local config = require("parley.config")

---Get the session storage directory
---@return string
function M.get_dir()
  local dir = vim.fn.stdpath("data") .. "/parley"
  vim.fn.mkdir(dir, "p")
  return dir
end

---Get the session file path for a buffer
---@param bufnr number|nil
---@return string
function M.get_file_path(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local dir = M.get_dir()
  return string.format("%s/session_%d.json", dir, bufnr)
end

---Save the current conversation session to a JSON file
---@param bufnr number|nil
---@return boolean ok
---@return string|nil err
function M.save(bufnr)
  local chat = require("parley.chat")
  local session = chat.get_session(bufnr)
  local messages = chat.get_messages(bufnr)

  if #messages <= 1 then
    return false, "No conversation to save (only system prompt)"
  end

  local data = {
    version = 1,
    saved_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    model = session.model,
    bufnr = bufnr,
    messages = messages,
  }

  local filepath = M.get_file_path(buffnr)
  local json = vim.json.encode(data)
  local f = io.open(filepath, "w")
  if not f then
    return false, "Failed to open file: " .. filepath
  end

  f:write(json)
  f:close()

  vim.notify(
    string.format("Session saved: %s", vim.fn.fnamemodify(filepath, ":t")),
    vim.log.levels.INFO,
    { title = "Parley" }
  )
  return true
end

---Load a conversation session from a JSON file
---@param bufnr number|nil
---@return boolean ok
---@return string|nil err
function M.load(bufnr)
  local chat = require("parley.chat")
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local filepath = M.get_file_path(bufnr)
  local f = io.open(filepath, "r")
  if not f then
    return false, "No saved session found for this buffer"
  end

  local json = f:read("*a")
  f:close()

  local ok, data = pcall(vim.json.decode, json)
  if not ok or not data or not data.messages then
    return false, "Failed to parse session file"
  end

  -- Restore the session
  local session = chat.get_session(bufnr)
  session.messages = data.messages
  if data.model then
    session.model = data.model
  end

  -- Refresh the UI
  local panel = require("parley.ui.panel")
  local conversation = require("parley.ui.conversation")
  panel.update_winbar()
  conversation.render()
  conversation.scroll_to_bottom()

  vim.notify(
    string.format("Session loaded: %d messages", #data.messages - 1),
    vim.log.levels.INFO,
    { title = "Parley" }
  )
  return true
end

---List all saved sessions
---@return table[] sessions list of {path, bufnr, saved_at, message_count}
function M.list()
  local dir = M.get_dir()
  local sessions = {}

  local handle = vim.loop.fs_scandir(dir)
  if not handle then return sessions end

  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then break end
    if type == "file" and name:match("^session_%d+%.json$") then
      local filepath = dir .. "/" .. name
      local f = io.open(filepath, "r")
      if f then
        local json = f:read("*a")
        f:close()
        local ok, data = pcall(vim.json.decode, json)
        if ok and data then
          local bufnr = name:match("session_(%d+)")
          table.insert(sessions, {
            path = filepath,
            bufnr = bufnr and tonumber(bufnr) or 0,
            saved_at = data.saved_at or "unknown",
            message_count = #data.messages - 1,
            model = data.model or "unknown",
          })
        end
      end
    end
  end

  -- Sort by saved_at descending
  table.sort(sessions, function(a, b)
    return (a.saved_at or "") > (b.saved_at or "")
  end)

  return sessions
end

---Delete a saved session file
---@param bufnr number|nil
---@return boolean ok
function M.delete(bufnr)
  local filepath = M.get_file_path(bufnr)
  local ok = os.remove(filepath)
  if ok then
    vim.notify("Session deleted", vim.log.levels.INFO, { title = "Parley" })
    return true
  end
  return false
end

return M
