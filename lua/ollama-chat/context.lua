local M = {}

---@class OllamaChat.Selection
---@field text string The selected text
---@field start_line number 1-based start line
---@field start_col number 1-based start col
---@field end_line number 1-based end line
---@field end_col number 1-based end col
---@field bufnr number Buffer number

---Get the current visual selection with position info.
---Works in visual, visual-line, and visual-block modes.
---@return OllamaChat.Selection|nil
function M.get_visual_selection()
  -- Check if we have a valid selection
  local mode = vim.fn.visualmode()
  if mode == "" or mode == nil then
    -- Not in visual mode — try to use the last visual selection
    mode = vim.fn.visualmode(1)
    if mode == "" or mode == nil then
      return nil
    end
  end

  local sel_start = vim.fn.getpos("'<")
  local sel_end = vim.fn.getpos("'>")

  if not sel_start or not sel_end then
    return nil
  end

  local start_line = sel_start[2]
  local start_col = sel_start[3]
  local end_line = sel_end[2]
  local end_col = sel_end[3]

  if start_line == 0 or end_line == 0 then
    return nil
  end

  -- For visual-line mode, select full lines
  if mode == "V" then
    start_col = 1
    end_col = #vim.fn.getline(end_line)
  end

  -- For visual-block mode, we'd need different handling
  -- For now, treat it like character-wise

  -- Validate positions
  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end

  -- Get the text (0-based API)
  local lines = vim.api.nvim_buf_get_text(
    0,
    start_line - 1,
    start_col - 1,
    end_line - 1,
    end_col,
    {}
  )

  local text = table.concat(lines, "\n")

  if text == "" then
    return nil
  end

  return {
    text = text,
    start_line = start_line,
    start_col = start_col,
    end_line = end_line,
    end_col = end_col,
    bufnr = vim.api.nvim_get_current_buf(),
  }
end

---Get the current buffer's filetype
---@return string
function M.get_filetype()
  return vim.bo.filetype
end

---Get the current buffer's filename
---@return string
function M.get_filename()
  return vim.fn.expand("%:t")
end

---Get the current buffer's full path
---@return string
function M.get_filepath()
  return vim.fn.expand("%:p")
end

---Get lines around the cursor for context
---@param context_lines number Number of lines before and after cursor
---@return string
function M.get_cursor_context(context_lines)
  context_lines = context_lines or 10
  local cursor_line = vim.fn.line(".")
  local total_lines = vim.api.nvim_buf_line_count(0)

  local start_line = math.max(1, cursor_line - context_lines)
  local end_line = math.min(total_lines, cursor_line + context_lines)

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  return table.concat(lines, "\n")
end

---Get the full buffer content (truncated to max_lines)
---@param max_lines number|nil
---@return string
function M.get_buffer_content(max_lines)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  if max_lines and #lines > max_lines then
    lines = vim.list_slice(lines, 1, max_lines)
    table.insert(lines, "... (truncated)")
  end
  return table.concat(lines, "\n")
end

---Build a context string from a selection for the LLM
---@param sel OllamaChat.Selection
---@return string
function M.format_selection_context(sel)
  local ft = M.get_filetype()
  local fname = M.get_filename()

  return string.format(
    "File: %s (lines %d-%d, %s)\n```%s\n%s\n```",
    fname,
    sel.start_line,
    sel.end_line,
    ft,
    ft,
    sel.text
  )
end

return M
