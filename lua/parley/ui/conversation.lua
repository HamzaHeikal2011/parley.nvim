local M = {}

local panel = require("parley.ui.panel")

---@class RenderedCodeBlock
---@field start_line number 0-based line number of ``` line
---@field end_line number 0-based line number of closing ```
---@field lang string language tag
---@field action_line number 0-based line of the action buttons

---@type RenderedCodeBlock[]
local code_blocks = {}

---Render the full conversation in the chat buffer
function M.render()
  local buf = panel.get_bufnr()
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return
end

  local chat = require("parley.chat")
  local messages = chat.get_messages()
  local ns_id = panel.get_ns_id()

  code_blocks = {}
  local lines = {}
  local extmarks = {}

  for _, msg in ipairs(messages) do
    if msg.role == "system" then
      -- Don't render system prompt
      goto continue
    end

    if msg.role == "user" then
      -- User message header
      table.insert(lines, "## 👤 You")
      table.insert(lines, "")

      -- Extract context chips from the message (they're prepended before the actual user text)
      local user_text = msg.content
      local chip_lines = {}

      -- Context chips are formatted as [Current file: ...] or Selected from ... or File: ...
      -- We display them as chips, then the user's actual question
      local context_end = 0
      local in_context = false

      for line in (user_text .. "\n"):gmatch("([^\n]*)\n") do
        if line:match("^%[Current file:") or line:match("^Selected from") or line:match("^File:") then
          table.insert(chip_lines, line)
          context_end = #lines + #chip_lines + 1
          in_context = true
        elseif line == "" and in_context then
          -- End of context section
          in_context = false
        end
      end

      -- Add chip display lines
      for _, chip_line in ipairs(chip_lines) do
        table.insert(lines, "  📎 `" .. chip_line .. "`")
      end

      if #chip_lines > 0 then
        table.insert(lines, "")
      end

      -- Add the user's actual question (strip context prefix)
      local question = user_text
      -- Remove context section (everything up to and including the first ``` closing)
      local after_context = user_text:match("```%s*\n\n(.*)")
      if after_context then
        question = after_context:match("^%s*(.*)") or after_context
      end

      for line in (question .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(lines, line)
      end

      table.insert(lines, "")
      table.insert(lines, "─" .. string.rep("─", 50))
      table.insert(lines, "")

    elseif msg.role == "assistant" then
      -- Assistant message header
      table.insert(lines, "## 🦙 Assistant")
      table.insert(lines, "")

      -- Parse markdown and extract code blocks
      local in_code = false
      local code_lang = ""
      local code_start_line = 0
      local code_content = {}

      for line in (msg.content .. "\n"):gmatch("([^\n]*)\n") do
        local lang = line:match("^```(%S+)")
        if lang and not in_code then
          in_code = true
          code_lang = lang
          code_start_line = #lines
          table.insert(lines, line)
        elseif line:match("^```%s*$") and in_code then
          in_code = false
          table.insert(lines, line)

          local action_line = #lines + 1
          table.insert(lines, "")
          table.insert(lines, string.format(
            "  [Apply](apply:%d)  [Copy](copy:%d)  [Diff](diff:%d)",
            code_start_line, code_start_line, code_start_line
          ))
          table.insert(lines, "")

          -- Record for action handling
          table.insert(code_blocks, {
            start_line = code_start_line,
            end_line = #lines - 4,  -- the ``` line
            lang = code_lang,
            action_line = action_line - 2,  -- 0-based: the action buttons line
          })

          code_lang = ""
        elseif in_code then
          table.insert(lines, line)
        else
          table.insert(lines, line)
        end
      end

      table.insert(lines, "")
      table.insert(lines, "─" .. string.rep("─", 50))
      table.insert(lines, "")
    end

    ::continue::
  end

  -- If no messages yet, show a welcome message
  if #messages <= 1 then  -- only system prompt
    table.insert(lines, "Welcome to Parley!")
    table.insert(lines, "")
    table.insert(lines, "Usage:")
    table.insert(lines, "  • Select code in visual mode, then press " .. require("parley.config").get().keymaps.attach_selection .. " to attach it")
    table.insert(lines, "  • Press 'i' or 'a' in this panel to open the input")
    table.insert(lines, "  • Type your question and press Ctrl+Enter to send")
    table.insert(lines, "  • Code blocks in responses have [Apply] [Copy] [Diff] actions")
    table.insert(lines, "")
  end

  -- Write to buffer
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  -- Apply highlights
  M.apply_highlights(buf, ns_id, lines)
end

---Apply syntax highlights to rendered lines
---@param bufnr number
---@param ns_id number
---@param lines string[]
function M.apply_highlights(bufnr, ns_id, lines)
  for i, line in ipairs(lines) do
    local lnum = i - 1  -- 0-based

    -- User/Assistant headers
    if line:match("^## 👤") then
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, 0, {
        end_col = #line,
        hl_group = "ParleyUser",
      })
    elseif line:match("^## 🦙") then
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, 0, {
        end_col = #line,
        hl_group = "ParleyAssistant",
      })
    end

    -- Chip lines
    if line:match("^%s*📎") then
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, 0, {
        end_col = #line,
        hl_group = "ParleyChip",
      })
    end

    -- Action buttons
    if line:match("%[Apply%]") then
      local s, e = line:match("()%[Apply%]()")
      if s then
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, s - 1, {
          end_col = e,
          hl_group = "ParleyActionApply",
        })
      end
      s, e = line:match("()%[Copy%]()")
      if s then
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, s - 1, {
          end_col = e,
          hl_group = "ParleyActionCopy",
        })
      end
      s, e = line:match("()%[Diff%]()")
      if s then
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, s - 1, {
          end_col = e,
          hl_group = "ParleyActionDiff",
        })
      end
    end

    -- Separators
    if line:match("^─+") then
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, lnum, 0, {
        end_col = #line,
        hl_group = "ParleySeparator",
      })
    end
  end
end

---Get the code blocks from the last render
---@return RenderedCodeBlock[]
function M.get_code_blocks()
  return code_blocks
end

---Find the code block at a given line
---@param line number 0-based line number
---@return RenderedCodeBlock|nil
function M.find_code_block_at(line)
  for _, block in ipairs(code_blocks) do
    -- The code block spans from start_line to end_line
    -- Action buttons are at action_line
    if line >= block.start_line and line <= block.end_line + 3 then
      return block
    end
  end
  return nil
end

---Append a streaming token to the last line being built
---@param text string
function M.append_stream_token(text)
  local buf = panel.get_bufnr()
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end

  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buf) then return end

    vim.bo[buf].modifiable = true

    local line_count = vim.api.nvim_buf_line_count(buf)
    if line_count == 0 then
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })
    else
      -- Get the last line and append
      local last_line = vim.api.nvim_buf_get_lines(buf, -2, -1, false)[1] or ""
      local new_last = last_line .. text
      -- Split on newlines in case the text contains them
      local new_lines = vim.split(new_last, "\n", { plain = true })
      vim.api.nvim_buf_set_lines(buf, -2, -1, false, new_lines)
    end

    vim.bo[buf].modifiable = false

    -- Scroll to bottom
    M.scroll_to_bottom()
  end)
end

---Scroll the chat window to the bottom
function M.scroll_to_bottom()
  local win = panel.get_winnr()
  if not win or not vim.api.nvim_win_is_valid(win) then return end

  local buf = panel.get_bufnr()
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end

  local line_count = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_win_set_cursor(win, { line_count, 0 })
end

---Show a streaming indicator
function M.show_streaming_indicator()
  local buf = panel.get_bufnr()
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "", "  ⏳ Generating..." })
  vim.bo[buf].modifiable = false
  M.scroll_to_bottom()
end

---Remove the streaming indicator
function M.remove_streaming_indicator()
  local buf = panel.get_bufnr()
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end

  local line_count = vim.api.nvim_buf_line_count(buf)
  if line_count >= 2 then
    local last_lines = vim.api.nvim_buf_get_lines(buf, -3, -1, false)
    if last_lines[2] and last_lines[2]:match("⏳") then
      vim.bo[buf].modifiable = true
      vim.api.nvim_buf_set_lines(buf, -3, -1, false, { "" })
      vim.bo[buf].modifiable = false
    end
  end
end

return M
