local M = {}

local panel = require("parley.ui.panel")

---Get the code text from a code block in the chat buffer
---@param block table RenderedCodeBlock
---@return string|nil
function M.get_code_from_block(block)
  local buf = panel.get_bufnr()
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return nil end

  -- Code is between start_line+1 and end_line-1 (excluding ``` lines)
  local code_lines = vim.api.nvim_buf_get_lines(
    buf,
    block.start_line + 1,  -- after opening ```
    block.end_line,        -- before closing ```
    false
  )

  return table.concat(code_lines, "\n")
end

---Apply the code block under the cursor to the editor
function M.apply_under_cursor()
  local conv = require("parley.ui.conversation")
  local win = panel.get_winnr()
  if not win or not vim.api.nvim_win_is_valid(win) then return end

  local cursor = vim.api.nvim_win_get_cursor(win)
  local line = cursor[1] - 1  -- 0-based

  local block = conv.find_code_block_at(line)
  if not block then
    vim.notify("No code block under cursor", vim.log.levels.WARN, { title = "Parley" })
    return
  end

  local code = M.get_code_from_block(block)
  if not code or code == "" then
    vim.notify("Could not extract code from block", vim.log.levels.WARN, { title = "Parley" })
    return
  end

  -- Find the target: check context chips for a selection target
  local chips = require("parley.context_chips").get_all()
  local target_chip = nil
  for _, chip in ipairs(chips) do
    if chip.type == "selection" and chip.bufnr and chip.start_line then
      target_chip = chip
      break
    end
  end

  if target_chip and target_chip.bufnr and vim.api.nvim_buf_is_valid(target_chip.bufnr) then
    -- Replace the selection in the target buffer
    local code_lines = vim.split(code, "\n")
    vim.api.nvim_buf_set_lines(
      target_chip.bufnr,
      target_chip.start_line - 1,
      target_chip.end_line,
      false,
      code_lines
    )
    vim.notify(
      string.format("Applied to %s (lines %d-%d)", target_chip.label, target_chip.start_line, target_chip.end_line),
      vim.log.levels.INFO,
      { title = "Parley" }
    )
  else
    -- No target selection — insert at cursor in the editor
    local editor_win = panel.get_editor_winnr()
    if editor_win and vim.api.nvim_win_is_valid(editor_win) then
      vim.api.nvim_set_current_win(editor_win)
      local cursor_pos = vim.api.nvim_win_get_cursor(editor_win)
      local code_lines = vim.split(code, "\n")
      vim.api.nvim_buf_set_lines(
        0,
        cursor_pos[1],
        cursor_pos[1],
        false,
        code_lines
      )
      vim.notify("Inserted at cursor", vim.log.levels.INFO, { title = "Parley" })
    else
      vim.notify("No editor window found to apply code", vim.log.levels.WARN, { title = "Parley" })
    end
  end
end

---Copy the code block under cursor to the system clipboard
function M.copy_under_cursor()
  local conv = require("parley.ui.conversation")
  local win = panel.get_winnr()
  if not win or not vim.api.nvim_win_is_valid(win) then return end

  local cursor = vim.api.nvim_win_get_cursor(win)
  local line = cursor[1] - 1

  local block = conv.find_code_block_at(line)
  if not block then
    vim.notify("No code block under cursor", vim.log.levels.WARN, { title = "Parley" })
    return
  end

  local code = M.get_code_from_block(block)
  if not code or code == "" then
    vim.notify("Could not extract code from block", vim.log.levels.WARN, { title = "Parley" })
    return
  end

  -- Copy to clipboard
  vim.fn.setreg("+", code)
  vim.fn.setreg('"', code)
  vim.notify("Code copied to clipboard", vim.log.levels.INFO, { title = "Parley" })
end

---Show a diff between the code block and the target selection
function M.diff_under_cursor()
  local conv = require("parley.ui.conversation")
  local win = panel.get_winnr()
  if not win or not vim.api.nvim_win_is_valid(win) then return end

  local cursor = vim.api.nvim_win_get_cursor(win)
  local line = cursor[1] - 1

  local block = conv.find_code_block_at(line)
  if not block then
    vim.notify("No code block under cursor", vim.log.levels.WARN, { title = "Parley" })
    return
  end

  local code = M.get_code_from_block(block)
  if not code or code == "" then
    vim.notify("Could not extract code from block", vim.log.levels.WARN, { title = "Parley" })
    return
  end

  -- Find target
  local chips = require("parley.context_chips").get_all()
  local target_chip = nil
  for _, chip in ipairs(chips) do
    if chip.type == "selection" and chip.bufnr and chip.start_line then
      target_chip = chip
      break
    end
  end

  if not target_chip then
    vim.notify("No selection context to diff against. Attach a selection first.", vim.log.levels.WARN, { title = "Parley" })
    return
  end

  if not vim.api.nvim_buf_is_valid(target_chip.bufnr) then
    vim.notify("Target buffer no longer exists", vim.log.levels.ERROR, { title = "Parley" })
    return
  end

  -- Get original text
  local original_lines = vim.api.nvim_buf_get_lines(
    target_chip.bufnr,
    target_chip.start_line - 1,
    target_chip.end_line,
    false
  )

  -- Open a diff tab
  vim.cmd("tabnew")
  local orig_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, orig_buf)
  vim.api.nvim_buf_set_lines(orig_buf, 0, -1, false, original_lines)
  vim.bo[orig_buf].filetype = vim.bo[target_chip.bufnr].filetype
  vim.bo[orig_buf].modifiable = false
  vim.api.nvim_buf_set_name(orig_buf, "[Original] " .. (target_chip.label or "selection"))

  vim.cmd("diffthis")

  vim.cmd("vsplit")
  local new_buf = vim.api.nvim_create_buf(false, true)
  local code_lines = vim.split(code, "\n")
  vim.api.nvim_win_set_buf(0, new_buf)
  vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, code_lines)
  vim.bo[new_buf].filetype = vim.bo[target_chip.bufnr].filetype
  vim.api.nvim_buf_set_name(new_buf, "[AI Suggestion]")

  vim.cmd("diffthis")

  -- Add keymaps for accept/reject
  local function map(bufnr, lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = bufnr, noremap = true, silent = true, desc = desc })
  end

  -- Accept: replace original with new
  map(new_buf, "<C-y>", function()
    local new_content = vim.api.nvim_buf_get_lines(new_buf, 0, -1, false)
    vim.bo[target_chip.bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(
      target_chip.bufnr,
      target_chip.start_line - 1,
      target_chip.end_line,
      false,
      new_content
    )
    vim.cmd("tabclose")
    vim.notify("Changes applied", vim.log.levels.INFO, { title = "Parley" })
  end, "Accept changes")

  -- Reject: close diff
  map(new_buf, "<C-n>", function()
    vim.cmd("tabclose")
  end, "Reject changes")

  map(orig_buf, "<C-n>", function()
    vim.cmd("tabclose")
  end, "Reject changes")
end

return M
