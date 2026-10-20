--[[
    unable.skins — standalone interface shell
    ------------------------------------------------------------
    Skin changer UI only. No game hooks, no remote calls.

    - ScreenGui parented into the hidden CoreGui layer (gethui, then
      CoreGui, then PlayerGui as the last resort).
    - RightControl toggles the window.
    - ProggyClean.ttf is read from the executor workspace (checked at
      fonts/ProggyClean.ttf, ProggyClean.ttf, and a couple of variants),
      then registered through a generated font-family file so Font.new
      can use it.
    - Every skin card owns an empty ViewportFrame (Card.Viewport) so real
      3D previews can be attached later without touching the layout.
      Cards are available through UnableSkinsUI.Cards and CardsByName.

    Usage (executor):
        loadstring(game:HttpGet("https://raw.githubusercontent.com/deadeb/unable/main/Skinchangerlua/UI.lua"))()

    Attach a preview later:
        local Card = getgenv().UnableSkinsUI.CardsByName["AK-47 | Neon Rider"]
        Model.Parent = Card.Viewport
        Card.Viewport.CurrentCamera = Camera
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

-- ---------------------------------------------------------------- theme

local function Hex(Value)
    return Color3.fromHex(Value)
end

local Theme = {
    Background = Hex("232323"),
    Secondary = Hex("151515"),
    SecondaryStroke = Hex("202020"),
    SecondaryStrokeFar = Hex("121213"),
    Screen = Hex("191919"),
    ScreenStroke = Hex("1d1d1e"),
    ScreenStrokeFar = Hex("161616"),
    Accent = Hex("bd3f5f"),
    Text = Hex("ffffff"),
    Muted = Hex("676767"),
}

-- ---------------------------------------------------------------- font

local FontCandidates = {
    "fonts/ProggyClean.ttf",
    "ProggyClean.ttf",
    "UnableSkins/ProggyClean.ttf",
    "fonts/proggyclean.ttf",
    "proggyclean.ttf",
    "fonts/ProggyClean.TTF",
    "ProggyClean.TTF",
}

-- Font.new expects a font-family asset, not a bare .ttf. Point a generated
-- family file at the font that already lives in the executor workspace.
local function LoadCustomFont()
    if type(getcustomasset) ~= "function" or type(writefile) ~= "function" then
        return nil
    end

    local Paths = FontCandidates

    if type(isfile) == "function" then
        Paths = {}

        for _, Path in ipairs(FontCandidates) do
            local Ok, Exists = pcall(isfile, Path)

            if Ok and Exists then
                Paths[#Paths + 1] = Path
            end
        end

        if #Paths == 0 then
            Paths = { FontCandidates[1] }
        end
    end

    for _, FontPath in ipairs(Paths) do
        local Ok, Result = pcall(function()
            local FontAsset = getcustomasset(FontPath)

            if type(FontAsset) ~= "string" or FontAsset == "" then
                return nil
            end

            local Family = {
                name = "ProggyClean",
                faces = {
                    {
                        name = "Regular",
                        weight = 400,
                        style = "normal",
                        assetId = FontAsset,
                    },
                },
            }

            local FamilyPath = "ProggyClean.font"

            if not pcall(writefile, FamilyPath, HttpService:JSONEncode(Family)) then
                return nil
            end

            return Font.new(getcustomasset(FamilyPath), Enum.FontWeight.Regular, Enum.FontStyle.Normal)
        end)

        if Ok and Result ~= nil then
            return Result
        end
    end

    return nil
end

local CustomFont = LoadCustomFont()

-- ---------------------------------------------------------------- helpers

local function Create(ClassName, Properties)
    local Object = Instance.new(ClassName)
    local Parent = nil

    if Properties then
        Parent = Properties.Parent

        for Key, Value in pairs(Properties) do
            if Key ~= "Parent" then
                Object[Key] = Value
            end
        end
    end

    if Parent then
        Object.Parent = Parent
    end

    return Object
end

local function Stroke(Object, Color, Thickness)
    local StrokeObject = Instance.new("UIStroke")
    StrokeObject.Color = Color
    StrokeObject.Thickness = Thickness or 1
    StrokeObject.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    StrokeObject.Parent = Object
    return StrokeObject
end

local function Text(Properties)
    local Label = Instance.new("TextLabel")
    Label.BackgroundTransparency = 1
    Label.BorderSizePixel = 0
    Label.TextColor3 = Theme.Text
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.TextYAlignment = Enum.TextYAlignment.Center
    Label.TextWrapped = false
    Label.RichText = false

    if CustomFont then
        local Applied = pcall(function()
            Label.FontFace = CustomFont
        end)

        if not Applied then
            Label.Font = Enum.Font.Code
        end
    else
        Label.Font = Enum.Font.Code
    end

    local Parent = nil

    if Properties then
        Parent = Properties.Parent

        for Key, Value in pairs(Properties) do
            if Key ~= "Parent" then
                Label[Key] = Value
            end
        end
    end

    if Parent then
        Label.Parent = Parent
    end

    return Label
end

-- A surface with the two-stage border used across the whole interface:
-- a one pixel outer frame (#121213 / #161616) and a one pixel inner stroke.
local function Surface(Parent, Position, Size, Fill, StrokeColor, FarColor)
    local Outer = Create("Frame", {
        BackgroundColor3 = FarColor,
        BorderSizePixel = 0,
        Position = Position,
        Size = Size,
    })

    local Inner = Create("Frame", {
        BackgroundColor3 = Fill,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(1, 1),
        Size = UDim2.new(1, -2, 1, -2),
    })

    local InnerStroke = Stroke(Inner, StrokeColor, 1)

    Inner.Parent = Outer
    Outer.Parent = Parent

    return Outer, Inner, InnerStroke
end

-- Pixel heart used for the logo and the tab markers.
local HEART = {
    "01100110",
    "11111111",
    "11111111",
    "11111111",
    "01111110",
    "00111100",
    "00011000",
}

local function PixelHeart(Parent, Position, Pixel, Color)
    local Holder = Create("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = Position,
        Size = UDim2.fromOffset(8 * Pixel, 7 * Pixel),
        Parent = Parent,
    })

    for RowIndex, Row in ipairs(HEART) do
        for Column = 1, #Row do
            if string.sub(Row, Column, Column) == "1" then
                Create("Frame", {
                    BackgroundColor3 = Color,
                    BorderSizePixel = 0,
                    Position = UDim2.fromOffset((Column - 1) * Pixel, (RowIndex - 1) * Pixel),
                    Size = UDim2.fromOffset(Pixel, Pixel),
                    Parent = Holder,
                })
            end
        end
    end

    return Holder
end

local function PaintHeart(Holder, Color)
    for _, Pixel in ipairs(Holder:GetChildren()) do
        if Pixel:IsA("Frame") then
            Pixel.BackgroundColor3 = Color
        end
    end
end

-- ---------------------------------------------------------------- window

local ViewportSize = Vector2.new(650, 470)
local PAGE_DATA

local function GetViewport()
    local Camera = workspace.CurrentCamera

    if Camera then
        return Camera.ViewportSize
    end

    return Vector2.new(1920, 1080)
end

local function BuildWindow()
    local Gui = Create("ScreenGui", {
        Name = "UnableSkins",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999999,
    })

    local Parented = false

    local HiddenOk, Hidden = pcall(function()
        if type(gethui) == "function" then
            return gethui()
        end
        return nil
    end)

    if HiddenOk and typeof(Hidden) == "Instance" then
        Parented = pcall(function()
            Gui.Parent = Hidden
        end)
    end

    if not Parented then
        Parented = pcall(function()
            Gui.Parent = game:GetService("CoreGui")
        end)
    end

    if not Parented then
        Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end

    local Root = Create("Frame", {
        Name = "Root",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(ViewportSize.X, ViewportSize.Y),
        Parent = Gui,
    })

    local UIScale = Create("UIScale", {
        Scale = 1,
        Parent = Root,
    })

    Create("Frame", {
        BackgroundColor3 = Theme.SecondaryStrokeFar,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromOffset(ViewportSize.X, ViewportSize.Y),
        Parent = Root,
    })

    local WindowBody = Create("Frame", {
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(1, 1),
        Size = UDim2.new(1, -2, 1, -2),
        Parent = Root,
    })
    Stroke(WindowBody, Theme.SecondaryStroke, 1)

    -- header
    local Header = Create("Frame", {
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 44),
        Parent = WindowBody,
    })

    Create("Frame", {
        BackgroundColor3 = Theme.SecondaryStrokeFar,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        Parent = Header,
    })

    PixelHeart(Header, UDim2.fromOffset(18, 15), 2, Theme.Accent)

    Text({
        Text = "unable.skins",
        Position = UDim2.fromOffset(42, 0),
        Size = UDim2.new(0, 240, 1, 0),
        TextSize = 14,
        TextColor3 = Theme.Accent,
        Parent = Header,
    })

    Text({
        Text = "rcontrol",
        Position = UDim2.new(1, -98, 0, 0),
        Size = UDim2.fromOffset(80, 44),
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = Theme.Muted,
        Parent = Header,
    })

    -- footer
    local Footer = Create("Frame", {
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -52),
        Size = UDim2.new(1, 0, 0, 52),
        Parent = WindowBody,
    })

    Create("Frame", {
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(1, -32, 0, 1),
        Parent = Footer,
    })

    local SelectedLabel = Text({
        Text = "",
        Position = UDim2.new(1, -338, 0, 0),
        Size = UDim2.fromOffset(320, 52),
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = Theme.Muted,
        RichText = true,
        Parent = Footer,
    })

    -- main screen
    local _, Screen = Surface(
        WindowBody,
        UDim2.fromOffset(16, 50),
        UDim2.fromOffset(616, 360),
        Theme.Screen,
        Theme.ScreenStroke,
        Theme.ScreenStrokeFar
    )

    local Tabs = {}
    local Pages = {}
    local Cards = {}
    local CardsByName = {}
    local SelectedCard = nil
    local ActiveTab = 0
    local TabX = 18

    local function SelectTab(Index)
        if Index == ActiveTab or not Tabs[Index] then
            return
        end

        ActiveTab = Index

        for TabIndex, Tab in ipairs(Tabs) do
            local Active = TabIndex == Index

            Tab.Page.Visible = Active
            Tab.Label.TextColor3 = Active and Theme.Text or Theme.Muted
            PaintHeart(Tab.Icon, Active and Theme.Accent or Theme.Muted)
        end
    end

    local function SelectCard(Card)
        if SelectedCard == Card then
            return
        end

        if SelectedCard then
            SelectedCard.SetSelected(false)
        end

        SelectedCard = Card
        Card.SetSelected(true)

        SelectedLabel.Text = '<font color="#676767">selected</font>  <font color="#ffffff">'
            .. Card.Data.Name
            .. "</font>"
    end

    local function AddCard(Body, Data, Column, Row)
        local Outer, Inner, InnerStroke = Surface(
            Body,
            UDim2.fromOffset(Column * 133, Row * 145),
            UDim2.fromOffset(123, 135),
            Theme.Screen,
            Theme.ScreenStroke,
            Theme.ScreenStrokeFar
        )

        Inner.ClipsDescendants = true

        local Stage = Create("Frame", {
            BackgroundColor3 = Theme.Screen,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(121, 91),
            ZIndex = 1,
            Parent = Inner,
        })

        local Gradient = Instance.new("UIGradient")
        Gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.SecondaryStroke),
            ColorSequenceKeypoint.new(1, Theme.Secondary),
        })
        Gradient.Rotation = 90
        Gradient.Parent = Stage

        local Viewport = Create("ViewportFrame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(121, 91),
            Ambient = Color3.fromRGB(115, 115, 122),
            LightColor = Color3.fromRGB(255, 255, 255),
            LightDirection = Vector3.new(-0.4, -1, -0.65),
            ZIndex = 3,
            Parent = Inner,
        })

        -- Preview slot. Parent your own model into Card.Viewport (and assign
        -- a CurrentCamera) once the real skin assets are ready.
        local Hover = Create("Frame", {
            BackgroundColor3 = Data.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(121, 91),
            ZIndex = 4,
            Parent = Inner,
        })

        Create("Frame", {
            BackgroundColor3 = Theme.SecondaryStroke,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 91),
            Size = UDim2.new(1, 0, 0, 1),
            ZIndex = 5,
            Parent = Inner,
        })

        local Info = Create("Frame", {
            BackgroundColor3 = Theme.Secondary,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 92),
            Size = UDim2.new(1, 0, 0, 41),
            ZIndex = 6,
            Parent = Inner,
        })

        local EquipBar = Create("Frame", {
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(2, 41),
            Visible = false,
            ZIndex = 7,
            Parent = Info,
        })

        local NameLabel = Text({
            Text = Data.Name,
            Position = UDim2.fromOffset(8, 2),
            Size = UDim2.fromOffset(105, 27),
            TextSize = 11,
            TextColor3 = Theme.Text,
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 7,
            Parent = Info,
        })

        local MetaLabel = Text({
            Text = Data.Wear,
            Position = UDim2.fromOffset(8, 29),
            Size = UDim2.fromOffset(105, 11),
            TextSize = 9,
            TextColor3 = Theme.Muted,
            ZIndex = 7,
            Parent = Info,
        })

        local Hit = Create("TextButton", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            AutoButtonColor = false,
            ZIndex = 20,
            Parent = Inner,
        })

        local Card = {
            Data = Data,
            Frame = Outer,
            Viewport = Viewport,
            Stroke = InnerStroke,
            Glow = Hover,
            Bar = EquipBar,
            NameLabel = NameLabel,
            Meta = MetaLabel,
            Selected = false,
        }

        function Card.SetSelected(State)
            Card.Selected = State
            InnerStroke.Color = State and Theme.Accent or Theme.ScreenStroke
            InnerStroke.Transparency = 0
            EquipBar.Visible = State
            MetaLabel.Text = State and "equipped" or Data.Wear
            MetaLabel.TextColor3 = State and Theme.Accent or Theme.Muted
            NameLabel.TextColor3 = Theme.Text
        end

        Hit.MouseEnter:Connect(function()
            TweenService:Create(InnerStroke, TweenInfo.new(0.12), {
                Color = Card.Selected and Theme.Accent or Theme.Muted,
            }):Play()

            TweenService:Create(Hover, TweenInfo.new(0.12), {
                BackgroundTransparency = 0.94,
            }):Play()
        end)

        Hit.MouseLeave:Connect(function()
            TweenService:Create(InnerStroke, TweenInfo.new(0.12), {
                Color = Card.Selected and Theme.Accent or Theme.ScreenStroke,
            }):Play()

            TweenService:Create(Hover, TweenInfo.new(0.14), {
                BackgroundTransparency = 1,
            }):Play()
        end)

        Hit.Activated:Connect(function()
            SelectCard(Card)
        end)

        Cards[#Cards + 1] = Card
        CardsByName[Data.Name] = Card
        return Card
    end

    local function AddPage(PageData, Index)
        local Page = Create("Frame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            Visible = false,
            Parent = Screen,
        })

        local function AddSection(SectionData, X)
            local _, Body = Surface(
                Page,
                UDim2.fromOffset(X, 12),
                UDim2.fromOffset(282, 334),
                Theme.Secondary,
                Theme.SecondaryStroke,
                Theme.SecondaryStrokeFar
            )

            Text({
                Text = SectionData.Title,
                Position = UDim2.fromOffset(12, 0),
                Size = UDim2.new(1, -24, 0, 28),
                TextSize = 13,
                TextColor3 = Theme.Text,
                Parent = Body,
            })

            Create("Frame", {
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                Position = UDim2.fromOffset(0, 28),
                Size = UDim2.new(1, 0, 0, 1),
                Parent = Body,
            })

            local CardsArea = Create("Frame", {
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Position = UDim2.fromOffset(12, 40),
                Size = UDim2.new(1, -24, 1, -52),
                Parent = Body,
            })

            for CardIndex, CardData in ipairs(SectionData.Cards) do
                local Column = (CardIndex - 1) % 2
                local Row = math.floor((CardIndex - 1) / 2)

                AddCard(CardsArea, CardData, Column, Row)
            end
        end

        AddSection(PageData.Sections[1], 16)
        AddSection(PageData.Sections[2], 316)

        local Width = 30 + #PageData.Name * 7

        local TabButton = Create("TextButton", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(TabX, 0),
            Size = UDim2.fromOffset(Width, 52),
            Text = "",
            AutoButtonColor = false,
            Parent = Footer,
        })

        local Icon = PixelHeart(TabButton, UDim2.fromOffset(0, 22), 1, Theme.Muted)

        local Label = Text({
            Text = PageData.Name,
            Position = UDim2.fromOffset(16, 0),
            Size = UDim2.new(1, -16, 1, 0),
            TextSize = 12,
            TextColor3 = Theme.Muted,
            Parent = TabButton,
        })

        local Tab = {
            Page = Page,
            Button = TabButton,
            Icon = Icon,
            Label = Label,
        }

        Tabs[#Tabs + 1] = Tab

        TabButton.MouseEnter:Connect(function()
            if ActiveTab ~= Index then
                TweenService:Create(Label, TweenInfo.new(0.1), {
                    TextColor3 = Hex("9a9a9a"),
                }):Play()
            end
        end)

        TabButton.MouseLeave:Connect(function()
            if ActiveTab ~= Index then
                TweenService:Create(Label, TweenInfo.new(0.1), {
                    TextColor3 = Theme.Muted,
                }):Play()
            end
        end)

        TabButton.Activated:Connect(function()
            SelectTab(Index)
        end)

        Pages[#Pages + 1] = Page
        TabX = TabX + Width + 20
    end

    for Index, PageData in ipairs(PAGE_DATA) do
        AddPage(PageData, Index)
    end

    local Dragging = false
    local DragStart = nil
    local DragOrigin = nil
    local Open = true
    local BaseScale = 1
    local Connections = {}

    local function Clamp()
        local ScreenSize = GetViewport()
        local Scale = UIScale.Scale
        local Width = ViewportSize.X * Scale
        local Height = ViewportSize.Y * Scale

        local CenterX = ScreenSize.X * 0.5 + Root.Position.X.Offset
        local CenterY = ScreenSize.Y * 0.5 + Root.Position.Y.Offset

        local MinX = Width * 0.5 + 6
        local MaxX = ScreenSize.X - Width * 0.5 - 6

        if MinX > MaxX then
            CenterX = ScreenSize.X * 0.5
        else
            CenterX = math.clamp(CenterX, MinX, MaxX)
        end

        local MinY = Height * 0.5 + 6
        local MaxY = ScreenSize.Y - Height * 0.5 - 6

        if MinY > MaxY then
            CenterY = ScreenSize.Y * 0.5
        else
            CenterY = math.clamp(CenterY, MinY, MaxY)
        end

        Root.Position = UDim2.new(0.5, CenterX - ScreenSize.X * 0.5, 0.5, CenterY - ScreenSize.Y * 0.5)
    end

    local function UpdateScale()
        local ScreenSize = GetViewport()
        local Scale = math.min((ScreenSize.X - 20) / ViewportSize.X, (ScreenSize.Y - 20) / ViewportSize.Y)
        Scale = math.clamp(Scale, 0.35, 1)

        BaseScale = Scale

        if Open then
            UIScale.Scale = Scale
        end

        Clamp()
    end

    local function SetOpen(State)
        if State == Open then
            return
        end

        Open = State

        if State then
            Root.Visible = true
            UIScale.Scale = BaseScale * 0.97

            local Tween =
                TweenService:Create(UIScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Scale = BaseScale,
                })
            Tween:Play()
        else
            local Tween =
                TweenService:Create(UIScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Scale = BaseScale * 0.97,
                })
            Tween:Play()

            task.delay(0.13, function()
                if not Open then
                    Root.Visible = false
                end
            end)
        end
    end

    -- header drag
    local DragArea = Create("TextButton", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 44),
        Text = "",
        AutoButtonColor = false,
        ZIndex = 40,
        Parent = Header,
    })

    DragArea.InputBegan:Connect(function(Input)
        if
            Input.UserInputType == Enum.UserInputType.MouseButton1
            or Input.UserInputType == Enum.UserInputType.Touch
        then
            Dragging = true
            DragStart = Input.Position
            DragOrigin = Root.Position
        end
    end)

    Connections[#Connections + 1] = UserInputService.InputChanged:Connect(function(Input)
        if not Dragging then
            return
        end

        if
            Input.UserInputType == Enum.UserInputType.MouseMovement
            or Input.UserInputType == Enum.UserInputType.Touch
        then
            local Delta = Input.Position - DragStart

            Root.Position = UDim2.new(0.5, DragOrigin.X.Offset + Delta.X, 0.5, DragOrigin.Y.Offset + Delta.Y)

            Clamp()
        end
    end)

    Connections[#Connections + 1] = UserInputService.InputEnded:Connect(function(Input)
        if
            Input.UserInputType == Enum.UserInputType.MouseButton1
            or Input.UserInputType == Enum.UserInputType.Touch
        then
            Dragging = false
        end
    end)

    Connections[#Connections + 1] = UserInputService.InputBegan:Connect(function(Input)
        if Input.KeyCode == Enum.KeyCode.RightControl then
            SetOpen(not Open)
        end
    end)

    -- keep the window inside the viewport when the camera changes size
    local CameraConnection = nil

    local function BindCamera()
        local Camera = workspace.CurrentCamera

        if CameraConnection then
            CameraConnection:Disconnect()
            CameraConnection = nil
        end

        if Camera then
            CameraConnection = Camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale)
        end

        UpdateScale()
    end

    Connections[#Connections + 1] = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(BindCamera)
    BindCamera()

    SelectTab(1)

    local Window = {
        Gui = Gui,
        Root = Root,
        Screen = Screen,
        Tabs = Tabs,
        Pages = Pages,
        Cards = Cards,
        CardsByName = CardsByName,
        SelectTab = SelectTab,
        SelectCard = SelectCard,
        SetOpen = SetOpen,
        UpdateScale = UpdateScale,
    }

    function Window.Destroy()
        for _, Connection in ipairs(Connections) do
            pcall(function()
                Connection:Disconnect()
            end)
        end

        if CameraConnection then
            pcall(function()
                CameraConnection:Disconnect()
            end)
        end

        if Gui then
            Gui:Destroy()
        end
    end

    if Cards[1] then
        SelectCard(Cards[1])
    end

    return Window
end

-- ---------------------------------------------------------------- data

PAGE_DATA = {
    {
        Name = "rifles",
        Sections = {
            {
                Title = "rifles",
                Cards = {
                    {
                        Name = "AK-47 | Neon Rider",
                        Wear = "factory new",
                        Accent = Hex("ff4f7b"),
                    },
                    {
                        Name = "M4A1-S | Printstream",
                        Wear = "minimal wear",
                        Accent = Hex("e9e9ea"),
                    },
                    { Name = "AWP | Neo-Noir", Wear = "field-tested", Accent = Hex("4f7dff") },
                    {
                        Name = "SCAR-20 | Bloodsport",
                        Wear = "factory new",
                        Accent = Hex("e33b3b"),
                    },
                },
            },
            {
                Title = "featured",
                Cards = {
                    {
                        Name = "FAMAS | Commando",
                        Wear = "minimal wear",
                        Accent = Hex("6fe3a5"),
                    },
                    {
                        Name = "Galil AR | Chatterbox",
                        Wear = "field-tested",
                        Accent = Hex("ffb03a"),
                    },
                    { Name = "SSG 08 | Dragonfire", Wear = "factory new", Accent = Hex("4fd2ff") },
                    { Name = "G3SG1 | Flux", Wear = "minimal wear", Accent = Hex("b06bff") },
                },
            },
        },
    },
    {
        Name = "pistols",
        Sections = {
            {
                Title = "pistols",
                Cards = {
                    { Name = "Glock-18 | Fade", Wear = "factory new", Accent = Hex("ff8a4f") },
                    { Name = "USP-S | Kill Confirmed", Wear = "minimal wear", Accent = Hex("e6e6e6") },
                    { Name = "P250 | See Ya Later", Wear = "factory new", Accent = Hex("4fe3c1") },
                    {
                        Name = "Five-SeveN | Hyper Beast",
                        Wear = "field-tested",
                        Accent = Hex("ff5ea8"),
                    },
                },
            },
            {
                Title = "heavy",
                Cards = {
                    { Name = "Desert Eagle | Blaze", Wear = "factory new", Accent = Hex("ff9a3d") },
                    { Name = "R8 Revolver | Fade", Wear = "minimal wear", Accent = Hex("ff6f9c") },
                    { Name = "Tec-9 | Fuel Injector", Wear = "factory new", Accent = Hex("ffd24f") },
                    {
                        Name = "Dual Berettas | Melondrama",
                        Wear = "field-tested",
                        Accent = Hex("63e36f"),
                    },
                },
            },
        },
    },
    {
        Name = "melee",
        Sections = {
            {
                Title = "knives",
                Cards = {
                    {
                        Name = "Karambit | Doppler",
                        Wear = "factory new",
                        Accent = Hex("7a5cff"),
                    },
                    {
                        Name = "Butterfly Knife | Marble Fade",
                        Wear = "factory new",
                        Accent = Hex("ff6b6b"),
                    },
                    {
                        Name = "M9 Bayonet | Crimson Web",
                        Wear = "minimal wear",
                        Accent = Hex("c22b3f"),
                    },
                    {
                        Name = "Bayonet | Tiger Tooth",
                        Wear = "factory new",
                        Accent = Hex("ffc94f"),
                    },
                },
            },
            {
                Title = "gloves",
                Cards = {
                    {
                        Name = "Sport Gloves | Pandora's Box",
                        Wear = "field-tested",
                        Accent = Hex("b05cff"),
                    },
                    { Name = "Specialist Gloves | Fade", Wear = "factory new", Accent = Hex("ff7ab8") },
                    {
                        Name = "Driver Gloves | King Snake",
                        Wear = "minimal wear",
                        Accent = Hex("e8e8e8"),
                    },
                    {
                        Name = "Hand Wraps | Cobalt Skulls",
                        Wear = "field-tested",
                        Accent = Hex("4f8dff"),
                    },
                },
            },
        },
    },
}

-- ---------------------------------------------------------------- boot

if type(getgenv) == "function" then
    local Previous = getgenv().UnableSkinsUI

    if type(Previous) == "table" and type(Previous.Destroy) == "function" then
        pcall(Previous.Destroy)
    end
end

local Window = BuildWindow()

if type(getgenv) == "function" then
    getgenv().UnableSkinsUI = Window
end
