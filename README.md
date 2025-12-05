# OpenRouter API Client for Lune

A comprehensive OpenRouter API client for Luau/Lune with streaming support, function calling, and conversation management.

---

## 📋 Table of Contents

- [Requirements](#-requirements)
- [Installation](#-installation)
- [Getting Your API Key](#-getting-your-api-key)
- [Quick Start](#-quick-start)
- [Features](#-features)
- [API Reference](#-api-reference)
- [Types](#-types)
- [Error Handling](#-error-handling)
- [License](#-license)

---

## 📦 Requirements

Before using this package, make sure you have:

1. **Lune** - A standalone Luau runtime
   - Download: https://github.com/lune-org/lune/releases
   - Or install via cargo: `cargo install lune`
   - Or via aftman: `aftman add lune-org/lune`

2. **curl** - Required for streaming functionality (pre-installed on most systems)

3. **OpenRouter API Key** - Get one at https://openrouter.ai/keys

---

## 🔧 Installation

### Step 1: Copy the Package

Copy the `OpenRouter` folder to your project's packages directory:

```
YourProject/
├── OpenRouter/
│   └── init.luau
├── .luaurc
└── your_script.luau
```

### Step 2: Configure Aliases

Add the alias to your `.luaurc` file in the project root:

```json
{
    "languageMode": "strict",
    "aliases": {
        "OpenRouter": "./OpenRouter"
    }
}
```

### Step 3: Set Up Your API Key

Create a `.env` file in your project root (recommended):

```env
OPENROUTER_API_KEY=sk-or-v1-your-api-key-here
```

Or set it as an environment variable:

**Windows (PowerShell):**
```powershell
$env:OPENROUTER_API_KEY = "sk-or-v1-your-api-key-here"
```

**Linux/macOS:**
```bash
export OPENROUTER_API_KEY="sk-or-v1-your-api-key-here"
```

---

## 🔑 Getting Your API Key

1. Go to [OpenRouter](https://openrouter.ai/)
2. Sign in or create an account
3. Navigate to [API Keys](https://openrouter.ai/keys)
4. Click "Create Key"
5. Copy your key (starts with `sk-or-v1-`)
6. Add credits to your account at [Credits](https://openrouter.ai/credits) (or use free models)

> **Note:** Free models are available! Look for models ending with `:free` like `google/gemma-2-9b-it:free`

---

## 🚀 Quick Start

### Basic Example

```lua
local process = require("@lune/process")
local OpenRouter = require("@OpenRouter")

-- Get API key from environment
local apiKey = process.env.OPENROUTER_API_KEY

-- Create client (uses a random free model by default)
local router = OpenRouter.new(apiKey)

-- Simple chat
local response, err = router:quickChat("Hello, how are you?")
if err then
    print("Error:", err.message)
else
    print(response)
end
```

### With System Prompt

```lua
local response, err = router:quickChat(
    "Explain quantum computing in simple terms",
    "You are a helpful physics teacher who explains complex topics simply"
)

if response then
    print(response)
end
```

### Using a Specific Model

```lua
-- Using a predefined model alias
local router = OpenRouter.new(apiKey, OpenRouter.MODELS.gpt4omini)

-- Or using a model ID directly
local router = OpenRouter.new(apiKey, "anthropic/claude-3.5-sonnet")
```

---

## ✨ Features

### Chat Completion

Full control over messages and responses:

```lua
local messages = {
    OpenRouter.systemMessage("You are a helpful coding assistant"),
    OpenRouter.userMessage("What is the difference between Lua and Luau?"),
}

local response, err = router:chat(messages)

if response then
    print("Response:", response.content)
    print("Model used:", response.model)
    print("Tokens used:", response.usage.total_tokens)
    print("Finish reason:", response.finish_reason)
end
```

### Simple Completion

Get just the text response:

```lua
local text, err = router:complete("Write a haiku about programming")
if text then
    print(text)
end
```

### Streaming Responses

Stream responses in real-time (great for long outputs):

```lua
local fullResponse, err = router:streamChat(
    "Tell me a short story about a robot",
    function(chunk, done)
        if done then
            print("\n--- Stream complete ---")
        else
            io.write(chunk)
            io.flush()
        end
    end,
    "You are a creative storyteller"
)
```

### Streaming with Message Array

```lua
local messages = {
    OpenRouter.systemMessage("You are a code expert"),
    OpenRouter.userMessage("Explain how binary search works"),
}

local fullResponse, err = router:streamMessages(
    messages,
    function(chunk, done)
        if not done then
            io.write(chunk)
            io.flush()
        end
    end,
    OpenRouter.MODELS.gpt4omini
)
```

### Conversation Management

Maintain context across multiple messages:

```lua
-- Create a conversation with a system prompt
local conversation = router:createConversation(
    OpenRouter.MODELS.gpt4omini,
    "You are a helpful programming tutor"
)

-- First message
local response1, _ = router:sendMessage(conversation, "What is Python?")
print("AI:", response1.content)

-- Follow-up (context is maintained)
local response2, _ = router:sendMessage(conversation, "What about Lua?")
print("AI:", response2.content)

-- The AI remembers the previous context
local response3, _ = router:sendMessage(conversation, "Which should I learn first?")
print("AI:", response3.content)
```

### Model Selection

```lua
-- Use predefined model aliases
local response, _ = router:chat(messages, OpenRouter.MODELS.gpt4o)
local response, _ = router:chat(messages, OpenRouter.MODELS.claude3sonnet)
local response, _ = router:chat(messages, OpenRouter.MODELS.llama3)

-- Use model ID directly
local response, _ = router:chat(messages, "anthropic/claude-3.5-sonnet")

-- Change default model
router:setDefaultModel(OpenRouter.MODELS.gemini)

-- Get a random free model
local freeModel = OpenRouter.getRandomFreeModel()
```

### Available Model Aliases

| Alias | Model ID | Description |
|-------|----------|-------------|
| `gpt4` | openai/gpt-4-turbo | GPT-4 Turbo |
| `gpt4o` | openai/gpt-4o | GPT-4o (Omni) |
| `gpt4omini` | openai/gpt-4o-mini | GPT-4o Mini (cheaper) |
| `claude3opus` | anthropic/claude-3-opus | Claude 3 Opus (most capable) |
| `claude3sonnet` | anthropic/claude-3.5-sonnet | Claude 3.5 Sonnet |
| `claude3haiku` | anthropic/claude-3-haiku | Claude 3 Haiku (fastest) |
| `gemini` | google/gemini-pro-1.5 | Gemini 1.5 Pro |
| `llama3` | meta-llama/llama-3.1-70b-instruct | LLaMA 3.1 70B |
| `llama3small` | meta-llama/llama-3.1-8b-instruct | LLaMA 3.1 8B |
| `mistral` | mistralai/mistral-large | Mistral Large |
| `mixtral` | mistralai/mixtral-8x22b-instruct | Mixtral 8x22B |
| `deepseek` | deepseek/deepseek-chat | DeepSeek Chat |
| `qwen` | qwen/qwen-2.5-72b-instruct | Qwen 2.5 72B |
| `gemma` | google/gemma-2-9b-it:free | Gemma 2 9B (FREE) |

### Free Models Available

These models are completely free to use:

- `google/gemma-2-9b-it:free`
- `meta-llama/llama-3.2-3b-instruct:free`
- `microsoft/phi-3-mini-128k-instruct:free`
- `huggingfaceh4/zephyr-7b-beta:free`
- `openchat/openchat-7b:free`
- `mistralai/mistral-7b-instruct:free`

### Generation Presets

Apply predefined generation settings:

```lua
-- Creative - High temperature for creative outputs
router:applyPreset("creative")

-- Balanced - Default settings
router:applyPreset("balanced")

-- Precise - Low temperature for factual outputs
router:applyPreset("precise")

-- Deterministic - Zero temperature, reproducible results
router:applyPreset("deterministic")

-- Code - Optimized for code generation
router:applyPreset("code")
```

### Custom Generation Options

Fine-tune generation parameters:

```lua
local response, err = router:chat(messages, nil, {
    temperature = 0.8,      -- Creativity (0.0 - 2.0)
    max_tokens = 2048,      -- Max output length
    top_p = 0.95,           -- Nucleus sampling
    top_k = 40,             -- Top-k sampling
    frequency_penalty = 0.5, -- Reduce repetition
    presence_penalty = 0.5,  -- Encourage new topics
    stop = { "\n\n" },      -- Stop sequences
    seed = 42,              -- For reproducibility
})
```

### Function/Tool Calling

Let the AI call functions:

```lua
-- Define a tool
local weatherTool = OpenRouter.createTool(
    "get_weather",
    "Get the current weather for a location",
    {
        location = { 
            type = "string", 
            description = "City name, e.g., 'Tokyo'" 
        },
        unit = { 
            type = "string", 
            enum = { "celsius", "fahrenheit" },
            description = "Temperature unit"
        },
    },
    { "location" }  -- Required parameters
)

-- Use the tool
local messages = {
    OpenRouter.userMessage("What's the weather in Tokyo?"),
}

local response, err = router:withTools(messages, { weatherTool })

if response and response.tool_calls then
    for _, call in ipairs(response.tool_calls) do
        print("Function:", call["function"].name)
        print("Arguments:", call["function"].arguments)
        
        -- Parse arguments and call your function
        local args = serde.decode("json", call["function"].arguments)
        -- local weather = getWeather(args.location, args.unit)
        
        -- Send the result back
        table.insert(messages, OpenRouter.assistantMessage(""))
        table.insert(messages, OpenRouter.toolMessage(
            "Sunny, 25°C", 
            call.id
        ))
    end
end
```

### Model Discovery

Explore available models:

```lua
-- List all models
local models, err = router:listModels()
if models then
    for _, model in ipairs(models) do
        print(model.id, "-", model.name)
    end
end

-- List only free models
local freeModels, err = router:listFreeModels()

-- Search models by name
local results, err = router:searchModels("llama")
if results then
    for _, model in ipairs(results) do
        print(model.id)
    end
end

-- Get specific model info
local model, err = router:getModel("openai/gpt-4o")
if model then
    print("Name:", model.name)
    print("Context length:", model.context_length)
    print("Prompt price:", model.pricing.prompt)
end
```

### Account Information

Check your credits and usage:

```lua
-- Check remaining credits
local credits, err = router:getCredits()
if credits then
    print("Credits remaining: $" .. credits)
end

-- Get full usage info
local usage, err = router:getUsage()
if usage then
    print("Limit:", usage.limit)
    print("Used:", usage.usage)
end
```

### Token Estimation

Estimate token count before making requests:

```lua
local text = "Your long text here..."
local estimatedTokens = router:estimateTokens(text)
print("Estimated tokens:", estimatedTokens)
```

---

## 📚 API Reference

### Constructor

```lua
OpenRouter.new(apiKey: string, defaultModel: string?): OpenRouter
```

Creates a new OpenRouter client.

- `apiKey` - Your OpenRouter API key (required)
- `defaultModel` - Model to use by default (optional, uses random free model if not specified)

### Instance Properties

| Property | Type | Description |
|----------|------|-------------|
| `apiKey` | string | Your API key |
| `baseUrl` | string | API base URL |
| `defaultModel` | string | Default model ID |
| `defaultOptions` | ChatOptions | Default generation options |
| `retryAttempts` | number | Number of retry attempts (default: 3) |
| `retryDelay` | number | Delay between retries in seconds (default: 1) |
| `timeout` | number | Request timeout in seconds (default: 60) |

### Methods

| Method | Description | Returns |
|--------|-------------|---------|
| `chat(messages, model?, options?)` | Full chat completion | `ChatResponse?, ErrorResponse?` |
| `complete(prompt, model?, options?)` | Simple text completion | `string?, ErrorResponse?` |
| `quickChat(prompt, systemPrompt?)` | Quick single message chat | `string?, ErrorResponse?` |
| `streamChat(prompt, callback, systemPrompt?, model?)` | Streaming with prompt | `string?, ErrorResponse?` |
| `streamMessages(messages, callback, model?, options?)` | Streaming with messages | `string?, ErrorResponse?` |
| `createConversation(model?, systemPrompt?)` | Create conversation | `Conversation` |
| `sendMessage(conversation, content, options?)` | Send in conversation | `ChatResponse?, ErrorResponse?` |
| `listModels()` | List all models | `{ModelInfo}?, ErrorResponse?` |
| `listFreeModels()` | List free models | `{ModelInfo}?, ErrorResponse?` |
| `getModel(modelId)` | Get model info | `ModelInfo?, ErrorResponse?` |
| `searchModels(query)` | Search models | `{ModelInfo}?, ErrorResponse?` |
| `getCredits()` | Get remaining credits | `number?, ErrorResponse?` |
| `getUsage()` | Get usage info | `any?, ErrorResponse?` |
| `withTools(messages, tools, model?, options?)` | Chat with tools | `ChatResponse?, ErrorResponse?` |
| `setDefaultModel(model)` | Set default model | `void` |
| `setDefaultOptions(options)` | Set default options | `void` |
| `applyPreset(preset)` | Apply preset config | `void` |
| `estimateTokens(text)` | Estimate tokens | `number` |

### Helper Functions

| Function | Description |
|----------|-------------|
| `OpenRouter.systemMessage(content)` | Create system message |
| `OpenRouter.userMessage(content)` | Create user message |
| `OpenRouter.assistantMessage(content)` | Create assistant message |
| `OpenRouter.toolMessage(content, toolCallId)` | Create tool response |
| `OpenRouter.createTool(name, desc, params, required?)` | Create tool definition |
| `OpenRouter.getRandomFreeModel()` | Get a random free model ID |

### Constants

| Constant | Description |
|----------|-------------|
| `OpenRouter.MODELS` | Table of model aliases |
| `OpenRouter.FREE_MODELS` | Array of free model IDs |
| `OpenRouter.PRESETS` | Table of preset configurations |

---

## 📝 Types

### ChatResponse

```lua
{
    content: string,           -- The AI's response text
    model: string?,            -- Model that was used
    usage: {
        prompt_tokens: number,
        completion_tokens: number,
        total_tokens: number,
    }?,
    finish_reason: string?,    -- "stop", "length", "tool_calls", etc.
    tool_calls: { ToolCall }?, -- Function calls if any
}
```

### ChatOptions

```lua
{
    temperature: number?,       -- 0.0 to 2.0 (default: 0.7)
    max_tokens: number?,        -- Maximum output tokens (default: 4096)
    top_p: number?,             -- Nucleus sampling (0.0 to 1.0)
    top_k: number?,             -- Top-k sampling
    frequency_penalty: number?, -- -2.0 to 2.0
    presence_penalty: number?,  -- -2.0 to 2.0
    repetition_penalty: number?, -- Repetition penalty
    stop: { string }?,          -- Stop sequences
    seed: number?,              -- For reproducibility
    tools: { Tool }?,           -- Function definitions
    tool_choice: any?,          -- "auto", "none", or specific
    response_format: { 
        type: string            -- "text" or "json_object"
    }?,
}
```

### Message

```lua
{
    role: string,              -- "system", "user", "assistant", or "tool"
    content: string,           -- Message content
    name: string?,             -- Optional name
    tool_calls: { ToolCall }?, -- For assistant messages with tool calls
    tool_call_id: string?,     -- For tool response messages
}
```

### ErrorResponse

```lua
{
    message: string,  -- Error description
    status: number,   -- HTTP status code (0 for network errors)
    code: string?,    -- Error code (e.g., "NETWORK_ERROR")
}
```

### ModelInfo

```lua
{
    id: string,                    -- Model ID
    name: string,                  -- Display name
    description: string?,          -- Model description
    context_length: number?,       -- Max context tokens
    pricing: {
        prompt: string?,           -- Price per token (prompt)
        completion: string?,       -- Price per token (completion)
    }?,
    top_provider: {
        max_completion_tokens: number?,
    }?,
}
```

---

## ⚠️ Error Handling

All methods return two values: the result and an error. Always check for errors:

```lua
local response, err = router:chat(messages)

if err then
    print("Error occurred!")
    print("Message:", err.message)
    print("Status:", err.status)
    print("Code:", err.code)
    return
end

-- Safe to use response here
print(response.content)
```

### Common Errors

| Status | Description |
|--------|-------------|
| 0 | Network error or timeout |
| 400 | Bad request (invalid parameters) |
| 401 | Unauthorized (invalid API key) |
| 402 | Payment required (no credits) |
| 429 | Rate limited |
| 500+ | Server error (will auto-retry) |

---

## Credits  

Made by yanlvl99_ [Discord](https://discord.com/channels/@me/1222190313204879421)


## 📄 License

MIT

---

## 🔗 Links

- [OpenRouter Website](https://openrouter.ai/)
- [OpenRouter Documentation](https://openrouter.ai/docs)
- [Lune Runtime](https://github.com/lune-org/lune)
- [Luau Language](https://luau-lang.org/)

