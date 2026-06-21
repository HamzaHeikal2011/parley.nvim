local M = {}

---@class OllamaChat.ContextChip
---@field id string Unique ID
---@field type "selection" | "buffer" | "file" | "lines"
---@field label string Display label
---@field content string The actual text content
---@field path string|nil File path
---@field bufnr number|nil Buffer number
---@field start_line number|nil
---@field end_line number|nil

---@type OllamaChat.ContextChip[]
local chips = {}

local id_counter = 0

local function next_id()
  id_counter = id_counter + 1
  return "chip_" .. tostring(id_counter)
end

---Add a context chip from visual selection
---@return boolean true if a chip was added
function M.add_selection()
  local ctx = require("ollama-chat.context")
  local sel = ctx.get_visual_selection()
  if not sel or sel.text == "" then
    vim.notify("No selection to attach", vim.log.levels.WARN, { title = "Ollama Chat" })
    return false
  end

  local ft = ctx.get_filetype()
  local cfg = require("ollama-chat.config").get()
  local text = sel.text

  -- Truncate if too many lines
  local lines = vim.split(text, "\n")
  if #lines > cfg.max_context_lines then
    lines = vim.list_slice(lines, 1, cfg.max_context_lines)
    text = table.concat(lines, "\n") .. "\n... (truncated)"
  end

  -- Check for duplicates
  for _, existing in ipairs(chips) do
    if existing.content == text then
      vim.notify("Selection already attached", vim.log.levels.INFO, { title = "Ollama Chat" })
      return false
    end
  end

  local chip = {
    id = next_id(),
    type = "selection",
    label = string.format("%s:%d-%d", ctx.get_filename(), sel.start_line, sel.end_line),
    content = text,
    path = ctx.get_filepath(),
    bufnr = sel.bufnr,
    start_line = sel.start_line,
    end_line = sel.end_line,
  }

  table.insert(chips, chip)
  vim.notify(string.format("Attached: %s", chip.label), vim.log.levels.INFO, { title = "Ollama Chat" })
  return true
end

---Add a context chip from the entire buffer
---@return boolean
function M.add_buffer()
  local ctx = require("ollama-chat.context")
  local cfg = require("ollama-chat.config").get()
  local path = ctx.get_filepath()
  local fname = ctx.get_filename()

  if path == "" or fname == "" then
    vim.notify("No buffer to attach", vim.log.levels.WARN, { title = "Ollama Chat" })
    return false
  end

  -- Check for duplicates
  for _, existing in ipairs(chips) do
    if existing.type == "buffer" and existing.path == path then
      vim.notify("Buffer already attached", vim.log.levels.INFO, { title = "Ollama Chat" })
      return false
    end
  end

  local content = ctx.get_buffer_content(cfg.max_context_lines)
  local line_count = vim.api.nvim_buf_line_count(0)

  local chip = {
    id = next_id(),
    type = "buffer",
    label = string.format("%s (%d lines)", fname, line_count),
    content = content,
    path = path,
    bufnr = vim.api.nvim_get_current_buf(),
  }

  table.insert(chips, chip)
  vim.notify(string.format("Attached: %s", chip.label), vim.log.levels.INFO, { title = "Ollama Chat" })
  return true
end

---Remove a chip by index
---@param index number 1-based index
function M.remove(index)
  if chips[index] then
    local label = chips[index].label
    table.remove(chips, index)
    vim.notify(string.format("Removed: %s", label), vim.log.levels.INFO, { title = "Ollama Chat" })
  end
end

---Remove a chip by id
---@param id string
function M.remove_by_id(id)
  for i, chip in ipairs(chips) do
    if chip.id == id then
      table.remove(chips, i)
      return
    end
  end
end

---Get all chips
---@return OllamaChat.ContextChip[]
function M.get_all()
  return chips
end

---Clear all chips
function M.clear()
  local count = #chips
  chips = {}
  vim.notify(string.format("Cleared %d context chip(s)", count), vim.log.levels.INFO, { title = "Ollama Chat" })
end

---Build the full context string from all chips for the LLM
---@return string
function M.build_context()
  if #chips == 0 then
    return ""
  end

  local ctx = require("ollama-chat.context")
  local ft = ctx.get_filetype()
  local parts = {}

  -- Always include current file info as implicit context
  local fname = ctx.get_filename()
  if fname and fname ~= "" then
    table.insert(parts, string.format("[Current file: %s (%s)]", fname, ft))
  end

  for _, chip in ipairs(chips) do
    if chip.type == "selection" then
      table.insert(parts, string.format(
        "Selected from %s (lines %d-%d):\n```%s\n%s\n```",
        chip.label,
        chip.start_line or 0,
        chip.end_line or 0,
        ft,
        chip.content
      ))
    elseif chip.type == "buffer" then
      table.insert(parts, string.format(
        "File %s:\n```\n%s\n```",
        chip.label,
        chip.content
      ))
    end
  end

  return table.concat(parts, "\n\n")
end

---Build just the labels for display
---@return string[]
function M.get_labels()
  local labels = {}
  for _, chip in ipairs(chips) do
    table.insert(labels, chip.label)
  end
  return labels
end

---Get the count of chips
---@return number
function M.count()
  return #chips
end

return M
