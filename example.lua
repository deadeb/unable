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

local MainTab = Window:Tab({ Name = "Main", Icon = "home" })
local VisualTab = Window:Tab({ Name = "Visuals", Icon = "eye" })

-- Sub tabs (listed under the active tab in the sidebar) ----------------------

local General = MainTab:SubTab({ Name = "General", Icon = "settings" })
local Movement = MainTab:SubTab({ Name = "Movement", Icon = "move" })
local Look = VisualTab:SubTab({ Name = "Look", Icon = "palette" })

local ConfigTab = Window:Tab({ Name = "Configs", Icon = "folder" })
local Configs = ConfigTab:SubTab({ Name = "Configs", Icon = "save" })

-- General --------------------------------------------------------------------

local Features = General:Section({ Name = "Features", Side = "Left" })
local Info = General:Section({ Name = "Info", Side = "Right" })

Features:Toggle({
    Name = "Example toggle",
    Flag = "ExampleToggle",
    Default = true,
    Callback = function(Value)
        print("[Unable] Example toggle:", Value)
    end
})

Features:Dropdown({
    Name = "Mode",
    Flag = "ExampleMode",
    Options = { "Low", "Normal", "High" },
    Default = "Normal",
    Callback = function(Value)
        print("[Unable] Mode:", Value)
    end
})

Features:Textbox({
    Name = "Message",
    Flag = "ExampleMessage",
    Placeholder = "Type something...",
    Callback = function(Value)
        print("[Unable] Message:", Value)
    end
})

Features:Keybind({
    Name = "Print key",
    Flag = "ExampleKey",
    Default = Enum.KeyCode.H,
    Callback = function(Key)
        print("[Unable] Key pressed:", Key)
    end
})

Info:Label({ Name = "Left column, right section" })

Info:Paragraph({
    Title = "Sidebar",
    Content = "Hover the sidebar to expand it. Tabs and sub tabs both live inside that sidebar now."
})

-- Movement -------------------------------------------------------------------

local Player = Movement:Section({ Name = "Player", Side = "Left" })

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

-- Look -----------------------------------------------------------------------

local Theme = Look:Section({ Name = "Theme", Side = "Left" })

Theme:Colorpicker({
    Name = "Accent",
    Flag = "Accent",
    Default = Library.Theme.Accent,
    Callback = function(Color)
        Library:SetAccent(Color)
        Library:ApplyThemeInstant()
    end
})

local PresetNames = { }

for _, Preset in Library.ThemePresets do
    table.insert(PresetNames, Preset.Name)
end

Theme:Dropdown({
    Name = "Theme preset",
    Flag = "ThemePreset",
    Options = PresetNames,
    Default = "Default",
    Callback = function(Value)
        Library:SetTheme(Value)
        Library:ApplyThemeInstant()
    end
})

Theme:Button({
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
