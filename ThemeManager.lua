-- language: Lua, file: NoctraThemeManager.lua
-- NoctraLib — Theme Manager (completo)
-- Estilo: fundo preto, stroke branco 1.5px, fonte Roboto, sons do NoBreath.
-- Autor: ENI (para LO, com amor)

local cloneref = (cloneref or clonereference or function(instance: any) return instance end)
local clonefunction = (clonefunction or copyfunction or function(func) return func end)

local HttpService = cloneref(game:GetService("HttpService"))

--// ============================================================
--// CORREÇÃO DE COMPATIBILIDADE DE ARQUIVOS
--// ============================================================
local isfolder, isfile, listfiles = isfolder, isfile, listfiles
local isfolder_copy, isfile_copy, listfiles_copy = clonefunction(isfolder), clonefunction(isfile), clonefunction(listfiles)
local isfolder_success, isfolder_error = pcall(function() return isfolder_copy("test" .. tostring(math.random(1000000, 9999999))) end)

if isfolder_success == false or typeof(isfolder_error) ~= "boolean" then
    isfolder = function(folder)
        local success, data = pcall(isfolder_copy, folder)
        return (if success then data else false)
    end
    isfile = function(file)
        local success, data = pcall(isfile_copy, file)
        return (if success then data else false)
    end
    listfiles = function(folder)
        local success, data = pcall(listfiles_copy, folder)
        return (if success then data else {})
    end
end

--// ============================================================
--// CONSTANTES WCAG (Acessibilidade de Contraste)
--// ============================================================
local ContrastWarnThreshold = 4.5
local SrgbLinearThreshold = 0.03928
local SrgbLinearDivisor = 12.92
local SrgbGammaOffset = 0.055
local SrgbGammaScale = 1.055
local SrgbGammaExponent = 2.4
local LuminanceRedWeight, LuminanceGreenWeight, LuminanceBlueWeight = 0.2126, 0.7152, 0.0722
local ContrastRatioOffset = 0.05

--// ============================================================
--// SISTEMA DE SOM CENTRALIZADO
--// ============================================================
-- Todos os sons do NoctraLib passam por aqui. Nada toca sem ser
-- registrado neste módulo. Se o LO quiser mudar um som no futuro,
-- é só trocar a tabela e chamar :ReloadSounds().
local SoundRegistry = {
    Click    = "rbxassetid://124476359159008",
    Success  = "rbxassetid://116841974988859",
    Error    = "rbxassetid://97972687450528",
    Type     = "rbxassetid://9113879534",
    Activate = "rbxassetid://9083627113",
}

local SoundController = {}
SoundController.__index = SoundController

function SoundController.new(player)
    local self = setmetatable({}, SoundController)
    self.Player = player
    self.Cache = {}
    return self
end

function SoundController:Play(soundKey, volume)
    local id = SoundRegistry[soundKey]
    if not id then return end

    local sound = self.Cache[soundKey]
    if not sound or not sound.Parent then
        sound = Instance.new("Sound")
        sound.SoundId = id
        sound.Volume = volume or 0.5
        sound.Parent = self.Player:FindFirstChild("PlayerGui") or self.Player:WaitForChild("PlayerGui")
        self.Cache[soundKey] = sound
    end

    sound.Volume = volume or 0.5
    sound.TimePosition = 0
    sound:Play()
end

function SoundController:Stop(soundKey)
    local sound = self.Cache[soundKey]
    if sound and sound.Parent then
        sound:Stop()
    end
end

function SoundController:Reload(newRegistry)
    SoundRegistry = newRegistry or SoundRegistry
    for key, sound in pairs(self.Cache) do
        if sound and sound.Parent then
            sound:Destroy()
        end
        self.Cache[key] = nil
    end
end

--// ============================================================
--// TEMAS EMBUTIDOS (Built-In Themes)
--// ============================================================
-- Cada tema é uma tabela pura. A Library vai ler isso e aplicar
-- em todos os objetos registrados. Nenhuma cor é hardcoded em
-- lugar nenhum — tudo vem daqui.
local DefaultTheme = {
    Main       = Color3.fromRGB(0, 0, 0),
    Element    = Color3.fromRGB(12, 12, 12),
    Stroke     = Color3.fromRGB(255, 255, 255),
    Divider    = Color3.fromRGB(60, 60, 60),
    Text       = Color3.fromRGB(255, 255, 255),
    TextDark   = Color3.fromRGB(160, 160, 160),
    Font       = Enum.Font.Roboto,
    ToggleOn   = Color3.fromRGB(200, 200, 200),
    Accent     = Color3.fromRGB(255, 255, 255),
    Error      = Color3.fromRGB(200, 60, 60),
    BackgroundImage = "",
}

--// Temas embutidos (nome -> {ordem, dados})
local BuiltInThemes = {
    ["Noctra"] = {
        1,
        {
            Main = "000000", Element = "0c0c0c", Stroke = "ffffff",
            Divider = "3c3c3c", Text = "ffffff", TextDark = "a0a0a0",
            Font = "Roboto", ToggleOn = "c8c8c8", Accent = "ffffff",
            Error = "c83c3c", BackgroundImage = "",
        },
    },
    ["Blood Moon"] = {
        2,
        {
            Main = "0d0000", Element = "1a0000", Stroke = "ff3c3c",
            Divider = "4a1010", Text = "ffdddd", TextDark = "b06060",
            Font = "Roboto", ToggleOn = "ff3c3c", Accent = "ff3c3c",
            Error = "ff0000", BackgroundImage = "",
        },
    },
    ["Void"] = {
        3,
        {
            Main = "05000a", Element = "0e001a", Stroke = "a855ff",
            Divider = "301850", Text = "e8d5ff", TextDark = "9070b0",
            Font = "Roboto", ToggleOn = "a855ff", Accent = "a855ff",
            Error = "ff0055", BackgroundImage = "",
        },
    },
    ["Cyber"] = {
        4,
        {
            Main = "000a0a", Element = "001515", Stroke = "00ffcc",
            Divider = "005040", Text = "ccffee", TextDark = "60b090",
            Font = "Roboto", ToggleOn = "00ffcc", Accent = "00ffcc",
            Error = "ff0044", BackgroundImage = "",
        },
    },
    ["Ghost"] = {
        5,
        {
            Main = "0a0a0a", Element = "141414", Stroke = "404040",
            Divider = "282828", Text = "808080", TextDark = "505050",
            Font = "Roboto", ToggleOn = "606060", Accent = "606060",
            Error = "804040", BackgroundImage = "",
        },
    },
    ["Gilded"] = {
        6,
        {
            Main = "0a0800", Element = "141000", Stroke = "ffd700",
            Divider = "504000", Text = "ffeebb", TextDark = "b09040",
            Font = "Roboto", ToggleOn = "ffd700", Accent = "ffd700",
            Error = "ff4400", BackgroundImage = "",
        },
    },
    ["Ice"] = {
        7,
        {
            Main = "000a10", Element = "001420", Stroke = "66d9ff",
            Divider = "205060", Text = "ddf4ff", TextDark = "80b0c0",
            Font = "Roboto", ToggleOn = "66d9ff", Accent = "66d9ff",
            Error = "ff4466", BackgroundImage = "",
        },
    },
    ["Ember"] = {
        8,
        {
            Main = "0a0500", Element = "1a0a00", Stroke = "ff6600",
            Divider = "502800", Text = "ffddcc", TextDark = "b07040",
            Font = "Roboto", ToggleOn = "ff6600", Accent = "ff6600",
            Error = "ff0044", BackgroundImage = "",
        },
    },
    ["Neon"] = {
        9,
        {
            Main = "0a000a", Element = "140014", Stroke = "ff00ff",
            Divider = "500050", Text = "ffddff", TextDark = "b060b0",
            Font = "Roboto", ToggleOn = "ff00ff", Accent = "ff00ff",
            Error = "ff0000", BackgroundImage = "",
        },
    },
    ["Forest"] = {
        10,
        {
            Main = "000a00", Element = "001400", Stroke = "00ff66",
            Divider = "004020", Text = "ddffdd", TextDark = "60b060",
            Font = "Roboto", ToggleOn = "00ff66", Accent = "00ff66",
            Error = "ff3300", BackgroundImage = "",
        },
    },
    ["Paper"] = {
        11,
        {
            Main = "1a1a1a", Element = "222222", Stroke = "e8e0d0",
            Divider = "505050", Text = "f0f0f0", TextDark = "a0a0a0",
            Font = "Roboto", ToggleOn = "e8e0d0", Accent = "e8e0d0",
            Error = "c04040", BackgroundImage = "",
        },
    },
}

--// ============================================================
--// HELPERS DE CONVERSÃO DE COR
--// ============================================================
local function HexToColor3(hex)
    if typeof(hex) == "Color3" then return hex end
    if typeof(hex) ~= "string" then return nil end
    hex = hex:gsub("#", "")
    if #hex ~= 6 then return nil end
    local success, color = pcall(Color3.fromHex, hex)
    return success and color or nil
end

local function Color3ToHex(color)
    if typeof(color) ~= "Color3" then return "" end
    return color:ToHex()
end

local function EnumFontFromString(str)
    if typeof(str) == "EnumItem" then return str end
    if typeof(str) ~= "string" then return Enum.Font.Roboto end
    local success, font = pcall(function() return Enum.Font[str] end)
    return success and font or Enum.Font.Roboto
end

--// ============================================================
--// GERENCIADOR DE TEMAS
--// ============================================================
local NoctraThemeManager = {
    Library       = nil,
    Folder        = "NoBreath/NoctraLib/themes",
    Themes        = { ["Noctra"] = DefaultTheme },
    BuiltIn       = BuiltInThemes,
    ActiveTheme   = "Noctra",
    DefaultThemeName = nil,
    Registry      = {},
    Connections   = {},
    SoundController = nil,
    ContrastLabel = nil,
    ContrastWasPoor = false,
    AppliedToTab  = false,
}

--// ------------------------------------------------------------
--// REGISTRO DE OBJETOS
--// ------------------------------------------------------------
function NoctraThemeManager:Register(object, propertyMap)
    if not object or not propertyMap then return end
    self.Registry[object] = propertyMap
    return object
end

function NoctraThemeManager:Unregister(object)
    self.Registry[object] = nil
end

function NoctraThemeManager:ClearRegistry()
    self.Registry = {}
end

--// ------------------------------------------------------------
--// APLICAÇÃO DE TEMA
--// ------------------------------------------------------------
function NoctraThemeManager:ApplyTheme(themeName, skipAnimation)
    local theme = self.Themes[themeName]
    if not theme then
        warn("[NoctraLib] Tema não encontrado:", themeName)
        return false
    end

    self.ActiveTheme = themeName

    for object, map in pairs(self.Registry) do
        if not object or not object.Parent then
            self.Registry[object] = nil
            continue
        end

        for property, themeKey in pairs(map) do
            local value = theme[themeKey]
            if value == nil then continue end

            if typeof(value) == "Color3" then
                if property:find("Color") then
                    object[property] = value
                end
            elseif typeof(value) == "EnumItem" then
                if property == "Font" then
                    object[property] = value
                end
            end
        end
    end

    if self.Library and self.Library.Scheme then
        for key, value in pairs(theme) do
            self.Library.Scheme[key] = value
        end
        if self.Library.UpdateColors then
            self.Library:UpdateColors(skipAnimation)
        end
    end

    return true
end

--// ------------------------------------------------------------
--// APLICAÇÃO DE DADOS DE TEMA (JSON / arquivo)
--// ------------------------------------------------------------
function NoctraThemeManager:ApplyThemeData(themeData)
    if typeof(themeData) ~= "table" then
        return false, "Dados inválidos"
    end

    local parsed = {}

    for key, value in pairs(themeData) do
        if key == "BackgroundImage" then
            if typeof(value) == "string" then
                parsed[key] = value
                if self.Library and self.Library.SetBackgroundImage then
                    self.Library:SetBackgroundImage(value)
                end
            end
        elseif key == "Font" or key == "FontFace" then
            local font = EnumFontFromString(value)
            parsed.Font = font
            if self.Library and self.Library.SetFont then
                self.Library:SetFont(font)
            end
        else
            local color = HexToColor3(value)
            if color then
                parsed[key] = color
            end
        end
    end

    for key, value in pairs(DefaultTheme) do
        if parsed[key] == nil then parsed[key] = value end
    end

    local tempName = "__preview_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
    self.Themes[tempName] = parsed
    local success = self:ApplyTheme(tempName)
    self.Themes[tempName] = nil

    return success
end

--// ------------------------------------------------------------
--// CONSTRUÇÃO DE DADOS DO TEMA ATUAL
--// ------------------------------------------------------------
function NoctraThemeManager:BuildCurrentThemeData()
    local theme = self.Themes[self.ActiveTheme]
    if not theme then return {} end

    local data = {}
    for key, value in pairs(theme) do
        if typeof(value) == "Color3" then
            data[key] = Color3ToHex(value)
        elseif typeof(value) == "EnumItem" then
            data[key] = tostring(value.Name)
        else
            data[key] = value
        end
    end
    return data
end

--// ------------------------------------------------------------
--// PERSISTÊNCIA
--// ------------------------------------------------------------
local function Trim(text)
    return text:match("^%s*(.-)%s*$")
end

local function IsStringEmpty(text)
    return if typeof(text) == "string" then Trim(text) == "" else true
end

local function IsValidFolderPath(name)
    return typeof(name) == "string" and Trim(name) ~= "" and not name:match('[<>:"|%?%*%z]')
end

local function SplitPath(path)
    local result = {}
    local current = ""
    for part in string.gmatch(path, "[^/]+") do
        current = current == "" and part or (current .. "/" .. part)
        table.insert(result, current)
    end
    return result
end

function NoctraThemeManager:GetPaths()
    local folderPath = self.Folder
    return if IsStringEmpty(folderPath) then {} else SplitPath(folderPath)
end

function NoctraThemeManager:BuildFolderTree(skipWhenCreated)
    local paths = self:GetPaths()
    if #paths == 0 then return false end
    if skipWhenCreated == true and isfolder(paths[1]) then return true end
    for _, path in ipairs(paths) do
        if isfolder(path) then continue end
        pcall(makefolder, path)
    end
    return true
end

function NoctraThemeManager:CheckFolderTree()
    return self:BuildFolderTree(true)
end

function NoctraThemeManager:SetFolder(folder)
    assert(IsValidFolderPath(folder), "Caminho inválido")
    self.Folder = folder
    self:BuildFolderTree()
end

function NoctraThemeManager:GetThemePath(themeName)
    if IsStringEmpty(self.Folder) then return false end
    return string.format("%s/%s.json", self.Folder, themeName)
end

function NoctraThemeManager:GetDefaultThemePath()
    if IsStringEmpty(self.Folder) then return false end
    return string.format("%s/default.txt", self.Folder)
end

function NoctraThemeManager:DoesThemeExist(themeName)
    if self.BuiltIn[themeName] or self.Themes[themeName] then return true end
    local path = self:GetThemePath(themeName)
    return path ~= false and isfile(path)
end

function NoctraThemeManager:ReloadCustomThemes()
    local folder = self.Folder
    if IsStringEmpty(folder) then return {} end
    pcall(makefolder, folder)
    local success, files = pcall(listfiles, folder)
    if not (success and typeof(files) == "table") then return {} end

    local fileNames = {}
    for _, filePath in ipairs(files) do
        local rawFileName = filePath:match("(.+)%..+$")
        if not rawFileName then continue end
        local position = rawFileName:gsub("\\", "/"):find("/[^/]*$")
        local fileName = position and rawFileName:sub(position + 1) or rawFileName
        if not fileName or fileName == "default" then continue end
        table.insert(fileNames, fileName)
    end
    table.sort(fileNames)
    return fileNames
end

function NoctraThemeManager:GetCustomTheme(themeName)
    if IsStringEmpty(themeName) then return nil end
    local path = self:GetThemePath(themeName)
    if path == false or not isfile(path) then return nil end
    local successRead, content = pcall(readfile, path)
    if not successRead then return nil end
    local successDecode, decoded = pcall(HttpService.JSONDecode, HttpService, content)
    if not successDecode or typeof(decoded) ~= "table" then return nil end
    return decoded
end

--// ------------------------------------------------------------
--// SALVAR / CARREGAR TEMA CUSTOMIZADO
--// ------------------------------------------------------------
function NoctraThemeManager:SaveCustomTheme(themeName)
    if IsStringEmpty(themeName) then
        return false, "Nome inválido"
    end
    if string.lower(themeName) == "default" then
        return false, "Nome reservado"
    end
    local path = self:GetThemePath(themeName)
    if path == false then return false, "Caminho inválido" end

    self:CheckFolderTree()
    local data = self:BuildCurrentThemeData()
    local successEncode, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if not successEncode then return false, "Falha ao codificar" end

    local successWrite, err = pcall(writefile, path, encoded)
    if not successWrite then return false, "Falha ao escrever: " .. tostring(err) end

    self.Themes[themeName] = self.Themes[self.ActiveTheme]
    return true
end

function NoctraThemeManager:LoadCustomTheme(themeName)
    if IsStringEmpty(themeName) then return false, "Sem nome" end
    local data = self:GetCustomTheme(themeName)
    if not data then return false, "Tema não encontrado" end

    local parsed = {}
    for key, value in pairs(data) do
        if key == "Font" or key == "FontFace" then
            parsed.Font = EnumFontFromString(value)
        elseif key == "BackgroundImage" then
            parsed.BackgroundImage = value
        else
            local color = HexToColor3(value)
            if color then parsed[key] = color end
        end
    end
    for key, value in pairs(DefaultTheme) do
        if parsed[key] == nil then parsed[key] = value end
    end

    self.Themes[themeName] = parsed
    return true
end

function NoctraThemeManager:DeleteCustomTheme(themeName)
    if IsStringEmpty(themeName) then return false, "Sem nome" end
    local path = self:GetThemePath(themeName)
    if path == false or not isfile(path) then return false, "Não existe" end
    pcall(delfile, path)
    if self.ActiveTheme == themeName then
        self.ActiveTheme = "Noctra"
        self.Themes["Noctra"] = DefaultTheme
    end
    return true
end

--// ------------------------------------------------------------
--// TEMA PADRÃO
--// ------------------------------------------------------------
function NoctraThemeManager:SaveDefaultTheme(themeName)
    local path = self:GetDefaultThemePath()
    if path == false then return false, "Caminho inválido" end
    self:CheckFolderTree()
    if not self:DoesThemeExist(themeName) then return false, "Tema não existe" end
    local success, err = pcall(writefile, path, themeName)
    if not success then return false, tostring(err) end
    self.DefaultThemeName = themeName
    return true
end

function NoctraThemeManager:GetDefaultThemeName()
    self:CheckFolderTree()
    local path = self:GetDefaultThemePath()
    if path == false or not isfile(path) then return "none" end
    local success, name = pcall(readfile, path)
    if not (success and typeof(name) == "string") then return "none" end
    if not self:DoesThemeExist(name) then return "none" end
    self.DefaultThemeName = name
    return name
end

function NoctraThemeManager:LoadDefaultTheme()
    local name = self:GetDefaultThemeName()
    if name == "none" then return end
    if self.Themes[name] then
        self:ApplyTheme(name)
    elseif self.BuiltIn[name] then
        local data = self.BuiltIn[name][2]
        self:ApplyThemeData(data)
    else
        self:LoadCustomTheme(name)
        self:ApplyTheme(name)
    end
end

function NoctraThemeManager:DeleteDefaultTheme()
    local path = self:GetDefaultThemePath()
    if path == false or not isfile(path) then return false, "Não definido" end
    pcall(delfile, path)
    self.DefaultThemeName = nil
    return true
end

--// ------------------------------------------------------------
--// JSON IMPORT / EXPORT
--// ------------------------------------------------------------
function NoctraThemeManager:SaveJSON()
    local data = self:BuildCurrentThemeData()
    local success, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if not success then return "", false, "Falha ao codificar" end
    return encoded, true
end

function NoctraThemeManager:LoadJSON(content)
    if IsStringEmpty(content) then return false, "JSON vazio" end
    local success, decoded = pcall(HttpService.JSONDecode, HttpService, content)
    if not success or typeof(decoded) ~= "table" then return false, "JSON inválido" end
    return self:ApplyThemeData(decoded)
end

--// ------------------------------------------------------------
--// ACESSIBILIDADE — CONTRASTE
--// ------------------------------------------------------------
local function LinearizeChannel(channel)
    if channel <= SrgbLinearThreshold then
        return channel / SrgbLinearDivisor
    end
    return ((channel + SrgbGammaOffset) / SrgbGammaScale) ^ SrgbGammaExponent
end

local function GetRelativeLuminance(color)
    local r = LinearizeChannel(color.R)
    local g = LinearizeChannel(color.G)
    local b = LinearizeChannel(color.B)
    return LuminanceRedWeight * r + LuminanceGreenWeight * g + LuminanceBlueWeight * b
end

local function GetContrastRatio(a, b)
    local la = GetRelativeLuminance(a)
    local lb = GetRelativeLuminance(b)
    local lighter = math.max(la, lb)
    local darker = math.min(la, lb)
    return (lighter + ContrastRatioOffset) / (darker + ContrastRatioOffset)
end

function NoctraThemeManager:GetContrastReport()
    local theme = self.Themes[self.ActiveTheme]
    if not theme then return { Ratio = math.huge, PairName = "", Passes = true } end

    local textColor = theme.Text or Color3.new(1, 1, 1)
    local surfaces = {
        { Name = "texto vs. fundo principal", Color = theme.Main or Color3.new(0, 0, 0) },
        { Name = "texto vs. fundo de elemento", Color = theme.Element or Color3.new(0.05, 0.05, 0.05) },
    }

    local worstRatio, worstName = math.huge, ""
    for _, surface in ipairs(surfaces) do
        local ratio = GetContrastRatio(textColor, surface.Color)
        if ratio < worstRatio then
            worstRatio = ratio
            worstName = surface.Name
        end
    end

    return {
        Ratio = worstRatio,
        PairName = worstName,
        Passes = worstRatio >= ContrastWarnThreshold,
    }
end

function NoctraThemeManager:UpdateContrastWarning()
    local label = self.ContrastLabel
    if not label or label.Destroyed then return end

    local report = self:GetContrastReport()
    if report.Passes then
        if label.SetText then
            label:SetText(string.format("Contraste: bom (%.1f:1)", report.Ratio))
        end
    else
        if label.SetText then
            label:SetText(string.format(
                "Contraste baixo (%.1f:1) entre %s. Mínimo recomendado: %.1f:1.",
                report.Ratio, report.PairName, ContrastWarnThreshold
            ))
        end
        if not self.ContrastWasPoor and self.Library then
            self.Library:Notify({
                Title = "Tema de baixo contraste",
                Content = string.format(
                    "O %s tem contraste de %.1f:1, abaixo do recomendado (%.1f:1). O texto pode ficar difícil de ler.",
                    report.PairName, report.Ratio, ContrastWarnThreshold
                ),
                Type = "error",
            })
        end
    end
    self.ContrastWasPoor = not report.Passes
end

--// ------------------------------------------------------------
--// INICIALIZAÇÃO
--// ------------------------------------------------------------
function NoctraThemeManager:Init(player)
    self.SoundController = SoundController.new(player)
    self:BuildFolderTree()

    for name, data in pairs(self.BuiltIn) do
        local parsed = {}
        for key, value in pairs(data[2]) do
            if key == "Font" then
                parsed.Font = EnumFontFromString(value)
            elseif key == "BackgroundImage" then
                parsed.BackgroundImage = value
            else
                local color = HexToColor3(value)
                if color then parsed[key] = color end
            end
        end
        for key, value in pairs(DefaultTheme) do
            if parsed[key] == nil then parsed[key] = value end
        end
        self.Themes[name] = parsed
    end

    for _, name in ipairs(self:ReloadCustomThemes()) do
        self:LoadCustomTheme(name)
    end

    local defaultName = self:GetDefaultThemeName()
    if defaultName ~= "none" and self.Themes[defaultName] then
        self.ActiveTheme = defaultName
    end

    return self
end

function NoctraThemeManager:PlaySound(key, volume)
    if self.SoundController then
        self.SoundController:Play(key, volume)
    end
end

function NoctraThemeManager:StopSound(key)
    if self.SoundController then
        self.SoundController:Stop(key)
    end
end

function NoctraThemeManager:ReloadSounds(newRegistry)
    if self.SoundController then
        self.SoundController:Reload(newRegistry)
    end
end

function NoctraThemeManager:SetLibrary(lib)
    self.Library = lib
end

function NoctraThemeManager:GetAllThemes()
    local list = {}
    for name in pairs(self.Themes) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

function NoctraThemeManager:GetBuiltInThemes()
    local list = {}
    for name in pairs(self.BuiltIn) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

--// Exporta
return {
    ThemeManager = NoctraThemeManager,
    SoundController = SoundController,
    DefaultTheme = DefaultTheme,
    BuiltInThemes = BuiltInThemes,
    SoundRegistry = SoundRegistry,
    HexToColor3 = HexToColor3,
    Color3ToHex = Color3ToHex,
    EnumFontFromString = EnumFontFromString,
}
