--[[
    Unable - example loader

    The deadeb/unable repository is public, so the loader downloads Unable.lua
    from the raw URL directly.

    Usage (executor):
        loadstring(game:HttpGet("https://raw.githubusercontent.com/deadeb/unable/main/example.lua"))()

    Or paste this file into your executor and run it.

    If the repository is ever made private again, set a token and the loader
    will fall back to the authenticated GitHub Contents API:
        getgenv().UnableToken = "github_pat_..."
    or put the token in UnableToken.txt in the executor workspace.

    Never commit a real token.
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

-- Window ---------------------------------------------------------------------

local Window = Library:Window({
    Name = "UNABLE",
    Icon = "layers"
})

-- Tabs (top level of the hover sidebar) --------------------------------------

local CombatTab = Window:Tab({ Name = "Combat", Icon = "swords" })
local EspTab = Window:Tab({ Name = "ESP", Icon = "radar" })
local MovementTab = Window:Tab({ Name = "Movement", Icon = "footprints" })
local WorldTab = Window:Tab({ Name = "World", Icon = "globe" })
local MiscTab = Window:Tab({ Name = "Misc", Icon = "wrench" })
local ConfigTab = Window:Tab({ Name = "Configs", Icon = "folder" })

-- Sub tabs (listed under the active tab in the sidebar) ----------------------
-- Tabs with no sub tabs still need a page for their sections, so they get a
-- hidden one and the sidebar shows nothing extra.

local Rage = CombatTab:SubTab({ Name = "Rage", Icon = "flame" })
local Legit = CombatTab:SubTab({ Name = "Legit", Icon = "shield-check" })

local EspMain = EspTab:SubTab({ Name = "Main", Icon = "layout-dashboard" })
local Chams = EspTab:SubTab({ Name = "Chams", Icon = "shirt" })

local Movement = MovementTab:SubTab({ Name = "Movement", Icon = "footprints", Hidden = true })

local World = WorldTab:SubTab({ Name = "World", Icon = "map" })
local PostProcessing = WorldTab:SubTab({ Name = "Post processing", Icon = "sliders-horizontal" })

local Misc = MiscTab:SubTab({ Name = "Misc", Icon = "wrench", Hidden = true })

local Configs = ConfigTab:SubTab({ Name = "Configs", Icon = "save" })

-- Small helper so the demo callbacks stay readable ---------------------------

local function Log(Name)
    return function(Value)
        print("[Unable] " .. Name .. ":", Value)
    end
end

-- Combat / Rage ---------------------------------------------------------------

local Aimbot = Rage:Section({ Name = "Aimbot", Side = "Left" })
local Target = Rage:Section({ Name = "Target", Side = "Right" })

Aimbot:Toggle({
    Name = "Enabled",
    Flag = "RageAimbot",
    Callback = Log("Rage aimbot")
})

Aimbot:Slider({
    Name = "FOV",
    Flag = "RageFOV",
    Min = 1,
    Max = 360,
    Default = 120,
    Decimals = 0,
    Callback = Log("Rage FOV")
})

Aimbot:Dropdown({
    Name = "Hitbox",
    Flag = "RageHitbox",
    Options = { "Head", "Torso", "Nearest" },
    Default = "Head",
    Callback = Log("Rage hitbox")
})

Aimbot:Slider({
    Name = "Smoothing",
    Flag = "RageSmoothing",
    Min = 1,
    Max = 20,
    Default = 1,
    Decimals = 0,
    Callback = Log("Rage smoothing")
})

Target:Toggle({
    Name = "Team check",
    Flag = "RageTeamCheck",
    Default = true,
    Callback = Log("Rage team check")
})

Target:Toggle({
    Name = "Wall check",
    Flag = "RageWallCheck",
    Default = true,
    Callback = Log("Rage wall check")
})

Target:Dropdown({
    Name = "Priority",
    Flag = "RagePriority",
    Options = { "Distance", "Health", "FOV" },
    Default = "Distance",
    Callback = Log("Rage priority")
})

Target:Slider({
    Name = "Max distance",
    Flag = "RageDistance",
    Min = 50,
    Max = 2000,
    Default = 1000,
    Decimals = 0,
    Callback = Log("Rage distance")
})

-- Combat / Legit --------------------------------------------------------------

local Trigger = Legit:Section({ Name = "Triggerbot", Side = "Left" })
local Silent = Legit:Section({ Name = "Silent aim", Side = "Right" })

Trigger:Toggle({
    Name = "Enabled",
    Flag = "LegitTrigger",
    Callback = Log("Triggerbot")
})

Trigger:Slider({
    Name = "Delay",
    Flag = "TriggerDelay",
    Min = 0,
    Max = 500,
    Default = 60,
    Decimals = 0,
    Suffix = " ms",
    Callback = Log("Trigger delay")
})

Trigger:Keybind({
    Name = "Trigger key",
    Flag = "TriggerKey",
    Default = Enum.KeyCode.E,
    Callback = Log("Trigger key")
})

Silent:Toggle({
    Name = "Enabled",
    Flag = "LegitSilent",
    Callback = Log("Silent aim")
})

Silent:Dropdown({
    Name = "Mode",
    Flag = "SilentMode",
    Options = { "Always", "On key" },
    Default = "On key",
    Callback = Log("Silent mode")
})

Silent:Slider({
    Name = "Hit chance",
    Flag = "SilentChance",
    Min = 1,
    Max = 100,
    Default = 100,
    Decimals = 0,
    Suffix = "%",
    Callback = Log("Hit chance")
})

Silent:Keybind({
    Name = "Aim key",
    Flag = "SilentKey",
    Default = Enum.KeyCode.Q,
    Callback = Log("Aim key")
})

-- ESP / Main ------------------------------------------------------------------

local Players = EspMain:Section({ Name = "Players", Side = "Left" })
local Colors = EspMain:Section({ Name = "Colors", Side = "Right" })

Players:Toggle({
    Name = "Enabled",
    Flag = "EspEnabled",
    Default = true,
    Callback = Log("ESP")
})

Players:Dropdown({
    Name = "Box",
    Flag = "EspBox",
    Options = { "None", "2D", "3D" },
    Default = "2D",
    Callback = Log("ESP box")
})

Players:Dropdown({
    Name = "Name",
    Flag = "EspName",
    Options = { "None", "Display", "Username" },
    Default = "Display",
    Callback = Log("ESP name")
})

Players:Slider({
    Name = "Distance",
    Flag = "EspDistance",
    Min = 50,
    Max = 2000,
    Default = 1000,
    Decimals = 0,
    Callback = Log("ESP distance")
})

Colors:Toggle({
    Name = "Team check",
    Flag = "EspTeamCheck",
    Default = true,
    Callback = Log("ESP team check")
})

Colors:Toggle({
    Name = "Team color",
    Flag = "EspTeamColor",
    Default = true,
    Callback = Log("ESP team color")
})

Colors:Colorpicker({
    Name = "Enemy",
    Flag = "EspEnemyColor",
    Default = Color3.fromRGB(255, 70, 70),
    Callback = Log("Enemy color")
})

Colors:Colorpicker({
    Name = "Friendly",
    Flag = "EspFriendlyColor",
    Default = Color3.fromRGB(80, 160, 255),
    Callback = Log("Friendly color")
})

-- ESP / Chams -----------------------------------------------------------------

local ChamsSection = Chams:Section({ Name = "Chams", Side = "Left" })
local Outline = Chams:Section({ Name = "Outline", Side = "Right" })

ChamsSection:Toggle({
    Name = "Enabled",
    Flag = "ChamsEnabled",
    Callback = Log("Chams")
})

ChamsSection:Dropdown({
    Name = "Material",
    Flag = "ChamsMaterial",
    Options = { "ForceField", "Plastic", "Neon", "Glass" },
    Default = "ForceField",
    Callback = Log("Chams material")
})

ChamsSection:Colorpicker({
    Name = "Visible",
    Flag = "ChamsVisible",
    Default = Color3.fromRGB(90, 255, 140),
    Callback = Log("Chams visible")
})

ChamsSection:Colorpicker({
    Name = "Hidden",
    Flag = "ChamsHidden",
    Default = Color3.fromRGB(255, 90, 90),
    Callback = Log("Chams hidden")
})

Outline:Toggle({
    Name = "Enabled",
    Flag = "OutlineEnabled",
    Default = true,
    Callback = Log("Outline")
})

Outline:Slider({
    Name = "Thickness",
    Flag = "OutlineThickness",
    Min = 1,
    Max = 10,
    Default = 1,
    Decimals = 0,
    Callback = Log("Outline thickness")
})

Outline:Dropdown({
    Name = "Style",
    Flag = "OutlineStyle",
    Options = { "Default", "Glow" },
    Default = "Default",
    Callback = Log("Outline style")
})

-- Movement --------------------------------------------------------------------

local Player = Movement:Section({ Name = "Player", Side = "Left" })
local MoveUtility = Movement:Section({ Name = "Utility", Side = "Right" })

Player:Slider({
    Name = "Walk speed",
    Flag = "WalkSpeed",
    Min = 16,
    Max = 200,
    Default = 16,
    Decimals = 1,
    Callback = function(Value)
        local Character = game:GetService("Players").LocalPlayer.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")

        if Humanoid then
            Humanoid.WalkSpeed = Value
        end
    end
})

Player:Slider({
    Name = "Jump power",
    Flag = "JumpPower",
    Min = 50,
    Max = 300,
    Default = 50,
    Decimals = 0,
    Callback = function(Value)
        local Character = game:GetService("Players").LocalPlayer.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")

        if Humanoid then
            Humanoid.JumpPower = Value
        end
    end
})

MoveUtility:Toggle({
    Name = "Infinite jump",
    Flag = "InfiniteJump",
    Callback = Log("Infinite jump")
})

MoveUtility:Toggle({
    Name = "Fly",
    Flag = "Fly",
    Callback = Log("Fly")
})

MoveUtility:Keybind({
    Name = "Fly key",
    Flag = "FlyKey",
    Default = Enum.KeyCode.F,
    Callback = Log("Fly key")
})

MoveUtility:Slider({
    Name = "Fly speed",
    Flag = "FlySpeed",
    Min = 20,
    Max = 500,
    Default = 80,
    Decimals = 0,
    Callback = Log("Fly speed")
})

-- World / World ---------------------------------------------------------------

local Environment = World:Section({ Name = "Environment", Side = "Left" })
local Sky = World:Section({ Name = "Sky", Side = "Right" })

Environment:Toggle({
    Name = "Fullbright",
    Flag = "Fullbright",
    Callback = Log("Fullbright")
})

Environment:Slider({
    Name = "Clock time",
    Flag = "ClockTime",
    Min = 0,
    Max = 24,
    Default = 14,
    Decimals = 1,
    Callback = Log("Clock time")
})

Environment:Toggle({
    Name = "Fog",
    Flag = "Fog",
    Default = true,
    Callback = Log("Fog")
})

Environment:Slider({
    Name = "Fog end",
    Flag = "FogEnd",
    Min = 100,
    Max = 5000,
    Default = 1000,
    Decimals = 0,
    Callback = Log("Fog end")
})

Sky:Dropdown({
    Name = "Weather",
    Flag = "Weather",
    Options = { "Clear", "Rain", "Snow", "Fog" },
    Default = "Clear",
    Callback = Log("Weather")
})

Sky:Slider({
    Name = "Star count",
    Flag = "StarCount",
    Min = 0,
    Max = 5000,
    Default = 1000,
    Decimals = 0,
    Callback = Log("Star count")
})

Sky:Button({
    Name = "Apply sky",
    Callback = function()
        Library:Notification({
            Name = "Sky",
            Description = "Sky settings applied.",
            Icon = "check",
            Duration = 3
        })
    end
})

-- World / Post processing -----------------------------------------------------

local Effects = PostProcessing:Section({ Name = "Effects", Side = "Left" })
local Presets = PostProcessing:Section({ Name = "Presets", Side = "Right" })

Effects:Toggle({
    Name = "Color correction",
    Flag = "ColorCorrection",
    Default = true,
    Callback = Log("Color correction")
})

Effects:Slider({
    Name = "Bloom",
    Flag = "Bloom",
    Min = 0,
    Max = 3,
    Default = 1,
    Decimals = 2,
    Callback = Log("Bloom")
})

Effects:Slider({
    Name = "Blur",
    Flag = "Blur",
    Min = 0,
    Max = 20,
    Default = 0,
    Decimals = 0,
    Callback = Log("Blur")
})

Effects:Slider({
    Name = "Saturation",
    Flag = "Saturation",
    Min = -1,
    Max = 1,
    Default = 0,
    Decimals = 2,
    Callback = Log("Saturation")
})

Presets:Dropdown({
    Name = "Preset",
    Flag = "PostPreset",
    Options = { "Default", "Cinematic", "Vivid", "Soft" },
    Default = "Default",
    Callback = Log("Post preset")
})

Presets:Button({
    Name = "Apply preset",
    Callback = function()
        Library:Notification({
            Name = "Post processing",
            Description = "Applied preset: " .. tostring(Library.Flags.PostPreset or "Default"),
            Icon = "sliders-horizontal",
            Duration = 3
        })
    end
})

-- Misc ------------------------------------------------------------------------

local MiscUtility = Misc:Section({ Name = "Utility", Side = "Left" })
local About = Misc:Section({ Name = "About", Side = "Right" })

MiscUtility:Toggle({
    Name = "Anti-AFK",
    Flag = "AntiAfk",
    Default = true,
    Callback = Log("Anti-AFK")
})

MiscUtility:Toggle({
    Name = "FPS unlocker",
    Flag = "FpsUnlocker",
    Callback = Log("FPS unlocker")
})

MiscUtility:Keybind({
    Name = "Menu key",
    Flag = "MenuKey",
    Default = Enum.KeyCode.RightShift,
    Callback = Log("Menu key")
})

MiscUtility:Button({
    Name = "Copy job id",
    Callback = function()
        if setclipboard then
            pcall(setclipboard, game.JobId)
        end

        Library:Notification({
            Name = "Job id",
            Description = game.JobId ~= "" and game.JobId or "Not available on this server.",
            Icon = "copy",
            Duration = 4
        })
    end
})

About:Paragraph({
    Title = "Unable",
    Content = "Hover the sidebar to expand it, or click the logo in the title bar to pin it open."
})

About:Button({
    Name = "Test notification",
    Callback = function()
        Library:Notification({
            Name = "Notification",
            Description = "The Unable library is loaded and working.",
            Icon = "bell",
            Duration = 4
        })
    end
})

-- Configs --------------------------------------------------------------------

-- Theme config page: theme presets, color editing, config save/load/delete and
-- the Unload button (disables every feature first, then tears the UI down).
Configs:ThemeConfig({ })

-- Ready ----------------------------------------------------------------------

Library:Notification({
    Name = "Unable loaded",
    Description = "Loaded from the GitHub repository.",
    Icon = "check",
    Duration = 5
})
