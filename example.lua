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
local SkinsTab = Window:Tab({ Name = "Skins", Icon = "shirt" })
local MiscTab = Window:Tab({ Name = "Misc", Icon = "wrench" })
local ConfigTab = Window:Tab({ Name = "Configs", Icon = "folder" })

-- Sub tabs (listed under the active tab in the sidebar) ----------------------
-- Tabs with no sub tabs still need a page for their sections, so they get a
-- hidden one and the sidebar shows nothing extra.

local Rage = CombatTab:SubTab({ Name = "Rage", Icon = "flame" })
local Legit = CombatTab:SubTab({ Name = "Legit", Icon = "shield-check" })

local EspMain = EspTab:SubTab({ Name = "Main", Icon = "layout-dashboard" })
local Chams = EspTab:SubTab({ Name = "Chams", Icon = "palette" })

local Movement = MovementTab:SubTab({ Name = "Movement", Icon = "footprints", Hidden = true })

local World = WorldTab:SubTab({ Name = "World", Icon = "map" })
local PostProcessing = WorldTab:SubTab({ Name = "Post processing", Icon = "sliders-horizontal" })

-- Skins has no sub tabs; its page lives on a hidden sub tab and the grid
-- renders every skin as its own 3D viewport widget.
local Skins = SkinsTab:SubTab({ Name = "Skins", Icon = "shirt", Hidden = true })

local Misc = MiscTab:SubTab({ Name = "Misc", Icon = "wrench", Hidden = true })

local Configs = ConfigTab:SubTab({ Name = "Configs", Icon = "save" })

-- The tabs above start empty except Skins; add sections and controls with:
--     local Aimbot = Rage:Section({ Name = "Aimbot", Side = "Left" })

-- Skins -----------------------------------------------------------------------

-- Placeholder weapon mesh for the viewport tiles. A real skin changer would
-- load the actual weapon model here and use Callback to apply the pick.
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
        -- Skin changer hook: apply the picked skin to the current weapon here.
        print("[Unable] Weapon skin:", Name)
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
