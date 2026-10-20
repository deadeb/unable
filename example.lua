--[[
    Unable - example loader

    The deadeb/unable repository is private, so this loader fetches Unable.lua
    through the authenticated GitHub Contents API.

    Token setup (pick one):
        1. In the executor, run this once (writes into the executor workspace):
               writefile("UnableToken.txt", "github_pat_...")
        2. Or set it for the current session before running this script:
               getgenv().UnableToken = "github_pat_..."
        3. Or paste it into the Token constant below.

    The token needs Contents: Read-only access to deadeb/unable
    (fine-grained token, repository access = deadeb/unable only;
    classic token: the "repo" scope).

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

-- Leave empty when the token comes from UnableToken.txt or getgenv().UnableToken.
local Token = ""

local TokenFiles = { "UnableToken.txt", "unabletoken.txt", "UnableToken", "Token.txt" }
local TokenSource = "not found"

local function NormalizeToken(Text)
    if type(Text) ~= "string" then return "" end

    Text = string.gsub(Text, "^\239\187\191", "")

    local Quoted = string.match(Text, "[\"']([%w_%-]+)[\"']")
    local Keyed = string.match(Text, "[Tt][Oo][Kk][Ee][Nn]%s*[:=]%s*([%w_%-]+)")
    local Bearer = string.match(Text, "[Bb][Ee][Aa][Rr][Ee][Rr]%s+([%w_%-]+)")

    Text = Quoted or Keyed or Bearer or Text
    Text = string.gsub(Text, "[^%w_%-]", "")

    return Text
end

local function LoadToken()
    local Env = type(getgenv) == "function" and getgenv().UnableToken or nil
    local Clean = NormalizeToken(Env)

    if #Clean >= 20 then
        TokenSource = "getgenv().UnableToken"
        return Clean
    end

    Clean = NormalizeToken(Token)

    if #Clean >= 20 then
        TokenSource = "Token constant"
        return Clean
    end

    for _, Name in TokenFiles do
        local Ok, Content = pcall(readfile, Name)

        if Ok and type(Content) == "string" then
            Clean = NormalizeToken(Content)

            if #Clean >= 20 then
                TokenSource = Name
                return Clean
            elseif #Content > 0 then
                TokenSource = Name .. " (invalid or placeholder)"
            end
        end
    end

    return ""
end

Token = LoadToken()

local HttpService = game:GetService("HttpService")
local Base64Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function Base64Decode(Input)
    local Lookup = { }

    for Index = 1, #Base64Chars do
        Lookup[string.sub(Base64Chars, Index, Index)] = Index - 1
    end

    Input = string.gsub(Input, "[^" .. Base64Chars .. "=]", "")
    Input = string.gsub(Input, "=", "")

    local Output = { }
    local Buffer = 0
    local Bits = 0

    for Index = 1, #Input do
        local Value = Lookup[string.sub(Input, Index, Index)]

        if Value then
            Buffer = Buffer * 64 + Value
            Bits = Bits + 6

            if Bits >= 8 then
                Bits = Bits - 8

                local Byte = math.floor(Buffer / (2 ^ Bits)) % 256
                table.insert(Output, string.char(Byte))
                Buffer = Buffer % (2 ^ Bits)
            end
        end
    end

    return table.concat(Output)
end

local Requesters = { }
local SeenRequesters = { }

local function AddRequester(Name, Function)
    if type(Function) ~= "function" or SeenRequesters[Function] then return end

    SeenRequesters[Function] = true
    table.insert(Requesters, {
        Name = Name,
        Call = function(Options)
            return Function(Options)
        end
    })
end

AddRequester("syn.request", syn and syn.request)
AddRequester("http.request", http and http.request)
AddRequester("http_request", http_request)
AddRequester("request", request)
AddRequester("fluxus.request", fluxus and fluxus.request)

local AttemptLog = { }
local SourceInfo = "unknown"

local function DecodeContents(Body)
    if string.find(Body, "local Library", 1, true) then
        return Body
    end

    local Ok, Data = pcall(function()
        return HttpService:JSONDecode(Body)
    end)

    if not Ok or type(Data) ~= "table" or type(Data.content) ~= "string" then
        return nil
    end

    local Encoded = string.gsub(Data.content, "%s+", "")

    for _, Decoder in { syn and syn.base64_decode, crypt and crypt.base64decode, base64_decode } do
        if type(Decoder) == "function" then
            local Done, Decoded = pcall(Decoder, Encoded)

            if Done and type(Decoded) == "string" and string.find(Decoded, "local Library", 1, true) then
                return Decoded
            end
        end
    end

    local Decoded = Base64Decode(Encoded)

    if string.find(Decoded, "local Library", 1, true) then
        return Decoded
    end

    return nil
end

local function Try(Requester, Url, Scheme)
    local Headers = {
        ["Accept"] = "application/vnd.github.raw",
        ["User-Agent"] = "Unable-Loader",
        ["X-GitHub-Api-Version"] = "2022-11-28"
    }

    if Token ~= "" and Scheme then
        Headers["Authorization"] = Scheme .. " " .. Token
    end

    local Ok, Response = pcall(Requester.Call, {
        Url = Url,
        Method = "GET",
        Headers = Headers
    })

    if not Ok then
        return nil, "request error: " .. tostring(Response)
    end

    if type(Response) == "string" then
        local LibraryBody = DecodeContents(Response)

        if LibraryBody then
            return LibraryBody
        end

        return nil, "unexpected body: " .. string.sub(string.gsub(Response, "%s+", " "), 1, 160)
    end

    if type(Response) ~= "table" then
        return nil, "unexpected response type: " .. type(Response)
    end

    local Body = Response.Body or Response.body or Response.Content or Response.content
    local Status = tonumber(Response.StatusCode or Response.Status or Response.status) or 0

    if type(Body) ~= "string" or Body == "" then
        return nil, "empty body (HTTP " .. tostring(Status) .. ")"
    end

    local Snippet = string.sub(string.gsub(Body, "%s+", " "), 1, 160)

    if Status >= 400 then
        return nil, "HTTP " .. tostring(Status) .. ": " .. Snippet
    end

    local LibraryBody = DecodeContents(Body)

    if LibraryBody then
        return LibraryBody
    end

    return nil, "HTTP " .. tostring(Status) .. " (unexpected body): " .. Snippet
end

local function Attempt(Requester, Url, Scheme)
    local Body, Err = Try(Requester, Url, Scheme)
    local Label = Url == ApiUrl and "api" or "raw"
    local Auth = Scheme and (" " .. Scheme) or " no-auth"

    if Body then
        SourceInfo = Requester.Name .. " [" .. Label .. "," .. Auth .. "]"
        return Body
    end

    table.insert(AttemptLog, Requester.Name .. " [" .. Label .. "," .. Auth .. "] -> " .. tostring(Err))
    return nil
end

local Source = nil

for _, Requester in Requesters do
    if Token ~= "" then
        Source = Source or Attempt(Requester, ApiUrl, "Bearer")
        Source = Source or Attempt(Requester, ApiUrl, "token")
        Source = Source or Attempt(Requester, RawUrl, "Bearer")
        Source = Source or Attempt(Requester, RawUrl, "token")
    else
        Source = Source or Attempt(Requester, RawUrl)
        Source = Source or Attempt(Requester, ApiUrl)
    end

    if Source then break end
end

if not Source then
    local Ok, Body = pcall(function()
        return game:HttpGet(RawUrl)
    end)

    if Ok and type(Body) == "string" and string.find(Body, "local Library", 1, true) then
        Source = Body
        SourceInfo = "game:HttpGet [raw,no-auth]"
    else
        table.insert(AttemptLog, "game:HttpGet [raw,no-auth] -> " .. (Ok and "unexpected body" or tostring(Body)))
    end
end

if type(Source) == "string" and #Source >= 64 then
    print("[Unable] Downloaded Unable.lua via " .. SourceInfo
        .. " (token: " .. (Token ~= "" and TokenSource or "none")
        .. ", " .. #Source .. " bytes).")
end

if type(Source) ~= "string" or #Source < 64 then
    local RequesterNames = { }

    for _, Requester in Requesters do
        table.insert(RequesterNames, Requester.Name)
    end

    local TokenLine

    if Token ~= "" then
        TokenLine = TokenSource .. ", " .. #Token .. " chars"
    else
        TokenLine = "not found"

        if TokenSource ~= "not found" then
            TokenLine = TokenLine .. " - " .. TokenSource
        end
    end

    local Lines = {
        "[Unable] Could not download the library from GitHub.",
        "",
        "Requesters: " .. (#RequesterNames > 0 and table.concat(RequesterNames, ", ") or "none"),
        "Token: " .. TokenLine
    }

    if Token == "" then
        table.insert(Lines, "readfile available: " .. tostring(readfile ~= nil))
        table.insert(Lines, "Token files checked: " .. table.concat(TokenFiles, ", "))
    end

    if #AttemptLog > 0 then
        table.insert(Lines, "Attempts:")

        for _, Entry in AttemptLog do
            table.insert(Lines, "  - " .. Entry)
        end
    end

    if #Requesters == 0 then
        table.insert(Lines, "Your executor has no request function, so it cannot send the Authorization header.")
    end

    table.insert(Lines, "")
    table.insert(Lines, "Fix:")
    table.insert(Lines, "  - run once in the executor: writefile(\"UnableToken.txt\", \"github_pat_...\")")
    table.insert(Lines, "  - or set getgenv().UnableToken = \"github_pat_...\" before running this script")
    table.insert(Lines, "  - or paste it into the Token constant at the top of this file")
    table.insert(Lines, "Token needs Contents: Read-only access to deadeb/unable.")

    error(table.concat(Lines, "\n"), 0)
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
