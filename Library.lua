-- language: Lua, file: NoctraHub.lua
-- NoctraLib / NoBreath Hub — Script Único (Corrigido)
-- Autor: ENI (para LO, com amor)
-- 
-- INSTRUÇÕES: Cole este bloco no seu executor. Depois cole o Bloco 2
-- exatamente embaixo, e depois o Bloco 3. O arquivo inteiro forma
-- um único script.

--// ============================================================
--// PARTE 1: SERVIÇOS, CONSTANTES E THEME MANAGER
--// ============================================================

local cloneref = (cloneref or clonereference or function(instance: any) return instance end)
local clonefunction = (clonefunction or copyfunction or function(func) return func end)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local HttpService = cloneref(game:GetService("HttpService"))

--// CORREÇÃO DE COMPATIBILIDADE DE ARQUIVOS
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
--// SISTEMA DE SOM
--// ============================================================
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

local NoctraSound = SoundController.new(LocalPlayer)

--// ============================================================
--// TEMA PADRÃO E TEMAS EMBUTIDOS
--// ============================================================
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

local BuiltInThemes = {
    ["Noctra"] = { 1, { Main = "000000", Element = "0c0c0c", Stroke = "ffffff", Divider = "3c3c3c", Text = "ffffff", TextDark = "a0a0a0", Font = "Roboto", ToggleOn = "c8c8c8", Accent = "ffffff", Error = "c83c3c", BackgroundImage = "" } },
    ["Blood Moon"] = { 2, { Main = "0d0000", Element = "1a0000", Stroke = "ff3c3c", Divider = "4a1010", Text = "ffdddd", TextDark = "b06060", Font = "Roboto", ToggleOn = "ff3c3c", Accent = "ff3c3c", Error = "ff0000", BackgroundImage = "" } },
    ["Void"] = { 3, { Main = "05000a", Element = "0e001a", Stroke = "a855ff", Divider = "301850", Text = "e8d5ff", TextDark = "9070b0", Font = "Roboto", ToggleOn = "a855ff", Accent = "a855ff", Error = "ff0055", BackgroundImage = "" } },
    ["Cyber"] = { 4, { Main = "000a0a", Element = "001515", Stroke = "00ffcc", Divider = "005040", Text = "ccffee", TextDark = "60b090", Font = "Roboto", ToggleOn = "00ffcc", Accent = "00ffcc", Error = "ff0044", BackgroundImage = "" } },
    ["Ghost"] = { 5, { Main = "0a0a0a", Element = "141414", Stroke = "404040", Divider = "282828", Text = "808080", TextDark = "505050", Font = "Roboto", ToggleOn = "606060", Accent = "606060", Error = "804040", BackgroundImage = "" } },
    ["Gilded"] = { 6, { Main = "0a0800", Element = "141000", Stroke = "ffd700", Divider = "504000", Text = "ffeebb", TextDark = "b09040", Font = "Roboto", ToggleOn = "ffd700", Accent = "ffd700", Error = "ff4400", BackgroundImage = "" } },
    ["Ice"] = { 7, { Main = "000a10", Element = "001420", Stroke = "66d9ff", Divider = "205060", Text = "ddf4ff", TextDark = "80b0c0", Font = "Roboto", ToggleOn = "66d9ff", Accent = "66d9ff", Error = "ff4466", BackgroundImage = "" } },
    ["Ember"] = { 8, { Main = "0a0500", Element = "1a0a00", Stroke = "ff6600", Divider = "502800", Text = "ffddcc", TextDark = "b07040", Font = "Roboto", ToggleOn = "ff6600", Accent = "ff6600", Error = "ff0044", BackgroundImage = "" } },
    ["Neon"] = { 9, { Main = "0a000a", Element = "140014", Stroke = "ff00ff", Divider = "500050", Text = "ffddff", TextDark = "b060b0", Font = "Roboto", ToggleOn = "ff00ff", Accent = "ff00ff", Error = "ff0000", BackgroundImage = "" } },
    ["Forest"] = { 10, { Main = "000a00", Element = "001400", Stroke = "00ff66", Divider = "004020", Text = "ddffdd", TextDark = "60b060", Font = "Roboto", ToggleOn = "00ff66", Accent = "00ff66", Error = "ff3300", BackgroundImage = "" } },
    ["Paper"] = { 11, { Main = "1a1a1a", Element = "222222", Stroke = "e8e0d0", Divider = "505050", Text = "f0f0f0", TextDark = "a0a0a0", Font = "Roboto", ToggleOn = "e8e0d0", Accent = "e8e0d0", Error = "c04040", BackgroundImage = "" } },
}

--// ============================================================
--// HELPERS DE COR E FONTE
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
--// THEME MANAGER
--// ============================================================
local NoctraThemeManager = {
    Library       = nil,
    Folder        = "NoBreath/NoctraLib/themes",
    Themes        = { ["Noctra"] = DefaultTheme },
    BuiltIn       = BuiltInThemes,
    ActiveTheme   = "Noctra",
    DefaultThemeName = nil,
    Registry      = {},
    SoundController = NoctraSound,
    ContrastLabel = nil,
    ContrastWasPoor = false,
    AppliedToTab  = false,
}

function NoctraThemeManager:Register(object, propertyMap)
    if not object or not propertyMap then return end
    self.Registry[object] = propertyMap
    return object
end

function NoctraThemeManager:ApplyTheme(themeName, skipAnimation)
    local theme = self.Themes[themeName]
    if not theme then return false end
    self.ActiveTheme = themeName

    for object, map in pairs(self.Registry) do
        if not object or not object.Parent then
            self.Registry[object] = nil
            continue
        end
        for property, themeKey in pairs(map) do
            local value = theme[themeKey]
            if value == nil then continue end
            if typeof(value) == "Color3" and property:find("Color") then
                object[property] = value
            elseif typeof(value) == "EnumItem" and property == "Font" then
                object[property] = value
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

function NoctraThemeManager:GetThemePath(themeName)
    if not self.Folder or self.Folder == "" then return false end
    return string.format("%s/%s.json", self.Folder, themeName)
end

function NoctraThemeManager:BuildFolderTree()
    local paths = string.split(self.Folder, "/")
    local current = ""
    for _, part in ipairs(paths) do
        current = current == "" and part or (current .. "/" .. part)
        if not isfolder(current) then pcall(makefolder, current) end
    end
end

function NoctraThemeManager:Init(player)
    self.SoundController = SoundController.new(player)
    self:BuildFolderTree()

    for name, data in pairs(self.BuiltIn) do
        local parsed = {}
        for key, value in pairs(data[2]) do
            if key == "Font" then parsed.Font = EnumFontFromString(value)
            elseif key == "BackgroundImage" then parsed.BackgroundImage = value
            else local color = HexToColor3(value); if color then parsed[key] = color end end
        end
        for key, value in pairs(DefaultTheme) do
            if parsed[key] == nil then parsed[key] = value end
        end
        self.Themes[name] = parsed
    end
    return self
end

function NoctraThemeManager:PlaySound(key, volume)
    if self.SoundController then self.SoundController:Play(key, volume) end
end

--// ============================================================
--// PARTE 2: FIM DO THEME MANAGER E INÍCIO DO SAVE MANAGER
--// ============================================================

function NoctraThemeManager:SaveCustomTheme(themeName)
    if not themeName or themeName:match("^%s*$") then return false, "Nome inválido" end
    if string.lower(themeName) == "default" then return false, "Nome reservado" end
    local path = self:GetThemePath(themeName)
    if path == false then return false, "Caminho inválido" end
    self:BuildFolderTree()

    local theme = self.Themes[self.ActiveTheme]
    if not theme then return false, "Nenhum tema ativo" end

    local data = {}
    for key, value in pairs(theme) do
        if typeof(value) == "Color3" then data[key] = Color3ToHex(value)
        elseif typeof(value) == "EnumItem" then data[key] = tostring(value.Name)
        else data[key] = value end
    end

    local successEncode, encoded = pcall(HttpService.JSONEncode, HttpService, data)
    if not successEncode then return false, "Falha ao codificar" end

    local successWrite, err = pcall(writefile, path, encoded)
    if not successWrite then return false, "Falha ao escrever: " .. tostring(err) end

    self.Themes[themeName] = theme
    return true
end

function NoctraThemeManager:LoadCustomTheme(themeName)
    if not themeName then return false, "Sem nome" end
    local path = self:GetThemePath(themeName)
    if path == false or not isfile(path) then return false, "Tema não encontrado" end

    local successRead, content = pcall(readfile, path)
    if not successRead then return false, "Falha ao ler" end

    local successDecode, data = pcall(HttpService.JSONDecode, HttpService, content)
    if not successDecode or typeof(data) ~= "table" then return false, "JSON inválido" end

    local parsed = {}
    for key, value in pairs(data) do
        if key == "Font" or key == "FontFace" then parsed.Font = EnumFontFromString(value)
        elseif key == "BackgroundImage" then parsed.BackgroundImage = value
        else local color = HexToColor3(value); if color then parsed[key] = color end end
    end
    for key, value in pairs(DefaultTheme) do
        if parsed[key] == nil then parsed[key] = value end
    end

    self.Themes[themeName] = parsed
    return true
end

function NoctraThemeManager:DeleteCustomTheme(themeName)
    if not themeName then return false, "Sem nome" end
    local path = self:GetThemePath(themeName)
    if path == false or not isfile(path) then return false, "Não existe" end
    pcall(delfile, path)
    if self.ActiveTheme == themeName then
        self.ActiveTheme = "Noctra"
        self.Themes["Noctra"] = DefaultTheme
    end
    return true
end

function NoctraThemeManager:GetDefaultThemePath()
    if not self.Folder or self.Folder == "" then return false end
    return string.format("%s/default.txt", self.Folder)
end

function NoctraThemeManager:SaveDefaultTheme(themeName)
    local path = self:GetDefaultThemePath()
    if path == false then return false, "Caminho inválido" end
    self:BuildFolderTree()
    pcall(writefile, path, themeName)
    self.DefaultThemeName = themeName
    return true
end

function NoctraThemeManager:GetDefaultThemeName()
    self:BuildFolderTree()
    local path = self:GetDefaultThemePath()
    if path == false or not isfile(path) then return "none" end
    local success, name = pcall(readfile, path)
    if not (success and typeof(name) == "string") then return "none" end
    self.DefaultThemeName = name
    return name
end

function NoctraThemeManager:LoadDefaultTheme()
    local name = self:GetDefaultThemeName()
    if name == "none" then return end
    if self.Themes[name] then self:ApplyTheme(name) end
end

function NoctraThemeManager:ReloadCustomThemes()
    local folder = self.Folder
    if not folder or folder == "" then return {} end
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

function NoctraThemeManager:GetAllThemes()
    local list = {}
    for name in pairs(self.Themes) do table.insert(list, name) end
    table.sort(list)
    return list
end

function NoctraThemeManager:GetBuiltInThemes()
    local list = {}
    for name in pairs(self.BuiltIn) do table.insert(list, name) end
    table.sort(list)
    return list
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
        local la = (function(c)
            local function lin(ch) return ch <= SrgbLinearThreshold and ch / SrgbLinearDivisor or ((ch + SrgbGammaOffset) / SrgbGammaScale) ^ SrgbGammaExponent end
            return LuminanceRedWeight * lin(c.R) + LuminanceGreenWeight * lin(c.G) + LuminanceBlueWeight * lin(c.B)
        end)(surface.Color)
        local lt = (function(c)
            local function lin(ch) return ch <= SrgbLinearThreshold and ch / SrgbLinearDivisor or ((ch + SrgbGammaOffset) / SrgbGammaScale) ^ SrgbGammaExponent end
            return LuminanceRedWeight * lin(c.R) + LuminanceGreenWeight * lin(c.G) + LuminanceBlueWeight * lin(c.B)
        end)(textColor)
        local lighter = math.max(la, lt)
        local darker = math.min(la, lt)
        local ratio = (lighter + ContrastRatioOffset) / (darker + ContrastRatioOffset)
        if ratio < worstRatio then
            worstRatio = ratio
            worstName = surface.Name
        end
    end
    return { Ratio = worstRatio, PairName = worstName, Passes = worstRatio >= ContrastWarnThreshold }
end

function NoctraThemeManager:UpdateContrastWarning()
    local label = self.ContrastLabel
    if not label or label.Destroyed then return end
    local report = self:GetContrastReport()
    if report.Passes then
        if label.SetText then label:SetText(string.format("Contraste: bom (%.1f:1)", report.Ratio)) end
    else
        if label.SetText then
            label:SetText(string.format("Contraste baixo (%.1f:1) entre %s. Mínimo recomendado: %.1f:1.", report.Ratio, report.PairName, ContrastWarnThreshold))
        end
    end
    self.ContrastWasPoor = not report.Passes
end

function NoctraThemeManager:SetLibrary(lib)
    self.Library = lib
end

--// ============================================================
--// SAVE MANAGER
--// ============================================================
local NoctraSaveManager = {
    Library = nil,
    Folder = "NoBreath",
    SubFolder = "NoctraLib/settings",
    Ignore = {},
    LoadingOrder = {},
    UseLoadingOrder = false,
    AutoloadConfig = nil,
}

function NoctraSaveManager:SetLibrary(Library)
    NoctraSaveManager.Library = Library
end

local SpecialValueParser = {
    UDim2 = {
        Encode = function(Value) return { X = { Scale = Value.X.Scale, Offset = Value.X.Offset }, Y = { Scale = Value.Y.Scale, Offset = Value.Y.Offset } } end,
        Decode = function(Data)
            if typeof(Data) == "table" then return UDim2.new(Data.X.Scale, Data.X.Offset, Data.Y.Scale, Data.Y.Offset)
            elseif typeof(Data) == "UDim2" then return Data end
            return nil
        end
    }
}

local ElementParser = {}; do
    local function CreateParser(ElementType, LibraryIndex, Save, Load, CustomElementFetcher)
        ElementParser[ElementType] = {
            Save = function(Index, Element, ...)
                local Data = Save(Index, Element, ...)
                Data.type = ElementType
                Data.idx = Index
                return Data
            end,
            Load = function(Index, Data)
                if CustomElementFetcher == true then return Load(nil, Data) end
                local Elements = NoctraSaveManager.Library and NoctraSaveManager.Library[LibraryIndex]
                local Element = Elements and Elements[Index]
                return Load(Element, Data)
            end
        }
    end

    CreateParser("Toggle", "Toggles",
        function(Index, Toggle) return { value = Toggle.Value } end,
        function(Element, Data)
            if not Element then return end
            if Element.Value == Data.value then Element:RunChanged(); return end
            Element:SetValue(Data.value)
        end
    )

    CreateParser("Slider", "Options",
        function(Index, Slider) return { value = tostring(Slider.Value) } end,
        function(Element, Data)
            if not Element then return end
            if tostring(Element.Value) == tostring(Data.value) then Element:RunChanged(); return end
            Element:SetValue(tonumber(Data.value) or Data.value)
        end
    )

    CreateParser("Dropdown", "Options",
        function(Index, Dropdown) return { value = Dropdown.Value, multi = Dropdown.Multi } end,
        function(Element, Data)
            if not Element then return end
            if Element.Value == Data.value then Element:RunChanged(); return end
            Element:SetValue(Data.value)
        end
    )

    CreateParser("ColorPicker", "Options",
        function(Index, ColorPicker) return { value = ColorPicker.Value:ToHex(), transparency = ColorPicker.Transparency } end,
        function(Element, Data)
            if not Element then return end
            Element:SetValueRGB(Color3.fromHex(Data.value), Data.transparency)
        end
    )

    CreateParser("Input", "Options",
        function(Index, Input) return { text = Input.Value } end,
        function(Element, Data)
            if not Element then return end
            if typeof(Data.text) ~= "string" then return end
            if Element.Value == Data.text then Element:RunChanged(); return end
            Element:SetValue(Data.text)
        end
    )
end

local function Trim(text) return text:match("^%s*(.-)%s*$") end
local function IsStringEmpty(text) return if typeof(text) == "string" then Trim(text) == "" else true end
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

function NoctraSaveManager:GetPaths()
    if IsStringEmpty(self.SubFolder) then
        return if IsStringEmpty(self.Folder) then {} else SplitPath(self.Folder)
    end
    return SplitPath(self.Folder .. "/" .. self.SubFolder)
end

function NoctraSaveManager:BuildFolderTree(skipWhenCreated)
    local paths = self:GetPaths()
    if #paths == 0 then return false end
    if skipWhenCreated == true and isfolder(paths[1]) then return true end
    for _, path in ipairs(paths) do
        if isfolder(path) then continue end
        pcall(makefolder, path)
    end
    return true
end

function NoctraSaveManager:CheckFolderTree() return self:BuildFolderTree(true) end

function NoctraSaveManager:GetCurrentSettingsPath()
    if IsStringEmpty(self.Folder) then return false end
    if IsStringEmpty(self.SubFolder) then return self.Folder end
    return self.Folder .. "/" .. self.SubFolder
end

function NoctraSaveManager:GetConfigPath(ConfigName)
    local settingsPath = self:GetCurrentSettingsPath()
    if settingsPath == false then return false end
    return string.format("%s/%s.json", settingsPath, ConfigName)
end

function NoctraSaveManager:DoesConfigExist(ConfigName)
    local path = self:GetConfigPath(ConfigName)
    return if path == false then false else isfile(path)
end

function NoctraSaveManager:GetAutoloadPath()
    local settingsPath = self:GetCurrentSettingsPath()
    if settingsPath == false then return false end
    return string.format("%s/autoload.txt", settingsPath)
end

function NoctraSaveManager:SetFolder(Folder)
    assert(IsValidFolderPath(Folder), "Caminho inválido")
    self.Folder = Folder
    self:BuildFolderTree()
end

function NoctraSaveManager:SetSubFolder(SubFolder)
    assert(IsValidFolderPath(SubFolder), "Caminho inválido")
    self.SubFolder = SubFolder
    self:BuildFolderTree()
end

function NoctraSaveManager:RefreshConfigList()
    local settingsPath = self:GetCurrentSettingsPath()
    if settingsPath == false then return {} end
    pcall(makefolder, settingsPath)
    local success, files = pcall(listfiles, settingsPath)
    if not (success and typeof(files) == "table") then return {} end
    local fileNames = {}
    for _, filePath in ipairs(files) do
        local rawFileName = filePath:match("(.+)%..+$")
        if not rawFileName then continue end
        local position = rawFileName:gsub("\\", "/"):find("/[^/]*$")
        local fileName = position and rawFileName:sub(position + 1) or rawFileName
        if not fileName or fileName == "autoload" then continue end
        table.insert(fileNames, fileName)
    end
    return fileNames
end

function NoctraSaveManager:SetIgnoreIndexes(Indexes)
    assert(typeof(Indexes) == "table", "Expected table")
    for _, Index in ipairs(Indexes) do self.Ignore[Index] = true end
end

function NoctraSaveManager:SaveJSON(ConfigName)
    local Library = self.Library
    local IgnoreIndexes = self.Ignore
    local CurrentData = {
        timestamp = os.date("%d.%m.%Y %H:%M:%S"),
        name = ConfigName or "",
        objects = {},
    }
    for Index, Toggle in pairs(Library.Toggles or {}) do
        if not Toggle.Type or IgnoreIndexes[Index] then continue end
        local Parser = ElementParser[Toggle.Type]
        if Parser then table.insert(CurrentData.objects, Parser.Save(Index, Toggle)) end
    end
    for Index, Option in pairs(Library.Options or {}) do
        if not Option.Type or IgnoreIndexes[Index] then continue end
        local Parser = ElementParser[Option.Type]
        if Parser then table.insert(CurrentData.objects, Parser.Save(Index, Option)) end
    end
    local successEncode, encoded = pcall(HttpService.JSONEncode, HttpService, CurrentData)
    if not successEncode then return "", false, "Falha ao codificar" end
    return encoded, true
end

function NoctraSaveManager:Save(ConfigName)
    if IsStringEmpty(ConfigName) then return false, "Nome inválido" end
    if string.lower(ConfigName) == "autoload" then return false, "Nome reservado" end
    local path = self:GetConfigPath(ConfigName)
    if path == false then return false, "Caminho inválido" end
    self:CheckFolderTree()
    local encoded, success, err = self:SaveJSON(ConfigName)
    if not success then return false, err end
    local successWrite, writeErr = pcall(writefile, path, encoded)
    if not successWrite then return false, "Falha ao escrever: " .. tostring(writeErr) end
    return true
end

function NoctraSaveManager:LoadJSON(Content)
    if IsStringEmpty(Content) then return false, "Nenhum JSON" end
    local success, decoded = pcall(HttpService.JSONDecode, HttpService, Content)
    if not success or typeof(decoded) ~= "table" or typeof(decoded.objects) ~= "table" then return false, "JSON inválido" end
    local Library = self.Library
    for _, Option in ipairs(decoded.objects) do
        if not Option.type or self.Ignore[Option.idx] then continue end
        local Parser = ElementParser[Option.type]
        if Parser then task.defer(Parser.Load, Option.idx, Option) end
    end
    return true
end

function NoctraSaveManager:Load(ConfigName)
    if IsStringEmpty(ConfigName) then return false, "Nenhum config selecionado" end
    local path = self:GetConfigPath(ConfigName)
    if path == false or not isfile(path) then return false, "Arquivo não existe" end
    local success, content = pcall(readfile, path)
    if not success then return false, "Falha ao ler" end
    return self:LoadJSON(content)
end

function NoctraSaveManager:Delete(ConfigName)
    if IsStringEmpty(ConfigName) then return false, "Nenhum config selecionado" end
    local path = self:GetConfigPath(ConfigName)
    if path == false or not isfile(path) then return false, "Arquivo não existe" end
    local success, err = pcall(delfile, path)
    if not success then return false, tostring(err) end
    return true
end

function NoctraSaveManager:GetAutoloadConfig()
    self:CheckFolderTree()
    local path = self:GetAutoloadPath()
    if path == false or not isfile(path) then return "none", false, "Autoload não definido" end
    local success, name = pcall(readfile, path)
    if not (success and typeof(name) == "string") then return "none", false, tostring(name) end
    if not self:DoesConfigExist(name) then return "none", false, "Config não encontrado" end
    self.AutoloadConfig = name
    return name, true
end

function NoctraSaveManager:SaveAutoloadConfig(ConfigName)
    if IsStringEmpty(ConfigName) then return false, "Nenhum config selecionado" end
    self:CheckFolderTree()
    local path = self:GetAutoloadPath()
    if path == false then return false, "Caminho inválido" end
    if not self:DoesConfigExist(ConfigName) then return false, "Config não existe" end
    local success, err = pcall(writefile, path, ConfigName)
    if not success then return false, tostring(err) end
    self.AutoloadConfig = ConfigName
    return true
end

function NoctraSaveManager:LoadAutoloadConfig()
    local name, success, err = self:GetAutoloadConfig()
    if not success then return end
    local loadSuccess, loadErr = self:Load(name)
    if not loadSuccess then
        if self.Library then self.Library:Notify({ Title = "Autoload", Content = "Falha ao carregar: " .. tostring(loadErr), Type = "error" }) end
        return
    end
    if self.Library then self.Library:Notify({ Title = "Autoload", Content = "Config " .. name .. " carregado.", Type = "success" }) end
end

function NoctraSaveManager:DeleteAutoLoadConfig()
    self:CheckFolderTree()
    local path = self:GetAutoloadPath()
    if path == false or not isfile(path) then return false, "Autoload não definido" end
    local success, err = pcall(delfile, path)
    if not success then return false, tostring(err) end
    self.AutoloadConfig = nil
    return true
end
--// ============================================================
--// PARTE 3: NOCTRALIB (INTERFACE PRINCIPAL — CORRIGIDA)
--// ============================================================

local NoctraLib = {
    Options = {},
    Toggles = {},
    Tabs = {},
    ThemeManager = NoctraThemeManager,
    SaveManager = NoctraSaveManager,
    Window = nil,
    ScreenGui = nil,
    Connections = {},
    Scheme = DefaultTheme,
    Player = LocalPlayer,
}

--// ============================================================
--// HELPERS DE UI DA LIBRARY
--// ============================================================
local function Create(className, properties, children)
    local obj = Instance.new(className)
    for k, v in pairs(properties or {}) do obj[k] = v end
    for _, child in pairs(children or {}) do child.Parent = obj end
    return obj
end

local function AddStroke(parent, thickness, color)
    return Create("UIStroke", {
        Color = color or NoctraLib.Scheme.Stroke,
        Thickness = thickness or 1.5,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function AddCorner(parent, radius)
    return Create("UICorner", { CornerRadius = UDim.new(0, radius or 6), Parent = parent })
end

local function MakeDraggable(frame, dragArea)
    local dragging, dragInput, mousePos, framePos = false, nil, nil, nil
    dragArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            mousePos = input.Position
            framePos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    dragArea.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            frame.Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
        end
    end)
end

local function MakeResizable(frame, sizeHandle)
    local dragging, dragInput, mousePos, frameSize = false, nil, nil, nil
    sizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            mousePos = input.Position
            frameSize = frame.Size
        end
    end)
    sizeHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            frame.Size = UDim2.new(
                frameSize.X.Scale,
                math.clamp(frameSize.X.Offset + delta.X, 400, 2000),
                frameSize.Y.Scale,
                math.clamp(frameSize.Y.Offset + delta.Y, 250, 1500)
            )
        end
    end)
end

--// ============================================================
--// NOTIFICAÇÕES
--// ============================================================
local NotificationHolder = Create("Frame", {
    Name = "NotificationHolder",
    Parent = CoreGui,
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -20, 1, -20),
    Size = UDim2.new(0, 320, 1, -20),
    AnchorPoint = Vector2.new(1, 1),
}, {
    Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 10) })
})

function NoctraLib:Notify(config)
    config = config or {}
    local title = config.Title or config.Name or "Notificação"
    local content = config.Content or config.Description or ""
    local isError = config.Type == "error"
    local sound = isError and "Error" or "Success"
    local borderColor = isError and NoctraLib.Scheme.Error or NoctraLib.Scheme.Stroke

    NoctraSound:Play(sound)

    local notifFrame = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = NotificationHolder,
    })

    local inner = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = NoctraLib.Scheme.Element,
        BackgroundTransparency = 0.1,
        Parent = notifFrame,
    }, {
        AddCorner(notifFrame, 8),
        AddStroke(notifFrame, 1.5, borderColor),
        Create("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
        Create("TextLabel", {
            Name = "Title", Text = title, Font = Enum.Font.RobotoBold, TextSize = 14, TextColor3 = NoctraLib.Scheme.Text,
            TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16)
        }),
        Create("TextLabel", {
            Name = "Content", Text = content, Font = Enum.Font.Roboto, TextSize = 13, TextColor3 = NoctraLib.Scheme.TextDark,
            TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, Position = UDim2.new(0, 0, 0, 20)
        }),
        Create("Frame", {
            Name = "TimerBar", Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = borderColor,
            Position = UDim2.new(0, 0, 1, -4), BackgroundTransparency = 0.2
        }, { AddCorner(notifFrame, 2) })
    })

    TweenService:Create(inner, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { BackgroundTransparency = 0 }):Play()
    TweenService:Create(inner.TimerBar, TweenInfo.new(3, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()

    task.delay(3, function()
        TweenService:Create(inner, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
        task.wait(0.3)
        notifFrame:Destroy()
    end)
end

--// ============================================================
--// ATUALIZAÇÃO DE CORES (CHAMADA PELO THEME MANAGER)
--// ============================================================
function NoctraLib:UpdateColors()
    --// Atualiza o Scheme local
    for key, value in pairs(NoctraThemeManager.Themes[NoctraThemeManager.ActiveTheme] or {}) do
        NoctraLib.Scheme[key] = value
    end

    --// Reaplica as cores em todos os objetos registrados
    for object, map in pairs(NoctraThemeManager.Registry) do
        if not object or not object.Parent then
            NoctraThemeManager.Registry[object] = nil
            continue
        end
        for property, themeKey in pairs(map) do
            local value = NoctraLib.Scheme[themeKey]
            if value == nil then continue end
            if typeof(value) == "Color3" and property:find("Color") then
                object[property] = value
            elseif typeof(value) == "EnumItem" and property == "Font" then
                object[property] = value
            end
        end
    end
end

--// ============================================================
--// CRIAÇÃO DA JANELA PRINCIPAL
--// ============================================================
function NoctraLib:MakeWindow(config)
    config = config or {}
    local windowName = config.Name or "NoctraLib"
    local subName = config.SubName or "v1.0"
    local logoIcon = config.Logo or ""
    local toggleKey = config.ToggleKey or Enum.KeyCode.RightShift

    local oldGui = CoreGui:FindFirstChild("NoctraLib")
    if oldGui then oldGui:Destroy() end

    local ScreenGui = Create("ScreenGui", {
        Name = "NoctraLib", Parent = CoreGui, ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    })
    NoctraLib.ScreenGui = ScreenGui

    local MainWindow = Create("Frame", {
        Name = "MainWindow", Parent = ScreenGui,
        Size = config.Size or UDim2.new(0, 620, 0, 410), Position = UDim2.new(0.5, -310, 0.5, -205),
        BackgroundColor3 = NoctraLib.Scheme.Main, BackgroundTransparency = 0.05, BorderSizePixel = 0, ClipsDescendants = true,
    }, { AddCorner(MainWindow, 10), AddStroke(MainWindow, 1.5, NoctraLib.Scheme.Stroke) })

    local TopBar = Create("Frame", {
        Name = "TopBar", Parent = MainWindow, Size = UDim2.new(1, 0, 0, 45),
        BackgroundColor3 = NoctraLib.Scheme.Main, BackgroundTransparency = 0.2, BorderSizePixel = 0,
    })

    Create("Frame", {
        Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = NoctraLib.Scheme.Divider, Parent = TopBar
    })

    if logoIcon ~= "" then
        Create("ImageLabel", {
            Parent = TopBar, Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(0, 15, 0.5, -12),
            BackgroundTransparency = 1, Image = logoIcon, ImageColor3 = NoctraLib.Scheme.Stroke
        })
    end

    local TitleLabel = Create("TextLabel", {
        Parent = TopBar, Size = UDim2.new(1, -120, 1, 0), Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1, Text = windowName, Font = Enum.Font.RobotoBold, TextSize = 16,
        TextColor3 = NoctraLib.Scheme.Text, TextXAlignment = Enum.TextXAlignment.Right
    })
    local SubTitleLabel = Create("TextLabel", {
        Parent = TopBar, Size = UDim2.new(1, -120, 1, 0), Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1, Text = subName, Font = Enum.Font.Roboto, TextSize = 11,
        TextColor3 = NoctraLib.Scheme.TextDark, TextXAlignment = Enum.TextXAlignment.Right
    })
    SubTitleLabel.Position = UDim2.new(0, 0, 0, 5)
    SubTitleLabel.Size = UDim2.new(1, -120, 1, 0)
    TitleLabel.Position = UDim2.new(0, 0, 0, -5)

    local ButtonFrame = Create("Frame", {
        Parent = TopBar, Size = UDim2.new(0, 90, 0, 30), Position = UDim2.new(0, 10, 0.5, -15),
        BackgroundTransparency = 1,
    }, { Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), VerticalAlignment = Enum.VerticalAlignment.Center }) })

    local function CreateControlButton(icon, callback)
        local btn = Create("TextButton", { Size = UDim2.new(0, 20, 0, 20), BackgroundTransparency = 1, Text = "", Parent = ButtonFrame, AutoButtonColor = false })
        local img = Create("ImageLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Image = icon, ImageColor3 = NoctraLib.Scheme.TextDark, Parent = btn })
        btn.MouseEnter:Connect(function() TweenService:Create(img, TweenInfo.new(0.2), { ImageColor3 = NoctraLib.Scheme.Text }):Play() end)
        btn.MouseLeave:Connect(function() TweenService:Create(img, TweenInfo.new(0.2), { ImageColor3 = NoctraLib.Scheme.TextDark }):Play() end)
        btn.MouseButton1Click:Connect(function()
            NoctraSound:Play("Click")
            callback()
        end)
        return btn
    end

    CreateControlButton("rbxassetid://102326100327209", function() MainWindow.Visible = false end)
    CreateControlButton("rbxassetid://10734896206", function()
        TweenService:Create(MainWindow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
            Size = MainWindow.Size.Y.Offset > 45 and UDim2.new(0, 300, 0, 45) or config.Size or UDim2.new(0, 620, 0, 410)
        }):Play()
    end)
    CreateControlButton("rbxassetid://10734924532", function()
        TweenService:Create(MainWindow, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
            Size = MainWindow.Size.X.Offset > 800 and UDim2.new(0, 620, 0, 410) or UDim2.new(0, 1000, 0, 620)
        }):Play()
    end)

    local DragPoint = Create("Frame", { Name = "DragPoint", Size = UDim2.new(1, -100, 0, 45), Position = UDim2.new(0, 100, 0, 0), BackgroundTransparency = 1, Active = true, Parent = TopBar })
    MakeDraggable(MainWindow, DragPoint)

    local ResizeHandle = Create("Frame", { Name = "ResizeHandle", Size = UDim2.new(0, 15, 0, 15), Position = UDim2.new(1, -5, 1, -5), BackgroundTransparency = 1, Active = true, Parent = MainWindow })
    MakeResizable(MainWindow, ResizeHandle)

    local ContentArea = Create("Frame", { Name = "ContentArea", Parent = MainWindow, Size = UDim2.new(1, 0, 1, -45), Position = UDim2.new(0, 0, 0, 45), BackgroundTransparency = 1 })

    local TabList = Create("ScrollingFrame", {
        Name = "TabList", Parent = ContentArea, Size = UDim2.new(0, 130, 1, 0),
        BackgroundTransparency = 1, ScrollBarThickness = 0, BorderSizePixel = 0, CanvasSize = UDim2.new(0, 0, 0, 0),
    }, {
        Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) }),
        Create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })
    })

    local ElementArea = Create("ScrollingFrame", {
        Name = "ElementArea", Parent = ContentArea, Size = UDim2.new(1, -130, 1, 0), Position = UDim2.new(0, 130, 0, 0),
        BackgroundTransparency = 1, ScrollBarThickness = 0, BorderSizePixel = 0, CanvasSize = UDim2.new(0, 0, 0, 0),
    }, {
        Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
        Create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) })
    })

    NoctraLib.Window = MainWindow
    NoctraLib.WindowObject = { MainWindow = MainWindow, ContentArea = ContentArea, TabList = TabList, ElementArea = ElementArea }

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == toggleKey then
            MainWindow.Visible = not MainWindow.Visible
            NoctraSound:Play("Click", 0.4)
        end
    end)

    return NoctraLib.WindowObject
end

--// ============================================================
--// CRIAÇÃO DE TABS E ELEMENTOS
--// ============================================================
function NoctraLib:MakeTab(config)
    config = config or {}
    local tabName = config.Name or "Tab"
    local tabIcon = config.Icon or "rbxassetid://10734924532"

    local TabButton = Create("TextButton", {
        Name = tabName, Size = UDim2.new(1, 0, 0, 35), BackgroundColor3 = NoctraLib.Scheme.Main, BackgroundTransparency = 1,
        Text = "", Parent = NoctraLib.WindowObject.TabList, AutoButtonColor = false,
    }, {
        AddCorner(TabButton, 6), AddStroke(TabButton, 1.5, NoctraLib.Scheme.Stroke),
        Create("ImageLabel", { Name = "Icon", Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 10, 0.5, -8), BackgroundTransparency = 1, Image = tabIcon, ImageColor3 = NoctraLib.Scheme.TextDark }),
        Create("TextLabel", { Name = "Title", Size = UDim2.new(1, -35, 1, 0), Position = UDim2.new(0, 32, 0, 0), BackgroundTransparency = 1, Text = tabName, Font = Enum.Font.RobotoBold, TextSize = 13, TextColor3 = NoctraLib.Scheme.TextDark, TextXAlignment = Enum.TextXAlignment.Left })
    })

    local TabContent = Create("Frame", {
        Name = tabName .. "Content", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false, Parent = NoctraLib.WindowObject.ElementArea,
    }, { Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }) })

    TabContent.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        NoctraLib.WindowObject.ElementArea.CanvasSize = UDim2.new(0, 0, 0, TabContent.UIListLayout.AbsoluteContentSize.Y + 20)
    end)

    local TabObject = { Name = tabName, Content = TabContent, Button = TabButton }

    TabButton.MouseButton1Click:Connect(function()
        NoctraSound:Play("Click")
        for _, child in pairs(NoctraLib.WindowObject.ElementArea:GetChildren()) do
            if child:IsA("Frame") then child.Visible = false end
        end
        TabContent.Visible = true
        for _, btn in pairs(NoctraLib.WindowObject.TabList:GetChildren()) do
            if btn:IsA("TextButton") then
                btn.BackgroundTransparency = 1
                if btn.Title then btn.Title.TextColor3 = NoctraLib.Scheme.TextDark end
                if btn.Icon then btn.Icon.ImageColor3 = NoctraLib.Scheme.TextDark end
            end
        end
        TabButton.BackgroundTransparency = 0.8
        TabButton.Title.TextColor3 = NoctraLib.Scheme.Text
        TabButton.Icon.ImageColor3 = NoctraLib.Scheme.Text
    end)

    if #NoctraLib.WindowObject.TabList:GetChildren() == 2 then
        TabButton.BackgroundTransparency = 0.8
        TabButton.Title.TextColor3 = NoctraLib.Scheme.Text
        TabButton.Icon.ImageColor3 = NoctraLib.Scheme.Text
        TabContent.Visible = true
    end

    table.insert(NoctraLib.Tabs, TabObject)

    local TabMethods = {}

    function TabMethods:AddSection(config)
        config = config or {}
        local SectionFrame = Create("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Parent = TabContent }, {
            Create("TextLabel", { Size = UDim2.new(1, 0, 1, 0), Text = config.Name or "Seção", Font = Enum.Font.RobotoBold, TextSize = 12, TextColor3 = NoctraLib.Scheme.TextDark, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1 }),
            Create("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = NoctraLib.Scheme.Divider, BackgroundTransparency = 0.5 })
        })
        return SectionFrame
    end

    function TabMethods:AddButton(config)
        config = config or {}
        local BtnFrame = Create("Frame", { Size = UDim2.new(1, 0, 0, 35), BackgroundColor3 = NoctraLib.Scheme.Element, BackgroundTransparency = 0.2, Parent = TabContent }, { AddCorner(BtnFrame, 6), AddStroke(BtnFrame, 1.5, NoctraLib.Scheme.Stroke) })
        local ClickBtn = Create("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", Parent = BtnFrame })
        Create("TextLabel", { Name = "Title", Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = config.Text or "Botão", Font = Enum.Font.RobotoBold, TextSize = 13, TextColor3 = NoctraLib.Scheme.Text, TextXAlignment = Enum.TextXAlignment.Left })
        ClickBtn.MouseEnter:Connect(function() TweenService:Create(BtnFrame, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(30, 30, 30) }):Play() end)
        ClickBtn.MouseLeave:Connect(function() TweenService:Create(BtnFrame, TweenInfo.new(0.2), { BackgroundColor3 = NoctraLib.Scheme.Element }):Play() end)
        ClickBtn.MouseButton1Click:Connect(function()
            NoctraSound:Play("Activate")
            if config.Func then config.Func() end
        end)
        local BtnObj = { Instance = BtnFrame }
        return BtnObj
    end

    function TabMethods:AddToggle(config)
        config = config or {}
        local flag = config.Flag or config.Name or "Toggle"
        local ToggleFrame = Create("Frame", { Size = UDim2.new(1, 0, 0, 35), BackgroundColor3 = NoctraLib.Scheme.Element, BackgroundTransparency = 0.2, Parent = TabContent }, { AddCorner(ToggleFrame, 6), AddStroke(ToggleFrame, 1.5, NoctraLib.Scheme.Stroke) })
        local ClickBtn = Create("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", Parent = ToggleFrame })
        Create("TextLabel", { Name = "Title", Size = UDim2.new(1, -50, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = config.Name or "Toggle", Font = Enum.Font.RobotoBold, TextSize = 13, TextColor3 = NoctraLib.Scheme.Text, TextXAlignment = Enum.TextXAlignment.Left })
        local ToggleBox = Create("Frame", { Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(1, -25, 0.5, -10), BackgroundColor3 = NoctraLib.Scheme.Main, Parent = ToggleFrame }, { AddCorner(ToggleBox, 4), AddStroke(ToggleBox, 1.5, NoctraLib.Scheme.Stroke), Create("ImageLabel", { Name = "Check", Size = UDim2.new(0, 12, 0, 12), Position = UDim2.new(0.5, -6, 0.5, -6), BackgroundTransparency = 1, Image = "rbxassetid://10709790644", ImageColor3 = NoctraLib.Scheme.Text, ImageTransparency = 1 }) })
        local state = config.Default or false
        local function update()
            if state then
                TweenService:Create(ToggleBox, TweenInfo.new(0.2), { BackgroundColor3 = NoctraLib.Scheme.ToggleOn }):Play()
                TweenService:Create(ToggleBox.Check, TweenInfo.new(0.2), { ImageTransparency = 0 }):Play()
            else
                TweenService:Create(ToggleBox, TweenInfo.new(0.2), { BackgroundColor3 = NoctraLib.Scheme.Main }):Play()
                TweenService:Create(ToggleBox.Check, TweenInfo.new(0.2), { ImageTransparency = 1 }):Play()
            end
        end
        update()
        ClickBtn.MouseButton1Click:Connect(function()
            state = not state
            update()
            NoctraSound:Play("Activate")
            if config.Callback then config.Callback(state) end
        end)
        local ToggleObj = { Type = "Toggle", Value = state, Flag = flag, Instance = ToggleFrame, SetValue = function(self, val) state = val; update(); if config.Callback then config.Callback(val) end end, RunChanged = function(self) if config.Callback then config.Callback(state) end end }
        NoctraLib.Options[flag] = ToggleObj
        NoctraLib.Toggles[flag] = ToggleObj
        return ToggleObj
    end

    function TabMethods:AddSlider(config)
        config = config or {}
        local flag = config.Flag or config.Name or "Slider"
        local min, max = config.Min or 0, config.Max or 100
        local default = config.Default or min
        local SliderFrame = Create("Frame", { Size = UDim2.new(1, 0, 0, 55), BackgroundColor3 = NoctraLib.Scheme.Element, BackgroundTransparency = 0.2, Parent = TabContent }, { AddCorner(SliderFrame, 6), AddStroke(SliderFrame, 1.5, NoctraLib.Scheme.Stroke) })
        Create("TextLabel", { Name = "Title", Size = UDim2.new(1, -20, 0, 15), Position = UDim2.new(0, 10, 0, 5), BackgroundTransparency = 1, Text = config.Name or "Slider", Font = Enum.Font.RobotoBold, TextSize = 12, TextColor3 = NoctraLib.Scheme.Text, TextXAlignment = Enum.TextXAlignment.Left })
        local BarBackground = Create("Frame", { Size = UDim2.new(1, -20, 0, 8), Position = UDim2.new(0, 10, 0, 30), BackgroundColor3 = Color3.fromRGB(30, 30, 30), Parent = SliderFrame }, { AddCorner(BarBackground, 4), AddStroke(BarBackground, 1, NoctraLib.Scheme.Divider) })
        local Fill = Create("Frame", { Size = UDim2.new((default - min) / (max - min), 0, 1, 0), BackgroundColor3 = NoctraLib.Scheme.Accent, Parent = BarBackground }, { AddCorner(Fill, 4) })
        local ValLabel = Create("TextLabel", { Size = UDim2.new(0, 50, 0, 15), Position = UDim2.new(1, -50, 0, 5), BackgroundTransparency = 1, Text = tostring(default), Font = Enum.Font.RobotoBold, TextSize = 12, TextColor3 = NoctraLib.Scheme.TextDark, TextXAlignment = Enum.TextXAlignment.Right })
        local dragging = false
        local function updateSlider(input)
            local mouseX = math.clamp(input.Position.X - BarBackground.AbsolutePosition.X, 0, BarBackground.AbsoluteSize.X)
            local percent = mouseX / BarBackground.AbsoluteSize.X
            local val = math.floor((percent * (max - min)) + min)
            Fill.Size = UDim2.new(percent, 0, 1, 0)
            ValLabel.Text = tostring(val)
            SliderObj.Value = val
            if config.Callback then config.Callback(val) end
        end
        BarBackground.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true; updateSlider(input) end end)
        UserInputService.InputChanged:Connect(function(input) if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then updateSlider(input) end end)
        UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then if dragging then NoctraSound:Play("Activate", 0.3) end; dragging = false end end)
        local SliderObj = { Type = "Slider", Value = default, Flag = flag, Instance = SliderFrame, SetValue = function(self, val) self.Value = val; local percent = (val - min) / (max - min); Fill.Size = UDim2.new(percent, 0, 1, 0); ValLabel.Text = tostring(val); if config.Callback then config.Callback(val) end end, RunChanged = function(self) if config.Callback then config.Callback(self.Value) end end }
        NoctraLib.Options[flag] = SliderObj
        return SliderObj
    end

    function TabMethods:AddDropdown(config)
        config = config or {}
        local flag = config.Flag or config.Name or "Dropdown"
        local values = config.Values or {}
        local default = config.Default or (values[1] or "")
        local DropFrame = Create("Frame", { Size = UDim2.new(1, 0, 0, 35), BackgroundColor3 = NoctraLib.Scheme.Element, BackgroundTransparency = 0.2, Parent = TabContent, ClipsDescendants = true }, { AddCorner(DropFrame, 6), AddStroke(DropFrame, 1.5, NoctraLib.Scheme.Stroke) })
        local ClickBtn = Create("TextButton", { Size = UDim2.new(1, 0, 0, 35), BackgroundTransparency = 1, Text = "", Parent = DropFrame })
        Create("TextLabel", { Name = "Title", Size = UDim2.new(1, -40, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = config.Name or "Dropdown", Font = Enum.Font.RobotoBold, TextSize = 13, TextColor3 = NoctraLib.Scheme.Text, TextXAlignment = Enum.TextXAlignment.Left })
        local ValueLabel = Create("TextLabel", { Size = UDim2.new(0, 100, 1, 0), Position = UDim2.new(1, -110, 0, 0), BackgroundTransparency = 1, Text = default, Font = Enum.Font.Roboto, TextSize = 13, TextColor3 = NoctraLib.Scheme.TextDark, TextXAlignment = Enum.TextXAlignment.Right })
        local Arrow = Create("ImageLabel", { Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(1, -25, 0.5, -8), BackgroundTransparency = 1, Image = "rbxassetid://10709790644", ImageColor3 = NoctraLib.Scheme.TextDark, Rotation = 0 })
        local DropList = Create("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0, 35), BackgroundColor3 = NoctraLib.Scheme.Main, BackgroundTransparency = 0.1, ClipsDescendants = true, Parent = DropFrame }, { AddCorner(DropList, 6), Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }), Create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }) })
        local isOpen = false
        local function updateList()
            for _, child in pairs(DropList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
            for _, val in ipairs(values) do
                local optBtn = Create("TextButton", { Size = UDim2.new(1, 0, 0, 25), BackgroundTransparency = 1, Text = val, Font = Enum.Font.Roboto, TextSize = 12, TextColor3 = NoctraLib.Scheme.TextDark, TextXAlignment = Enum.TextXAlignment.Left, Parent = DropList })
                Create("UIPadding", { PaddingLeft = UDim.new(0, 10) }).Parent = optBtn
                optBtn.MouseEnter:Connect(function() optBtn.TextColor3 = NoctraLib.Scheme.Text end)
                optBtn.MouseLeave:Connect(function() optBtn.TextColor3 = NoctraLib.Scheme.TextDark end)
                optBtn.MouseButton1Click:Connect(function()
                    ValueLabel.Text = val
                    DropdownObj.Value = val
                    if config.Callback then config.Callback(val) end
                    NoctraSound:Play("Activate")
                    isOpen = false
                    TweenService:Create(DropList, TweenInfo.new(0.2), { Size = UDim2.new(1, 0, 0, 0) }):Play()
                    TweenService:Create(Arrow, TweenInfo.new(0.2), { Rotation = 0 }):Play()
                end)
            end
            DropList.CanvasSize = UDim2.new(0, 0, 0, #values * 27 + 8)
        end
        updateList()
        ClickBtn.MouseButton1Click:Connect(function()
            isOpen = not isOpen
            NoctraSound:Play("Click")
            TweenService:Create(Arrow, TweenInfo.new(0.2), { Rotation = isOpen and 180 or 0 }):Play()
            TweenService:Create(DropList, TweenInfo.new(0.2), { Size = UDim2.new(1, 0, 0, isOpen and math.min(#values * 27 + 8, 150) or 0) }):Play()
            DropFrame.Size = isOpen and UDim2.new(1, 0, 0, 35 + math.min(#values * 27 + 8, 150)) or UDim2.new(1, 0, 0, 35)
        end)
        local DropdownObj = { Type = "Dropdown", Value = default, Flag = flag, Instance = DropFrame, SetValue = function(self, val) self.Value = val; ValueLabel.Text = val; if config.Callback then config.Callback(val) end end, RunChanged = function(self) if config.Callback then config.Callback(self.Value) end end }
        NoctraLib.Options[flag] = DropdownObj
        return DropdownObj
    end

    function TabMethods:AddTextbox(config)
        config = config or {}
        local flag = config.Flag or config.Name or "Textbox"
        local default = config.Default or ""
        local TbFrame = Create("Frame", { Size = UDim2.new(1, 0, 0, 35), BackgroundColor3 = NoctraLib.Scheme.Element, BackgroundTransparency = 0.2, Parent = TabContent }, { AddCorner(TbFrame, 6), AddStroke(TbFrame, 1.5, NoctraLib.Scheme.Stroke) })
        Create("TextLabel", { Name = "Title", Size = UDim2.new(1, -120, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = config.Name or "Textbox", Font = Enum.Font.RobotoBold, TextSize = 13, TextColor3 = NoctraLib.Scheme.Text, TextXAlignment = Enum.TextXAlignment.Left })
        local InputBox = Create("TextBox", { Size = UDim2.new(0, 100, 0, 25), Position = UDim2.new(1, -110, 0.5, -12.5), BackgroundColor3 = NoctraLib.Scheme.Main, Text = default, PlaceholderText = "Digite...", Font = Enum.Font.Roboto, TextSize = 12, TextColor3 = NoctraLib.Scheme.Text, PlaceholderColor3 = NoctraLib.Scheme.TextDark, TextXAlignment = Enum.TextXAlignment.Center, Parent = TbFrame, ClearTextOnFocus = false }, { AddCorner(InputBox, 4), AddStroke(InputBox, 1.5, NoctraLib.Scheme.Divider) })
        InputBox.Focused:Connect(function() TweenService:Create(InputBox, TweenInfo.new(0.2), { BackgroundColor3 = NoctraLib.Scheme.Element }):Play(); NoctraSound:Play("Type") end)
        InputBox.FocusLost:Connect(function() TweenService:Create(InputBox, TweenInfo.new(0.2), { BackgroundColor3 = NoctraLib.Scheme.Main }):Play(); if config.Callback then config.Callback(InputBox.Text) end end)
        local TextboxObj = { Type = "Input", Value = default, Flag = flag, Instance = TbFrame, SetValue = function(self, val) self.Value = val; InputBox.Text = val; if config.Callback then config.Callback(val) end end, RunChanged = function(self) if config.Callback then config.Callback(self.Value) end end }
        NoctraLib.Options[flag] = TextboxObj
        return TextboxObj
    end

    function TabMethods:AddColorPicker(config)
        config = config or {}
        local flag = config.Flag or config.Name or "ColorPicker"
        local default = config.Default or Color3.fromRGB(255, 255, 255)
        local CPFrame = Create("Frame", { Size = UDim2.new(1, 0, 0, 35), BackgroundColor3 = NoctraLib.Scheme.Element, BackgroundTransparency = 0.2, Parent = TabContent }, { AddCorner(CPFrame, 6), AddStroke(CPFrame, 1.5, NoctraLib.Scheme.Stroke) })
        Create("TextLabel", { Name = "Title", Size = UDim2.new(1, -50, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = config.Name or "ColorPicker", Font = Enum.Font.RobotoBold, TextSize = 13, TextColor3 = NoctraLib.Scheme.Text, TextXAlignment = Enum.TextXAlignment.Left })
        local ColorBox = Create("Frame", { Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(1, -25, 0.5, -10), BackgroundColor3 = default, Parent = CPFrame }, { AddCorner(ColorBox, 4), AddStroke(ColorBox, 1.5, NoctraLib.Scheme.Stroke) })
        local palette = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0), Color3.fromRGB(0, 0, 255), Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 0, 255), Color3.fromRGB(0, 255, 255), Color3.fromRGB(0, 0, 0) }
        local colorIndex = 1
        local ClickBtn = Create("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", Parent = CPFrame })
        ClickBtn.MouseButton1Click:Connect(function()
            colorIndex = colorIndex + 1
            if colorIndex > #palette then colorIndex = 1 end
            local newColor = palette[colorIndex]
            ColorBox.BackgroundColor3 = newColor
            ColorpickerObj.Value = newColor
            if config.Callback then config.Callback(newColor) end
            NoctraSound:Play("Activate")
        end)
        local ColorpickerObj = { Type = "ColorPicker", Value = default, Flag = flag, Instance = CPFrame, Transparency = 0, SetValueRGB = function(self, color, transp) self.Value = color; self.Transparency = transp; ColorBox.BackgroundColor3 = color; if config.Callback then config.Callback(color) end end, RunChanged = function(self) if config.Callback then config.Callback(self.Value) end end }
        NoctraLib.Options[flag] = ColorpickerObj
        return ColorpickerObj
    end

    return TabMethods
end

--// ============================================================
--// CONSTRUÇÃO DA SEÇÃO DE CONFIGURAÇÕES (SAVE MANAGER)
--// ============================================================
function NoctraSaveManager:BuildConfigSection(Tab, IconName)
    assert(NoctraSaveManager.Library, "Library não definida. Chame SaveManager:SetLibrary(Library) primeiro.")
    
    Tab:AddSection({ Name = "Gerenciamento de Configs" })
    
    local ConfigNameInput = Tab:AddTextbox({
        Name = "Nome do Config",
        Default = "",
        Flag = "SaveManager_ConfigName",
        Callback = function() end
    })
    
    local ConfigList = Tab:AddDropdown({
        Name = "Lista de Configs",
        Values = NoctraSaveManager:RefreshConfigList(),
        Default = "",
        Flag = "SaveManager_ConfigList",
        Callback = function(value) end
    })
    
    local ConfigJSONInput = Tab:AddTextbox({
        Name = "JSON do Config",
        Default = "",
        Flag = "SaveManager_JSON",
        Callback = function() end
    })
    
    Tab:AddButton({
        Text = "Criar / Salvar Config",
        Func = function()
            local name = ConfigNameInput.Value
            if IsStringEmpty(name) then
                NoctraLib:Notify({ Title = "Erro", Content = "Nome do config não pode ser vazio.", Type = "error" })
                return
            end
            local success, err = NoctraSaveManager:Save(name)
            if success then
                NoctraLib:Notify({ Title = "Config", Content = "Config '" .. name .. "' salvo com sucesso.", Type = "success" })
                ConfigList:SetValue(nil)
            else
                NoctraLib:Notify({ Title = "Erro", Content = "Falha ao salvar: " .. tostring(err), Type = "error" })
            end
        end
    })
    
    Tab:AddButton({
        Text = "Carregar Config Selecionado",
        Func = function()
            local name = ConfigList.Value
            if IsStringEmpty(name) then
                NoctraLib:Notify({ Title = "Erro", Content = "Selecione um config primeiro.", Type = "error" })
                return
            end
            local success, err = NoctraSaveManager:Load(name)
            if success then
                NoctraLib:Notify({ Title = "Config", Content = "Config '" .. name .. "' carregado.", Type = "success" })
            else
                NoctraLib:Notify({ Title = "Erro", Content = "Falha ao carregar: " .. tostring(err), Type = "error" })
            end
        end
    })
    
    Tab:AddButton({
        Text = "Deletar Config Selecionado",
        Func = function()
            local name = ConfigList.Value
            if IsStringEmpty(name) then
                NoctraLib:Notify({ Title = "Erro", Content = "Selecione um config primeiro.", Type = "error" })
                return
            end
            local success, err = NoctraSaveManager:Delete(name)
            if success then
                NoctraLib:Notify({ Title = "Config", Content = "Config '" .. name .. "' deletado.", Type = "success" })
                ConfigList:SetValue(nil)
            else
                NoctraLib:Notify({ Title = "Erro", Content = "Falha ao deletar: " .. tostring(err), Type = "error" })
            end
        end
    })
    
    Tab:AddButton({
        Text = "Definir como Autoload",
        Func = function()
            local name = ConfigList.Value
            if IsStringEmpty(name) then
                NoctraLib:Notify({ Title = "Erro", Content = "Selecione um config primeiro.", Type = "error" })
                return
            end
            local success, err = NoctraSaveManager:SaveAutoloadConfig(name)
            if success then
                NoctraLib:Notify({ Title = "Autoload", Content = "Config '" .. name .. "' definido como autoload.", Type = "success" })
            else
                NoctraLib:Notify({ Title = "Erro", Content = "Falha ao definir autoload: " .. tostring(err), Type = "error" })
            end
        end
    })
    
    Tab:AddButton({
        Text = "Resetar Autoload",
        Func = function()
            local success = NoctraSaveManager:DeleteAutoLoadConfig()
            if success then
                NoctraLib:Notify({ Title = "Autoload", Content = "Autoload resetado.", Type = "success" })
            else
                NoctraLib:Notify({ Title = "Autoload", Content = "Não havia autoload definido.", Type = "info" })
            end
        end
    })
    
    Tab:AddButton({
        Text = "Exportar Config Atual",
        Func = function()
            local encoded, success, err = NoctraSaveManager:SaveJSON()
            if success then
                ConfigJSONInput:SetValue(encoded)
                if setclipboard then
                    setclipboard(encoded)
                end
                NoctraLib:Notify({ Title = "Export", Content = "Config copiado para a área de transferência.", Type = "success" })
            else
                NoctraLib:Notify({ Title = "Erro", Content = "Falha ao exportar: " .. tostring(err), Type = "error" })
            end
        end
    })
    
    Tab:AddButton({
        Text = "Importar Config do JSON",
        Func = function()
            local json = ConfigJSONInput.Value
            if IsStringEmpty(json) then
                NoctraLib:Notify({ Title = "Erro", Content = "O campo JSON está vazio.", Type = "error" })
                return
            end
            local success, err = NoctraSaveManager:LoadJSON(json)
            if success then
                NoctraLib:Notify({ Title = "Import", Content = "Config importado com sucesso.", Type = "success" })
            else
                NoctraLib:Notify({ Title = "Erro", Content = "Falha ao importar: " .. tostring(err), Type = "error" })
            end
        end
    })
    
    Tab:AddButton({
        Text = "Atualizar Lista de Configs",
        Func = function()
            ConfigList:SetValue(nil)
            NoctraLib:Notify({ Title = "Configs", Content = "Lista atualizada.", Type = "info" })
        end
    })
    
    NoctraSaveManager:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName", "SaveManager_JSON" })
    
    return ConfigNameInput
end
--// ============================================================
--// PARTE 4: SERVER MANAGER
--// ============================================================

local NoctraServerManager = {
    Library = nil,
    Tab = nil,
    PlayerListFrame = nil,
    LogFrame = nil,
    LogContent = nil,
    PlayerButtons = {},
    Connections = {},
    ActionLog = {},
    IsFrozen = {},
    MaxLogLines = 50,
}

--// ============================================================
--// SISTEMA DE LOG
--// ============================================================
function NoctraServerManager:Log(action, playerName, details)
    local timestamp = os.date("%H:%M:%S")
    local entry = string.format("[%s] %s: %s%s", timestamp, action, playerName or "—", details and (" (" .. details .. ")") or "")
    table.insert(self.ActionLog, 1, entry)
    if #self.ActionLog > self.MaxLogLines then table.remove(self.ActionLog) end

    if self.LogContent then
        self.LogContent.Text = table.concat(self.ActionLog, "\n")
        self.LogFrame.CanvasSize = UDim2.new(0, 0, 0, self.LogContent.TextBounds.Y + 12)
    end
    print("[NoctraServer] " .. entry)
end

--// ============================================================
--// AÇÕES NOS JOGADORES
--// ============================================================
local function GetCharacter(player) return player and player.Character end
local function GetHumanoid(player) local char = GetCharacter(player); return char and char:FindFirstChildOfClass("Humanoid") or nil end

function NoctraServerManager:Kick(player, reason)
    if not player or player == LocalPlayer then
        if self.Library then self.Library:Notify({ Title = "Kick", Content = "Não é possível kickar você mesmo.", Type = "error" }) end
        return
    end
    reason = reason or "Kickado via NoBreath"
    local success = pcall(function() player:Kick(reason) end)
    if success then
        self:Log("KICK", player.Name, reason)
        if self.Library then self.Library:Notify({ Title = "Kick", Content = player.Name .. " foi kickado.", Type = "success" }) end
    else
        if self.Library then self.Library:Notify({ Title = "Kick", Content = "Falha ao kickar " .. player.Name, Type = "error" }) end
    end
end

function NoctraServerManager:Freeze(player, state)
    if not player or player == LocalPlayer then return end
    local char = GetCharacter(player)
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    self.IsFrozen[player] = state
    if state then
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
    else
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
    end
    self:Log(state and "FREEZE" or "UNFREEZE", player.Name)
end

function NoctraServerManager:Damage(player, amount)
    if not player or player == LocalPlayer then return end
    local humanoid = GetHumanoid(player)
    if humanoid then
        humanoid:TakeDamage(amount or 10)
        self:Log("DAMAGE", player.Name, tostring(amount or 10))
    end
end

function NoctraServerManager:Heal(player, amount)
    if not player or player == LocalPlayer then return end
    local humanoid = GetHumanoid(player)
    if humanoid then
        humanoid.Health = math.min(humanoid.Health + (amount or 50), humanoid.MaxHealth)
        self:Log("HEAL", player.Name, tostring(amount or 50))
    end
end

function NoctraServerManager:TeleportToPlayer(player)
    if not player or player == LocalPlayer then return end
    local char = GetCharacter(LocalPlayer)
    local targetChar = GetCharacter(player)
    if char and targetChar and char:FindFirstChild("HumanoidRootPart") and targetChar:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = targetChar.HumanoidRootPart.CFrame
        self:Log("TELEPORT", player.Name, "fui até ele")
    end
end

function NoctraServerManager:TeleportPlayerToMe(player)
    if not player or player == LocalPlayer then return end
    local char = GetCharacter(LocalPlayer)
    local targetChar = GetCharacter(player)
    if char and targetChar and char:FindFirstChild("HumanoidRootPart") and targetChar:FindFirstChild("HumanoidRootPart") then
        targetChar.HumanoidRootPart.CFrame = char.HumanoidRootPart.CFrame
        self:Log("TELEPORT", player.Name, "veio até mim")
    end
end

function NoctraServerManager:SetWalkSpeed(player, speed)
    if not player or player == LocalPlayer then return end
    local humanoid = GetHumanoid(player)
    if humanoid then
        humanoid.WalkSpeed = speed or 16
        self:Log("SPEED", player.Name, tostring(speed))
    end
end

function NoctraServerManager:KickAll(reason)
    local count = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            pcall(function() player:Kick(reason or "Kick em massa via NoBreath") end)
            count += 1
        end
    end
    self:Log("KICK ALL", "—", tostring(count) .. " jogadores")
    if self.Library then self.Library:Notify({ Title = "Kick All", Content = tostring(count) .. " jogadores kickados.", Type = "success" }) end
end

function NoctraServerManager:FreezeAll(state)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then self:Freeze(player, state) end
    end
    self:Log(state and "FREEZE ALL" or "UNFREEZE ALL", "—")
end

--// ============================================================
--// CONSTRUÇÃO DA UI
--// ============================================================
function NoctraServerManager:BuildUI(Tab)
    self.Tab = Tab
    local Scheme = self.Library.Scheme or DefaultTheme

    Tab:AddSection({ Name = "Jogadores Online" })

    self.PlayerListFrame = Create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 200),
        BackgroundColor3 = Scheme.Main,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0,0,0,0),
    }, {
        AddCorner(self.PlayerListFrame, 6),
        AddStroke(self.PlayerListFrame, 1.5, Scheme.Stroke),
        Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
        Create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) })
    })
    self.PlayerListFrame.Parent = Tab.Content

    Tab:AddSection({ Name = "Ações Rápidas" })

    local actionsRow = Create("Frame", { Size = UDim2.new(1, 0, 0, 35), BackgroundTransparency = 1 }, { Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }) })
    actionsRow.Parent = Tab.Content

    local function MakeActionButton(text, color, callback)
        local btn = Create("TextButton", {
            Size = UDim2.new(0, 120, 1, 0),
            BackgroundColor3 = color,
            Text = "", Parent = actionsRow, AutoButtonColor = false,
        }, {
            AddCorner(btn, 6), AddStroke(btn, 1.5, Scheme.Stroke),
            Create("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = text, Font = Enum.Font.RobotoBold, TextSize = 12, TextColor3 = Scheme.Text, TextXAlignment = Enum.TextXAlignment.Center })
        })
        btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundTransparency = 0.2 }):Play() end)
        btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play() end)
        btn.MouseButton1Click:Connect(function() NoctraSound:Play("Activate"); callback() end)
        return btn
    end

    MakeActionButton("Kickar Todos", Scheme.Error, function() self:KickAll() end)
    MakeActionButton("Congelar Todos", Scheme.Element, function() self:FreezeAll(true) end)
    MakeActionButton("Descongelar", Scheme.Element, function() self:FreezeAll(false) end)

    Tab:AddSection({ Name = "Log de Ações" })

    self.LogFrame = Create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 120),
        BackgroundColor3 = Scheme.Main,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0,0,0,0),
    }, { AddCorner(self.LogFrame, 6), AddStroke(self.LogFrame, 1.5, Scheme.Stroke) })
    self.LogFrame.Parent = Tab.Content

    self.LogContent = Create("TextLabel", {
        Size = UDim2.new(1, -12, 0, 0), Position = UDim2.new(0, 6, 0, 6), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        Text = "Aguardando ações...", Font = Enum.Font.Code, TextSize = 11, TextColor3 = Scheme.TextDark,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
    })
    self.LogContent.Parent = self.LogFrame

    self:RefreshPlayerList()

    table.insert(self.Connections, Players.PlayerAdded:Connect(function() self:RefreshPlayerList() end))
    table.insert(self.Connections, Players.PlayerRemoving:Connect(function(player)
        self.PlayerButtons[player] = nil
        task.wait(0.5)
        self:RefreshPlayerList()
    end))

    task.spawn(function()
        while self.Tab and self.Tab.Content and self.Tab.Content.Parent do
            task.wait(2)
            pcall(function() self:RefreshPlayerList() end)
        end
    end)
end

--// ============================================================
--// ATUALIZAÇÃO DA LISTA DE JOGADORES
--// ============================================================
function NoctraServerManager:RefreshPlayerList()
    if not self.PlayerListFrame then return end
    local Scheme = self.Library.Scheme or DefaultTheme

    for _, child in ipairs(self.PlayerListFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    self.PlayerButtons = {}

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local isFrozen = self.IsFrozen[player] == true
        local entry = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = isFrozen and Color3.fromRGB(20, 10, 10) or Scheme.Element,
            BackgroundTransparency = 0.2,
            Parent = self.PlayerListFrame,
        }, {
            AddCorner(entry, 4),
            AddStroke(entry, 1, isFrozen and Scheme.Error or Scheme.Stroke),
            Create("TextLabel", { Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0, 8, 0, 0), BackgroundTransparency = 1, Text = player.Name, Font = Enum.Font.RobotoBold, TextSize = 12, TextColor3 = isFrozen and Scheme.Error or Scheme.Text, TextXAlignment = Enum.TextXAlignment.Left }),
        })

        local kickBtn = Create("TextButton", {
            Size = UDim2.new(0, 50, 0, 22), Position = UDim2.new(1, -175, 0.5, -11),
            BackgroundColor3 = Scheme.Error, Text = "", Parent = entry, AutoButtonColor = false,
        }, { AddCorner(kickBtn, 4), AddStroke(kickBtn, 1, Scheme.Stroke), Create("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "Kick", Font = Enum.Font.RobotoBold, TextSize = 10, TextColor3 = Scheme.Text }) })
        kickBtn.MouseButton1Click:Connect(function() NoctraSound:Play("Activate"); self:Kick(player, "Kickado via NoBreath Server Manager") end)

        local freezeBtn = Create("TextButton", {
            Size = UDim2.new(0, 50, 0, 22), Position = UDim2.new(1, -120, 0.5, -11),
            BackgroundColor3 = isFrozen and Scheme.Error or Scheme.Element, Text = "", Parent = entry, AutoButtonColor = false,
        }, { AddCorner(freezeBtn, 4), AddStroke(freezeBtn, 1, Scheme.Stroke), Create("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = isFrozen and "Unfreeze" or "Freeze", Font = Enum.Font.RobotoBold, TextSize = 10, TextColor3 = Scheme.Text }) })
        freezeBtn.MouseButton1Click:Connect(function()
            NoctraSound:Play("Activate")
            local currentState = self.IsFrozen[player] == true
            self:Freeze(player, not currentState)
            self:RefreshPlayerList()
        end)

        local tpBtn = Create("TextButton", {
            Size = UDim2.new(0, 50, 0, 22), Position = UDim2.new(1, -65, 0.5, -11),
            BackgroundColor3 = Scheme.Element, Text = "", Parent = entry, AutoButtonColor = false,
        }, { AddCorner(tpBtn, 4), AddStroke(tpBtn, 1, Scheme.Stroke), Create("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "TP", Font = Enum.Font.RobotoBold, TextSize = 10, TextColor3 = Scheme.Text }) })
        tpBtn.MouseButton1Click:Connect(function()
            NoctraSound:Play("Activate")
            self:TeleportToPlayer(player)
            if self.Library then self.Library:Notify({ Title = "Teleporte", Content = "Fui até " .. player.Name, Type = "success" }) end
        end)

        self.PlayerButtons[player] = entry
    end
    self.PlayerListFrame.CanvasSize = UDim2.new(0, 0, 0, #Players:GetPlayers() * 34 + 10)
end

function NoctraServerManager:Init(Library, Tab)
    self.Library = Library
    self:BuildUI(Tab)
    self:Log("INIT", "—", "Server Manager inicializado")
    return self
end

function NoctraServerManager:Destroy()
    for _, conn in ipairs(self.Connections) do pcall(function() conn:Disconnect() end) end
    self.Connections = {}
    self.PlayerButtons = {}
    self.ActionLog = {}
    self.IsFrozen = {}
end

--// ============================================================
--// PARTE 5: LOADER FINAL E INICIALIZAÇÃO DO HUB
--// ============================================================

--// Inicializa os Managers
NoctraThemeManager:Init(LocalPlayer)
NoctraThemeManager:SetLibrary(NoctraLib)
NoctraSaveManager:SetLibrary(NoctraLib)
NoctraSaveManager:BuildFolderTree()

--// Vincula os Managers à Library
NoctraLib.ThemeManager = NoctraThemeManager
NoctraLib.SaveManager = NoctraSaveManager

--// Cria a janela principal
local Window = NoctraLib:MakeWindow({
    Name = "NoBreath",
    SubName = "v1.0 | NoctraLib",
    Logo = "rbxassetid://102326100327209",
    ToggleKey = Enum.KeyCode.RightShift,
    Size = UDim2.new(0, 650, 0, 420),
})

--// ============================================================
--// ABA 1: PRINCIPAL
--// ============================================================
local MainTab = NoctraLib:MakeTab({
    Name = "Principal",
    Icon = "rbxassetid://10734924532",
})

MainTab:AddSection({ Name = "Combate" })

MainTab:AddToggle({
    Name = "Auto Farm",
    Flag = "AutoFarm",
    Default = false,
    Callback = function(state)
        print("[NoBreath] AutoFarm:", state)
        if state then
            NoctraLib:Notify({ Title = "Auto Farm", Content = "Ativado", Type = "success" })
        else
            NoctraLib:Notify({ Title = "Auto Farm", Content = "Desativado", Type = "info" })
        end
    end,
})

MainTab:AddToggle({
    Name = "Auto Dodge",
    Flag = "AutoDodge",
    Default = false,
    Callback = function(state) print("[NoBreath] AutoDodge:", state) end,
})

MainTab:AddSlider({
    Name = "Velocidade",
    Min = 16, Max = 250, Default = 50,
    Flag = "Speed",
    Callback = function(value)
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then char.Humanoid.WalkSpeed = value end
    end,
})

MainTab:AddButton({
    Text = "Ativar LoopKick",
    Func = function()
        NoctraLib:Notify({ Title = "LoopKick", Content = "Função ativada com sucesso.", Type = "success" })
        print("[NoBreath] LoopKick ativado!")
    end,
})

MainTab:AddButton({
    Text = "Reset Character",
    Func = function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.Health = 0
        end
    end,
})

MainTab:AddSection({ Name = "Visual" })

MainTab:AddDropdown({
    Name = "Modo de Câmera",
    Values = { "Padrão", "Primeira Pessoa", "Visão Superior" },
    Default = "Padrão",
    Flag = "CameraMode",
    Callback = function(value) print("[NoBreath] Câmera:", value) end,
})

MainTab:AddTextbox({
    Name = "Mensagem de Chat",
    Default = "",
    Flag = "ChatMessage",
    Callback = function(text) print("[NoBreath] Mensagem:", text) end,
})

MainTab:AddColorPicker({
    Name = "Cor do ESP",
    Default = Color3.fromRGB(255, 255, 255),
    Flag = "ESPColor",
    Callback = function(color) print("[NoBreath] Cor do ESP:", color) end,
})

--// ============================================================
--// ABA 2: CONFIGS (SAVE MANAGER)
--// ============================================================
local ConfigTab = NoctraLib:MakeTab({
    Name = "Configs",
    Icon = "rbxassetid://10734924532",
})

local ConfigBox = NoctraSaveManager:BuildConfigSection(ConfigTab, "folder-cog")

--// ============================================================
--// ABA 3: TEMAS (THEME MANAGER)
--// ============================================================
local ThemeTab = NoctraLib:MakeTab({
    Name = "Temas",
    Icon = "rbxassetid://10734924532",
})

local ThemeSection = ThemeTab:AddSection({ Name = "Temas Embutidos" })
local themeNames = NoctraThemeManager:GetBuiltInThemes()
local themeDropdown = ThemeTab:AddDropdown({
    Name = "Selecionar Tema",
    Values = themeNames,
    Default = "Noctra",
    Flag = "ThemeManager_ThemeList",
    Callback = function(value)
        NoctraThemeManager:ApplyTheme(value)
        NoctraLib:Notify({ Title = "Tema", Content = "Tema aplicado: " .. value, Type = "success" })
    end,
})
ThemeTab:AddButton({
    Text = "Salvar Tema Atual",
    Func = function()
        local themeName = "MeuTema_" .. os.time()
        local success, err = NoctraThemeManager:SaveCustomTheme(themeName)
        if success then
            NoctraLib:Notify({ Title = "Tema Salvo", Content = themeName, Type = "success" })
        else
            NoctraLib:Notify({ Title = "Erro", Content = tostring(err), Type = "error" })
        end
    end,
})
ThemeTab:AddButton({
    Text = "Definir como Padrão",
    Func = function()
        local success = NoctraThemeManager:SaveDefaultTheme(themeDropdown.Value)
        if success then
            NoctraLib:Notify({ Title = "Tema Padrão", Content = themeDropdown.Value, Type = "success" })
        end
    end,
})

--// ============================================================
--// ABA 4: SERVIDOR (SERVER MANAGER)
--// ============================================================
local ServerTab = NoctraLib:MakeTab({
    Name = "Servidor",
    Icon = "rbxassetid://10734924532",
})

NoctraServerManager:Init(NoctraLib, ServerTab)

--// ============================================================
--// WATERMARK E SEARCH BAR
--// ============================================================
local function CreateWatermark()
    local wmFrame = Create("Frame", {
        Name = "Watermark",
        Size = UDim2.new(0, 200, 0, 28),
        Position = UDim2.new(0, 15, 0, 15),
        BackgroundColor3 = NoctraLib.Scheme.Main,
        BackgroundTransparency = 0.3,
        Parent = NoctraLib.ScreenGui,
    }, { AddCorner(wmFrame, 6), AddStroke(wmFrame, 1.5, NoctraLib.Scheme.Stroke) })

    local wmText = Create("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "", Font = Enum.Font.RobotoBold, TextSize = 12,
        TextColor3 = NoctraLib.Scheme.Text, TextXAlignment = Enum.TextXAlignment.Center,
    })

    local fps, ping = 0, 0
    local frameCounter, lastTick = 0, tick()

    local rsConnection = RunService.RenderStepped:Connect(function()
        frameCounter += 1
        if tick() - lastTick >= 1 then
            fps = frameCounter
            frameCounter = 0
            lastTick = tick()
            local network = game:GetService("Stats").Network
            ping = math.floor(network.ServerStatsItem["Data Ping"]:GetValue())
            wmText.Text = string.format("NoBreath | %d fps | %d ms", fps, ping)
            wmFrame.Size = UDim2.new(0, wmText.TextBounds.X + 24, 0, 28)
        end
    end)
    table.insert(NoctraLib.Connections, rsConnection)
end

local function CreateSearchBar()
    local searchHolder = Create("Frame", {
        Name = "SearchHolder",
        Size = UDim2.new(0, 200, 0, 30),
        Position = UDim2.new(1, -220, 0, 60),
        BackgroundColor3 = NoctraLib.Scheme.Main,
        BackgroundTransparency = 0.2,
        Parent = NoctraLib.Window,
        Visible = true,
    }, { AddCorner(searchHolder, 6), AddStroke(searchHolder, 1.5, NoctraLib.Scheme.Stroke) })

    local InputBox = Create("TextBox", {
        Name = "SearchInput",
        Size = UDim2.new(1, -30, 1, 0),
        Position = UDim2.new(0, 15, 0, 0),
        BackgroundTransparency = 1,
        PlaceholderText = "Pesquisar...",
        PlaceholderColor3 = NoctraLib.Scheme.TextDark,
        Text = "",
        Font = Enum.Font.Roboto,
        TextSize = 13,
        TextColor3 = NoctraLib.Scheme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = searchHolder,
    })
    Create("ImageLabel", {
        Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(1, -25, 0.5, -7),
        BackgroundTransparency = 1, Image = "rbxassetid://10734924532", ImageColor3 = NoctraLib.Scheme.TextDark
    })

    InputBox.Focused:Connect(function() NoctraSound:Play("Type") end)
    InputBox:GetPropertyChangedSignal("Text"):Connect(function()
        local query = string.lower(InputBox.Text)
        for _, obj in pairs(NoctraLib.Options) do
            if obj.Instance and obj.Instance:IsA("Frame") then
                local textLabel = obj.Instance:FindFirstChild("Title") or (obj.Instance:FindFirstChild("Content") and obj.Instance.Content:FindFirstChild("Title"))
                if textLabel then
                    local match = query == "" or string.find(string.lower(textLabel.Text), query)
                    obj.Instance.Visible = match
                end
            end
        end
    end)
end

CreateWatermark()
CreateSearchBar()

--// ============================================================
--// AUTOLOAD
--// ============================================================
task.spawn(function()
    task.wait(0.8)
    NoctraSaveManager:LoadAutoloadConfig()
end)

--// ============================================================
--// LOG FINAL
--// ============================================================
print("[NoBreath] NoBreath Hub carregado com sucesso.")
print("[NoBreath] RightShift para mostrar/esconder.")
print("[NoBreath] Abas: Principal, Configs, Temas, Servidor.")

--// ============================================================
--// SALVA REFERÊNCIAS
--// ============================================================
getgenv().NoctraLoaded = {
    Window = Window,
    Library = NoctraLib,
    ThemeManager = NoctraThemeManager,
    SaveManager = NoctraSaveManager,
    ServerManager = NoctraServerManager,
}

return getgenv().NoctraLoaded
