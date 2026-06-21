-- ollama-chat.nvim
-- Entry point: lazy-load guard, commands, and <Plug> mappings

if vim.g.loaded_ollama_chat then
  return
end
vim.g.loaded_ollama_chat = true

local function cmd(name, fn, opts)
  opts = opts or {}
  vim.api.nvim_create_user_command(name, fn, opts)
end

-- Commands
cmd("OllamaChat", function(opts)
  local sub = opts.fargs[1]
  local chat = require("ollama-chat")
  if sub == "open" or sub == nil then
    chat.open()
  elseif sub == "close" then
    chat.close()
  elseif sub == "toggle" then
    chat.toggle()
  elseif sub == "input" then
    chat.input()
  elseif sub == "stop" then
    chat.stop()
  elseif sub == "clear" then
    chat.clear()
  elseif sub == "model" then
    chat.switch_model()
  elseif sub == "attach" then
    if opts.range > 0 then
      -- Called from visual mode with range
      chat.attach_selection()
    else
      chat.attach_buffer()
    end
  elseif sub == "context_clear" then
    chat.clear_context()
  else
    chat.open()
  end
end, {
  nargs = "?",
  range = true,
  desc = "Ollama Chat commands",
  complete = function()
    return { "open", "close", "toggle", "input", "stop", "clear", "model", "attach", "context_clear" }
  end,
})

cmd("OllamaChatAttach", function()
  require("ollama-chat").attach_selection()
end, { range = true, desc = "Attach selection to Ollama Chat" })

cmd("OllamaChatAttachBuffer", function()
  require("ollama-chat").attach_buffer()
end, { desc = "Attach buffer to Ollama Chat" })

cmd("OllamaChatClearContext", function()
  require("ollama-chat").clear_context()
end, { desc = "Clear context chips" })

cmd("OllamaChatModel", function()
  require("ollama-chat").switch_model()
end, { desc = "Switch Ollama model" })

cmd("OllamaChatStop", function()
  require("ollama-chat").stop()
end, { desc = "Stop current generation" })

cmd("OllamaChatClear", function()
  require("ollama-chat").clear()
end, { desc = "Clear conversation" })

-- <Plug> mappings
vim.keymap.set({ "n", "v" }, "<Plug>(OllamaChat)", function()
  require("ollama-chat").toggle()
end, { noremap = true, silent = true, desc = "Toggle Ollama Chat" })

vim.keymap.set("v", "<Plug>(OllamaChatAttach)", function()
  require("ollama-chat").attach_selection()
end, { noremap = true, silent = true, desc = "Attach selection to Ollama Chat" })

vim.keymap.set("n", "<Plug>(OllamaChatAttachBuffer)", function()
  require("ollama-chat").attach_buffer()
end, { noremap = true, silent = true, desc = "Attach buffer to Ollama Chat" })

vim.keymap.set("n", "<Plug>(OllamaChatClearContext)", function()
  require("ollama-chat").clear_context()
end, { noremap = true, silent = true, desc = "Clear context chips" })

vim.keymap.set("n", "<Plug>(OllamaChatModel)", function()
  require("ollama-chat").switch_model()
end, { noremap = true, silent = true, desc = "Switch Ollama model" })

-- Default keymaps (only if user hasn't mapped anything)
local function set_default(lhs, plug, modes)
  modes = modes or "n"
  for mode in modes:gmatch(".") do
    if vim.fn.hasmapto(plug, mode) == 0 then
      vim.keymap.set(mode, lhs, plug, { noremap = true, silent = true })
    end
  end
end

-- These use the config keymaps, but we set sensible defaults
-- Users can override in their lazy.nvim config
vim.defer_fn(function()
  local ok, cfg = pcall(require, "ollama-chat.config")
  if not ok then return end
  local km = cfg.get().keymaps

  set_default(km.toggle, "<Plug>(OllamaChat)", "nv")
  set_default(km.attach_selection, "<Plug>(OllamaChatAttach)", "v")
  set_default(km.attach_buffer, "<Plug>(OllamaChatAttachBuffer)", "n")
  set_default(km.clear_context, "<Plug>(OllamaChatClearContext)", "n")
  set_default(km.switch_model, "<Plug>(OllamaChatModel)", "n")
end, 100)
