local M = {}

local config = {
  openai_api_key = nil, -- Will be read from env var OPENAI_API_KEY if not set
  model = "qwen-plus",
  api_url = "https://api.openai.com/v1/chat/completions",
  max_tokens = 4096,
  system_prompt = [[You are a specialized Git commit message generator. The user provides the result of running `git diff --cached`. Your task is to create clear, structured, and informative commit messages that follow a specific format:

1. First line: A concise title (60-72 characters) that summarizes the change using imperative mood
2. Followed by a blank line
3. Then a bulleted list of specific changes, each starting with a present-tense action verb

RULES:
- Title must be specific and descriptive
- Use imperative mood in title (e.g., "Add", "Fix", "Update", not "Added", "Fixed", "Updated")
- Keep the title under 72 characters
- Each bullet point should start with "- " followed by a present-tense action verb
- Bullet points should be concise but informative about what changed and why
- Keep total bullet points at most 3-5, for simple changes 1 bullet point
- Organize bullet points in order of importance
- Highlight important technical details that would be relevant to other developers
- Do not include unnecessary details or explanations that belong in documentation
- Focus on WHAT changed and WHY, not HOW

Avoid vague messages like "Fix bug" or "Update code" - be specific about what was fixed or updated.]]
}

local function get_api_key()
  -- First try to get from environment variable
  local env_key = vim.env.OPENAI_API_KEY
  if env_key and env_key ~= "" then
    return env_key
  end
  
  -- Fallback to configured key
  return config.openai_api_key
end

-- Setup keymaps using autocmd
local function setup_keymaps()
  local group = vim.api.nvim_create_augroup("NeogitAICommit", { clear = true })
  
  -- Set up autocmd for gitcommit filetype
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "gitcommit",
    callback = function(ev)
      -- Set up keymaps for both normal and insert mode
      vim.keymap.set({ "n", "i" }, "<C-c><return>", function()
        M.generate_commit_message(ev.buf)
      end, { buffer = ev.buf, desc = "Generate commit message" })

      vim.keymap.set({ "n", "i" }, "<C-c><C-m>", function()
        M.generate_commit_message(ev.buf)
      end, { buffer = ev.buf, desc = "Generate commit message" })
      
      -- Print a message to confirm the keymap is set
      vim.notify("Press <C-c><C-m>) to generate commit message using AI", vim.log.levels.INFO)
    end,
  })
end

-- Function to get lines from a buffer
local function get_buffer_lines(bufnr, start_line, end_line)
  return vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
end

-- Function to set lines in a buffer
local function set_buffer_lines(bufnr, start_line, end_line, lines)
  vim.api.nvim_buf_set_lines(bufnr, start_line, end_line, false, lines)
end

function M.generate_commit_message(bufnr)
  local api_key = get_api_key()
  if not api_key then
    vim.notify("OpenAI API key not found. Please set OPENAI_API_KEY environment variable or configure via setup()", vim.log.levels.ERROR)
    return
  end

  local git = require("neogit.lib.git")
  local staged_diff = git.cli.diff.cached.call().stdout
  if #staged_diff == 0 then
    vim.notify("No staged changes to generate commit message from", vim.log.levels.WARN)
    return
  end

  -- Join the diff lines with newlines
  local diff_content = table.concat(staged_diff, "\n")
  
  -- Debug info
  vim.notify("Diff content length: " .. #diff_content .. " characters", vim.log.levels.INFO)

  -- Show a loading message
  vim.notify("Generating commit message...", vim.log.levels.INFO)

  -- Make the API request
  local curl = require("plenary.curl")
  local response = curl.post(config.api_url, {
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. api_key
    },
    body = vim.fn.json_encode({
      model = config.model,
      messages = {
        { role = "system", content = config.system_prompt },
        { role = "user", content = diff_content }
      },
      stream = false,
    })
  })

  if response.status ~= 200 then
    vim.notify("Failed to generate commit message: " .. response.body, vim.log.levels.ERROR)
    return
  end

  local result = vim.fn.json_decode(response.body)
  if not result or not result.choices or #result.choices == 0 then
    vim.notify("Invalid response from OpenAI API", vim.log.levels.ERROR)
    return
  end

  local commit_message = result.choices[1].message.content

  -- Get all lines from the buffer
  local lines = get_buffer_lines(bufnr, 0, -1)
  
  -- Find the first comment section
  local comment_char = git.config.get("core.commentChar"):read() or "#"
  local first_comment_start = -1
  local comment_pattern = "^" .. comment_char
  
  for i, line in ipairs(lines) do
    if line:match(comment_pattern) then
      first_comment_start = i - 1  -- Convert to 0-based index
      break
    end
  end

  if first_comment_start >= 0 then
    -- Get the comment section once
    local comment_lines = {}
    local in_comment = false
    
    for i = first_comment_start + 1, #lines do
      local line = lines[i]
      if line:match(comment_pattern) then
        if not in_comment then
          in_comment = true
        end
        table.insert(comment_lines, line)
      elseif in_comment then
        -- We've found the end of the first comment block
        break
      end
    end

    -- Clear the buffer
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
    
    -- Insert the generated message
    local message_lines = vim.split(commit_message, "\n")
    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, message_lines)
    
    -- Add a blank line between message and comments if needed
    if #message_lines > 0 and not message_lines[#message_lines]:match("^%s*$") then
      vim.api.nvim_buf_set_lines(bufnr, #message_lines, #message_lines, false, {""})
    end
    
    -- Add the comment section
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, comment_lines)
  else
    -- No comments found, just set the message
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(commit_message, "\n"))
  end

  vim.notify("Commit message generated!", vim.log.levels.INFO)
end

-- Function to get current buffer if it's a commit message buffer
local function get_commit_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype == "gitcommit" then
    return bufnr
  end
  return nil
end

-- Create the Neovim command
local function create_commands()
  vim.api.nvim_create_user_command("NeogitAICommit", function()
    local bufnr = get_commit_buffer()
    if not bufnr then
      vim.notify("This command can only be used in a git commit message buffer", vim.log.levels.ERROR)
      return
    end
    M.generate_commit_message(bufnr)
  end, {
    desc = "Generate AI-powered commit message"
  })
end

function M.setup(opts)
  opts = opts or {}
  config = vim.tbl_deep_extend("force", config, opts)
  setup_keymaps()
  create_commands()
end

return M
