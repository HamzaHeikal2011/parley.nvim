local M = {}

---Set up highlight groups for the chat UI.
---Links to existing groups so it works with any colorscheme.
function M.setup()
  -- Panel title (model name in winbar)
  vim.api.nvim_set_hl(0, "ParleyTitle", { link = "FloatTitle", default = true })
  vim.api.nvim_set_hl(0, "ParleyBar", { link = "WinBar", default = true })
  vim.api.nvim_set_hl(0, "ParleyModel", { link = "Comment", default = true })

  -- User messages
  vim.api.nvim_set_hl(0, "ParleyUser", { link = "Title", default = true })
  vim.api.nvim_set_hl(0, "ParleyUserPrefix", { link = "Identifier", default = true })

  -- Assistant messages
  vim.api.nvim_set_hl(0, "ParleyAssistant", { link = "Normal", default = true })
  vim.api.nvim_set_hl(0, "ParleyAssistantPrefix", { link = "Special", default = true })

  -- Context chips
  vim.api.nvim_set_hl(0, "ParleyChip", { link = "Label", default = true })
  vim.api.nvim_set_hl(0, "ParleyChipBorder", { link = "FloatBorder", default = true })

  -- Code block actions
  vim.api.nvim_set_hl(0, "ParleyAction", { link = "Function", default = true })
  vim.api.nvim_set_hl(0, "ParleyActionApply", { link = "String", default = true })
  vim.api.nvim_set_hl(0, "ParleyActionCopy", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "ParleyActionDiff", { link = "Type", default = true })

  -- Status indicators
  vim.api.nvim_set_hl(0, "ParleyStatusIdle", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "ParleyStatusWorking", { link = "WarningMsg", default = true })
  vim.api.nvim_set_hl(0, "ParleyStatusDone", { link = "MoreMsg", default = true })
  vim.api.nvim_set_hl(0, "ParleyStatusError", { link = "ErrorMsg", default = true })

  -- Separator
  vim.api.nvim_set_hl(0, "ParleySeparator", { link = "WinSeparator", default = true })

  -- Status line hints
  vim.api.nvim_set_hl(0, "ParleyHint", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "ParleyHintAction", { link = "Function", default = true })

  -- Welcome screen
  vim.api.nvim_set_hl(0, "ParleyWelcome", { link = "Title", default = true })
  vim.api.nvim_set_hl(0, "ParleyWelcomeKey", { link = "Special", default = true })
  vim.api.nvim_set_hl(0, "ParleyWelcomeSection", { link = "Type", default = true })

  -- Input area
  vim.api.nvim_set_hl(0, "ParleyInputPrompt", { link = "Identifier", default = true })
end

return M
