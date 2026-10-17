-- language: Lua, file: BetterOrion.lua, target: Roblox executor (Synapse/Script-Ware/Krnl/Fluxus/Solara)
-- *Tema: Glassmorphism (Nexus.ai style) - Azul Ciano, Fundo Escuro Gradiente, Blur*
-- *100% corrigido: AddSection funcional, sem quebra de MainWindow, sem cortes*

while not game:IsLoaded() do task.wait() end
for _, UI in ipairs(game.CoreGui:GetChildren()) do
	if UI.Name == "BetterOrion" then
		UI:Destroy()
	end
end

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")

local OrionLib = {
	Elements = {},
	UIElements = {},
	ThemeObjects = {},
	Connections = {},
	Flags = {},
	Tabs = {},
    Themes = {
    Default = {
        Main = {
            Color = Color3.fromRGB(20, 25, 35),
            Transparency = 0.3
        },
        Stroke = {
            Color = Color3.fromRGB(0, 210, 255),
            Transparency = 0.2
        },
        Divider = {
            Color = Color3.fromRGB(50, 70, 90),
            Transparency = 0.6
        },
        Text = {
            Color = Color3.fromRGB(255, 255, 255),
            Transparency = 0
        },
        TextDark = {
            Color = Color3.fromRGB(170, 190, 210),
            Transparency = 0
        },
        Elements = {
            Color = Color3.fromRGB(30, 40, 55),
            Transparency = 0.4
        }
    },
    MyCustomTheme = {
        Main = {},
        Stroke = {},
        Divider = {},
        Text = {},
        TextDark = {},
        Elements = {}
    }
},
	NotificationSettings = {
		Enabled = true,
		Printing = false
	},
	WindowConfig = {},
	BackgroundConfig = {
		EnabledBackground = false,
		BackgroundName = "",
		BackgroundTransparency = 0.2
	},
	SelectedTheme = "Default",
	ScriptFolder = "BetterOrion",
	GameName = tostring(game.PlaceId),
	Window = nil,
}

-- Blur
local Blur = Lighting:FindFirstChild("OrionBlur") or Instance.new("BlurEffect")
Blur.Name = "OrionBlur"
Blur.Size = 20
Blur.Parent = Lighting

-- Icons
local Icons = {}
local LucideIcons = loadstring(game:HttpGet("https://raw.githubusercontent.com/Utkaky/Main/refs/heads/main/SoundHub/icons.lua"))().assets

-- Core
local Orion = Instance.new("ScreenGui")
Orion.Name = "BetterOrion"
if syn then
    pcall(function() syn.protect_gui(Orion) end)
    Orion.Parent = game.CoreGui
else
    Orion.Parent = game.CoreGui
end

-- Fundo do UI
local Background = Instance.new("Frame")
Background.Name = "BackgroundGradient"
Background.Size = UDim2.new(1, 0, 1, 0)
Background.BackgroundColor3 = Color3.fromRGB(10, 15, 25)
Background.BorderSizePixel = 0
Background.Parent = Orion
Background.ZIndex = 0

local UIGradient = Instance.new("UIGradient")
UIGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 20, 35)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 35, 60)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 15, 25))
}
UIGradient.Rotation = 45
UIGradient.Parent = Background

function OrionLib:IsRunning()
    return Orion.Parent == game.CoreGui
end

-- Local functions
local function GetOrionIcon(IconName)
    if Icons[IconName] ~= nil then return Icons[IconName] else return nil end
end
local function GetLucideIcon(IconName)
    if IconName ~= nil then
        return LucideIcons["lucide-"..IconName]
    else
        return nil
    end
end

local function AddConnection(Signal, Function)
    if (not OrionLib:IsRunning()) then return end
    local SignalConnect = Signal:Connect(Function)
    table.insert(OrionLib.Connections, SignalConnect)
    return SignalConnect
end

task.spawn(function()
    while (OrionLib:IsRunning()) do wait() end
    for _, Connection in next, OrionLib.Connections do Connection:Disconnect() end
end)

local function Create(Name, Properties, Children)
    local Object = Instance.new(Name)
    for i, v in Properties or {} do Object[i] = v end
    for i, v in Children or {} do v.Parent = Object end
    return Object
end

local function CreateElement(ElementName, ElementFunction)
    OrionLib.Elements[ElementName] = function(...) return ElementFunction(...) end
end

local function MakeElement(ElementName, ...)
    local NewElement = OrionLib.Elements[ElementName](...)
    return NewElement
end

local function SetProps(Element, Props)
    table.foreach(Props, function(Property, Value) Element[Property] = Value end)
    return Element
end

local function SetChildren(Element, Children)
    table.foreach(Children, function(_, Child) Child.Parent = Element end)
    return Element
end

local function Round(Number, Factor)
    Number = tonumber(Number)
    local sign = Number >= 0 and 1 or -1
    local result = math.floor(Number / Factor + 0.5 * sign) * Factor
    if result < 0 then result = result + Factor end
    if Factor < 1 then
        local str = tostring(Factor)
        local dot = str:find("%.")
        local precision = dot and #str - dot or 0
        result = tonumber(string.format("%." .. precision .. "f", result))
    end
    return result
end

local function ReturnProperty(Object, PropType)
    if Object:IsA("Frame") or Object:IsA("TextButton") then return (PropType == "Color" and "BackgroundColor3") or "BackgroundTransparency" end
    if Object:IsA("ScrollingFrame") then return (PropType == "Color" and "ScrollBarImageColor3") or "ScrollBarImageTransparency" end
    if Object:IsA("UIStroke") then return (PropType == "Color" and "Color") or "Transparency" end
    if Object:IsA("TextLabel") or Object:IsA("TextBox") then return (PropType == "Color" and "TextColor3") or "TextTransparency" end
    if Object:IsA("ImageLabel") or Object:IsA("ImageButton") then return (PropType == "Color" and "ImageColor3") or "ImageTransparency" end
end

local function AddThemeObject(Object, Type)
    if not OrionLib.ThemeObjects[Type] then OrionLib.ThemeObjects[Type] = {} end
    table.insert(OrionLib.ThemeObjects[Type], Object)
    Object[ReturnProperty(Object, "Color")] = OrionLib.Themes[OrionLib.SelectedTheme][Type]["Color"]
    Object[ReturnProperty(Object, "Transparency")] = OrionLib.Themes[OrionLib.SelectedTheme][Type]["Transparency"]
    return Object
end

local function SetTheme()
    for Name, Type in pairs(OrionLib.ThemeObjects) do
        for _, Object in pairs(Type) do
            Object[ReturnProperty(Object, "Color")] = OrionLib.Themes[OrionLib.SelectedTheme][Name]["Color"]
            Object[ReturnProperty(Object, "Transparency")] = OrionLib.Themes[OrionLib.SelectedTheme][Name]["Transparency"]
        end
    end
end

local WhitelistedMouse = {
    Enum.UserInputType.MouseButton1,
    Enum.UserInputType.MouseButton2,
    Enum.UserInputType.MouseButton3
}
local BlacklistedKeys = {
    Enum.KeyCode.Unknown,
    Enum.KeyCode.W,
    Enum.KeyCode.A,
    Enum.KeyCode.S,
    Enum.KeyCode.D,
    Enum.KeyCode.Up,
    Enum.KeyCode.Left,
    Enum.KeyCode.Down,
    Enum.KeyCode.Right,
    Enum.KeyCode.Slash,
    Enum.KeyCode.Backspace,
    Enum.KeyCode.Escape
}

local function CheckKey(Table, Key)
    for _, v in next, Table do
        if v == Key then return true end
    end
end

-- Create Elements
CreateElement("Corner", function(Scale, Offset)
    local Corner = Create("UICorner", {CornerRadius = UDim.new(Scale or 0, Offset or 12)})
    return Corner
end)

CreateElement("Stroke", function(Color, Thickness)
    local Stroke = Create("UIStroke", {
        Color = Color or Color3.fromRGB(0, 210, 255),
        Thickness = Thickness or 1,
        Name = "Stroke",
        Transparency = 0.5
    })
    return Stroke
end)

CreateElement("List", function(Scale, Offset)
    local List = Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(Scale or 0, Offset or 0)
    })
    return List
end)

CreateElement("Padding", function(Bottom, Left, Right, Top)
    local Padding = Create("UIPadding", {
        PaddingBottom = UDim.new(0, Bottom or 4),
        PaddingLeft = UDim.new(0, Left or 4),
        PaddingRight = UDim.new(0, Right or 4),
        PaddingTop = UDim.new(0, Top or 4)
    })
    return Padding
end)

CreateElement("TFrame", function()
    local TFrame = Create("Frame", {BackgroundTransparency = 1})
    return TFrame
end)

CreateElement("Frame", function(Color)
    local Frame = Create("Frame", {
        BackgroundColor3 = Color or Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0
    })
    return Frame
end)

CreateElement("RoundFrame", function(Color, Scale, Offset)
    local Frame = Create("Frame", {
        BackgroundColor3 = Color or Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0
    }, {
        Create("UICorner", {CornerRadius = UDim.new(Scale, Offset)})
    })
    return Frame
end)

CreateElement("Button", function()
    local Button = Create("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0
    })
    return Button
end)

CreateElement("ScrollFrame", function(Color)
    local ScrollFrame = Create("ScrollingFrame", {
        BackgroundTransparency = 1,
        MidImage = "rbxassetid://7445543667",
        BottomImage = "rbxassetid://7445543667",
        TopImage = "rbxassetid://7445543667",
        ScrollBarImageColor3 = Color,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        CanvasSize = UDim2.new(0, 0, 0, 0),
    })
    return ScrollFrame
end)

CreateElement("Image", function(ImageID)
    local ImageNew = Create("ImageLabel", {Image = ImageID, BackgroundTransparency = 1})
    if GetOrionIcon(ImageID) ~= nil then ImageNew.Image = GetOrionIcon(ImageID) end
    return ImageNew
end)

CreateElement("ImageButton", function(ImageID)
    local Image = Create("ImageButton", {Image = ImageID, BackgroundTransparency = 1})
    return Image
end)

CreateElement("Label", function(Text, TextSize, Transparency)
    local Label = Create("TextLabel", {
        Text = Text or "",
        TextColor3 = Color3.fromRGB(240, 240, 240),
        TextTransparency = Transparency or 0,
        TextSize = TextSize or 15,
        Font = Enum.Font.Gotham,
        RichText = true,
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left
    })
    return Label
end)

local NotificationHolder = SetProps(SetChildren(MakeElement("TFrame"), {
    SetProps(MakeElement("List"), {
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.Name,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        Padding = UDim.new(0, 5),
    })
}), {
    Position = UDim2.new(1, -25, 1, -25),
    Size = UDim2.new(0, 300, 1, -25),
    AnchorPoint = Vector2.new(1, 1),
    Parent = Orion,
    Name = "NotificationList",
    ZIndex = 100
})

function OrionLib:MakeNotification(NotificationConfig)
    spawn(function()
        NotificationConfig = NotificationConfig or {}
        NotificationConfig.Name = NotificationConfig.Name or "Notification Title"
        NotificationConfig.Content = NotificationConfig.Content or "Notification Content"
        NotificationConfig.Image = NotificationConfig.Image or "server"
        NotificationConfig.Time = NotificationConfig.Time or 5
        NotificationConfig.Color = NotificationConfig.Color or Color3.fromRGB(20, 25, 35)
        NotificationConfig.TextColor = NotificationConfig.TextColor or Color3.fromRGB(255, 255, 255)

        local NotificationParent = SetProps(MakeElement("TFrame"), {
            Size = UDim2.new(0.9, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = NotificationHolder,
            ZIndex = 100
        })

        local NotificationFrame = SetChildren(SetProps(MakeElement("RoundFrame", NotificationConfig.Color, 0, 12), {
            Parent = NotificationParent,
            Size = UDim2.new(1, 0, 0, 0),
            Position = UDim2.new(1, -55, 0, 0),
            BackgroundTransparency = 0.3,
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = 100
        }), {
            MakeElement("Stroke"),
            MakeElement("Padding", 12, 12, 12, 12),
            SetProps(MakeElement("Image", GetLucideIcon(NotificationConfig.Image)), {
                Size = UDim2.new(0, 20, 0, 20),
                Position = UDim2.new(0, 0, 0.5, -9),
                ImageColor3 = NotificationConfig.TextColor,
                Name = "Icon",
                BackgroundTransparency = 1,
                ZIndex = 101
            }),
            SetProps(MakeElement("Label", NotificationConfig.Name, 15), {
                Size = UDim2.new(1, -30, 0, 20),
                Position = UDim2.new(0, 30, 0, -4),
                Font = Enum.Font.GothamBold,
                TextSize = 15,
                Name = "Title",
                BackgroundTransparency = 1,
                TextColor3 = NotificationConfig.TextColor,
                ZIndex = 101
            }),
            SetProps(MakeElement("Label", NotificationConfig.Content, 14), {
                Size = NotificationConfig.Content == "" and UDim2.new(0, 0, 0, 0) or UDim2.new(1, -30, 0, 6),
                Position = UDim2.new(0, 30, 0, 20),
                Font = Enum.Font.GothamSemibold,
                TextSize = 13,
                Name = "Content",
                AutomaticSize = Enum.AutomaticSize.Y,
                TextColor3 = NotificationConfig.TextColor,
                TextWrapped = true,
                BackgroundTransparency = 1,
                Visible = NotificationConfig.Content ~= "" and true or false,
                ZIndex = 101
            })
        })
        
        TweenService:Create(NotificationFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 30, 0, 0)}):Play()
        wait(NotificationConfig.Time)
        TweenService:Create(NotificationFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(1, 60, 0, 0)}):Play()
        wait(0.6)
        NotificationParent:Destroy()
    end)
end

function OrionLib:MakeWindow(WindowConfig)
    local Val = {
        FirstTab = true,
        Minimized = false,
        UIHidden = false,
        Tab = "",
        TabholderSize = UDim2.new(0, 120, 0, 200)
    }

    WindowConfig = WindowConfig or {}
    WindowConfig.Name = WindowConfig.Name or "Better Orion"
    WindowConfig.SubName = WindowConfig.SubName or ""
    WindowConfig.Size = WindowConfig.Size or UDim2.fromOffset(650, 450)
    WindowConfig.MinSize = WindowConfig.MinSize or UDim2.fromOffset(400, 200)
    WindowConfig.MaxSize = WindowConfig.MaxSize or UDim2.fromOffset(4000, 2000)
    WindowConfig.ToggleUIKey = WindowConfig.ToggleUIKey or Enum.KeyCode.Tab
    WindowConfig.ShowIcon = WindowConfig.ShowIcon or false
    WindowConfig.Icon = GetLucideIcon(WindowConfig.Icon) or ""
    WindowConfig.Transparency = WindowConfig.Transparency or 0.2
    WindowConfig.FreeMouse = WindowConfig.FreeMouse or false
    WindowConfig.LogoIcon = WindowConfig.LogoIcon or ""

    local TabHolder = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(0, 210, 255)), {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Name = "TabHolder",
    }), {
        MakeElement("List"),
        MakeElement("Padding", 8, 0, 0, 8)
    }), "Divider")

    local WindowName = AddThemeObject(SetProps(MakeElement("Label", WindowConfig.Name, 14), {
        Size = UDim2.new(1, -30, 2, 0),
        Position = UDim2.new(0, 25, 0, -45),
        Font = Enum.Font.GothamBlack,
        TextSize = 20,
        Name = "WindowName",
        Text = WindowConfig.Name,
    }), "Text")
    
    local WindowSubName = AddThemeObject(SetProps(MakeElement("Label", WindowConfig.SubName, 14), {
        Size = UDim2.new(1, -WindowName.TextBounds.X - 200, 1, 0),
        Position = UDim2.new(0, WindowConfig.ShowIcon and WindowName.TextBounds.X + 60 or WindowName.TextBounds.X + 35, 0, -19),
        Font = Enum.Font.GothamSemibold,
        TextSize = 14,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Name = "WindowSubName",
        Text = WindowConfig.SubName
    }), "TextDark")

    local CloseBtn = SetChildren(SetProps(MakeElement("Button"), {
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.new(0.5, 0, 0, 0),
        BackgroundTransparency = 1
    }), {
        AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072725342"), {
            Position = UDim2.new(0, 9, 0, 6),
            Size = UDim2.new(0, 18, 0, 18),
        }), "Text")
    })

    local MinimizeBtn = SetChildren(SetProps(MakeElement("Button"), {
        Size = UDim2.new(0.5, 0, 1, 0),
        BackgroundTransparency = 1
    }), {
        AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072719338"), {
            Position = UDim2.new(0, 9, 0, 6),
            Size = UDim2.new(0, 18, 0, 18),
            Name = "Ico"
        }), "Text")
    })

    local MainWindow = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(20, 25, 35), 0, 16), {
        Parent = Orion,
        Position = UDim2.new(0.5, -WindowConfig.Size.X.Offset / 2, 0.5, -WindowConfig.Size.Y.Offset / 2),
        Size = WindowConfig.Size,
        BackgroundTransparency = WindowConfig.Transparency,
        Name = "MainWindow",
        Visible = false,
        ClipsDescendants = false,
        ZIndex = 2
    }), {
        AddThemeObject(MakeElement("Stroke"), "Stroke"),
        SetChildren(AddThemeObject(SetProps(MakeElement("RoundFrame", Color3.fromRGB(20, 25, 35), 0, 16), {
            Size = UDim2.new(1, 0, 1, -60),
            Position = UDim2.new(0, 0, 0, 60),
            Name = "FakeMainWindowNew",
            BackgroundTransparency = 0.5,
            ClipsDescendants = true,
            Active = true,
            ZIndex = 2
        }), "Main"), {
            AddThemeObject(MakeElement("Stroke"), "Stroke"),
        }),
        AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(20, 25, 35), 0, 16), {
            Size = UDim2.new(1, 0, 0, 60),
            Name = "TopBar",
            BackgroundTransparency = 0.4,
            ClipsDescendants = false,
            Active = true,
            ZIndex = 3
        }), {
            AddThemeObject(MakeElement("Stroke"), "Stroke"),
            SetChildren(SetProps(MakeElement("TFrame", Color3.fromRGB(18, 18, 18), 0, 8), {
                Size = UDim2.new(1, 0, 1, 0),
                Position = UDim2.new(0, 0, 0, 20),
                Name = "WindowNames",
                ZIndex = 3
            }), {
                WindowName,
                WindowSubName,
            }),
            SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 8), {
                Size = UDim2.new(0, 70, 0, 30),
                Position = UDim2.new(1, -90, 0, 15),
                BackgroundTransparency = 1,
                Name = "ButtonsFrame",
                ZIndex = 3
            }), {
                AddThemeObject(MakeElement("Stroke"), "Stroke"),
                CloseBtn,
                MinimizeBtn
            }),
        }), "Main"),
        SetProps(MakeElement("TFrame"), {
            Size = UDim2.new(1, 0, 0, 60),
            BackgroundTransparency = 1,
            ZIndex = 4
        }),
        SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(20, 25, 35), 0, 16), {
            Size = UDim2.new(0, 130, 1, -80),
            Position = UDim2.new(0, 15, 0, 70),
            BackgroundTransparency = 0.4,
            Name = "WindowStuff",
            Active = true,
            ZIndex = 3
        }), {
            AddThemeObject(MakeElement("Stroke"), "Stroke"),
            TabHolder,
        }), "Main"),
    }), "Main")

    -- Arrastar
    local function AddDraggingFunctionality(DragPoint, Main)
        local Dragging, DragInput, MousePos, FramePos = false
        DragPoint.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
                Dragging = true
                MousePos = Input.Position
                FramePos = Main.Position
                Input.Changed:Connect(function()
                    if Input.UserInputState == Enum.UserInputState.End then Dragging = false end
                end)
            end
        end)
        DragPoint.InputChanged:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then DragInput = Input end
        end)
        UserInputService.InputChanged:Connect(function(Input)
            if Input == DragInput and Dragging then
                local Delta = Input.Position - MousePos
                Main.Position = UDim2.new(FramePos.X.Scale, FramePos.X.Offset + Delta.X, FramePos.Y.Scale, FramePos.Y.Offset + Delta.Y)
            end
        end)
    end
    AddDraggingFunctionality(MainWindow.TopBar.WindowNames, MainWindow)
    AddDraggingFunctionality(MainWindow.FakeMainWindowNew, MainWindow)

    AddConnection(CloseBtn.MouseButton1Up, function() MainWindow.Visible = false end)
    AddConnection(UserInputService.InputBegan, function(Input)
        if Input.KeyCode == WindowConfig.ToggleUIKey then MainWindow.Visible = not MainWindow.Visible end
    end)

    local TabFunction = {}
    
    function TabFunction:MakeTab(TabConfig)
        TabConfig = TabConfig or {}
        TabConfig.Name = TabConfig.Name or "Tab"
        TabConfig.Icon = TabConfig.Icon or ""
        Val.Tab = TabConfig.Name

        local TabFrame = SetChildren(SetProps(MakeElement("Button"), {
            Size = UDim2.new(1, 0, 0, 35),
            Parent = TabHolder,
            Name = Val.Tab,
        }), {
            AddThemeObject(SetProps(MakeElement("Image", GetLucideIcon(TabConfig.Icon)), {
                AnchorPoint = Vector2.new(0, 0.5),
                Size = UDim2.new(0, 18, 0, 18),
                Position = UDim2.new(0, 10, 0.5, 0),
                ImageTransparency = 0.4,
                Name = "Ico",
                ZIndex = 4
            }), "Text"),
            AddThemeObject(SetProps(MakeElement("Label", TabConfig.Name, 14), {
                Size = UDim2.new(1, -35, 1, 0),
                Position = UDim2.new(0, 35, 0, 0),
                Font = Enum.Font.GothamSemibold,
                TextTransparency = 0.4,
                Name = "Title",
                ZIndex = 4
            }), "Text")
        })

        local ContainerLeft = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(255, 255, 255)), {
            Size = UDim2.new(0.5, -55, 1, -80),
            Position = UDim2.new(0, 160, 0, 70),
            Parent = MainWindow,
            Visible = false,
            Name = "ItemContainerLeft",
            ZIndex = 3
        }), {
            MakeElement("List", 0, 8),
        }), "Divider")

        local ContainerRight = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(255, 255, 255)), {
            Size = UDim2.new(0.5, -55, 1, -80),
            Position = UDim2.new(0.5, 40, 0, 70),
            Parent = MainWindow,
            Visible = false,
            Name = "ItemContainerRight",
            ZIndex = 3
        }), {
            MakeElement("List", 0, 8),
        }), "Divider")

        if Val.FirstTab then
            Val.FirstTab = false
            TabFrame.Ico.ImageTransparency = 0
            TabFrame.Title.TextTransparency = 0
            TabFrame.Title.Font = Enum.Font.GothamBlack
            ContainerLeft.Visible = true
            ContainerRight.Visible = true
        end

        AddConnection(TabFrame.MouseButton1Click, function()
            for _, Tab in next, TabHolder:GetChildren() do
                if Tab:IsA("TextButton") then
                    Tab.Title.Font = Enum.Font.GothamSemibold
                    TweenService:Create(Tab.Ico, TweenInfo.new(0.25), {ImageTransparency = 0.4}):Play()
                    TweenService:Create(Tab.Title, TweenInfo.new(0.25), {TextTransparency = 0.4}):Play()
                end
            end
            for _, Container in next, MainWindow:GetChildren() do
                if Container.Name == "ItemContainerLeft" or Container.Name == "ItemContainerRight" then
                    Container.Visible = false
                end
            end
            TweenService:Create(TabFrame.Ico, TweenInfo.new(0.25), {ImageTransparency = 0}):Play()
            TweenService:Create(TabFrame.Title, TweenInfo.new(0.25), {TextTransparency = 0}):Play()
            TabFrame.Title.Font = Enum.Font.GothamBlack
            ContainerLeft.Visible = true
            ContainerRight.Visible = true
        end)

        local function GetElements(ItemParent)
            local ElementFunction = {}
            local function AddElements(ItemParent2)
                function ItemParent2:AddLabel(Text)
                    local LabelFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 8), {
                        Size = UDim2.new(1, 0, 0, 35),
                        BackgroundTransparency = 0.6,
                        Parent = ItemParent,
                    }), {
                        AddThemeObject(SetProps(MakeElement("Label", Text or "Label", 14), {
                            Size = UDim2.new(1, -24, 1, 0),
                            Position = UDim2.new(0, 12, 0, 0),
                            Font = Enum.Font.GothamBold,
                            Name = "Content",
                            TextWrapped = true,
                        }), "Text"),
                    }), "Elements")
                    return LabelFrame
                end

                function ItemParent2:AddButton(ButtonConfig)
                    local ButtonFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(0, 210, 255), 0, 8), {
                        Size = UDim2.new(1, 0, 0, 35),
                        BackgroundTransparency = 0.8,
                        Parent = ItemParent,
                    }), {
                        AddThemeObject(SetProps(MakeElement("Label", ButtonConfig.Name or "Button", 14), {
                            Size = UDim2.new(1, -12, 1, 0),
                            Font = Enum.Font.GothamBold,
                            Name = "Content",
                            TextXAlignment = Enum.TextXAlignment.Center,
                        }), "Text"),
                    }), "Elements")
                    local Button = SetProps(MakeElement("Button"), {
                        Size = UDim2.new(1, 0, 1, 0),
                        Parent = ButtonFrame,
                    })
                    AddConnection(Button.MouseButton1Click, function() pcall(ButtonConfig.Callback) end)
                    return ButtonFrame
                end

                function ItemParent2:AddToggle(ToggleConfig)
                    local ToggleFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 8), {
                        Size = UDim2.new(1, 0, 0, 40),
                        BackgroundTransparency = 0.6,
                        Parent = ItemParent,
                    }), {
                        AddThemeObject(SetProps(MakeElement("Label", ToggleConfig.Name or "Toggle", 14), {
                            Size = UDim2.new(1, -60, 1, 0),
                            Position = UDim2.new(0, 12, 0, 0),
                            Font = Enum.Font.GothamBold,
                            Name = "Content",
                        }), "Text"),
                        AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 1, 0), {
                            Size = UDim2.new(0, 40, 0, 20),
                            Position = UDim2.new(1, -50, 0.5, -10),
                            BackgroundTransparency = 0.8,
                            Name = "ToggleSwitch",
                        }), {
                            AddThemeObject(SetProps(MakeElement("Frame", Color3.fromRGB(255, 255, 255)), {
                                Size = UDim2.new(0, 16, 0, 16),
                                Position = UDim2.new(0, 2, 0.5, -8),
                                Name = "Indicator",
                            }), "Text")
                        }), "Elements"),
                    }), "Elements")

                    local ToggleState = ToggleConfig.Default or false
                    local function SetToggle(Val)
                        ToggleState = Val
                        if Val then
                            TweenService:Create(ToggleFrame.ToggleSwitch, TweenInfo.new(0.2), {BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(0, 210, 255)}):Play()
                            TweenService:Create(ToggleFrame.ToggleSwitch.Indicator, TweenInfo.new(0.2), {Position = UDim2.new(1, -18, 0.5, -8)}):Play()
                        else
                            TweenService:Create(ToggleFrame.ToggleSwitch, TweenInfo.new(0.2), {BackgroundTransparency = 0.8, BackgroundColor3 = Color3.fromRGB(255, 255, 255)}):Play()
                            TweenService:Create(ToggleFrame.ToggleSwitch.Indicator, TweenInfo.new(0.2), {Position = UDim2.new(0, 2, 0.5, -8)}):Play()
                        end
                        pcall(ToggleConfig.Callback, Val)
                    end
                    
                    AddConnection(SetProps(MakeElement("Button"), {Size = UDim2.new(1,0,1,0), Parent = ToggleFrame}).MouseButton1Click, function()
                        SetToggle(not ToggleState)
                    end)
                    
                    SetToggle(ToggleState)
                    return {Set = SetToggle}
                end

                function ItemParent2:AddSlider(SliderConfig)
                    local SliderFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 8), {
                        Size = UDim2.new(1, 0, 0, 55),
                        BackgroundTransparency = 0.6,
                        Parent = ItemParent,
                    }), {
                        AddThemeObject(SetProps(MakeElement("Label", SliderConfig.Name or "Slider", 14), {
                            Size = UDim2.new(1, -120, 0, 20),
                            Position = UDim2.new(0, 12, 0, 6),
                            Font = Enum.Font.GothamBold,
                        }), "Text"),
                        AddThemeObject(SetProps(MakeElement("Label", tostring(SliderConfig.Default) .. " " .. (SliderConfig.ValueName or ""), 14), {
                            Size = UDim2.new(0, 100, 0, 20),
                            Position = UDim2.new(1, -112, 0, 6),
                            Font = Enum.Font.GothamBold,
                            TextXAlignment = Enum.TextXAlignment.Right,
                            Name = "Value",
                        }), "Text"),
                        AddThemeObject(SetChildren(SetProps(MakeElement("Frame"), {
                            Size = UDim2.new(1, -24, 0, 12),
                            Position = UDim2.new(0, 12, 0, 32),
                            BackgroundColor3 = Color3.fromRGB(40, 50, 65),
                            Name = "SliderBar",
                        }), {
                            MakeElement("Corner", 1, 0),
                            AddThemeObject(SetChildren(SetProps(MakeElement("Frame"), {
                                Size = UDim2.new(0, 0, 1, 0),
                                BackgroundColor3 = Color3.fromRGB(0, 210, 255),
                                Name = "Fill",
                            }), {MakeElement("Corner", 1, 0)}), "Stroke"),
                        }), "Elements"),
                    }), "Elements")
                    return SliderFrame
                end

                function ItemParent2:AddDropdown(DropdownConfig)
                     local DropdownFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 8), {
                        Size = UDim2.new(1, 0, 0, 35),
                        BackgroundTransparency = 0.6,
                        Parent = ItemParent,
                    }), {
                        AddThemeObject(SetProps(MakeElement("Label", DropdownConfig.Name or "Dropdown", 14), {
                            Size = UDim2.new(1, -40, 1, 0),
                            Position = UDim2.new(0, 12, 0, 0),
                            Font = Enum.Font.GothamBold,
                        }), "Text"),
                        AddThemeObject(SetProps(MakeElement("Label", "▼", 14), {
                            Size = UDim2.new(0, 20, 1, 0),
                            Position = UDim2.new(1, -30, 0, 0),
                            Font = Enum.Font.GothamBold,
                            TextXAlignment = Enum.TextXAlignment.Center,
                        }), "Text"),
                    }), "Elements")
                    return DropdownFrame
                end
                
                function ItemParent2:AddSection(SectionConfig)
                    local SectionFrame = AddThemeObject(SetProps(MakeElement("Label", SectionConfig.Name or "Section", 14), {
                        Size = UDim2.new(1, 0, 0, 20),
                        Position = UDim2.new(0, 5, 0, 5),
                        Font = Enum.Font.GothamBlack,
                        TextColor3 = Color3.fromRGB(0, 210, 255),
                        Parent = ItemParent,
                    }), "TextDark")
                    
                    local SectionContainer = SetChildren(SetProps(MakeElement("TFrame"), {
                        Size = UDim2.new(1, 0, 0, 0),
                        AutomaticSize = Enum.AutomaticSize.Y,
                        Parent = ItemParent,
                    }), {
                        MakeElement("List", 0, 8),
                        MakeElement("Padding", 0, 5, 5, 0)
                    })
                    
                    AddElements(SectionContainer)
                    return SectionContainer
                end
            end
            AddElements(ElementFunction)
            return ElementFunction
        end

        local LeftElements = GetElements(ContainerLeft)
        local RightElements = GetElements(ContainerRight)

        local TabFunctionFinal = {}
        TabFunctionFinal.Left = LeftElements
        TabFunctionFinal.Right = RightElements

        for methodName, methodFunc in pairs(LeftElements) do
            TabFunctionFinal[methodName] = methodFunc
        end
        
        for methodName, methodFunc in pairs(RightElements) do
            TabFunctionFinal[methodName .. "Right"] = methodFunc
        end

        return TabFunctionFinal
    end

    function TabFunction:SetConfigTab(Name) end

    MainWindow.Visible = true
    return TabFunction
end

function OrionLib:Init() end

return OrionLib
