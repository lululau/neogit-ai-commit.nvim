# neogit-ai-commit

A Neovim plugin that extends [Neogit](https://github.com/NeogitOrg/neogit) to add AI-powered commit message generation using OpenAI's GPT models or compatible APIs.

## Features

- Generate conventional commit messages using:
  - Command: `:NeogitAICommit`
  - Normal and Insert mode: `<C-c><return>`
- Uses OpenAI-compatible APIs to analyze staged changes and generate meaningful commit messages
- Follows conventional commit format with a concise title and bullet points
- Preserves Neogit's comment section in commit messages
- Configurable model and system prompt
- Supports reading API key from environment variable

## Requirements

- Neovim 0.5+
- [Neogit](https://github.com/Neogit/neogit)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- OpenAI API key or compatible API key (via environment variable)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'lululau/neogit-ai-commit.nvim',
  dependencies = {
    'NeogitOrg/neogit',
    'nvim-lua/plenary.nvim'
  },
  event = "VeryLazy",
  cmd = "NeogitAICommit",
  config = function()
    require('neogit-ai-commit').setup({
      -- API key will be read from OPENAI_API_KEY environment variable
      api_url = "https://api.openai.com/v1/chat/completions", -- OpenAI API URL
      model = "gpt-3.5-turbo", -- Model to use
      max_tokens = 4096,
    })
  end
}
```

## Usage

1. Stage your changes using Neogit or git
2. Start a commit in Neogit (press `c c` in Neogit status buffer)
3. In the commit message buffer, you can:
   - Run the command `:NeogitAICommit`
   - In normal or insert mode: press `<C-c><return>`
4. The plugin will analyze your staged changes and generate a conventional commit message
5. Review and edit the generated message if needed
6. Save and commit as usual

## Commands

- `:NeogitAICommit` - Generate an AI-powered commit message in the current commit message buffer

## Keymaps

The plugin provides a unified way to generate a commit message in the commit buffer:

### Normal and Insert Mode
- `<C-c><return>` - Generate commit message

## Configuration

The plugin can be configured with the following options:

```lua
require('neogit-ai-commit').setup({
  -- Optional: Your API key
  -- If not set, will try to read from OPENAI_API_KEY environment variable
  openai_api_key = nil,
  
  -- The model to use
  model = "gpt-3.5-turbo",
  
  -- The API URL
  api_url = "https://api.openai.com/v1/chat/completions",
  
  -- Maximum tokens for the API request
  max_tokens = 4096,
  
  -- Optional: Custom system prompt for the AI
  system_prompt = "Your custom prompt here..."
})
```

### Environment Variables

- `OPENAI_API_KEY`: Your API key. This is the recommended way to provide the API key.

## License

MIT 
