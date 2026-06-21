local M = {}

local config = require("parley.config")

---HTTP client using vim.system() + curl.
---Zero Neovim plugin dependencies — curl is required (Ollama users have it).

---Check if the Ollama server is reachable
---@param url string
---@param timeout_ms number
---@param cb fun(ok: boolean, err_str: string|nil)
function M.health_check(url, timeout_ms, cb)
  url = url or config.get().url
  timeout_ms = timeout_ms or 3000

  -- Use curl with a short timeout to check server availability
  vim.system(
    { "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "--max-time", tostring(timeout_ms / 1000), url .. "/api/tags" },
    {},
    function(obj)
      vim.schedule(function()
        if obj.code ~= 0 then
          cb(false, "curl exited with code " .. tostring(obj.code))
          return
        end
        local status = obj.stdout and obj.stdout:gsub("%s+", "") or ""
        if status == "200" then
          cb(true)
        else
          cb(false, "HTTP status " .. status)
        end
      end)
    end
  )
end

---Fetch available models from Ollama
---@param url string
---@param cb fun(models: string[]|nil, err: string|nil)
function M.list_models(url, cb)
  url = url or config.get().url

  vim.system(
    { "curl", "-s", url .. "/api/tags" },
    {},
    function(obj)
      vim.schedule(function()
        if obj.code ~= 0 then
          cb(nil, "curl exited with code " .. tostring(obj.code))
          return
        end
        local ok, data = pcall(vim.json.decode, obj.stdout)
        if not ok or not data or not data.models then
          cb(nil, "Failed to parse model list: " .. tostring(obj.stdout))
          return
        end
        local models = {}
        for _, m in ipairs(data.models) do
          table.insert(models, m.name)
        end
        cb(models)
      end)
    end
  )
end

---Stream a chat completion from Ollama.
---Uses /api/chat for conversation support.
---@param messages OllamaMessage[]
---@param model string
---@param options table|nil Extra model options (temperature, num_ctx, etc.)
---@param on_chunk fun(text: string) Called for each streamed token
---@param on_done fun() Called when stream completes
---@param on_error fun(err: string) Called on error
---@return fun() cancel_fn Call this to stop the stream
function M.stream_chat(messages, model, options, on_chunk, on_done, on_error)
  local cfg = config.get()
  model = model or cfg.model
  options = options or {}

  local body = vim.json.encode({
    model = model,
    messages = messages,
    stream = true,
    options = {
      temperature = options.temperature or cfg.temperature,
      num_ctx = options.num_ctx or cfg.num_ctx,
    },
  })

  local url = cfg.url .. "/api/chat"
  local full_output = {}

  -- We use curl with -N (no buffer) for streaming
  -- Each line of stdout is a JSON object
  local job = vim.system(
    { "curl", "-s", "-N", url, "-H", "Content-Type: application/json", "-d", body },
    {
      stdout = function(_, data)
        if not data then return end
        -- Data may contain multiple lines or partial lines
        for line in data:gmatch("[^\n]+") do
          line = line:match("^%s*(.-)%s*$")  -- trim
          if line ~= "" then
            local ok, json = pcall(vim.json.decode, line)
            if ok then
              if json.message and json.message.content then
                local text = json.message.content
                table.insert(full_output, text)
                vim.schedule(function()
                  on_chunk(text)
                end)
              end
              if json.done then
                vim.schedule(function()
                  on_done()
                end)
              end
              if json.error then
                vim.schedule(function()
                  on_error(json.error)
                end)
              end
            end
          end
        end
      end,
      stderr = function(_, data)
        if data and data ~= "" then
          vim.schedule(function()
            on_error("stderr: " .. data)
          end)
        end
      end,
    },
    function()
      -- on_exit — if we haven't received done=true, signal done anyway
      vim.schedule(function()
        on_done()
      end)
    end
  )

  -- Return cancellation function
  return function()
    if job and job.pid then
      job:kill(15)  -- SIGTERM
    end
  end
end

---Non-streaming chat (for simple use cases)
---@param messages OllamaMessage[]
---@param model string
---@param cb fun(response: string|nil, err: string|nil)
function M.chat(messages, model, cb)
  local cfg = config.get()

  local body = vim.json.encode({
    model = model or cfg.model,
    messages = messages,
    stream = false,
    options = {
      temperature = cfg.temperature,
      num_ctx = cfg.num_ctx,
    },
  })

  vim.system(
    { "curl", "-s", cfg.url .. "/api/chat", "-H", "Content-Type: application/json", "-d", body },
    { timeout = 120000 },
    function(obj)
      vim.schedule(function()
        if obj.code ~= 0 then
          cb(nil, "Request failed (code " .. tostring(obj.code) .. ")")
          return
        end
        local ok, json = pcall(vim.json.decode, obj.stdout)
        if not ok then
          cb(nil, "Failed to parse response")
          return
        end
        if json.error then
          cb(nil, json.error)
          return
        end
        cb(json.message and json.message.content)
      end)
    end
  )
end

return M
