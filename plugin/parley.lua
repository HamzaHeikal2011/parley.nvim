-- parley.nvim
-- Entry point: lazy-load guard, commands, and <Plug> mappings

if vim.g.loaded_parley then
  return
end
vim.g.loaded_parley = true

local function cmd(name, fn, opts)
  opts = opts or {}
  vim.api.nvim_create_user_command(name, fn, opts)
end

-- Commands
cmd("Parley", function(opts)
  local sub = opts.fargs[1]
  local chat = require("parley")
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
  desc = "Parley commands",
  complete = function()
    return { "open", "close", "toggle", "input", "stop", "clear", "model", "attach", "context_clear" }
  end,
})

cmd("ParleyAttach", function()
  require("parley").attach_selection()
end, { range = true, desc = "Attach selection to Parley" })

cmd("ParleyAttachBuffer", function()
  require("parley").attach_buffer()
end, { desc = "Attach buffer to Parley" })

cmd("ParleyClearContext", function()
  require("parley").clear_context()
end, { desc = "Clear context chips" })

cmd("ParleyModel", function()
  require("parley").switch_model()
end, { desc = "Switch Ollama model" })

cmd("ParleyStop", function()
  require("parley").stop()
end, { desc = "Stop current generation" })

cmd("ParleyClear", function()
  require("parley").clear()
end, { desc = "Clear conversation" })

-- <Plug> mappings
vim.keymap.set({ "n", "v" }, "<Plug>(Parley)", function()
  require("parley").toggle()
end, { noremap = true, silent = true, desc = "Toggle Parley" })

vim.keymap.set("v", "<Plug>(ParleyAttach)", function()
  require("parley").attach_selection()
end, { noremap = true, silent = true, desc = "Attach selection to Parley" })

vim.keymap.set("n", "<Plug>(ParleyAttachBuffer)", function()
  require("parley").attach_buffer()
end, { noremap = true, silent = true, desc = "Attach buffer to Parley" })

vim.keymap.set("n", "<Plug>(ParleyClearContext)", function()
  require("parley").clear_context()
end, { noremap = true, silent = true, desc = "Clear context chips" })

vim.keymap.set("n", "<Plug>(ParleyModel)", function()
  require("parley").switch_model()
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
  local ok, cfg = pcall(require, "parley.config")
  if not ok then return end
  local km = cfg.get().keymaps

  set_default(km.toggle, "<Plug>(Parley)", "nv")
  set_default(km.attach_selection, "<Plug>(ParleyAttach)", "v")
  set_default(km.attach_buffer, "<Plug>(ParleyAttachBuffer)", "n")
  set_default(km.clear_context, "<Plug>(ParleyClearContext)", "n")
  set_default(km.switch_model, "<Plug>(ParleyModel)", "n")
end, 100)
