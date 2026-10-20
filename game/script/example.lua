--[[
    Unable - example loader + full feature UI

    The deadeb/unable repository is public, so the loader downloads Unable.lua
    from the raw URL directly.

    Usage (executor):
        loadstring(game:HttpGet("https://raw.githubusercontent.com/deadeb/unable/main/example.lua"))()

    Or paste this file into your executor and run it.
]]

local RawUrl = "https://raw.githubusercontent.com/deadeb/unable/main/Unable.lua"
local ApiUrl = "https://api.github.com/repos/deadeb/unable/contents/Unable.lua?ref=main"

local function IsLibrary(Source)
    return type(Source) == "string"
        and #Source >= 64
        and string.find(Source, "local Library", 1, true) ~= nil
end

local function ReadToken()
    local Token = type(getgenv) == "function" and getgenv().UnableToken or nil

    if type(Token) ~= "string" or Token == "" then
        local Ok, Content = pcall(readfile, "UnableToken.txt")

        if Ok and type(Content) == "string" then
            Token = Content
        end
    end

    if type(Token) ~= "string" then
        return ""
    end

    Token = string.gsub(Token, "%s+", "")
    Token = string.gsub(Token, "[\"']", "")

    return Token
end

local function FetchApi(Token)
    local Requester = (syn and syn.request)
        or (http and http.request)
        or http_request
        or request

    if not Requester then
        return nil
    end

    local Headers = {
        ["Accept"] = "application/vnd.github.raw",
        ["User-Agent"] = "Unable-Loader",
        ["X-GitHub-Api-Version"] = "2022-11-28"
    }

    if Token ~= "" then
        Headers["Authorization"] = "Bearer " .. Token
    end

    local Ok, Response = pcall(Requester, {
        Url = ApiUrl,
        Method = "GET",
        Headers = Headers
    })

    if not Ok or type(Response) ~= "table" then
        return nil
    end

    local Body = Response.Body or Response.body

    if IsLibrary(Body) then
        return Body
    end

    return nil
end

local Source = nil
local LoadedVia = "raw"

local Ok, Body = pcall(function()
    return game:HttpGet(RawUrl)
end)

if Ok and IsLibrary(Body) then
    Source = Body
else
    Source = FetchApi(ReadToken())
    LoadedVia = "api (fallback)"
end

if not IsLibrary(Source) then
    error(
        "[Unable] Could not download the library from:\n"
        .. RawUrl
        .. "\nCheck the URL in a browser and your executor's HTTP access.",
        0
    )
end

print("[Unable] Downloaded Unable.lua via " .. LoadedVia .. " (" .. #Source .. " bytes).")

local Chunk, CompileError = loadstring(Source)

if not Chunk then
    error("[Unable] Failed to compile the library: " .. tostring(CompileError), 0)
end

local Library = Chunk()

-- Shared state for all feature toggles and values.
local State = {}

local function Notify(Name, Description)
    Library:Notification({
        Name = Name or "Unable",
        Description = Description or "",
        Icon = "check",
        Duration = 3
    })
end

-- Window ---------------------------------------------------------------------

local Window = Library:Window({
    Name = "UNABLE",
    Icon = "layers"
})

-- Tabs -----------------------------------------------------------------------

local CombatTab = Window:Tab({ Name = "Combat", Icon = "swords" })
local EspTab = Window:Tab({ Name = "ESP", Icon = "radar" })
local MovementTab = Window:Tab({ Name = "Movement", Icon = "footprints" })
local WorldTab = Window:Tab({ Name = "World", Icon = "globe" })
local SkinsTab = Window:Tab({ Name = "Skins", Icon = "shirt" })
local ExploitsTab = Window:Tab({ Name = "Exploits", Icon = "wrench" })
local MiscTab = Window:Tab({ Name = "Misc", Icon = "settings" })
local ConfigTab = Window:Tab({ Name = "Configs", Icon = "folder" })

-- Sub tabs -------------------------------------------------------------------

local Rage = CombatTab:SubTab({ Name = "Rage", Icon = "flame" })
local Legit = CombatTab:SubTab({ Name = "Legit", Icon = "shield-check" })

local EspMain = EspTab:SubTab({ Name = "Main", Icon = "layout-dashboard" })
local Chams = EspTab:SubTab({ Name = "Chams", Icon = "palette" })

local Movement = MovementTab:SubTab({ Name = "Movement", Icon = "footprints", Hidden = true })

local World = WorldTab:SubTab({ Name = "World", Icon = "map" })
local PostProcessing = WorldTab:SubTab({ Name = "Post processing", Icon = "sliders-horizontal" })

local Skins = SkinsTab:SubTab({ Name = "Skins", Icon = "shirt", Hidden = true })

local Network = ExploitsTab:SubTab({ Name = "Network", Icon = "globe" })
local Economy = ExploitsTab:SubTab({ Name = "Economy", Icon = "save" })
local Inventory = ExploitsTab:SubTab({ Name = "Inventory", Icon = "folder" })
local AntiCheat = ExploitsTab:SubTab({ Name = "Anti-cheat", Icon = "shield-check" })
local ExploitUI = ExploitsTab:SubTab({ Name = "UI", Icon = "layout-dashboard" })

local Misc = MiscTab:SubTab({ Name = "Misc", Icon = "wrench", Hidden = true })

local Configs = ConfigTab:SubTab({ Name = "Configs", Icon = "save" })

-- Combat / Rage --------------------------------------------------------------

local RageAimbot = Rage:Section({ Name = "Silent aim", Side = "Left" })
local RageTrigger = Rage:Section({ Name = "Triggerbot", Side = "Right" })
local RageRecoil = Rage:Section({ Name = "Recoil control", Side = "Left" })
local RagePenetration = Rage:Section({ Name = "Penetration", Side = "Right" })
local RageLagComp = Rage:Section({ Name = "Lag compensation", Side = "Left" })
local RageMasking = Rage:Section({ Name = "Shot masking", Side = "Right" })

local SilentAimToggle = RageAimbot:Toggle({
    Name = "Silent aim",
    Default = false,
    Flag = "RageSilentAim",
    Callback = function(Value)
        State.SilentAim = Value
    end
})
SilentAimToggle:Keybind({ Default = Enum.KeyCode.Q, Mode = "Toggle", Flag = "KeybindSilentAim" })

RageAimbot:Slider({
    Name = "FOV",
    Min = 0,
    Max = 360,
    Default = 30,
    Decimals = 0,
    Suffix = "deg",
    Flag = "RageSilentAimFov",
    Callback = function(Value) State.SilentAimFov = Value end
})

RageAimbot:Slider({
    Name = "Hitchance",
    Min = 0,
    Max = 100,
    Default = 80,
    Decimals = 0,
    Suffix = "%",
    Flag = "RageSilentAimHitchance",
    Callback = function(Value) State.SilentAimHitchance = Value end
})

RageAimbot:Dropdown({
    Name = "Hitbox",
    Items = { "Head", "Chest", "Stomach", "Nearest" },
    Default = "Head",
    Flag = "RageSilentAimHitbox",
    Callback = function(Value) State.SilentAimHitbox = Value end
})

local TriggerbotToggle = RageTrigger:Toggle({
    Name = "Triggerbot",
    Default = false,
    Flag = "RageTriggerbot",
    Callback = function(Value) State.Triggerbot = Value end
})
TriggerbotToggle:Keybind({ Default = Enum.KeyCode.E, Mode = "Hold", Flag = "KeybindTriggerbot" })

RageTrigger:Slider({
    Name = "Delay",
    Min = 0,
    Max = 250,
    Default = 0,
    Decimals = 0,
    Suffix = "ms",
    Flag = "RageTriggerbotDelay",
    Callback = function(Value) State.TriggerbotDelay = Value end
})

RageTrigger:Slider({
    Name = "Hitchance",
    Min = 0,
    Max = 100,
    Default = 90,
    Decimals = 0,
    Suffix = "%",
    Flag = "RageTriggerbotHitchance",
    Callback = function(Value) State.TriggerbotHitchance = Value end
})

local RecoilToggle = RageRecoil:Toggle({
    Name = "Recoil compensation",
    Default = false,
    Flag = "RageRecoil",
    Callback = function(Value) State.RecoilComp = Value end
})

RageRecoil:Slider({
    Name = "Pitch compensation",
    Min = 0,
    Max = 100,
    Default = 100,
    Decimals = 0,
    Suffix = "%",
    Flag = "RageRecoilPitch",
    Callback = function(Value) State.RecoilPitch = Value end
})

RageRecoil:Slider({
    Name = "Yaw compensation",
    Min = 0,
    Max = 100,
    Default = 100,
    Decimals = 0,
    Suffix = "%",
    Flag = "RageRecoilYaw",
    Callback = function(Value) State.RecoilYaw = Value end
})

local WallbangToggle = RagePenetration:Toggle({
    Name = "Wallbang",
    Default = false,
    Flag = "RageWallbang",
    Callback = function(Value) State.Wallbang = Value end
})

RagePenetration:Slider({
    Name = "Minimum damage",
    Min = 1,
    Max = 100,
    Default = 10,
    Decimals = 0,
    Suffix = "hp",
    Flag = "RageWallbangMinDamage",
    Callback = function(Value) State.WallbangMinDamage = Value end
})

RagePenetration:Slider({
    Name = "Max wall thickness",
    Min = 0,
    Max = 500,
    Default = 128,
    Decimals = 0,
    Suffix = "studs",
    Flag = "RageWallbangThickness",
    Callback = function(Value) State.WallbangThickness = Value end
})

local LagCompToggle = RageLagComp:Toggle({
    Name = "Lag compensation abuse",
    Default = false,
    Flag = "RageLagComp",
    Callback = function(Value) State.LagCompAbuse = Value end
})

RageLagComp:Slider({
    Name = "Max rewind",
    Min = 0,
    Max = 1000,
    Default = 200,
    Decimals = 0,
    Suffix = "ms",
    Flag = "RageLagCompRewind",
    Callback = function(Value) State.LagCompRewind = Value end
})

RageLagComp:Slider({
    Name = "Render time offset",
    Min = -500,
    Max = 500,
    Default = 0,
    Decimals = 0,
    Suffix = "ms",
    Flag = "RageLagCompRenderOffset",
    Callback = function(Value) State.LagCompRenderOffset = Value end
})

local ShotMaskToggle = RageMasking:Toggle({
    Name = "Shot masking",
    Default = false,
    Flag = "RageShotMasking",
    Callback = function(Value) State.ShotMasking = Value end
})

RageMasking:Slider({
    Name = "Mask delay",
    Min = 0,
    Max = 500,
    Default = 0,
    Decimals = 0,
    Suffix = "ms",
    Flag = "RageShotMaskDelay",
    Callback = function(Value) State.ShotMaskDelay = Value end
})

-- Combat / Legit -------------------------------------------------------------

local LegitAimbot = Legit:Section({ Name = "Aimbot", Side = "Left" })
local LegitTrigger = Legit:Section({ Name = "Triggerbot", Side = "Right" })
local LegitRecoil = Legit:Section({ Name = "Recoil control", Side = "Left" })

local LegitAimbotToggle = LegitAimbot:Toggle({
    Name = "Legit aimbot",
    Default = false,
    Flag = "LegitAimbot",
    Callback = function(Value) State.LegitAimbot = Value end
})
LegitAimbotToggle:Keybind({ Default = Enum.KeyCode.F, Mode = "Hold", Flag = "KeybindLegitAimbot" })

LegitAimbot:Slider({
    Name = "FOV",
    Min = 0,
    Max = 180,
    Default = 8,
    Decimals = 1,
    Suffix = "deg",
    Flag = "LegitAimbotFov",
    Callback = function(Value) State.LegitAimbotFov = Value end
})

LegitAimbot:Slider({
    Name = "Smoothing",
    Min = 1,
    Max = 30,
    Default = 8,
    Decimals = 1,
    Flag = "LegitAimbotSmooth",
    Callback = function(Value) State.LegitAimbotSmooth = Value end
})

LegitAimbot:Dropdown({
    Name = "Hitbox",
    Items = { "Head", "Neck", "Chest", "Stomach" },
    Default = "Head",
    Flag = "LegitAimbotHitbox",
    Callback = function(Value) State.LegitAimbotHitbox = Value end
})

local LegitTriggerToggle = LegitTrigger:Toggle({
    Name = "Legit triggerbot",
    Default = false,
    Flag = "LegitTriggerbot",
    Callback = function(Value) State.LegitTriggerbot = Value end
})
LegitTriggerToggle:Keybind({ Default = Enum.KeyCode.F, Mode = "Hold", Flag = "KeybindLegitTriggerbot" })

LegitTrigger:Slider({
    Name = "Reaction time",
    Min = 0,
    Max = 250,
    Default = 60,
    Decimals = 0,
    Suffix = "ms",
    Flag = "LegitTriggerbotReaction",
    Callback = function(Value) State.LegitTriggerbotReaction = Value end
})

local LegitRecoilToggle = LegitRecoil:Toggle({
    Name = "Recoil control",
    Default = false,
    Flag = "LegitRecoil",
    Callback = function(Value) State.LegitRecoil = Value end
})

LegitRecoil:Slider({
    Name = "Strength",
    Min = 0,
    Max = 100,
    Default = 100,
    Decimals = 0,
    Suffix = "%",
    Flag = "LegitRecoilStrength",
    Callback = function(Value) State.LegitRecoilStrength = Value end
})

-- ESP ------------------------------------------------------------------------

local EspBoxes = EspMain:Section({ Name = "Boxes", Side = "Left" })
local EspInfo = EspMain:Section({ Name = "Information", Side = "Right" })
local EspChams = Chams:Section({ Name = "Chams", Side = "Left" })

EspBoxes:Toggle({
    Name = "Boxes",
    Default = false,
    Flag = "EspBoxes",
    Callback = function(Value) State.EspBoxes = Value end
})

EspBoxes:Toggle({
    Name = "Filled boxes",
    Default = false,
    Flag = "EspFilledBoxes",
    Callback = function(Value) State.EspFilledBoxes = Value end
})

EspBoxes:Slider({
    Name = "Max distance",
    Min = 0,
    Max = 5000,
    Default = 1500,
    Decimals = 0,
    Suffix = "studs",
    Flag = "EspMaxDistance",
    Callback = function(Value) State.EspMaxDistance = Value end
})

EspInfo:Toggle({
    Name = "Names",
    Default = false,
    Flag = "EspNames",
    Callback = function(Value) State.EspNames = Value end
})

EspInfo:Toggle({
    Name = "Health",
    Default = false,
    Flag = "EspHealth",
    Callback = function(Value) State.EspHealth = Value end
})

EspInfo:Toggle({
    Name = "Weapon",
    Default = false,
    Flag = "EspWeapon",
    Callback = function(Value) State.EspWeapon = Value end
})

EspInfo:Toggle({
    Name = "Distance",
    Default = false,
    Flag = "EspDistance",
    Callback = function(Value) State.EspDistance = Value end
})

EspInfo:Toggle({
    Name = "Skeleton",
    Default = false,
    Flag = "EspSkeleton",
    Callback = function(Value) State.EspSkeleton = Value end
})

EspChams:Toggle({
    Name = "Chams",
    Default = false,
    Flag = "EspChams",
    Callback = function(Value) State.EspChams = Value end
})

EspChams:Dropdown({
    Name = "Material",
    Items = { "ForceField", "Neon", "Glass", "Metal" },
    Default = "ForceField",
    Flag = "EspChamsMaterial",
    Callback = function(Value) State.EspChamsMaterial = Value end
})

EspChams:Slider({
    Name = "Transparency",
    Min = 0,
    Max = 1,
    Default = 0.35,
    Decimals = 2,
    Flag = "EspChamsTransparency",
    Callback = function(Value) State.EspChamsTransparency = Value end
})

-- Movement -------------------------------------------------------------------

local MovementMain = Movement:Section({ Name = "Movement", Side = "Left" })
local MovementVisual = Movement:Section({ Name = "Visual", Side = "Right" })

local AutoBhopToggle = MovementMain:Toggle({
    Name = "Auto bhop",
    Default = false,
    Flag = "MovementAutoBhop",
    Callback = function(Value) State.AutoBhop = Value end
})
AutoBhopToggle:Keybind({ Default = Enum.KeyCode.Space, Mode = "Toggle", Flag = "KeybindAutoBhop" })

MovementMain:Toggle({
    Name = "Auto strafe",
    Default = false,
    Flag = "MovementAutoStrafe",
    Callback = function(Value) State.AutoStrafe = Value end
})

MovementMain:Dropdown({
    Name = "Strafe mode",
    Items = { "Legit", "Rage" },
    Default = "Legit",
    Flag = "MovementStrafeMode",
    Callback = function(Value) State.StrafeMode = Value end
})

MovementMain:Toggle({
    Name = "Counter strafe",
    Default = false,
    Flag = "MovementCounterStrafe",
    Callback = function(Value) State.CounterStrafe = Value end
})

MovementMain:Slider({
    Name = "Counter strafe amount",
    Min = 0,
    Max = 100,
    Default = 100,
    Decimals = 0,
    Suffix = "%",
    Flag = "MovementCounterStrafeAmount",
    Callback = function(Value) State.CounterStrafeAmount = Value end
})

MovementMain:Toggle({
    Name = "Crouch jump assist",
    Default = false,
    Flag = "MovementCrouchJump",
    Callback = function(Value) State.CrouchJumpAssist = Value end
})

MovementVisual:Toggle({
    Name = "No-clip visual",
    Default = false,
    Flag = "MovementNoClipVisual",
    Callback = function(Value) State.NoClipVisual = Value end
})

MovementVisual:Toggle({
    Name = "Speed edit visual",
    Default = false,
    Flag = "MovementSpeedEditVisual",
    Callback = function(Value) State.SpeedEditVisual = Value end
})

MovementVisual:Slider({
    Name = "Visual speed",
    Min = 16,
    Max = 100,
    Default = 20,
    Decimals = 1,
    Suffix = "stud/s",
    Flag = "MovementVisualSpeed",
    Callback = function(Value) State.VisualSpeed = Value end
})

-- World ----------------------------------------------------------------------

local WorldMain = World:Section({ Name = "World", Side = "Left" })
local WorldVisual = World:Section({ Name = "Visual", Side = "Right" })

WorldMain:Toggle({
    Name = "Fullbright",
    Default = false,
    Flag = "WorldFullbright",
    Callback = function(Value) State.Fullbright = Value end
})

WorldMain:Toggle({
    Name = "Remove fog",
    Default = false,
    Flag = "WorldRemoveFog",
    Callback = function(Value) State.RemoveFog = Value end
})

WorldMain:Toggle({
    Name = "No flash",
    Default = false,
    Flag = "WorldNoFlash",
    Callback = function(Value) State.NoFlash = Value end
})

WorldVisual:Slider({
    Name = "Field of view",
    Min = 60,
    Max = 120,
    Default = 90,
    Decimals = 0,
    Suffix = "deg",
    Flag = "WorldFov",
    Callback = function(Value) State.WorldFov = Value end
})

WorldVisual:Slider({
    Name = "Time of day",
    Min = 0,
    Max = 24,
    Default = 12,
    Decimals = 1,
    Suffix = "h",
    Flag = "WorldTimeOfDay",
    Callback = function(Value) State.TimeOfDay = Value end
})

-- Post processing ------------------------------------------------------------

local PostFx = PostProcessing:Section({ Name = "Post processing", Side = "Left" })

PostFx:Slider({
    Name = "Saturation",
    Min = 0,
    Max = 2,
    Default = 1,
    Decimals = 2,
    Flag = "PostSaturation",
    Callback = function(Value) State.Saturation = Value end
})

PostFx:Slider({
    Name = "Contrast",
    Min = 0,
    Max = 2,
    Default = 1,
    Decimals = 2,
    Flag = "PostContrast",
    Callback = function(Value) State.Contrast = Value end
})

PostFx:Slider({
    Name = "Bloom",
    Min = 0,
    Max = 1,
    Default = 0.2,
    Decimals = 2,
    Flag = "PostBloom",
    Callback = function(Value) State.Bloom = Value end
})

-- Skins ----------------------------------------------------------------------

local function BuildSkin(World, BladeColor, BladeMaterial, BladeAlpha)
    local Model = Instance.new("Model")
    Model.Name = "Skin"

    local Blade = Instance.new("Part")
    Blade.Name = "Blade"
    Blade.Anchored = true
    Blade.CanCollide = false
    Blade.Material = BladeMaterial or Enum.Material.Metal
    Blade.Color = BladeColor
    Blade.Transparency = BladeAlpha or 0
    Blade.Size = Vector3.new(0.22, 2.1, 0.5)
    Blade.CFrame = CFrame.new(0, 1.1, 0)
    Blade.Parent = Model

    local Guard = Instance.new("Part")
    Guard.Name = "Guard"
    Guard.Anchored = true
    Guard.CanCollide = false
    Guard.Material = Enum.Material.Metal
    Guard.Color = Color3.fromRGB(105, 105, 110)
    Guard.Size = Vector3.new(0.6, 0.14, 0.72)
    Guard.CFrame = CFrame.new(0, -0.02, 0)
    Guard.Parent = Model

    local Handle = Instance.new("Part")
    Handle.Name = "Handle"
    Handle.Anchored = true
    Handle.CanCollide = false
    Handle.Material = Enum.Material.SmoothPlastic
    Handle.Color = Color3.fromRGB(28, 28, 32)
    Handle.Size = Vector3.new(0.34, 1.05, 0.55)
    Handle.CFrame = CFrame.new(0, -0.6, 0)
    Handle.Parent = Model

    Model.Parent = World
    Model:PivotTo(CFrame.Angles(0, math.rad(-35), math.rad(16)))

    return Model
end

local SkinSection = Skins:Section({ Name = "Weapon skins", Side = "Left" })

SkinSection:ModelGrid({
    Flag = "WeaponSkin",
    Default = "Default",
    Columns = 3,
    TileHeight = 96,
    Items = {
        { Name = "Default", Build = function(World)
            BuildSkin(World, Color3.fromRGB(205, 205, 210), Enum.Material.Metal)
        end },
        { Name = "Crimson", Build = function(World)
            BuildSkin(World, Color3.fromRGB(205, 45, 55), Enum.Material.Neon)
        end },
        { Name = "Gold", Build = function(World)
            BuildSkin(World, Color3.fromRGB(214, 178, 74), Enum.Material.Metal)
        end },
        { Name = "Emerald", Build = function(World)
            BuildSkin(World, Color3.fromRGB(52, 206, 122), Enum.Material.Neon)
        end },
        { Name = "Ice", Build = function(World)
            BuildSkin(World, Color3.fromRGB(165, 222, 255), Enum.Material.Ice, 0.25)
        end },
        { Name = "Void", Build = function(World)
            BuildSkin(World, Color3.fromRGB(118, 72, 255), Enum.Material.ForceField)
        end }
    },
    Callback = function(Name)
        State.WeaponSkin = Name
        print("[Unable] Weapon skin:", Name)
    end
})

local SkinApply = Skins:Section({ Name = "Apply", Side = "Right" })

SkinApply:Textbox({
    Name = "Skin name",
    Default = "Default",
    Placeholder = "Skin name",
    Flag = "SkinNameInput",
    Callback = function(Value) State.SkinNameInput = Value end
})

SkinApply:Textbox({
    Name = "Skin ID",
    Default = "",
    Placeholder = "Skin ID",
    Flag = "SkinIdInput",
    Callback = function(Value) State.SkinIdInput = Value end
})

SkinApply:Button({
    Name = "Apply local skin",
    Callback = function()
        Notify("Skins", "Local skin apply requested: " .. tostring(State.SkinNameInput))
    end
})

-- Exploits / Network ---------------------------------------------------------

local NetworkCommands = Network:Section({ Name = "Commands", Side = "Left" })
local NetworkTiming = Network:Section({ Name = "Timing", Side = "Right" })
local NetworkPackets = Network:Section({ Name = "Packets", Side = "Left" })

NetworkCommands:Toggle({
    Name = "Command injection",
    Default = false,
    Flag = "ExploitCommandInjection",
    Callback = function(Value) State.CommandInjection = Value end
})

NetworkCommands:Toggle({
    Name = "Silent aim angles",
    Default = false,
    Flag = "ExploitSilentAimAngles",
    Callback = function(Value) State.SilentAimAngles = Value end
})

NetworkCommands:Slider({
    Name = "Command rate",
    Min = 1,
    Max = 20,
    Default = 7,
    Decimals = 0,
    Suffix = "cmd/frame",
    Flag = "ExploitCommandRate",
    Callback = function(Value) State.CommandRate = Value end
})

NetworkTiming:Toggle({
    Name = "Tick manipulation",
    Default = false,
    Flag = "ExploitTickManipulation",
    Callback = function(Value) State.TickManipulation = Value end
})

NetworkTiming:Slider({
    Name = "Tick delta",
    Min = 0,
    Max = 0.2,
    Default = 0,
    Decimals = 3,
    Suffix = "s",
    Flag = "ExploitTickDelta",
    Callback = function(Value) State.TickDelta = Value end
})

NetworkTiming:Slider({
    Name = "Render time offset",
    Min = -500,
    Max = 500,
    Default = 0,
    Decimals = 0,
    Suffix = "ms",
    Flag = "ExploitRenderTimeOffset",
    Callback = function(Value) State.RenderTimeOffset = Value end
})

NetworkPackets:Toggle({
    Name = "Idle command abuse",
    Default = false,
    Flag = "ExploitIdleCommandAbuse",
    Callback = function(Value) State.IdleCommandAbuse = Value end
})

NetworkPackets:Toggle({
    Name = "Choke / lag switch",
    Default = false,
    Flag = "ExploitChoke",
    Callback = function(Value) State.Choke = Value end
})

NetworkPackets:Slider({
    Name = "Choke amount",
    Min = 0,
    Max = 1000,
    Default = 0,
    Decimals = 0,
    Suffix = "ms",
    Flag = "ExploitChokeAmount",
    Callback = function(Value) State.ChokeAmount = Value end
})

NetworkPackets:Toggle({
    Name = "Packet crafting",
    Default = false,
    Flag = "ExploitPacketCrafting",
    Callback = function(Value) State.PacketCrafting = Value end
})

-- Exploits / Economy ---------------------------------------------------------

local EconomyActions = Economy:Section({ Name = "Actions", Side = "Left" })
local EconomySpoof = Economy:Section({ Name = "Spoofing", Side = "Right" })
local EconomyAutomation = Economy:Section({ Name = "Automation", Side = "Left" })

EconomyActions:Textbox({
    Name = "Promocode",
    Default = "",
    Placeholder = "CODE",
    Finished = true,
    Flag = "EconomyPromocode",
    Callback = function(Value) State.Promocode = Value end
})

EconomyActions:Button({
    Name = "Redeem promocode",
    Callback = function()
        Notify("Economy", "Promocode redeem requested: " .. tostring(State.Promocode))
    end
})

EconomyActions:Button({
    Name = "Open container",
    Callback = function()
        Notify("Economy", "Container open requested")
    end
})

EconomyActions:Button({
    Name = "Reveal market item",
    Callback = function()
        Notify("Economy", "Market reveal requested")
    end
})

EconomyActions:Button({
    Name = "Trade up",
    Callback = function()
        Notify("Economy", "Trade up requested")
    end
})

EconomyActions:Button({
    Name = "Upgrade item",
    Callback = function()
        Notify("Economy", "Upgrade requested")
    end
})

EconomySpoof:Button({
    Name = "Buy weapon",
    Callback = function()
        Notify("Economy", "Buy weapon requested")
    end
})

EconomySpoof:Button({
    Name = "Refund weapon",
    Callback = function()
        Notify("Economy", "Refund weapon requested")
    end
})

EconomySpoof:Button({
    Name = "Pick up weapon",
    Callback = function()
        Notify("Economy", "Pickup weapon requested")
    end
})

EconomySpoof:Button({
    Name = "Buy store item",
    Callback = function()
        Notify("Economy", "Store item buy requested")
    end
})

EconomyAutomation:Toggle({
    Name = "Auto claim rewards",
    Default = false,
    Flag = "EconomyAutoClaim",
    Callback = function(Value) State.AutoClaimRewards = Value end
})

EconomyAutomation:Toggle({
    Name = "Auto claim battlepass",
    Default = false,
    Flag = "EconomyAutoBattlepass",
    Callback = function(Value) State.AutoBattlepass = Value end
})

EconomyAutomation:Toggle({
    Name = "Auto claim achievements",
    Default = false,
    Flag = "EconomyAutoAchievements",
    Callback = function(Value) State.AutoAchievements = Value end
})

EconomyAutomation:Toggle({
    Name = "Auto claim care packages",
    Default = false,
    Flag = "EconomyAutoCarePackages",
    Callback = function(Value) State.AutoCarePackages = Value end
})

-- Exploits / Inventory -------------------------------------------------------

local InventorySpoof = Inventory:Section({ Name = "Spoofing", Side = "Left" })
local InventoryMutation = Inventory:Section({ Name = "Mutation", Side = "Right" })
local InventoryLoadout = Inventory:Section({ Name = "Loadout", Side = "Left" })

InventorySpoof:Toggle({
    Name = "Skin spoof",
    Default = false,
    Flag = "InventorySkinSpoof",
    Callback = function(Value) State.SkinSpoof = Value end
})

InventorySpoof:Toggle({
    Name = "Equip spoof",
    Default = false,
    Flag = "InventoryEquipSpoof",
    Callback = function(Value) State.EquipSpoof = Value end
})

InventorySpoof:Toggle({
    Name = "Inventory mutation",
    Default = false,
    Flag = "InventoryMutation",
    Callback = function(Value) State.InventoryMutation = Value end
})

InventoryMutation:Textbox({
    Name = "Weapon name",
    Default = "",
    Placeholder = "Weapon",
    Flag = "InventoryWeaponName",
    Callback = function(Value) State.InventoryWeaponName = Value end
})

InventoryMutation:Textbox({
    Name = "Skin name",
    Default = "",
    Placeholder = "Skin",
    Flag = "InventorySkinName",
    Callback = function(Value) State.InventorySkinName = Value end
})

InventoryMutation:Textbox({
    Name = "Skin ID",
    Default = "",
    Placeholder = "Skin ID",
    Flag = "InventorySkinId",
    Callback = function(Value) State.InventorySkinId = Value end
})

InventoryLoadout:Button({
    Name = "Spoof loadout skin",
    Callback = function()
        Notify("Inventory", "Loadout skin spoof requested")
    end
})

InventoryLoadout:Button({
    Name = "Spoof equipped item",
    Callback = function()
        Notify("Inventory", "Equipped item spoof requested")
    end
})

InventoryLoadout:Button({
    Name = "Reset local inventory",
    Callback = function()
        Notify("Inventory", "Local inventory reset requested")
    end
})

-- Exploits / Anti-cheat ------------------------------------------------------

local AntiCheatInfo = AntiCheat:Section({ Name = "Tattletale", Side = "Left" })
local AntiCheatEnvironment = AntiCheat:Section({ Name = "Environment", Side = "Right" })
local AntiCheatReport = AntiCheat:Section({ Name = "Reports", Side = "Left" })

AntiCheatInfo:Toggle({
    Name = "Hide executor globals",
    Default = false,
    Flag = "AntiCheatHideGlobals",
    Callback = function(Value) State.HideExecutorGlobals = Value end
})

AntiCheatInfo:Toggle({
    Name = "Avoid guarded hooks",
    Default = true,
    Flag = "AntiCheatAvoidHooks",
    Callback = function(Value) State.AvoidGuardedHooks = Value end
})

AntiCheatInfo:Toggle({
    Name = "Input-only automation",
    Default = true,
    Flag = "AntiCheatInputOnly",
    Callback = function(Value) State.InputOnlyAutomation = Value end
})

AntiCheatEnvironment:Toggle({
    Name = "Clean _G",
    Default = false,
    Flag = "AntiCheatCleanG",
    Callback = function(Value) State.CleanG = Value end
})

AntiCheatEnvironment:Toggle({
    Name = "Clean getfenv(0)",
    Default = false,
    Flag = "AntiCheatCleanFenv",
    Callback = function(Value) State.CleanFenv = Value end
})

AntiCheatEnvironment:Toggle({
    Name = "Suppress report loop",
    Default = false,
    Flag = "AntiCheatSuppressReport",
    Callback = function(Value) State.SuppressReportLoop = Value end
})

AntiCheatReport:Slider({
    Name = "Report interval",
    Min = 1,
    Max = 10,
    Default = 4,
    Decimals = 0,
    Suffix = "s",
    Flag = "AntiCheatReportInterval",
    Callback = function(Value) State.ReportInterval = Value end
})

AntiCheatReport:Toggle({
    Name = "Forge seal",
    Default = false,
    Flag = "AntiCheatForgeSeal",
    Callback = function(Value) State.ForgeSeal = Value end
})

AntiCheatReport:Button({
    Name = "Copy Tattletale notes",
    Callback = function()
        Notify("Anti-cheat", "Tattletale uses report-based telemetry and guarded functions")
    end
})

-- Exploits / UI --------------------------------------------------------------

local DebugVisuals = ExploitUI:Section({ Name = "Debug visuals", Side = "Left" })
local ConsoleAccess = ExploitUI:Section({ Name = "Console", Side = "Right" })
local SocialAbuse = ExploitUI:Section({ Name = "Social", Side = "Left" })

DebugVisuals:Toggle({
    Name = "Hitbox visualizer",
    Default = false,
    Flag = "UiHitboxVisualizer",
    Callback = function(Value) State.HitboxVisualizer = Value end
})

DebugVisuals:Toggle({
    Name = "Server shot visualizer",
    Default = false,
    Flag = "UiServerShotVisualizer",
    Callback = function(Value) State.ServerShotVisualizer = Value end
})

DebugVisuals:Toggle({
    Name = "Zone visualizer",
    Default = false,
    Flag = "UiZoneVisualizer",
    Callback = function(Value) State.ZoneVisualizer = Value end
})

ConsoleAccess:Toggle({
    Name = "Console spoof",
    Default = false,
    Flag = "UiConsoleSpoof",
    Callback = function(Value) State.ConsoleSpoof = Value end
})

ConsoleAccess:Toggle({
    Name = "Stats debug",
    Default = false,
    Flag = "UiStatsDebug",
    Callback = function(Value) State.StatsDebug = Value end
})

ConsoleAccess:Button({
    Name = "Request console access",
    Callback = function()
        Notify("UI", "Console access request sent")
    end
})

SocialAbuse:Toggle({
    Name = "Chat spam",
    Default = false,
    Flag = "UiChatSpam",
    Callback = function(Value) State.ChatSpam = Value end
})

SocialAbuse:Toggle({
    Name = "Votekick spam",
    Default = false,
    Flag = "UiVotekickSpam",
    Callback = function(Value) State.VotekickSpam = Value end
})

SocialAbuse:Toggle({
    Name = "Map vote spam",
    Default = false,
    Flag = "UiMapVoteSpam",
    Callback = function(Value) State.MapVoteSpam = Value end
})

SocialAbuse:Textbox({
    Name = "Chat message",
    Default = "",
    Placeholder = "Message",
    Flag = "UiChatMessage",
    Callback = function(Value) State.ChatMessage = Value end
})

-- Misc -----------------------------------------------------------------------

local MiscMain = Misc:Section({ Name = "Misc", Side = "Left" })

MiscMain:Toggle({
    Name = "Unload on death",
    Default = false,
    Flag = "MiscUnloadOnDeath",
    Callback = function(Value) State.UnloadOnDeath = Value end
})

MiscMain:Button({
    Name = "Copy state",
    Callback = function()
        print("[Unable] State:", State)
    end
})

-- Configs --------------------------------------------------------------------

Configs:ThemeConfig({ })

-- Ready ----------------------------------------------------------------------

Library:Notification({
    Name = "Unable loaded",
    Description = "Full feature UI loaded from the GitHub repository.",
    Icon = "check",
    Duration = 5
})
