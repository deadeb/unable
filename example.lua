--[[
    Unable - example loader

    The deadeb/unable repository is private, so this loader fetches Unable.lua
    through the authenticated GitHub Contents API.

    Token setup (pick one):
        1. Executor workspace file: create "UnableToken.txt" and put a
           fine-grained GitHub token in it (Repository access: deadeb/unable,
           Permissions: Contents = Read-only). Nothing else in the file.
        2. Or paste the token into the Token constant below.

    Never commit a real token: UnableToken.txt is git-ignored on purpose.

    Usage:
        Paste this file into your executor and run it. (It cannot fetch itself
        from GitHub while the repository is private - the token has to come
        from somewhere the executor can already read.)

    If the repository is ever made public, the loader falls back to the plain
    raw URL automatically when no token is set.
]]

local RawUrl = "https://raw.githubusercontent.com/deadeb/unable/main/Unable.lua"
local ApiUrl = "https://api.github.com/repos/deadeb/unable/contents/Unable.lua?ref=main"

-- Leave empty when the token comes from UnableToken.txt.
local Token = ""

if Token == "" and isfile and isfile("UnableToken.txt") then
    local Ok, Content = pcall(readfile, "UnableToken.txt")

    if Ok and type(Content) == "string" then
        Token = string.gsub(Content, "%s+", "")
    end
end

local function GetRequester()
    return (syn and syn.request)
    or (http and http.request)
    or (fluxus and fluxus.request)
    or http_request
    or request
end

local function Fetch()
    local Requester = GetRequester()

    if Token ~= "" and Requester then
        local Ok, Response = pcall(Requester, {
            Url = ApiUrl,
            Method = "GET",
            Headers = {
                ["Authorization"] = "Bearer " .. Token,
                ["Accept"] = "application/vnd.github.raw",
                ["User-Agent"] = "Unable-Loader"
            }
        })

        if Ok and type(Response) == "table" and type(Response.Body) == "string" then
            return Response.Body
        end
    end

    -- Untokened fallback: works only if the repository is public.
    local Ok, Body = pcall(function()
        return game:HttpGet(Token ~= "" and ApiUrl or RawUrl)
    end)

    if Ok then
        return Body
    end

    return nil
end

local Source = Fetch()

if type(Source) ~= "string" or #Source < 64 or not string.find(Source, "local Library", 1, true) then
    error(
        "[Unable] Could not download the library.\n"
        .. "The repository is private, so a token is required:\n"
        .. "  - create UnableToken.txt (fine-grained token, Contents: Read-only) in your executor workspace, or\n"
        .. "  - paste the token into the Token constant in this file.",
        0
    )
end

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
