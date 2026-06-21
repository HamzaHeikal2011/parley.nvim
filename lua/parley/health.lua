local M = {}

local config = require("parley.config")
local http = require("parley.http")

function M.check()
  vim.health.start("parley.nvim")

  -- Check Neovim version
  local version = vim.version()
  if version.minor >= 10 then
    vim.health.ok(string.format("Neovim version: %d.%d.%d (>= 0.10 required)", version.major, version.minor, version.patch))
  else
    vim.health.error(string.format("Neovim version: %d.%d.%d (0.10+ required)", version.major, version.minor, version.patch))
  end

  -- Check curl
  if vim.fn.executable("curl") == 1 then
    local curl_version = vim.fn.system("curl --version"):match("curl (%d+%.%d+%.%d+)")
    vim.health.ok("curl is available" .. (curl_version and (" (v" .. curl_version .. ")") or ""))
  else
    vim.health.error("curl not found in PATH")
  end

  -- Check Vim JSON support
  if vim.json and vim.json.encode and vim.json.decode then
    vim.health.ok("vim.json is available")
  else
    vim.health.error("vim.json not available (requires Neovim 0.5+)")
  end

  -- Check vim.system support
  if vim.system then
    vim.health.ok("vim.system is available")
  else
    vim.health.error("vim.system not available (requires Neovim 0.10+)")
  end

  -- Check Ollama server
  local cfg = config.get()
  vim.health.info("Ollama URL: " .. cfg.url)
  vim.health.info("Default model: " .. cfg.model)

  -- Async health check for server
  http.health_check(cfg.url, 3000, function(ok, err)
    if ok then
      vim.health.ok("Ollama server is reachable at " .. cfg.url)

      -- Check available models
      http.list_models(cfg.url, function(models, merr)
        if models and #models > 0 then
          vim.health.ok(string.format("Available models (%d):", #models))
          for _, m in ipairs(models) do
            local marker = (m == cfg.model) and " (default)" or ""
            vim.health.ok("  - " .. m .. marker)
          end

          -- Check if default model exists
          local found = false
          for _, m in ipairs(models) do
            if m == cfg.model then
              found = true
              break
            end
          end
          if not found then
            vim.health.warn("Default model '" .. cfg.model .. "' not found in available models")
          end
        else
          vim.health.warn("No models found: " .. (merr or "unknown error"))
        end
      end)
    else
      vim.health.error("Ollama server not reachable: " .. (err or "unknown error"))
      vim.health.info("Make sure Ollama is running: ollama serve")
    end
  end)
end

return M
