-- language: Lua, file: NoctraSaveManager.lua
-- NoctraLib — Save Manager (completo)
-- Autor: ENI (para LO, com amor)

local cloneref = (cloneref or clonereference or function(instance: any) return instance end)
local clonefunction = (clonefunction or copyfunction or function(func) return func end)

local HttpService = cloneref(game:GetService("HttpService"))

--// Fix is_____ functions para shitsploits
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
--// SAVE MANAGER
--// ============================================================
local NoctraSaveManager = {
    Library = nil,

    Folder = "NoBreath",
    SubFolder = "NoctraLib/settings",

    Ignore = {},
    LoadingOrder = {},
    UseLoadingOrder = false,

    AutoloadConfig = nil
}

function NoctraSaveManager:SetLibrary(Library)
    NoctraSaveManager.Library = Library
end

--// ============================================================
--// ELEMENT PARSER
--// ============================================================
local SpecialValueParser = {
    UDim2 = {
        Encode = function(Value: UDim2)
            return {
                X = { Scale = Value.X.Scale, Offset = Value.X.Offset },
                Y = { Scale = Value.Y.Scale, Offset = Value.Y.Offset }
            }
        end,
        Decode = function(Data: any)
            local DataType = typeof(Data)
            if DataType == "table" then
                return UDim2.new(Data.X.Scale, Data.X.Offset, Data.Y.Scale, Data.Y.Offset)
            elseif DataType == "UDim2" then
                return Data
            end
            return nil
        end
    }
}

local ElementParser = {}; do
    local function CreateParser(
        ElementType: string, 
        LibraryIndex: string, 
        Save: (string, any, ...any) -> any, 
        Load: (any?, any) -> any,
        CustomElementFetcher: boolean?
    )
        ElementParser[ElementType] = { 
            Save = function(Index: string, Element: any, ...)
                local Data = Save(Index, Element, ...)
                Data.type = ElementType
                Data.idx = Index
                return Data
            end, 
            Load = function(Index: string?, Data: any)
                if CustomElementFetcher == true then
                    return Load(nil, Data)
                end
                local Elements = NoctraSaveManager.Library and NoctraSaveManager.Library[LibraryIndex]
                local Element = Elements and Elements[Index]
                return Load(Element, Data)
            end
        }
    end

    CreateParser(
        "Toggle", "Toggles",
        function(Index: string, Toggle: any)
            return { value = Toggle.Value }
        end,
        function(Element: any?, Data: any)
            if not Element then return end
            if Element.Value == Data.value then
                Element:RunChanged()
                return
            end
            Element:SetValue(Data.value)
        end
    )

    CreateParser(
        "Slider", "Options",
        function(Index: string, Slider: any)
            return { value = tostring(Slider.Value) }
        end,
        function(Element: any?, Data: any)
            if not Element then return end
            if tostring(Element.Value) == tostring(Data.value) then
                Element:RunChanged()
                return
            end
            Element:SetValue(tonumber(Data.value) or Data.value)
        end
    )

    CreateParser(
        "Dropdown", "Options",
        function(Index: string, Dropdown: any)
            return { value = Dropdown.Value, multi = Dropdown.Multi }
        end,
        function(Element: any?, Data: any)
            if not Element then return end
            if Element.Value == Data.value then
                Element:RunChanged()
                return
            end
            Element:SetValue(Data.value)
        end
    )

    CreateParser(
        "ColorPicker", "Options",
        function(Index: string, ColorPicker: any)
            return { value = ColorPicker.Value:ToHex(), transparency = ColorPicker.Transparency }
        end,
        function(Element: any?, Data: any)
            if not Element then return end
            Element:SetValueRGB(Color3.fromHex(Data.value), Data.transparency)
        end
    )

    CreateParser(
        "KeyPicker", "Options",
        function(Index: string, KeyPicker: any)
            return { mode = KeyPicker.Mode, key = KeyPicker.Value, modifiers = KeyPicker.Modifiers, toggled = KeyPicker.Toggled }
        end,
        function(Element: any?, Data: any)
            if not Element then return end
            Element:SetValue({ Data.key, Data.mode, Data.modifiers })
            if Data.mode == "Toggle" and Data.toggled ~= nil then
                Element.Toggled = Data.toggled
                Element:Update()
            end
        end
    )

    CreateParser(
        "Input", "Options",
        function(Index: string, Input: any)
            return { text = Input.Value }
        end,
        function(Element: any?, Data: any)
            if not Element then return end
            if typeof(Data.text) ~= "string" then return end
            if Element.Value == Data.text then
                Element:RunChanged()
                return
            end
            Element:SetValue(Data.text)
        end
    )

    CreateParser(
        "Groupbox", "Tabs",
        function(Index: string, Groupbox: any, TabIndex: string)
            return {
                tabIdx = TabIndex,
                collapsed = Groupbox.Collapsed,
                poppedOut = Groupbox.PoppedOut == true,
                popoutPos = if Groupbox.PoppedOut and Groupbox.PopOutFloat then SpecialValueParser.UDim2.Encode(Groupbox.PopOutFloat.Position) else nil,
            }
        end,
        function(_, Data: any)
            local TabIndex, Index = Data.tabIdx, Data.idx
            if typeof(TabIndex) ~= "string" or typeof(Index) ~= "string" then return end
            local Tabs = NoctraSaveManager.Library and NoctraSaveManager.Library.Tabs
            local Tab = Tabs and Tabs[TabIndex]
            if not Tab then return end
            local Groupbox = Tab.Groupboxes[Index]
            if not Groupbox then return end

            if Groupbox.Collapsed ~= Data.collapsed then
                Groupbox:SetCollapsed(Data.collapsed == true)
            end
            if Groupbox.PopOutEnabled then
                if Data.poppedOut == true then
                    local Position = SpecialValueParser.UDim2.Decode(Data.popoutPos)
                    Groupbox:SetPoppedOut(true, Position)
                elseif Groupbox.PoppedOut then
                    Groupbox:SetPoppedOut(false)
                end
            end
        end,
        true
    )

    CreateParser(
        "Tabbox", "Tabs",
        function(Index: string, Tabbox: any, TabIndex: string)
            return {
                tabIdx = TabIndex,
                poppedOut = Tabbox.PoppedOut == true,
                popoutPos = if Tabbox.PoppedOut and Tabbox.PopOutFloat then SpecialValueParser.UDim2.Encode(Tabbox.PopOutFloat.Position) else nil,
            }
        end,
        function(_, Data: any)
            local TabIndex, Index = Data.tabIdx, Data.idx
            if typeof(TabIndex) ~= "string" or typeof(Index) ~= "string" then return end
            local Tabs = NoctraSaveManager.Library and NoctraSaveManager.Library.Tabs
            local Tab = Tabs and Tabs[TabIndex]
            if not Tab then return end
            local Tabbox = Tab.Tabboxes and Tab.Tabboxes[Index]
            if not Tabbox then return end

            if Tabbox.PopOutEnabled then
                if Data.poppedOut == true then
                    local Position = SpecialValueParser.UDim2.Decode(Data.popoutPos)
                    Tabbox:SetPoppedOut(true, Position)
                elseif Tabbox.PoppedOut then
                    Tabbox:SetPoppedOut(false)
                end
            end
        end,
        true
    )
end

--// ============================================================
--// HELPERS
--// ============================================================
local function Trim(Text: string)
    return Text:match("^%s*(.-)%s*$")
end

local function IsStringEmpty(String: string): boolean
    return if typeof(String) == "string" then Trim(String) == "" else true
end

local function IsValidFolderPath(Name: string): boolean
    return typeof(Name) == "string" and (
        Trim(Name) ~= "" and 
        not Name:match("^%s*$") and 
        not Name:find('[<>:"|%?%*%z]')
    )
end

local function SplitPath(Path: string): {string}
    local Result = {}
    local Current = ""
    for Part in string.gmatch(Path, "[^/]+") do
        Current = if Current == "" then Part else (Current .. "/" .. Part)
        table.insert(Result, Current)
    end
    return Result
end

local function GetFolderPath(): false | string
    if IsStringEmpty(NoctraSaveManager.Folder) then
        return false
    end
    return string.format("%s", NoctraSaveManager.Folder)
end

local function GetSubFolderPath(): false | string
    if IsStringEmpty(NoctraSaveManager.Folder) or IsStringEmpty(NoctraSaveManager.SubFolder) then
        return false
    end
    return string.format("%s/%s", NoctraSaveManager.Folder, NoctraSaveManager.SubFolder)
end

local function GetCurrentSettingsPath(): false | string
    local SubFolderPath = GetSubFolderPath()
    return if SubFolderPath == false then GetFolderPath() else SubFolderPath
end

local function GetConfigPath(ConfigName: string): false | string
    local CurrentSettingsPath = GetCurrentSettingsPath()
    return if CurrentSettingsPath == false then false else string.format("%s/%s.json", CurrentSettingsPath, ConfigName)
end

local function DoesConfigExist(ConfigName: string): boolean
    local ConfigPath = GetConfigPath(ConfigName)
    return if ConfigPath == false then false else isfile(ConfigPath)
end

local function GetAutoloadPath(): false | string
    local CurrentSettingsPath = GetCurrentSettingsPath()
    return if CurrentSettingsPath == false then false else string.format("%s/autoload.txt", CurrentSettingsPath)
end

--// ============================================================
--// INDEXES
--// ============================================================
function NoctraSaveManager:SetLoadingOrder(Enabled: boolean, Order: {string}?)
    NoctraSaveManager.UseLoadingOrder = Enabled == true
    NoctraSaveManager.LoadingOrder = typeof(Order) == "table" and Order or NoctraSaveManager.LoadingOrder
end

function NoctraSaveManager:SetIgnoreIndexes(Indexes: {string}?)
    assert(typeof(Indexes) == "table", "Expected table, got " .. typeof(Indexes))
    for _, Index in Indexes do
        NoctraSaveManager.Ignore[Index] = true
    end
end

function NoctraSaveManager:IgnoreThemeSettings()
    NoctraSaveManager:SetIgnoreIndexes({
        "BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor", "FontFace", "BackgroundImage",
        "ThemeManager_ThemeList", "ThemeManager_CustomThemeList", "ThemeManager_CustomThemeName", "ThemeManager_ThemeJSON"
    })
end

--// ============================================================
--// FOLDERS
--// ============================================================
function NoctraSaveManager:GetPaths(): {string}
    local SubFolderPath = GetSubFolderPath()
    if SubFolderPath == false then
        local FolderPath = GetFolderPath()
        return if FolderPath == false then {} else SplitPath(FolderPath)
    end
    return SplitPath(SubFolderPath)
end

function NoctraSaveManager:BuildFolderTree(SkipWhenCreated: boolean?)
    local Paths = NoctraSaveManager:GetPaths()
    if #Paths == 0 then return false end

    if SkipWhenCreated == true and isfolder(Paths[1]) then
        return true
    end

    for _, Path in Paths do
        if isfolder(Path) then continue end
        pcall(makefolder, Path)
    end
    return true
end

function NoctraSaveManager:CheckFolderTree()
    return NoctraSaveManager:BuildFolderTree(true)
end

function NoctraSaveManager:CheckSubFolder(CreateFolder: boolean)
    local SubFolderPath = GetSubFolderPath()
    if SubFolderPath == false then return false end

    local FolderExists = isfolder(SubFolderPath)
    if not CreateFolder then return FolderExists end

    pcall(makefolder, SubFolderPath)
    return true
end

function NoctraSaveManager:SetFolder(Folder: string)
    assert(IsValidFolderPath(Folder), "Invalid path provided")
    NoctraSaveManager.Folder = Folder
    NoctraSaveManager:BuildFolderTree()
end

function NoctraSaveManager:SetSubFolder(SubFolder: string)
    assert(IsValidFolderPath(SubFolder), "Invalid path provided")
    NoctraSaveManager.SubFolder = SubFolder
    NoctraSaveManager:BuildFolderTree()
end

--// ============================================================
--// CONFIG MANAGEMENT
--// ============================================================
function NoctraSaveManager:RefreshConfigList()
    local SettingsPath = GetCurrentSettingsPath()
    if SettingsPath == false then return {} end

    pcall(makefolder, SettingsPath)
    local SuccessList, Files = pcall(listfiles, SettingsPath)
    if not (SuccessList and typeof(Files) == "table") then
        if NoctraSaveManager.Library then
            NoctraSaveManager.Library:Notify(string.format("Falha ao carregar lista de configs: %s", tostring(Files)))
        end
        return {}
    end

    local FileNames = {}
    for _, FilePath in Files do
        local RawFileName = FilePath:match("(.+)%..+$")
        if not RawFileName then continue end
        local Position = RawFileName:gsub("\\", "/"):find("/[^/]*$")
        local FileName = Position and RawFileName:sub(Position + 1) or RawFileName
        if not FileName or FileName == "autoload" then continue end
        table.insert(FileNames, FileName)
    end
    return FileNames
end

function NoctraSaveManager:SaveJSON(ConfigName)
    local Library = NoctraSaveManager.Library
    local IgnoreIndexes = NoctraSaveManager.Ignore
    local CurrentData = {
        timestamp = os.date("%d.%m.%Y %H:%M:%S"),
        name = ConfigName or "",
        objects = {},
        keybindMenu = nil,
    }

    --// Keybind Menu (se a Library tiver suporte)
    if Library.KeybindFrame then
        local Hidden = {}
        for Index, Option in Library.Options do
            if Option.Type == "KeyPicker" and Option.NoUI ~= true and Option.MenuVisible == false then
                Hidden[Index] = true
            end
        end
        local KeybindMenu = Library.KeybindMenu
        local SettingsPosition = nil
        if KeybindMenu and KeybindMenu.SettingsFrame then
            SettingsPosition = SpecialValueParser.UDim2.Encode(KeybindMenu.SettingsFrame.Position)
        end
        CurrentData.keybindMenu = {
            visible = Library.KeybindFrame.Visible,
            position = SpecialValueParser.UDim2.Encode(Library.KeybindFrame.Position),
            collapsed = if KeybindMenu then KeybindMenu.Collapsed == true else false,
            settingsOpen = false,
            settingsPosition = SettingsPosition,
            hidden = Hidden,
        }
    end

    --// Toggles
    for Index, Toggle in Library.Toggles do
        if not Toggle.Type or IgnoreIndexes[Index] then continue end
        local Parser = ElementParser[Toggle.Type]
        if Parser then table.insert(CurrentData.objects, Parser.Save(Index, Toggle)) end
    end

    --// Options
    for Index, Option in Library.Options do
        if not Option.Type or IgnoreIndexes[Index] then continue end
        local Parser = ElementParser[Option.Type]
        if Parser then table.insert(CurrentData.objects, Parser.Save(Index, Option)) end
    end

    --// Groupboxes, Tabboxes
    for TabIndex, Tab in Library.Tabs do
        if Tab.Groupboxes then
            for Index, Groupbox in Tab.Groupboxes do
                if typeof(Index) ~= "string" or IgnoreIndexes[Index] then continue end
                local Parser = ElementParser.Groupbox
                if Parser then table.insert(CurrentData.objects, Parser.Save(Index, Groupbox, TabIndex)) end
            end
        end
        if Tab.Tabboxes then
            for Index, Tabbox in Tab.Tabboxes do
                if typeof(Index) ~= "string" or IgnoreIndexes[Index] then continue end
                local Parser = ElementParser.Tabbox
                if Parser then table.insert(CurrentData.objects, Parser.Save(Index, Tabbox, TabIndex)) end
            end
        end
    end

    local SuccessEncode, EncodedData = pcall(HttpService.JSONEncode, HttpService, CurrentData)
    if not SuccessEncode then return "", false, "Falha ao codificar dados" end
    return EncodedData, true
end

function NoctraSaveManager:Save(ConfigName: string): (boolean, string?)
    if IsStringEmpty(ConfigName) then return false, "Nome de config inválido" end
    if string.lower(ConfigName) == "autoload" then return false, "Nome de config inválido" end

    local ConfigPath = GetConfigPath(ConfigName)
    if ConfigPath == false then return false, "Caminho inválido" end

    NoctraSaveManager:CheckFolderTree()

    local EncodedData, SuccessEncode, EncodeErrorMessage = NoctraSaveManager:SaveJSON(ConfigName)
    if not SuccessEncode then return false, EncodeErrorMessage end

    local SuccessWrite, ErrorMessage = pcall(writefile, ConfigPath, EncodedData)
    if not SuccessWrite then return false, "Falha ao escrever arquivo: " .. tostring(ErrorMessage) end
    return true
end

function NoctraSaveManager:LoadJSON(Content: string)
    if IsStringEmpty(Content) then return false, "Nenhum JSON fornecido" end

    local SuccessDecode, Decoded = pcall(HttpService.JSONDecode, HttpService, Content)
    if not SuccessDecode or typeof(Decoded) ~= "table" or typeof(Decoded.objects) ~= "table" then
        return false, "Falha ao decodificar JSON"
    end

    local Library = NoctraSaveManager.Library
    local LoadingOrder = NoctraSaveManager.LoadingOrder
    local IgnoreIndexes = NoctraSaveManager.Ignore

    if NoctraSaveManager.UseLoadingOrder == true and typeof(LoadingOrder) == "table" then
        table.sort(Decoded.objects, function(a, b)
            local aIndex = table.find(LoadingOrder, a.type) or math.huge
            local bIndex = table.find(LoadingOrder, b.type) or math.huge
            return aIndex < bIndex
        end)
    end

    --// Keybind Menu
    if Library.KeybindFrame and typeof(Decoded.keybindMenu) == "table" then
        local KFData = Decoded.keybindMenu
        local IsVisible = KFData.visible == true
        local Position = SpecialValueParser.UDim2.Decode(KFData.position)

        Library.KeybindFrame.Visible = IsVisible
        Library.KeybindFrame.Position = Position or Library.KeybindFrame.Position

        local KMToggle = Library.Options and Library.Options.KeybindMenuOpen
        if KMToggle then KMToggle:SetValue(IsVisible) end

        local KM = Library.KeybindMenu
        if KM then
            if KM.SetCollapsed then KM:SetCollapsed(KFData.collapsed == true) end
            if typeof(KFData.hidden) == "table" then
                for Index, Option in Library.Options do
                    if Option.Type ~= "KeyPicker" or Option.NoUI == true or not Option.SetMenuVisibility then continue end
                    Option:SetMenuVisibility(KFData.hidden[Index] ~= true)
                end
            end
            local SPos = SpecialValueParser.UDim2.Decode(KFData.settingsPosition)
            if SPos and KM.SettingsFrame then KM.SettingsFrame.Position = SPos end
            KM:SetSettingsOpen(false)
        end
    end

    --// Elements
    for _, Option in Decoded.objects do
        if not Option.type or IgnoreIndexes[Option.idx] then continue end
        local Parser = ElementParser[Option.type]
        if not Parser then continue end
        task.defer(Parser.Load, Option.idx, Option)
    end
    return true
end

function NoctraSaveManager:Load(ConfigName: string): (boolean, string?)
    if IsStringEmpty(ConfigName) then return false, "Nenhum config selecionado" end
    local ConfigPath = GetConfigPath(ConfigName)
    if ConfigPath == false or not isfile(ConfigPath) then return false, "Arquivo de config não existe" end

    local SuccessRead, Content = pcall(readfile, ConfigPath)
    if not SuccessRead then return false, "Falha ao ler arquivo" end
    return NoctraSaveManager:LoadJSON(Content)
end

function NoctraSaveManager:Delete(ConfigName: string): (boolean | string?)
    if IsStringEmpty(ConfigName) then return false, "Nenhum config selecionado" end
    local ConfigPath = GetConfigPath(ConfigName)
    if ConfigPath == false or not isfile(ConfigPath) then return false, "Arquivo não existe" end

    local SuccessDelete, ErrorMessage = pcall(delfile, ConfigPath)
    if not SuccessDelete then return false, "Falha ao deletar: " .. tostring(ErrorMessage) end

    if ConfigName == NoctraSaveManager.AutoloadConfig then
        NoctraSaveManager:DeleteAutoLoadConfig()
    end
    return true
end

--// ============================================================
--// AUTOLOAD
--// ============================================================
function NoctraSaveManager:GetAutoloadConfig(): (string, boolean, string?)
    NoctraSaveManager:CheckFolderTree()
    local AutoloadPath = GetAutoloadPath()
    if AutoloadPath == false then return "none", false, "Caminho inválido" end
    if not isfile(AutoloadPath) then return "none", false, "Autoload não definido" end

    local SuccessRead, AutoloadConfigName = pcall(readfile, AutoloadPath)
    if not (SuccessRead and typeof(AutoloadConfigName) == "string") then
        return "none", false, AutoloadConfigName
    end
    if not DoesConfigExist(AutoloadConfigName) then return "none", false, "Arquivo não encontrado" end

    NoctraSaveManager.AutoloadConfig = AutoloadConfigName
    return AutoloadConfigName, true
end

function NoctraSaveManager:SaveAutoloadConfig(ConfigName: string): (boolean, string?)
    if IsStringEmpty(ConfigName) then return false, "Nenhum config selecionado" end
    NoctraSaveManager:CheckFolderTree()
    local AutoloadPath = GetAutoloadPath()
    if AutoloadPath == false then return false, "Caminho inválido" end
    if not DoesConfigExist(ConfigName) then return false, "Config não existe" end

    local SuccessWrite, ErrorMessage = pcall(writefile, AutoloadPath, ConfigName)
    if not SuccessWrite then return false, ErrorMessage end
    NoctraSaveManager.AutoloadConfig = ConfigName
    return true
end

function NoctraSaveManager:LoadAutoloadConfig()
    local ConfigName, Success, FetchErrorMessage = NoctraSaveManager:GetAutoloadConfig()
    if not Success or FetchErrorMessage then
        if FetchErrorMessage ~= "Autoload não definido" then
            NoctraSaveManager.Library:Notify(string.format("Falha ao carregar autoload: %s", FetchErrorMessage))
        end
        return
    end
    local SuccessLoad, LoadErrorMessage = NoctraSaveManager:Load(ConfigName)
    if not SuccessLoad then
        NoctraSaveManager.Library:Notify(string.format("Falha ao carregar autoload: %s", LoadErrorMessage))
        return
    end
    NoctraSaveManager.Library:Notify(string.format("Autoload carregado: %q", ConfigName))
end

function NoctraSaveManager:DeleteAutoLoadConfig(): (boolean, string?)
    NoctraSaveManager:CheckFolderTree()
    local AutoloadPath = GetAutoloadPath()
    if AutoloadPath == false then return false, "Caminho inválido" end
    if not isfile(AutoloadPath) then return false, "Autoload não definido" end

    local SuccessDelete, ErrorMessage = pcall(delfile, AutoloadPath)
    if not SuccessDelete then return false, ErrorMessage end
    NoctraSaveManager.AutoloadConfig = nil
    return true
end

--// ============================================================
--// GUI (Módulo visual de config para a Library)
--// ============================================================
local function ShowDialog(Condition, Index, Title, Description, DestructiveText, DestructiveAction)
    if Condition() == false then
        return DestructiveAction()
    end
    return NoctraSaveManager.Library.Window:AddDialog(Index, {
        Title = Title,
        Description = Description,
        AutoDismiss = false,
        FooterButtons = {
            Cancel = {
                Title = "Cancelar",
                Variant = "Ghost",
                Order = 1,
                Callback = function(Dialog) Dialog:Dismiss() end
            },
            DestructiveAction = {
                Title = DestructiveText,
                Variant = "Destructive",
                Order = 2,
                Callback = function(Dialog)
                    Dialog:Dismiss()
                    DestructiveAction()
                end
            }
        }
    })
end

function NoctraSaveManager:BuildConfigSection(Tab, IconName)
    assert(NoctraSaveManager.Library, "Library não definida. Chame SaveManager:SetLibrary(Library) primeiro.")
    local ConfigurationBox = Tab:AddGroupbox({
        Side = "Right",
        Name = "Configurações",
        IconName = IconName or "folder-cog",
    })

    local ConfigNameInput, ConfigList, ConfigJSONInput, AutoloadConfigLabel
    local function RefreshList()
        ConfigList:SetValues(NoctraSaveManager:RefreshConfigList())
        ConfigList:SetValue(nil)
    end
    local function RefreshAutoloadConfigLabel()
        local AutoloadConfigName = NoctraSaveManager:GetAutoloadConfig()
        AutoloadConfigLabel:SetText(string.format("Autoload atual: %s", AutoloadConfigName))
        if ConfigList then RefreshList() end
    end

    ConfigurationBox:AddInput("SaveManager_ConfigName", { Text = "Nome do config" })

    ConfigurationBox:AddButton("Criar config", function()
        local ConfigName = ConfigNameInput.Value
        if IsStringEmpty(ConfigName) then
            NoctraSaveManager.Library:Notify("O nome do config não pode ser vazio.")
            return
        end
        if string.lower(ConfigName) == "autoload" then
            NoctraSaveManager.Library:Notify("Nome inválido.")
            return
        end
        ShowDialog(
            function() return DoesConfigExist(ConfigName) end,
            "SaveManager_CreateConfig",
            "Config já existe",
            string.format("Um config chamado %q já existe. Sobrescrever vai substituir pelas configurações atuais.", ConfigName),
            "Sobrescrever",
            function()
                local Success, ErrorMessage = NoctraSaveManager:Save(ConfigName)
                if not Success then
                    NoctraSaveManager.Library:Notify(string.format("Falha ao criar config %q: %s", ConfigName, ErrorMessage))
                    return
                end
                NoctraSaveManager.Library:Notify(string.format("Config criado: %q", ConfigName))
                RefreshList()
            end
        )
    end)

    ConfigurationBox:AddDivider()

    ConfigurationBox:AddDropdown("SaveManager_ConfigList", {
        Text = "Lista de configs",
        Values = NoctraSaveManager:RefreshConfigList(),
        AllowNull = true,
        Multi = false,
        FormatDisplayValue = function(Value)
            if Value == NoctraSaveManager.AutoloadConfig then return string.format("%s (autoload)", Value) end
            return Value
        end,
        FormatListValue = function(Value)
            if Value == NoctraSaveManager.AutoloadConfig then return string.format("%s (autoload)", Value) end
            return Value
        end
    })

    ConfigurationBox:AddButton({
        Text = "Carregar config",
        DoubleClick = false,
        Func = function()
            local ConfigName = ConfigList.Value
            if IsStringEmpty(ConfigName) then
                NoctraSaveManager.Library:Notify("Selecione um config primeiro.")
                return
            end
            ShowDialog(
                function() return true end,
                "SaveManager_LoadConfig",
                "Carregar config",
                string.format("Tem certeza que deseja carregar %q? Suas configurações atuais serão sobrescritas.", ConfigName),
                "Carregar",
                function()
                    local Success, ErrorMessage = NoctraSaveManager:Load(ConfigName)
                    if not Success then
                        NoctraSaveManager.Library:Notify(string.format("Falha ao carregar config %q: %s", ConfigName, ErrorMessage))
                        return
                    end
                    NoctraSaveManager.Library:Notify(string.format("Config carregado: %q", ConfigName))
                end
            )
        end
    })
    
    ConfigurationBox:AddButton({
        Text = "Sobrescrever config",
        DoubleClick = false,
        Func = function()
            local ConfigName = ConfigList.Value
            if IsStringEmpty(ConfigName) then
                NoctraSaveManager.Library:Notify("Selecione um config primeiro.")
                return
            end
            ShowDialog(
                function() return true end,
                "SaveManager_OverwriteConfig",
                "Sobrescrever config",
                string.format("Tem certeza que deseja sobrescrever %q com suas configurações atuais? Isso não pode ser desfeito.", ConfigName),
                "Sobrescrever",
                function()
                    local Success, ErrorMessage = NoctraSaveManager:Save(ConfigName)
                    if not Success then
                        NoctraSaveManager.Library:Notify(string.format("Falha ao sobrescrever config %q: %s", ConfigName, ErrorMessage))
                        return
                    end
                    NoctraSaveManager.Library:Notify(string.format("Config sobrescrito: %q", ConfigName))
                end
            )
        end
    })

    ConfigurationBox:AddButton({
        Text = "Deletar config",
        DoubleClick = false,
        Func = function()
            local ConfigName = ConfigList.Value
            if IsStringEmpty(ConfigName) then
                NoctraSaveManager.Library:Notify("Selecione um config primeiro.")
                return
            end
            ShowDialog(
                function() return true end,
                "SaveManager_DeleteConfig",
                "Deletar config",
                string.format("Tem certeza que deseja deletar %q? Isso não pode ser desfeito.", ConfigName),
                "Deletar",
                function()
                    local Success, ErrorMessage = NoctraSaveManager:Delete(ConfigName)
                    if not Success then
                        NoctraSaveManager.Library:Notify(string.format("Falha ao deletar config %q: %s", ConfigName, ErrorMessage))
                        return
                    end
                    NoctraSaveManager.Library:Notify(string.format("Config deletado: %q", ConfigName))
                    RefreshAutoloadConfigLabel()
                end
            )
        end
    })

    ConfigurationBox:AddButton("Atualizar lista", RefreshList)

    ConfigurationBox:AddButton({
        Text = "Definir como autoload",
        DoubleClick = false,
        Func = function()
            local ConfigName = ConfigList.Value
            if IsStringEmpty(ConfigName) then
                NoctraSaveManager.Library:Notify("Selecione um config primeiro.")
                return
            end
            local Success, ErrorMessage = NoctraSaveManager:SaveAutoloadConfig(ConfigName)
            if not Success then
                NoctraSaveManager.Library:Notify(string.format("Falha ao definir autoload %q: %s", ConfigName, ErrorMessage))
                return
            end
            NoctraSaveManager.Library:Notify(string.format("Autoload definido: %q", ConfigName))
            RefreshAutoloadConfigLabel()
        end
    })

    ConfigurationBox:AddButton({
        Text = "Resetar autoload",
        DoubleClick = false,
        Func = function()
            ShowDialog(
                function() return true end,
                "SaveManager_ResetAutoload",
                "Resetar autoload",
                "Tem certeza que deseja limpar o autoload? Nenhum config será carregado automaticamente na próxima inicialização.",
                "Resetar",
                function()
                    local Success, ErrorMessage = NoctraSaveManager:DeleteAutoLoadConfig()
                    if not Success then
                        NoctraSaveManager.Library:Notify(string.format("Falha ao resetar autoload: %s", ErrorMessage))
                        return
                    end
                    NoctraSaveManager.Library:Notify("Autoload resetado.")
                    RefreshAutoloadConfigLabel()
                end
            )
        end
    })

    AutoloadConfigLabel = ConfigurationBox:AddLabel("Autoload atual: ...", true)

    ConfigurationBox:AddDivider()

    ConfigurationBox:AddInput("SaveManager_JSON", { Text = "JSON do config" })

    ConfigurationBox:AddButton("Importar config", function()
        local ConfigJSON = ConfigJSONInput.Value
        if IsStringEmpty(ConfigJSON) then
            NoctraSaveManager.Library:Notify("O JSON do config não pode ser vazio.")
            return
        end
        ShowDialog(
            function() return true end,
            "SaveManager_ImportConfig",
            "Importar config",
            "Tem certeza que deseja importar este config? Suas configurações atuais serão sobrescritas.",
            "Importar",
            function()
                local Success, ErrorMessage = NoctraSaveManager:LoadJSON(ConfigJSON)
                if not Success then
                    NoctraSaveManager.Library:Notify(string.format("Falha ao importar config: %s", ErrorMessage))
                    return
                end
                NoctraSaveManager.Library:Notify("Config importado com sucesso.")
            end
        )
    end)

    ConfigurationBox:AddButton("Exportar config atual", function()
        local EncodedData, Success, ErrorMessage = NoctraSaveManager:SaveJSON()
        if not Success then
            NoctraSaveManager.Library:Notify(ErrorMessage)
            return
        end
        ConfigJSONInput:SetValue(EncodedData)
        if setclipboard then
            setclipboard(EncodedData)
            NoctraSaveManager.Library:Notify("Config copiado para a área de transferência.")
        end
    end)

    ConfigNameInput, ConfigList, ConfigJSONInput =
        NoctraSaveManager.Library.Options.SaveManager_ConfigName, 
        NoctraSaveManager.Library.Options.SaveManager_ConfigList,
        NoctraSaveManager.Library.Options.SaveManager_JSON

    RefreshAutoloadConfigLabel()
    NoctraSaveManager:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName", "SaveManager_JSON" })

    return ConfigurationBox
end

NoctraSaveManager:BuildFolderTree()
return NoctraSaveManager
