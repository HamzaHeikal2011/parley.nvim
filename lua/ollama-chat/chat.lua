local M = {}

---@class OllamaMessage
---@field role "system" | "user" | "assistant"
---@field content string

---@class OllamaChat.Session
---@field messages OllamaMessage[]
---@field model string
---@field bufnr number The buffer this session is associated with
---@field cancel_fn fun()|nil Cancel function for in-flight request

---@type table<number, OllamaChat.Session>
local sessions = {}

---Get or create a session for a buffer
---@param bufnr number|nil
---@return OllamaChat.Session
function M.get_session(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not sessions[bufnr] then
    local cfg = require("ollama-chat.config").get()
    sessions[bufnr] = {
      messages = {},
      model = cfg.model,
      bufnr = bufnr,
      cancel_fn = nil,
    }

    -- Add system prompt
    if cfg.system_prompt and cfg.system_prompt ~= "" then
      table.insert(sessions[bufnr].messages, {
        role = "system",
        content = cfg.system_prompt,
      })
    end
  end

  return sessions[bufnr]
end

---Add a message to the session
---@param bufnr number|nil
---@param role "user" | "assistant"
---@param content string
function M.add_message(bufnr, role, content)
  local session = M.get_session(bufnr)
  table.insert(session.messages, {
    role = role,
    content = content,
  })
end

---Get all messages for the session
---@param bufnr number|nil
---@return OllamaMessage[]
function M.get_messages(bufnr)
  local session = M.get_session(bufnr)
  return session.messages
end

---Clear the session (removes all messages, re-adds system prompt)
---@param bufnr number|nil
function M.clear_session(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  sessions[bufnr] = nil
  -- Re-create with just system prompt
  M.get_session(bufnr)
end

---Set the cancel function for the current request
---@param bufnr number|nil
---@param fn fun()
function M.set_cancel_fn(bufnr, fn)
  local session = M.get_session(bufnr)
  session.cancel_fn = fn
end

---Cancel the current request
---@param bufnr number|nil
function M.cancel(bufnr)
  local session = M.get_session(bufnr)
  if session.cancel_fn then
    session.cancel_fn()
    session.cancel_fn = nil
  end
end

---Check if there's an active request
---@param bufnr number|nil
---@return boolean
function M.is_active(bufnr)
  local session = M.get_session(bufnr)
  return session.cancel_fn ~= nil
end

---Switch the model for a session
---@param bufnr number|nil
---@param model string
function M.set_model(bufnr, model)
  local session = M.get_session(bufnr)
  session.model = model
end

---Get the model for a session
---@param bufnr number|nil
---@return string
function M.get_model(bufnr)
  local session = M.get_session(bufnr)
  return session.model
end

---Build the user message with context chips prepended
---@param user_text string
---@return string
function M.build_user_message(user_text)
  local chips = require("ollama-chat.context_chips")
  local context = chips.build_context()

  if context == "" then
    return user_text
  end

  return context .. "\n\n" .. user_text
end

return M
