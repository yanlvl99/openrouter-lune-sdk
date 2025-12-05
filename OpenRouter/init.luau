local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

export type Message = {
    role: string,
    content: string,
    name: string?,
    tool_calls: { ToolCall }?,
    tool_call_id: string?,
}

export type ToolCall = {
    id: string,
    type: string,
    ["function"]: {
        name: string,
        arguments: string,
    },
}

export type ToolFunction = {
    name: string,
    description: string,
    parameters: {
        type: string,
        properties: { [string]: any },
        required: { string }?,
    },
}

export type Tool = {
    type: string,
    ["function"]: ToolFunction,
}

export type ChatOptions = {
    temperature: number?,
    max_tokens: number?,
    top_p: number?,
    top_k: number?,
    frequency_penalty: number?,
    presence_penalty: number?,
    repetition_penalty: number?,
    stop: { string }?,
    seed: number?,
    tools: { Tool }?,
    tool_choice: any?,
    response_format: { type: string }?,
    stream: boolean?,
}

export type ModelPricing = {
    prompt: string?,
    completion: string?,
}

export type ModelProvider = {
    max_completion_tokens: number?,
}

export type ModelInfo = {
    id: string,
    name: string,
    description: string?,
    context_length: number?,
    pricing: ModelPricing?,
    top_provider: ModelProvider?,
    per_request_limits: any?,
}

export type ErrorResponse = {
    message: string,
    status: number,
    code: string?,
}

export type Conversation = {
    model: string?,
    messages: { Message },
    systemPrompt: string?,
    options: ChatOptions?,
}

export type StreamCallback = (chunk: string, done: boolean) -> ()

export type UsageInfo = {
    prompt_tokens: number,
    completion_tokens: number,
    total_tokens: number,
}

export type ChatResponse = {
    content: string,
    model: string?,
    usage: UsageInfo?,
    finish_reason: string?,
    tool_calls: { ToolCall }?,
}

type PresetOptions = {
    temperature: number,
    top_p: number,
    frequency_penalty: number,
    presence_penalty: number,
}

local PRESETS: { [string]: PresetOptions } = {
    creative = {
        temperature = 1.2,
        top_p = 0.95,
        frequency_penalty = 0.5,
        presence_penalty = 0.5,
    },
    balanced = {
        temperature = 0.7,
        top_p = 0.9,
        frequency_penalty = 0.0,
        presence_penalty = 0.0,
    },
    precise = {
        temperature = 0.2,
        top_p = 0.8,
        frequency_penalty = 0.0,
        presence_penalty = 0.0,
    },
    deterministic = {
        temperature = 0.0,
        top_p = 1.0,
        frequency_penalty = 0.0,
        presence_penalty = 0.0,
    },
    code = {
        temperature = 0.1,
        top_p = 0.95,
        frequency_penalty = 0.1,
        presence_penalty = 0.0,
    },
}

local FREE_MODELS: { string } = {
    "google/gemma-2-9b-it:free",
    "meta-llama/llama-3.2-3b-instruct:free",
    "microsoft/phi-3-mini-128k-instruct:free",
    "huggingfaceh4/zephyr-7b-beta:free",
    "openchat/openchat-7b:free",
    "mistralai/mistral-7b-instruct:free",
}

local POPULAR_MODELS: { [string]: string } = {
    gpt4 = "openai/gpt-4-turbo",
    gpt4o = "openai/gpt-4o",
    gpt4omini = "openai/gpt-4o-mini",
    claude3opus = "anthropic/claude-3-opus",
    claude3sonnet = "anthropic/claude-3.5-sonnet",
    claude3haiku = "anthropic/claude-3-haiku",
    gemini = "google/gemini-pro-1.5",
    llama3 = "meta-llama/llama-3.1-70b-instruct",
    llama3small = "meta-llama/llama-3.1-8b-instruct",
    mistral = "mistralai/mistral-large",
    mixtral = "mistralai/mixtral-8x22b-instruct",
    deepseek = "deepseek/deepseek-chat",
    qwen = "qwen/qwen-2.5-72b-instruct",
    gemma = "google/gemma-2-9b-it:free",
}

local function getRandomFreeModel(): string
    local index = math.random(1, #FREE_MODELS)
    return FREE_MODELS[index]
end

export type OpenRouter = {
    apiKey: string,
    baseUrl: string,
    defaultModel: string,
    defaultOptions: ChatOptions,
    retryAttempts: number,
    retryDelay: number,
    timeout: number,
    
    _request: (self: OpenRouter, method: string, endpoint: string, payload: any?) -> (any?, ErrorResponse?),
    _mergeOptions: (self: OpenRouter, options: ChatOptions?) -> ChatOptions,
    
    chat: (self: OpenRouter, messages: { Message }, model: string?, options: ChatOptions?) -> (ChatResponse?, ErrorResponse?),
    complete: (self: OpenRouter, prompt: string, model: string?, options: ChatOptions?) -> (string?, ErrorResponse?),
    streamChat: (self: OpenRouter, prompt: string, onChunk: StreamCallback, systemPrompt: string?, model: string?) -> (string?, ErrorResponse?),
    streamMessages: (self: OpenRouter, messages: { Message }, onChunk: StreamCallback, model: string?, options: ChatOptions?) -> (string?, ErrorResponse?),
    
    quickChat: (self: OpenRouter, prompt: string, systemPrompt: string?) -> (string?, ErrorResponse?),
    
    createConversation: (self: OpenRouter, model: string?, systemPrompt: string?) -> Conversation,
    sendMessage: (self: OpenRouter, conversation: Conversation, content: string, options: ChatOptions?) -> (ChatResponse?, ErrorResponse?),
    
    listModels: (self: OpenRouter) -> ({ ModelInfo }?, ErrorResponse?),
    listFreeModels: (self: OpenRouter) -> ({ ModelInfo }?, ErrorResponse?),
    getModel: (self: OpenRouter, modelId: string) -> (ModelInfo?, ErrorResponse?),
    searchModels: (self: OpenRouter, query: string) -> ({ ModelInfo }?, ErrorResponse?),
    
    getCredits: (self: OpenRouter) -> (number?, ErrorResponse?),
    getUsage: (self: OpenRouter) -> (any?, ErrorResponse?),
    
    withTools: (self: OpenRouter, messages: { Message }, tools: { Tool }, model: string?, options: ChatOptions?) -> (ChatResponse?, ErrorResponse?),
    
    setDefaultModel: (self: OpenRouter, model: string) -> (),
    setDefaultOptions: (self: OpenRouter, options: ChatOptions) -> (),
    applyPreset: (self: OpenRouter, preset: string) -> (),
    
    estimateTokens: (self: OpenRouter, text: string) -> number,
}

local OpenRouterClass = {}
OpenRouterClass.__index = OpenRouterClass

function OpenRouterClass.new(apiKey: string, defaultModel: string?): OpenRouter
    local self:any = setmetatable({}, OpenRouterClass)
    
    self.apiKey = apiKey
    self.baseUrl = "https://openrouter.ai/api/v1"
    self.defaultModel = defaultModel or getRandomFreeModel()
    self.defaultOptions = {
        temperature = 0.7,
        max_tokens = 4096,
    }
    self.retryAttempts = 3
    self.retryDelay = 1
    self.timeout = 60
    
    return self
end

function OpenRouterClass._request(self: OpenRouter, method: string, endpoint: string, payload: any?): (any?, ErrorResponse?)
    local url:any = self.baseUrl .. endpoint
    local headers: { [string]: string } = {
        ["Authorization"] = "Bearer " .. self.apiKey,
        ["Content-Type"] = "application/json",
        ["HTTP-Referer"] = "https://github.com/lune-org/lune",
        ["X-Title"] = "Lune OpenRouter Client",
    }
    
    local body: string? = nil
    if payload then
        body = serde.encode("json", payload)
    end
    
    local lastError: ErrorResponse? = nil
    
    for attempt = 1, self.retryAttempts do
        local success, result = pcall(function()
            local requestParams: any = {
                url = url,
                method = method,
                headers = headers,
            }
            if body then
                requestParams.body = body
            end
            return net.request(requestParams) 
        end)
        
        if success and type(result) == "table" then
            local response = result :: any
            if response.ok then
                local data = serde.decode("json", response.body)
                return data, nil
            else
                local errorData: any = nil
                pcall(function()
                    errorData = serde.decode("json", response.body)
                end)
                
                local errorMessage = "Request failed"
                if errorData and errorData.error then
                    if type(errorData.error) == "string" then
                        errorMessage = errorData.error
                    elseif type(errorData.error) == "table" and errorData.error.message then
                        errorMessage = errorData.error.message
                    end
                end
                
                local errorCode: string? = nil
                if errorData and type(errorData.error) == "table" then
                    errorCode = errorData.error.code
                end
                
                lastError = {
                    message = errorMessage,
                    status = response.statusCode or 0,
                    code = errorCode,
                }
                
                if (response.statusCode or 0) >= 500 and attempt < self.retryAttempts then
                    task.wait(self.retryDelay * attempt)
                else
                    return nil, lastError
                end
            end
        else
            lastError = {
                message = tostring(result),
                status = 0,
                code = "NETWORK_ERROR",
            }
            
            if attempt < self.retryAttempts then
                task.wait(self.retryDelay * attempt)
            end
        end
    end
    
    return nil, lastError or { message = "Unknown error", status = 0 }
end

function OpenRouterClass._mergeOptions(self: OpenRouter, options: ChatOptions?): ChatOptions
    local merged: ChatOptions = {}
    
    for key, value in pairs(self.defaultOptions :: any) do
        (merged :: any)[key] = value
    end
    
    if options then
        for key, value in pairs(options :: any) do
            (merged :: any)[key] = value
        end
    end
    
    return merged
end

function OpenRouterClass.chat(self: OpenRouter, messages: { Message }, model: string?, options: ChatOptions?): (ChatResponse?, ErrorResponse?)
    local mergedOptions = self:_mergeOptions(options)
    
    local payload: any = {
        model = model or self.defaultModel,
        messages = messages,
    }
    
    for key, value in pairs(mergedOptions :: any) do
        if key ~= "stream" then
            payload[key] = value
        end
    end
    
    local response, err = self:_request("POST", "/chat/completions", payload)
    
    if err then
        return nil, err
    end
    
    if response and response.choices and #response.choices > 0 then
        local choice = response.choices[1]
        local result: ChatResponse = {
            content = if choice.message and choice.message.content then choice.message.content else "",
            model = response.model,
            usage = response.usage,
            finish_reason = choice.finish_reason,
            tool_calls = if choice.message then choice.message.tool_calls else nil,
        }
        return result, nil
    end
    
    return nil, { message = "Invalid response format", status = 0 }
end

function OpenRouterClass.complete(self: OpenRouter, prompt: string, model: string?, options: ChatOptions?): (string?, ErrorResponse?)
    local messages: { Message } = {
        { role = "user", content = prompt },
    }
    
    local response, err = self:chat(messages, model, options)
    
    if err then
        return nil, err
    end
    
    if response then
        return response.content, nil
    end
    
    return nil, { message = "No response", status = 0 }
end

function OpenRouterClass.quickChat(self: OpenRouter, prompt: string, systemPrompt: string?): (string?, ErrorResponse?)
    local messages: { Message } = {}
    
    if systemPrompt then
        table.insert(messages, { role = "system", content = systemPrompt })
    end
    
    table.insert(messages, { role = "user", content = prompt })
    
    local response, err = self:chat(messages, nil, nil)
    
    if err then
        return nil, err
    end
    
    if response then
        return response.content, nil
    end
    
    return nil, { message = "No response", status = 0 }
end

function OpenRouterClass.streamChat(self: OpenRouter, prompt: string, onChunk: StreamCallback, systemPrompt: string?, model: string?): (string?, ErrorResponse?)
    local messages: { Message } = {}
    
    if systemPrompt then
        table.insert(messages, { role = "system", content = systemPrompt })
    end
    
    table.insert(messages, { role = "user", content = prompt })
    
    return self:streamMessages(messages, onChunk, model, nil)
end

function OpenRouterClass.streamMessages(self: OpenRouter, messages: { Message }, onChunk: StreamCallback, model: string?, options: ChatOptions?): (string?, ErrorResponse?)
    local mergedOptions = self:_mergeOptions(options)
    
    local payload: any = {
        model = model or self.defaultModel,
        messages = messages,
        stream = true,
    }
    
    for key, value in pairs(mergedOptions :: any) do
        if key ~= "stream" then
            payload[key] = value
        end
    end
    
    local jsonPayload = serde.encode("json", payload)
    
    local args: { string } = {
        "-s", "-S",
        "-X", "POST",
        "-H", "Content-Type: application/json",
        "-H", "Authorization: Bearer " .. self.apiKey,
        "-H", "HTTP-Referer: https://github.com/lune-org/lune",
        "-H", "X-Title: Lune OpenRouter Client",
        "-d", jsonPayload,
        "--no-buffer",
        self.baseUrl .. "/chat/completions",
    }
    
    local child = process.create("curl", args)
    
    local fullContent = ""
    local buffer = ""
    
    while true do
        local chunk = child.stdout:read(1024)
        if not chunk or #chunk == 0 then
            break
        end
        
        buffer = buffer .. chunk
        
        while true do
            local lineEnd = buffer:find("\n")
            if not lineEnd then
                break
            end
            
            local line = buffer:sub(1, lineEnd - 1)
            buffer = buffer:sub(lineEnd + 1)
            
            if line:sub(1, 6) == "data: " then
                local jsonData = line:sub(7)
                
                if jsonData == "[DONE]" then
                    onChunk("", true)
                    break
                end
                
                local parseSuccess, parsed = pcall(function()
                    return serde.decode("json", jsonData)
                end)
                
                if parseSuccess and parsed and parsed.choices and #parsed.choices > 0 then
                    local delta = parsed.choices[1].delta
                    if delta and delta.content then
                        fullContent = fullContent .. delta.content
                        onChunk(delta.content, false)
                    end
                end
            end
        end
    end
    
    if fullContent == "" then
        local stderr = child.stderr:read(4096)
        if stderr and #stderr > 0 then
            return nil, { message = "Stream error: " .. stderr, status = 0 }
        end
    end
    
    return fullContent, nil
end

function OpenRouterClass.createConversation(self: OpenRouter, model: string?, systemPrompt: string?): Conversation
    local conversation: Conversation = {
        model = model or self.defaultModel,
        messages = {},
        systemPrompt = systemPrompt,
        options = nil,
    }
    
    if systemPrompt then
        table.insert(conversation.messages, {
            role = "system",
            content = systemPrompt,
        })
    end
    
    return conversation
end

function OpenRouterClass.sendMessage(self: OpenRouter, conversation: Conversation, content: string, options: ChatOptions?): (ChatResponse?, ErrorResponse?)
    table.insert(conversation.messages, {
        role = "user",
        content = content,
    })
    
    local response, err = self:chat(conversation.messages, conversation.model, options or conversation.options)
    
    if err then
        table.remove(conversation.messages)
        return nil, err
    end
    
    if response then
        table.insert(conversation.messages, {
            role = "assistant",
            content = response.content,
            tool_calls = response.tool_calls,
        })
        return response, nil
    end
    
    table.remove(conversation.messages)
    return nil, { message = "No response", status = 0 }
end

function OpenRouterClass.listModels(self: OpenRouter): ({ ModelInfo }?, ErrorResponse?)
    local response, err = self:_request("GET", "/models", nil)
    
    if err then
        return nil, err
    end
    
    if response and response.data then
        return response.data :: { ModelInfo }, nil
    end
    
    return nil, { message = "Invalid response format", status = 0 }
end

function OpenRouterClass.listFreeModels(self: OpenRouter): ({ ModelInfo }?, ErrorResponse?)
    local models, err = self:listModels()
    
    if err then
        return nil, err
    end
    
    local freeModels: { ModelInfo } = {}
    
    if models then
        for _, model in ipairs(models) do
            local isFree = false
            if model.id and string.find(model.id, ":free") then
                isFree = true
            elseif model.pricing and model.pricing.prompt == "0" then
                isFree = true
            end
            
            if isFree then
                table.insert(freeModels, model)
            end
        end
    end
    
    return freeModels, nil
end

function OpenRouterClass.getModel(self: OpenRouter, modelId: string): (ModelInfo?, ErrorResponse?)
    local models, err = self:listModels()
    
    if err then
        return nil, err
    end
    
    if models then
        for _, model in ipairs(models) do
            if model.id == modelId then
                return model, nil
            end
        end
    end
    
    return nil, { message = "Model not found: " .. modelId, status = 404 }
end

function OpenRouterClass.searchModels(self: OpenRouter, query: string): ({ ModelInfo }?, ErrorResponse?)
    local models, err = self:listModels()
    
    if err then
        return nil, err
    end
    
    local results: { ModelInfo } = {}
    local lowerQuery = string.lower(query)
    
    if models then
        for _, model in ipairs(models) do
            local matchId = model.id and string.find(string.lower(model.id), lowerQuery, 1, true)
            local matchName = model.name and string.find(string.lower(model.name), lowerQuery, 1, true)
            local matchDesc = model.description and string.find(string.lower(model.description), lowerQuery, 1, true)
            
            if matchId or matchName or matchDesc then
                table.insert(results, model)
            end
        end
    end
    
    return results, nil
end

function OpenRouterClass.getCredits(self: OpenRouter): (number?, ErrorResponse?)
    local response, err = self:_request("GET", "/auth/key", nil)
    
    if err then
        return nil, err
    end
    
    if response and response.data then
        local limit = response.data.limit or 0
        local usage = response.data.usage or 0
        return limit - usage, nil
    end
    
    return nil, { message = "Invalid response format", status = 0 }
end

function OpenRouterClass.getUsage(self: OpenRouter): (any?, ErrorResponse?)
    local response, err = self:_request("GET", "/auth/key", nil)
    
    if err then
        return nil, err
    end
    
    if response and response.data then
        return response.data, nil
    end
    
    return nil, { message = "Invalid response format", status = 0 }
end

function OpenRouterClass.withTools(self: OpenRouter, messages: { Message }, tools: { Tool }, model: string?, options: ChatOptions?): (ChatResponse?, ErrorResponse?)
    local mergedOptions = self:_mergeOptions(options)
    mergedOptions.tools = tools
    
    return self:chat(messages, model, mergedOptions)
end

function OpenRouterClass.setDefaultModel(self: OpenRouter, model: string)
    self.defaultModel = model
end

function OpenRouterClass.setDefaultOptions(self: OpenRouter, options: ChatOptions)
    for key, value in pairs(options :: any) do
        (self.defaultOptions :: any)[key] = value
    end
end

function OpenRouterClass.applyPreset(self: OpenRouter, preset: string)
    local presetOptions = PRESETS[preset]
    if presetOptions then
        self:setDefaultOptions(presetOptions :: any)
    end
end

function OpenRouterClass.estimateTokens(_self: OpenRouter, text: string): number
    local charCount = #text
    return math.ceil(charCount / 4)
end

local function systemMessage(content: string): Message
    return { role = "system", content = content }
end

local function userMessage(content: string): Message
    return { role = "user", content = content }
end

local function assistantMessage(content: string): Message
    return { role = "assistant", content = content }
end

local function toolMessage(content: string, toolCallId: string): Message
    return { role = "tool", content = content, tool_call_id = toolCallId }
end

local function createTool(name: string, description: string, parameters: { [string]: any }, required: { string }?): Tool
    return {
        type = "function",
        ["function"] = {
            name = name,
            description = description,
            parameters = {
                type = "object",
                properties = parameters,
                required = required,
            },
        },
    }
end

return {
    new = OpenRouterClass.new,
    
    MODELS = POPULAR_MODELS,
    FREE_MODELS = FREE_MODELS,
    PRESETS = PRESETS,
    
    createTool = createTool,
    systemMessage = systemMessage,
    userMessage = userMessage,
    assistantMessage = assistantMessage,
    toolMessage = toolMessage,
    getRandomFreeModel = getRandomFreeModel,
}
