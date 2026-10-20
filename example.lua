--[[
    Unable - example loader

    Downloads the latest Unable.lua straight from GitHub and builds a small
    demo interface against it.

    Usage (executor):
        loadstring(game:HttpGet("https://raw.githubusercontent.com/deadeb/unable/main/example.lua"))()

    Or just paste this file into your executor and run it.
]]

local RawUrl = "https://raw.githubusercontent.com/deadeb/unable/main/Unable.lua"

local Source = game:HttpGet(RawUrl)

if type(Source) ~= "string" or #Source < 64 then
    error("[Unable] Failed to download the library from " .. RawUrl)
end

local Chunk, CompileError = loadstring(Source)

if not Chunk then
    error("[Unable] Failed to compile the library: " .. tostring(CompileError))
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

-- Ready ----------------------------------------------------------------------

Library:Notification({
    Name = "Unable loaded",
    Description = "Loaded from " .. RawUrl,
    Icon = "check",
    Duration = 5
})
