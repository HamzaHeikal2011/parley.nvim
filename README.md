# ollama-chat.nvim

A Neovim plugin that provides a **persistent side-panel chat interface** for Ollama local LLM models.

Inspired by Cursor's side panel, Claude Code's VS Code extension, and Windsurf's context chips.

## Features

- **Side panel** (not a floating window) — code and chat visible simultaneously
- **Context chips** — attach selections/buffers as removable context pills
- **Streaming responses** with markdown rendering
- **Inline code block actions** — Apply, Copy, Diff with single keypresses
- **Per-buffer conversation sessions** — follow-up questions just work
- **Zero plugin dependencies** — only requires `curl` + Neovim 0.10+
- **Works out of the box** — no `setup()` call required

## Requirements

- Neovim >= 0.10
- curl (Ollama users typically have this)
- Ollama server running locally

## Installation

### lazy.nvim

```lua
{
  "yourname/ollama-chat.nvim",
  event = "VeryLazy",
  opts = {
    url = "http://127.0.0.1:11434",
    model = "qwen2.5-coder:7b",
  },
  keys = {
    { "<leader>oc", "<cmd>OllamaChat<cr>", desc = "Ollama Chat" },
    { "<leader>oa", "<cmd>OllamaChatAttach<cr>", desc = "Attach selection", mode = "v" },
    { "<leader>ob", "<cmd>OllamaChatAttachBuffer<cr>", desc = "Attach buffer" },
    { "<leader>ox", "<cmd>OllamaChatClearContext<cr>", desc = "Clear context" },
    { "<leader>om", "<cmd>OllamaChatModel<cr>", desc = "Switch model" },
  },
}
```

## Configuration

```lua
opts = {
  url = "http://127.0.0.1:11434",
  model = "qwen2.5-coder:7b",
  temperature = 0.2,
  num_ctx = 8192,
  panel_width = 0.3,         -- 30% of editor width
  panel_position = "right",  -- "right" or "left"
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
```

## Workflow

1. Select code in visual mode
2. Press `<leader>oa` to attach selection (shows as a chip)
3. Press `<leader>oc` to open the chat panel
4. Press `i` to open the input area
5. Type your question
6. Press `<CR>` (single line) or `<C-CR>` (multi-line) to send
7. Response streams in the panel
8. Navigate to a code block and press:
   - `<C-y>` to Apply the code
   - `<C-d>` to Copy to clipboard
   - `<C-f>` to show a Diff
9. Keep the conversation going with follow-up questions

## Commands

| Command | Description |
|---|---|
| `:OllamaChat` | Toggle chat panel |
| `:OllamaChatAttach` | Attach visual selection |
| `:OllamaChatAttachBuffer` | Attach entire buffer |
| `:OllamaChatClearContext` | Clear context chips |
| `:OllamaChatModel` | Switch model |
| `:OllamaChatStop` | Stop generation |
| `:OllamaChatClear` | Clear conversation |

## Health Check

```
:checkhealth ollama-chat
```

## License

MIT
