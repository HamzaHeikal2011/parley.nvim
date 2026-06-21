---@class OllamaChat.Config
---@field url string Ollama server URL
---@field model string Default model name
---@field temperature number Sampling temperature (0.0-2.0)
---@field num_ctx number Context window size
---@field system_prompt string System prompt for the model
---@field panel_width number Panel width ratio (0.0-1.0)
---@field panel_position "right" | "left" Panel position
---@field max_context_lines number Max lines of context to auto-attach
---@field keymaps OllamaChat.Keymaps Keybinding overrides

---@class OllamaChat.Keymaps
---@field toggle string Toggle chat panel
---@field attach_selection string Attach visual selection
---@field attach_buffer string Attach entire buffer
---@field clear_context string Clear context chips
---@field switch_model string Switch model
---@field submit string Submit message (in input)
---@field stop string Stop generation
---@field close string Close panel
---@field clear_conversation string Clear conversation
---@field apply_code string Apply code block
---@field copy_code string Copy code block
---@field show_diff string Show diff for code block

local M = {}

---@type OllamaChat.Config
M.defaults = {
  url = "http://127.0.0.1:11434",
  model = "qwen2.5-coder:7b",
  temperature = 0.2,
  num_ctx = 8192,
  system_prompt = [[You are a concise coding assistant integrated into Neovim.
- Provide brief, accurate explanations
- Use markdown code blocks with language tags for all code
- When asked to modify code, show the complete modified version
- Prefer practical solutions over theoretical discussion
- If you need more context, ask for it specifically]],

  panel_width = 0.3,
  panel_position = "right",
  max_context_lines = 100,

  keymaps = {
    toggle = "<leader>oc",
    attach_selection = "<leader>oa",
    attach_buffer = "<leader>ob",
    clear_context = "<leader>ox",
    switch_model = "<leader>om",
    submit = "<C-CR>",
    stop = "<C-c>",
    close = "q",
    clear_conversation = "<C-l>",
    apply_code = "<C-y>",
    copy_code = "<C-d>",
    show_diff = "<C-f>",
  },
}

---@type OllamaChat.Config
M.current = {}

---Validate a user config table
---@param cfg table
---@return boolean ok
---@return string|nil err
function M.validate(cfg)
  local ok, err = pcall(vim.validate, {
    url = { cfg.url, "string" },
    model = { cfg.model, "string" },
    temperature = { cfg.temperature, "number", true },
    num_ctx = { cfg.num_ctx, "number", true },
    system_prompt = { cfg.system_prompt, "string", true },
    panel_width = { cfg.panel_width, "number", true },
    panel_position = { cfg.panel_position, { "right", "left" }, true },
    max_context_lines = { cfg.max_context_lines, "number", true },
  })
  if not ok then
    return false, "ollama-chat config: " .. tostring(err)
  end
  return true, nil
end

---Merge user opts into defaults with validation
---@param opts table|nil
---@return OllamaChat.Config
function M.merge(opts)
  opts = opts or {}
  local merged = vim.tbl_deep_extend("force", M.defaults, opts)
  local ok, err = M.validate(merged)
  if not ok then
    vim.notify(err, vim.log.levels.ERROR, { title = "ollama-chat" })
    vim.notify("Falling back to default config", vim.log.levels.WARN, { title = "ollama-chat" })
    merged = vim.deepcopy(M.defaults)
  end
  M.current = merged
  return M.current
end

---Get the current config (or default if not setup yet)
---@return OllamaChat.Config
function M.get()
  if M.current and M.current.url then
    return M.current
  end
  return M.defaults
end

return M
