local M = {}

local config = require("parley.config")
local http = require("parley.http")
local chat = require("parley.chat")
local panel = require("parley.ui.panel")
local conversation = require("parley.ui.conversation")
local input = require("parley.ui.input")
local highlights = require("parley.ui.highlights")

---@type fun()|nil
local cancel_current = nil

---Setup the plugin
---@param opts table|nil User configuration
function M.setup(opts)
  -- Merge config
  config.merge(opts)

  -- Set up highlights
  highlights.setup()

  -- Set up autocommands
  M.setup_autocmds()
end

---Set up autocommands
function M.setup_autocmds()
  local group = vim.api.nvim_create_augroup("Parley", { clear = true })

  -- Re-apply highlights when colorscheme changes
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      highlights.setup()
    end,
  })

  -- Auto-save session when leaving a buffer
  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    callback = function()
      local session = require("parley.session")
      local chat = require("parley.chat")
      local messages = chat.get_messages()
      if #messages > 1 then
        session.save()
      end
    end,
  })
end

---Toggle the chat panel
function M.toggle()
  panel.toggle()
end

---Open the chat panel
function M.open()
  panel.open()
end

---Close the chat panel
function M.close()
  panel.close()
end

---Attach the current visual selection as context
function M.attach_selection()
  local chips = require("parley.context_chips")
  chips.add_selection()
end

---Attach the current buffer as context
function M.attach_buffer()
  local chips = require("parley.context_chips")
  chips.add_buffer()
end

---Clear all context chips
function M.clear_context()
  local chips = require("parley.context_chips")
  chips.clear()
end

---Open the input area
function M.input()
  if not panel.is_visible() then
    panel.open()
  end
  input.open()
end

---Send a message to Ollama
---@param text string The user's message text
function M.send_message(text)
  if not text or text == "" then return end

  -- Ensure panel is open
  if not panel.is_visible() then
    panel.open()
  end

  -- Build the full message with context
  local full_message = chat.build_user_message(text)

  -- Add user message to session
  chat.add_message(nil, "user", full_message)

  -- Re-render to show the user message
  conversation.render()
  conversation.scroll_to_bottom()

  -- Show streaming indicator
  conversation.show_streaming_indicator()
  panel.start_spinner()

  -- Get the session for the API call
  local session = chat.get_session()
  local messages = chat.get_messages()

  -- Accumulate streamed tokens for session storage
  local accumulated_response = {}

  -- Start streaming
  cancel_current = http.stream_chat(
    messages,
    session.model,
    nil,  -- use default options
    -- on_chunk
    function(token)
      conversation.remove_streaming_indicator()
      conversation.append_stream_token(token)
      table.insert(accumulated_response, token)
    end,
    -- on_done
    function()
      cancel_current = nil
      panel.stop_spinner()
      panel.update_winbar()

      -- Store the full accumulated response in the session
      local full_response = table.concat(accumulated_response, "")
      if full_response ~= "" then
        chat.add_message(nil, "assistant", full_response)
      end
      accumulated_response = {}

      panel.update_winbar()
      panel.update_statusline()
      conversation.render()
      conversation.scroll_to_bottom()
    end,
    -- on_error
    function(err)
      cancel_current = nil
      accumulated_response = {}
      panel.stop_spinner()
      conversation.remove_streaming_indicator()
      panel.update_winbar()
      panel.update_statusline()
      vim.notify("Error: " .. err, vim.log.levels.ERROR, { title = "Parley" })
    end
  )

  -- Store cancel function in session
  chat.set_cancel_fn(nil, function()
    if cancel_current then
      cancel_current()
      cancel_current = nil
    end
  end)

  panel.update_winbar()
end

---Stop the current generation
function M.stop()
  chat.cancel()
  if cancel_current then
    cancel_current()
    cancel_current = nil
  end
  conversation.remove_streaming_indicator()
  panel.update_winbar()
  vim.notify("Generation stopped", vim.log.levels.INFO, { title = "Parley" })
end

---Clear the conversation
function M.clear()
  chat.clear_session()
  conversation.render()
  vim.notify("Conversation cleared", vim.log.levels.INFO, { title = "Parley" })
end

---Switch the model
function M.switch_model()
  local cfg = config.get()

  http.list_models(cfg.url, function(models, err)
    if err then
      vim.notify("Failed to list models: " .. err, vim.log.levels.ERROR, { title = "Parley" })
      return
    end

    if not models or #models == 0 then
      vim.notify("No models found. Is Ollama running?", vim.log.levels.WARN, { title = "Parley" })
      return
    end

    vim.ui.select(models, {
      prompt = "Select a model:",
      format_item = function(item)
        if item == chat.get_model() then
          return item .. " (current)"
        end
        return item
      end,
    }, function(selected)
      if selected then
        chat.set_model(nil, selected)
        panel.update_winbar()
        vim.notify("Model: " .. selected, vim.log.levels.INFO, { title = "Parley" })
      end
    end)
  end)
end

---Get the current status
---@return "IDLE" | "WORKING"
function M.status()
  if chat.is_active() then
    return "WORKING"
  end
  return "IDLE"
end

---Save the current conversation session
function M.save_session()
  local session = require("parley.session")
  session.save()
end

---Load a saved conversation session
function M.load_session()
  local session = require("parley.session")
  session.load()
end

return M
