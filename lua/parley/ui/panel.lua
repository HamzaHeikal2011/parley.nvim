local M = {}

---@class PanelState
local state = {
  bufnr = nil,       -- the main chat buffer
  winnr = nil,       -- the chat window (right panel)
  input_bufnr = nil, -- the input buffer
  input_winnr = nil, -- the input window
  ns_id = nil,       -- namespace for extmarks
  is_visible = false,
  editor_winnr = nil, -- the editor window we came from
}

---Get or create the chat buffer (reused across open/close)
---@return number bufnr
function M.get_or_create_buf()
  if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
    return state.bufnr
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "[Parley]")

  -- Buffer options
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false
  vim.bo[buf].swapfile = false
  vim.bo[buf].bufhidden = "hide"

  state.bufnr = buf
  return buf
end

---Open or toggle the side panel
function M.open()
  local cfg = require("parley.config").get()

  -- If already visible, close it
  if state.is_visible and state.winnr and vim.api.nvim_win_is_valid(state.winnr) then
    M.close()
    return
  end

  -- If window exists but was closed (e.g. user closed it), recreate
  if state.winnr and not vim.api.nvim_win_is_valid(state.winnr) then
    state.winnr = nil
    state.is_visible = false
  end

  -- Remember the current window (the editor)
  state.editor_winnr = vim.api.nvim_get_current_win()

  -- Create the chat buffer
  local buf = M.get_or_create_buf()

  -- Create a vertical split on the right
  if cfg.panel_position == "right" then
    vim.cmd("botright vsplit")
  else
    vim.cmd("topleft vsplit")
  end

  local chat_win = vim.api.nvim_get_current_win()

  -- Set width
  local total_width = vim.o.columns
  local panel_cols = math.floor(total_width * cfg.panel_width)
  if panel_cols < 35 then panel_cols = 35 end
  if panel_cols > 120 then panel_cols = 120 end
  vim.api.nvim_win_set_width(chat_win, panel_cols)

  -- Set the buffer
  vim.api.nvim_win_set_buf(chat_win, buf)

  -- Window options
  vim.wo[chat_win].wrap = true
  vim.wo[chat_win].linebreak = true
  vim.wo[chat_win].number = false
  vim.wo[chat_win].relativenumber = false
  vim.wo[chat_win].signcolumn = "no"
  vim.wo[chat_win].cursorline = false
  vim.wo[chat_win].winbar = M.render_winbar()
  vim.wo[chat_win].statusline = M.render_statusline()

  -- Create namespace for extmarks
  state.ns_id = vim.api.nvim_create_namespace("parley")

  state.winnr = chat_win
  state.is_visible = true

  -- Render the conversation
  require("parley.ui.conversation").render()

  -- Set up buffer-local keymaps
  M.setup_keymaps(buf)

  -- Auto-command to clean up when buffer is wiped
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      state.is_visible = false
      state.winnr = nil
    end,
  })

  -- Auto-update status line on cursor movement and mode changes
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "ModeChanged" }, {
    buffer = buf,
    callback = function()
      M.update_statusline()
    end,
  })
end

---Close the side panel and return focus to editor
function M.close()
  if state.winnr and vim.api.nvim_win_is_valid(state.winnr) then
    vim.api.nvim_win_close(state.winnr, true)
  end
  state.is_visible = false
  state.winnr = nil

  -- Return focus to editor
  if state.editor_winnr and vim.api.nvim_win_is_valid(state.editor_winnr) then
    vim.api.nvim_set_current_win(state.editor_winnr)
  end
end

---Toggle the panel
function M.toggle()
  if state.is_visible then
    M.close()
  else
    M.open()
  end
end

---Check if panel is visible
---@return boolean
function M.is_visible()
  return state.is_visible and state.winnr ~= nil and vim.api.nvim_win_is_valid(state.winnr)
end

---Get the chat window handle
---@return number|nil
function M.get_winnr()
  return state.winnr
end

---Get the chat buffer handle
---@return number|nil
function M.get_bufnr()
  return state.bufnr
end

---Get the namespace id for extmarks
---@return number|nil
function M.get_ns_id()
  return state.ns_id
end

---Get the editor window handle
---@return number|nil
function M.get_editor_winnr()
  return state.editor_winnr
end

---Render the winbar (top bar of the panel)
---@return string
function M.render_winbar()
  local chat = require("parley.chat")
  local model = chat.get_model()
  local status = chat.is_active() and M.spinner_char .. " Working" or ""
  return string.format(
    " %%#ParleyTitle#🦙 Parley%%#ParleyBar# │ %%#ParleyModel#%s%s %%*",
    model,
    status
  )
end

---Spinner animation state
local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spinner_index = 1
local spinner_timer = nil

---Start the spinner animation
function M.start_spinner()
  if spinner_timer then return end
  spinner_timer = vim.uv.new_timer()
  spinner_timer:start(0, 80, vim.schedule_wrap(function()
    spinner_index = (spinner_index % #spinner_frames) + 1
    M.update_winbar()
  end))
end

---Stop the spinner animation
function M.stop_spinner()
  if spinner_timer then
    spinner_timer:stop()
    spinner_timer:close()
    spinner_timer = nil
  end
  M.update_winbar()
end

---Get the current spinner character
---@return string
function M.spinner_char()
  return spinner_frames[spinner_index]
end

---Update the winbar (e.g. when model changes or status changes)
function M.update_winbar()
  if state.winnr and vim.api.nvim_win_is_valid(state.winnr) then
    vim.wo[state.winnr].winbar = M.render_winbar()
  end
end

---Render the status line (bottom hint bar) with keybind info
---@return string
function M.render_statusline()
  local cfg = require("parley.config").get()
  local km = cfg.keymaps
  local chat = require("parley.chat")

  -- Build key hints
  local hints = {}

  -- Always-visible: close, clear, stop
  table.insert(hints, string.format("%%#ParleyHint#%s%%* Close", km.close or "q"))
  table.insert(hints, string.format("%%#ParleyHint#%s%%* Clear", km.clear_conversation or "<C-l>"))
  table.insert(hints, string.format("%%#ParleyHint#%s%%* Stop", km.stop or "<C-c>"))

  -- Code block actions (contextual — shown when cursor is on a code block)
  table.insert(hints, string.format("%%#ParleyHintAction#%s%%* Apply", km.apply_code or "<C-y>"))
  table.insert(hints, string.format("%%#ParleyHintAction#%s%%* Copy", km.copy_code or "<C-d>"))
  table.insert(hints, string.format("%%#ParleyHintAction#%s%%* Diff", km.show_diff or "<C-f>"))

  -- Status indicator
  local status_hl = chat.is_active() and "ParleyStatusWorking" or "ParleyStatusIdle"
  local status_text = chat.is_active() and "⏳ Generating..." or "Ready"

  local hint_str = table.concat(hints, " │ ")
  return string.format(
    " %s │ %%#%s#%%* %s",
    hint_str,
    status_hl,
    status_text
  )
end

---Update the status line (e.g. when status changes)
function M.update_statusline()
  if state.winnr and vim.api.nvim_win_is_valid(state.winnr) then
    vim.wo[state.winnr].statusline = M.render_statusline()
  end
end

---Set up buffer-local keymaps for the chat panel
---@param bufnr number
function M.setup_keymaps(bufnr)
  local cfg = require("parley.config").get()
  local km = cfg.keymaps

  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, {
      buffer = bufnr,
      noremap = true,
      silent = true,
      desc = desc,
    })
  end

  -- Close panel
  map("n", km.close or "q", function() M.close() end, "Close chat panel")

  -- Clear conversation
  map("n", km.clear_conversation or "<C-l>", function()
    require("parley.chat").clear_session()
    require("parley.ui.conversation").render()
  end, "Clear conversation")

  -- Stop generation
  map("n", km.stop or "<C-c>", function()
    require("parley.chat").cancel()
    vim.notify("Generation stopped", vim.log.levels.INFO, { title = "Parley" })
  end, "Stop generation")

  -- Open input
  map("n", "i", function()
    require("parley.ui.input").open()
  end, "Open input")

  map("n", "a", function()
    require("parley.ui.input").open()
  end, "Open input (append)")

  -- Apply code block under cursor
  map("n", km.apply_code or "<C-y>", function()
    require("parley.ui.diff").apply_under_cursor()
  end, "Apply code block")

  -- Copy code block under cursor
  map("n", km.copy_code or "<C-d>", function()
    require("parley.ui.diff").copy_under_cursor()
  end, "Copy code block")

  -- Show diff for code block under cursor
  map("n", km.show_diff or "<C-f>", function()
    require("parley.ui.diff").diff_under_cursor()
  end, "Show diff for code block")
end

return M
