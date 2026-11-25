return {
  -- AI assistant: Avante (formerly CodeCompanion)
  -- Local-first via Ollama; model picker in the chat UI lists every model
  -- on the endpoint (switch to gpt-oss:20b-32k etc. without reconfiguring).
  -- Add cloud providers (mistral/openai/anthropic) to `providers` when an
  -- API key is available in the environment.
  -- AI-generated (Claude Code, 2026-11-25) — review before reuse elsewhere.
  {
    "avante-corp/avante.nvim",
    cmd = "Avante",
    event = "VeryLazy",
    config = function()
      require("avante").setup({
        provider = "ollama",
        providers = {
          ollama = {
            endpoint = "http://localhost:11434",
            model = "qwen3-coder:30b-32k",
            is_env_set = require("avante.providers.ollama").check_endpoint_alive,
          },
        },
      })
    end,
  },
}
