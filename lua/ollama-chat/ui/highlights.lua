local M = {}

---Set up highlight groups for the chat UI.
---Links to existing groups so it works with any colorscheme.
function M.setup()
  -- Panel title (model name in winbar)
  vim.api.nvim_set_hl(0, "OllamaChatTitle", { link = "FloatTitle", default = true })
  vim.api.nvim_set_hl(0, "OllamaChatBar", { link = "WinBar", default = true })
  vim.api.nvim_set_hl(0, "OllamaChatModel", { link = "Comment", default = true })

  -- User messages
  vim.api.nvim_set_hl(0, "OllamaChatUser", { link = "Title", default = true })
  vim.api.nvim_set_hl(0, "OllamaChatUserPrefix", { link = "Identifier", default = true })

  -- Assistant messages
  vim.api.nvim_set_hl(0, "OllamaChatAssistant", { link = "Normal", default = true })
  vim.api.nvim_set_hl(0, "OllamaChatAssistantPrefix", { link = "Special", default = true })

  -- Context chips
  vim.api.nvim_set_hl(0, "OllamaChatChip", { link = "Label", default = true })
  vim.api.nvim_set_hl(0, "OllamaChatChipBorder", { link = "FloatBorder", default = true })

  -- Code block actions
  vim.api.nvim_set_hl(0, "OllamaChatAction", { link = "Function", default = true })
  vim.api.nvim_set_hl(0, "OllamaChatActionApply", { link = "String", default = true })
  vim.api.nvim_set_hl(0, "OllamaChatActionCopy", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "OllamaChatActionDiff", { link = "Type", default = true })

  -- Status indicators
  vim.api.nvim_set_hl(0, "OllamaChatStatusIdle", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "OllamaChatStatusWorking", { link = "WarningMsg", default = true })
  vim.api.nvim_set_hl(0, "OllamaChatStatusDone", { link = "MoreMsg", default = true })
  vim.api.nvim_set_hl(0, "OllamaChatStatusError", { link = "ErrorMsg", default = true })

  -- Separator
  vim.api.nvim_set_hl(0, "OllamaChatSeparator", { link = "WinSeparator", default = true })

  -- Input area
  vim.api.nvim_set_hl(0, "OllamaChatInputPrompt", { link = "Identifier", default = true })
end

return M
