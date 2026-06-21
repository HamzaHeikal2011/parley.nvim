local M = {}

local panel = require("ollama-chat.ui.panel")

local state = {
  bufnr = nil,
  winnr = nil,
}

---Open the input area at the bottom of the chat panel
function M.open()
  -- If input is already open, just focus it
  if state.winnr and vim.api.nvim_win_is_valid(state.winnr) then
    vim.api.nvim_set_current_win(state.winnr)
    vim.cmd("startinsert!")
    return
  end

  local chat_win = panel.get_winnr()
  if not chat_win or not vim.api.nvim_win_is_valid(chat_win) then
    vim.notify("Chat panel is not open", vim.log.levels.WARN, { title = "Ollama Chat" })
    return
  end

  -- Focus the chat window first
  vim.api.nvim_set_current_win(chat_win)

  -- Create a horizontal split at the bottom
  vim.cmd("belowright split")

  local input_win = vim.api.nvim_get_current_win()
  local cfg = require("ollama-chat.config").get()

  -- Set height
  vim.api.nvim_win_set_height(input_win, 3)

  -- Create input buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(input_win, buf)

  vim.bo[buf].buftype = "prompt"
  vim.bo[buf].filetype = "ollama-chat-input"
  vim.bo[buf].swapfile = false

  -- Set up prompt
  vim.fn.prompt_setprompt(buf, " > ")

  -- Auto-resize as user types
  vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = buf,
    callback = function()
      local line_count = vim.api.nvim_buf_line_count(buf)
      local height = math.min(math.max(line_count + 1, 3), 12)
      pcall(vim.api.nvim_win_set_height, input_win, height)
    end,
  })

  -- Keymaps for the input buffer
  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, {
      buffer = buf,
      noremap = true,
      silent = true,
      desc = desc,
    })
  end

  -- Submit on Ctrl+Enter
  map("i", cfg.keymaps.submit or "<C-CR>", function()
    M.submit()
  end, "Submit message")

  -- Also allow Enter for single-line, Ctrl+Enter for multiline
  map("i", "<CR>", function()
    local line_count = vim.api.nvim_buf_line_count(buf)
    if line_count == 1 then
      M.submit()
    else
      -- In multiline, Enter adds a new line; Ctrl+Enter submits
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
    end
  end, "New line or submit")

  -- Close input on Escape
  map("i", "<Esc>", function()
    M.close_input()
  end, "Close input")

  -- Stop generation
  map("i", cfg.keymaps.stop or "<C-c>", function()
    require("ollama-chat.chat").cancel()
    vim.notify("Generation stopped", vim.log.levels.INFO, { title = "Ollama Chat" })
  end, "Stop generation")

  state.bufnr = buf
  state.winnr = input_win

  -- Start in insert mode
  vim.cmd("startinsert!")
end

---Close the input window
function M.close_input()
  if state.winnr and vim.api.nvim_win_is_valid(state.winnr) then
    vim.api.nvim_win_close(state.winnr, true)
  end
  state.bufnr = nil
  state.winnr = nil

  -- Return focus to chat panel
  local chat_win = panel.get_winnr()
  if chat_win and vim.api.nvim_win_is_valid(chat_win) then
    vim.api.nvim_set_current_win(chat_win)
  end
end

---Get the text from the input buffer and clear it
---@return string
function M.get_and_clear()
  if not state.bufnr or not vim.api.nvim_buf_is_valid(state.bufnr) then
    return ""
  end

  local lines = vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)
  local text = table.concat(lines, "\n")

  -- Remove the prompt prefix
  text = text:gsub("^ > ", "")

  -- Clear the buffer
  vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, { "" })

  return text
end

---Submit the current input
function M.submit()
  local text = M.get_and_clear()

  if text == "" or not text:match("%S") then
    return
  end

  -- Close the input window
  M.close_input()

  -- Send to the chat module
  local chat_mod = require("ollama-chat")
  chat_mod.send_message(text)
end

return M
