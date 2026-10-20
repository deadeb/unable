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
	return type(Source) == "string" and #Source >= 64 and string.find(Source, "local Library", 1, true) ~= nil
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
	local Requester = (syn and syn.request) or (http and http.request) or http_request or request

	if not Requester then
		return nil
	end

	local Headers = {
		["Accept"] = "application/vnd.github.raw",
		["User-Agent"] = "Unable-Loader",
		["X-GitHub-Api-Version"] = "2022-11-28",
	}

	if Token ~= "" then
		Headers["Authorization"] = "Bearer " .. Token
	end

	local Ok, Response = pcall(Requester, {
		Url = ApiUrl,
		Method = "GET",
		Headers = Headers,
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
local State = {
	AvoidGuardedHooks = true,
	InputOnlyAutomation = true,
}
local Runtime

-- Window ---------------------------------------------------------------------

local Window = Library:Window({
	Name = "UNABLE",
	Icon = "layers",
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

local SilentAimToggle = RageAimbot:Toggle({
	Name = "Silent aim",
	Default = false,
	Flag = "RageSilentAim",
	Callback = function(Value)
		State.SilentAim = Value
	end,
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
	Callback = function(Value)
		State.SilentAimFov = Value
	end,
})

RageAimbot:Slider({
	Name = "Hitchance",
	Min = 0,
	Max = 100,
	Default = 80,
	Decimals = 0,
	Suffix = "%",
	Flag = "RageSilentAimHitchance",
	Callback = function(Value)
		State.SilentAimHitchance = Value
	end,
})

RageAimbot:Dropdown({
	Name = "Hitbox",
	Items = { "Head", "Chest", "Stomach", "Nearest" },
	Default = "Head",
	Flag = "RageSilentAimHitbox",
	Callback = function(Value)
		State.SilentAimHitbox = Value
	end,
})

local TriggerbotToggle = RageTrigger:Toggle({
	Name = "Triggerbot",
	Default = false,
	Flag = "RageTriggerbot",
	Callback = function(Value)
		State.Triggerbot = Value
	end,
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
	Callback = function(Value)
		State.TriggerbotDelay = Value
	end,
})

RageTrigger:Slider({
	Name = "Hitchance",
	Min = 0,
	Max = 100,
	Default = 90,
	Decimals = 0,
	Suffix = "%",
	Flag = "RageTriggerbotHitchance",
	Callback = function(Value)
		State.TriggerbotHitchance = Value
	end,
})

RageRecoil:Toggle({
	Name = "Remove weapon recoil",
	Default = false,
	Flag = "RageRemoveRecoil",
	Callback = function(Value)
		State.RemoveRecoil = Value
	end,
})

RageRecoil:Toggle({
	Name = "Remove weapon spread",
	Default = false,
	Flag = "RageRemoveSpread",
	Callback = function(Value)
		State.RemoveSpread = Value
	end,
})

RageRecoil:Toggle({
	Name = "Remove aim punch",
	Default = false,
	Flag = "RageRemoveAimPunch",
	Callback = function(Value)
		State.RemoveAimPunch = Value
	end,
})

RagePenetration:Toggle({
	Name = "Wallbang",
	Default = false,
	Flag = "RageWallbang",
	Callback = function(Value)
		State.Wallbang = Value
	end,
})

RagePenetration:Slider({
	Name = "Max wall thickness",
	Min = 0,
	Max = 500,
	Default = 128,
	Decimals = 0,
	Suffix = "studs",
	Flag = "RageWallbangThickness",
	Callback = function(Value)
		State.WallbangThickness = Value
	end,
})

RageLagComp:Toggle({
	Name = "Lag compensation abuse",
	Default = false,
	Flag = "RageLagComp",
	Callback = function(Value)
		State.LagCompAbuse = Value
	end,
})

RageLagComp:Slider({
	Name = "Max rewind",
	Min = 0,
	Max = 1000,
	Default = 200,
	Decimals = 0,
	Suffix = "ms",
	Flag = "RageLagCompRewind",
	Callback = function(Value)
		State.LagCompRewind = Value
	end,
})

-- Combat / Legit -------------------------------------------------------------

local LegitAimbot = Legit:Section({ Name = "Aimbot", Side = "Left" })
local LegitTrigger = Legit:Section({ Name = "Triggerbot", Side = "Right" })
local LegitRecoil = Legit:Section({ Name = "Recoil control", Side = "Left" })

local LegitAimbotToggle = LegitAimbot:Toggle({
	Name = "Legit aimbot",
	Default = false,
	Flag = "LegitAimbot",
	Callback = function(Value)
		State.LegitAimbot = Value
	end,
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
	Callback = function(Value)
		State.LegitAimbotFov = Value
	end,
})

LegitAimbot:Slider({
	Name = "Smoothing",
	Min = 1,
	Max = 30,
	Default = 8,
	Decimals = 1,
	Flag = "LegitAimbotSmooth",
	Callback = function(Value)
		State.LegitAimbotSmooth = Value
	end,
})

LegitAimbot:Dropdown({
	Name = "Hitbox",
	Items = { "Head", "Neck", "Chest", "Stomach" },
	Default = "Head",
	Flag = "LegitAimbotHitbox",
	Callback = function(Value)
		State.LegitAimbotHitbox = Value
	end,
})

local LegitTriggerToggle = LegitTrigger:Toggle({
	Name = "Legit triggerbot",
	Default = false,
	Flag = "LegitTriggerbot",
	Callback = function(Value)
		State.LegitTriggerbot = Value
	end,
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
	Callback = function(Value)
		State.LegitTriggerbotReaction = Value
	end,
})

LegitRecoil:Toggle({
	Name = "Remove aim punch",
	Default = false,
	Flag = "LegitRemoveAimPunch",
	Callback = function(Value)
		State.LegitRemoveAimPunch = Value
	end,
})

-- ESP ------------------------------------------------------------------------

local EspBoxes = EspMain:Section({ Name = "Boxes", Side = "Left" })
local EspInfo = EspMain:Section({ Name = "Information", Side = "Right" })
local EspChams = Chams:Section({ Name = "Chams", Side = "Left" })

EspBoxes:Toggle({
	Name = "Boxes",
	Default = false,
	Flag = "EspBoxes",
	Callback = function(Value)
		State.EspBoxes = Value
	end,
})

EspBoxes:Toggle({
	Name = "Filled boxes",
	Default = false,
	Flag = "EspFilledBoxes",
	Callback = function(Value)
		State.EspFilledBoxes = Value
	end,
})

EspBoxes:Slider({
	Name = "Max distance",
	Min = 0,
	Max = 5000,
	Default = 1500,
	Decimals = 0,
	Suffix = "studs",
	Flag = "EspMaxDistance",
	Callback = function(Value)
		State.EspMaxDistance = Value
	end,
})

EspInfo:Toggle({
	Name = "Names",
	Default = false,
	Flag = "EspNames",
	Callback = function(Value)
		State.EspNames = Value
	end,
})

EspInfo:Toggle({
	Name = "Health",
	Default = false,
	Flag = "EspHealth",
	Callback = function(Value)
		State.EspHealth = Value
	end,
})

EspInfo:Toggle({
	Name = "Weapon",
	Default = false,
	Flag = "EspWeapon",
	Callback = function(Value)
		State.EspWeapon = Value
	end,
})

EspInfo:Toggle({
	Name = "Distance",
	Default = false,
	Flag = "EspDistance",
	Callback = function(Value)
		State.EspDistance = Value
	end,
})

EspInfo:Toggle({
	Name = "Skeleton",
	Default = false,
	Flag = "EspSkeleton",
	Callback = function(Value)
		State.EspSkeleton = Value
	end,
})

EspChams:Toggle({
	Name = "Chams",
	Default = false,
	Flag = "EspChams",
	Callback = function(Value)
		State.EspChams = Value
	end,
})

EspChams:Dropdown({
	Name = "Material",
	Items = { "ForceField", "Neon", "Glass", "Metal" },
	Default = "ForceField",
	Flag = "EspChamsMaterial",
	Callback = function(Value)
		State.EspChamsMaterial = Value
	end,
})

EspChams:Slider({
	Name = "Transparency",
	Min = 0,
	Max = 1,
	Default = 0.35,
	Decimals = 2,
	Flag = "EspChamsTransparency",
	Callback = function(Value)
		State.EspChamsTransparency = Value
	end,
})

-- Movement -------------------------------------------------------------------

local MovementMain = Movement:Section({ Name = "Movement", Side = "Left" })
local MovementVisual = Movement:Section({ Name = "Visual", Side = "Right" })

local AutoBhopToggle = MovementMain:Toggle({
	Name = "Auto bhop",
	Default = false,
	Flag = "MovementAutoBhop",
	Callback = function(Value)
		State.AutoBhop = Value
	end,
})
AutoBhopToggle:Keybind({ Default = Enum.KeyCode.Space, Mode = "Toggle", Flag = "KeybindAutoBhop" })

MovementMain:Toggle({
	Name = "Auto strafe",
	Default = false,
	Flag = "MovementAutoStrafe",
	Callback = function(Value)
		State.AutoStrafe = Value
	end,
})

MovementMain:Dropdown({
	Name = "Strafe mode",
	Items = { "Legit", "Rage" },
	Default = "Legit",
	Flag = "MovementStrafeMode",
	Callback = function(Value)
		State.StrafeMode = Value
	end,
})

MovementMain:Toggle({
	Name = "Counter strafe",
	Default = false,
	Flag = "MovementCounterStrafe",
	Callback = function(Value)
		State.CounterStrafe = Value
	end,
})

MovementMain:Slider({
	Name = "Counter strafe amount",
	Min = 0,
	Max = 100,
	Default = 100,
	Decimals = 0,
	Suffix = "%",
	Flag = "MovementCounterStrafeAmount",
	Callback = function(Value)
		State.CounterStrafeAmount = Value
	end,
})

MovementMain:Toggle({
	Name = "Crouch jump assist",
	Default = false,
	Flag = "MovementCrouchJump",
	Callback = function(Value)
		State.CrouchJumpAssist = Value
	end,
})

MovementVisual:Toggle({
	Name = "No-clip visual",
	Default = false,
	Flag = "MovementNoClipVisual",
	Callback = function(Value)
		State.NoClipVisual = Value
	end,
})

-- World ----------------------------------------------------------------------

local WorldMain = World:Section({ Name = "World", Side = "Left" })
local WorldVisual = World:Section({ Name = "Visual", Side = "Right" })

WorldMain:Toggle({
	Name = "Fullbright",
	Default = false,
	Flag = "WorldFullbright",
	Callback = function(Value)
		State.Fullbright = Value
	end,
})

WorldMain:Toggle({
	Name = "Remove fog",
	Default = false,
	Flag = "WorldRemoveFog",
	Callback = function(Value)
		State.RemoveFog = Value
	end,
})

WorldVisual:Toggle({
	Name = "Custom FOV",
	Default = false,
	Flag = "WorldCustomFov",
	Callback = function(Value)
		State.CustomFovEnabled = Value
	end,
})

WorldVisual:Slider({
	Name = "Field of view",
	Min = 60,
	Max = 120,
	Default = 90,
	Decimals = 0,
	Suffix = "deg",
	Flag = "WorldFov",
	Callback = function(Value)
		State.WorldFov = Value
	end,
})

WorldVisual:Toggle({
	Name = "Custom time of day",
	Default = false,
	Flag = "WorldCustomTime",
	Callback = function(Value)
		State.CustomTimeEnabled = Value
	end,
})

WorldVisual:Slider({
	Name = "Time of day",
	Min = 0,
	Max = 24,
	Default = 12,
	Decimals = 1,
	Suffix = "h",
	Flag = "WorldTimeOfDay",
	Callback = function(Value)
		State.TimeOfDay = Value
	end,
})

-- Post processing ------------------------------------------------------------

local PostFx = PostProcessing:Section({ Name = "Post processing", Side = "Left" })

PostFx:Toggle({
	Name = "Enable post processing",
	Default = false,
	Flag = "PostEnabled",
	Callback = function(Value)
		State.PostProcessingEnabled = Value
	end,
})

PostFx:Slider({
	Name = "Saturation",
	Min = 0,
	Max = 2,
	Default = 1,
	Decimals = 2,
	Flag = "PostSaturation",
	Callback = function(Value)
		State.Saturation = Value
	end,
})

PostFx:Slider({
	Name = "Contrast",
	Min = 0,
	Max = 2,
	Default = 1,
	Decimals = 2,
	Flag = "PostContrast",
	Callback = function(Value)
		State.Contrast = Value
	end,
})

PostFx:Slider({
	Name = "Bloom",
	Min = 0,
	Max = 1,
	Default = 0.2,
	Decimals = 2,
	Flag = "PostBloom",
	Callback = function(Value)
		State.Bloom = Value
	end,
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
		{
			Name = "Default",
			Build = function(World)
				BuildSkin(World, Color3.fromRGB(205, 205, 210), Enum.Material.Metal)
			end,
		},
		{
			Name = "Crimson",
			Build = function(World)
				BuildSkin(World, Color3.fromRGB(205, 45, 55), Enum.Material.Neon)
			end,
		},
		{
			Name = "Gold",
			Build = function(World)
				BuildSkin(World, Color3.fromRGB(214, 178, 74), Enum.Material.Metal)
			end,
		},
		{
			Name = "Emerald",
			Build = function(World)
				BuildSkin(World, Color3.fromRGB(52, 206, 122), Enum.Material.Neon)
			end,
		},
		{
			Name = "Ice",
			Build = function(World)
				BuildSkin(World, Color3.fromRGB(165, 222, 255), Enum.Material.Ice, 0.25)
			end,
		},
		{
			Name = "Void",
			Build = function(World)
				BuildSkin(World, Color3.fromRGB(118, 72, 255), Enum.Material.ForceField)
			end,
		},
	},
	Callback = function(Name)
		State.WeaponSkin = Name
		if Runtime and Runtime.Ready then
			Runtime:ApplySkin(Name)
		end
	end,
})

local SkinApply = Skins:Section({ Name = "Apply", Side = "Right" })

SkinApply:Textbox({
	Name = "Skin name",
	Default = "Default",
	Placeholder = "Skin name",
	Flag = "SkinNameInput",
	Callback = function(Value)
		State.SkinNameInput = Value
	end,
})

SkinApply:Button({
	Name = "Apply local skin",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:ApplySkin(State.SkinNameInput)
		end
	end,
})

-- Exploits / Network ---------------------------------------------------------

local NetworkCommands = Network:Section({ Name = "Commands", Side = "Left" })
local NetworkTiming = Network:Section({ Name = "Timing", Side = "Right" })
local NetworkPackets = Network:Section({ Name = "Packets", Side = "Left" })

NetworkCommands:Slider({
	Name = "Command rate",
	Min = 1,
	Max = 20,
	Default = 7,
	Decimals = 0,
	Suffix = "cmd/frame",
	Flag = "ExploitCommandRate",
	Callback = function(Value)
		State.CommandRate = Value
	end,
})

NetworkTiming:Toggle({
	Name = "Custom time scale",
	Default = false,
	Flag = "ExploitCustomTimeScale",
	Callback = function(Value)
		State.CustomTimeScale = Value
	end,
})

NetworkTiming:Slider({
	Name = "Time scale",
	Min = 0.25,
	Max = 3,
	Default = 1,
	Decimals = 2,
	Suffix = "x",
	Flag = "ExploitTimeScale",
	Callback = function(Value)
		State.TimeScale = Value
	end,
})

NetworkPackets:Toggle({
	Name = "Idle command abuse",
	Default = false,
	Flag = "ExploitIdleCommandAbuse",
	Callback = function(Value)
		State.IdleCommandAbuse = Value
	end,
})

NetworkPackets:Toggle({
	Name = "Choke / lag switch",
	Default = false,
	Flag = "ExploitChoke",
	Callback = function(Value)
		State.Choke = Value
	end,
})

NetworkPackets:Slider({
	Name = "Choke amount",
	Min = 0,
	Max = 1000,
	Default = 0,
	Decimals = 0,
	Suffix = "ms",
	Flag = "ExploitChokeAmount",
	Callback = function(Value)
		State.ChokeAmount = Value
	end,
})

NetworkPackets:Textbox({
	Name = "Blink event",
	Default = "Gui.SendMessage",
	Placeholder = "Gui.SendMessage",
	Flag = "ExploitEventPath",
	Callback = function(Value)
		State.EventPath = Value
	end,
})

NetworkPackets:Textbox({
	Name = "JSON arguments",
	Default = '["hello"]',
	Placeholder = '["hello"]',
	Flag = "ExploitEventArguments",
	Callback = function(Value)
		State.EventArguments = Value
	end,
})

NetworkPackets:Button({
	Name = "Fire Blink event",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:FireEventConsole()
		end
	end,
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
	Callback = function(Value)
		State.Promocode = Value
	end,
})

EconomyActions:Button({
	Name = "Redeem promocode",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:RedeemPromocode()
		end
	end,
})

EconomyActions:Textbox({
	Name = "Container ID",
	Default = "",
	Placeholder = "Container",
	Flag = "EconomyContainerId",
	Callback = function(Value)
		State.ContainerId = Value
	end,
})

EconomyActions:Button({
	Name = "Open container",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:OpenContainer()
		end
	end,
})

EconomyActions:Textbox({
	Name = "Market item ID",
	Default = "",
	Placeholder = "Market item",
	Flag = "EconomyMarketId",
	Callback = function(Value)
		State.MarketItemId = Value
	end,
})

EconomyActions:Button({
	Name = "Reveal market item",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:RevealMarketItem()
		end
	end,
})

EconomyActions:Textbox({
	Name = "Trade-up items (JSON)",
	Default = "[]",
	Placeholder = '[{"WeaponName":"AK47","SkinName":"Default","SkinId":"0"}]',
	Flag = "EconomyTradeUpJson",
	Callback = function(Value)
		State.TradeUpJson = Value
	end,
})

EconomyActions:Button({
	Name = "Trade up",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:TradeUp()
		end
	end,
})

EconomyActions:Textbox({
	Name = "Upgrade inventory (JSON)",
	Default = '{"WeaponName":"","SkinName":"","SkinId":""}',
	Placeholder = "Inventory descriptor",
	Flag = "EconomyUpgradeInventory",
	Callback = function(Value)
		State.UpgradeInventoryJson = Value
	end,
})

EconomyActions:Textbox({
	Name = "Upgrade exchange (JSON)",
	Default = '{"WeaponName":"","SkinName":""}',
	Placeholder = "Exchange descriptor",
	Flag = "EconomyUpgradeExchange",
	Callback = function(Value)
		State.UpgradeExchangeJson = Value
	end,
})

EconomyActions:Button({
	Name = "Upgrade item",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:UpgradeItem()
		end
	end,
})

EconomySpoof:Textbox({
	Name = "Buy weapon",
	Default = "",
	Placeholder = "Weapon name",
	Flag = "EconomyBuyWeapon",
	Callback = function(Value)
		State.BuyWeaponName = Value
	end,
})

EconomySpoof:Button({
	Name = "Buy weapon",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:BuyWeapon()
		end
	end,
})

EconomySpoof:Textbox({
	Name = "Refund type",
	Default = "Weapon",
	Placeholder = "Weapon",
	Flag = "EconomyRefundType",
	Callback = function(Value)
		State.RefundType = Value
	end,
})

EconomySpoof:Textbox({
	Name = "Refund slot",
	Default = "0",
	Placeholder = "0",
	Flag = "EconomyRefundSlot",
	Callback = function(Value)
		State.RefundSlot = Value
	end,
})

EconomySpoof:Button({
	Name = "Refund weapon",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:RefundWeapon()
		end
	end,
})

EconomySpoof:Textbox({
	Name = "Store container (C)",
	Default = "0",
	Placeholder = "0",
	Flag = "EconomyStoreContainer",
	Callback = function(Value)
		State.StoreContainer = Value
	end,
})

EconomySpoof:Textbox({
	Name = "Store item (I)",
	Default = "",
	Placeholder = "Item",
	Flag = "EconomyStoreItem",
	Callback = function(Value)
		State.StoreItem = Value
	end,
})

EconomySpoof:Textbox({
	Name = "Store amount (A)",
	Default = "1",
	Placeholder = "1",
	Flag = "EconomyStoreAmount",
	Callback = function(Value)
		State.StoreAmount = Value
	end,
})

EconomySpoof:Button({
	Name = "Buy store item",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:BuyStoreItem()
		end
	end,
})

EconomyAutomation:Toggle({
	Name = "Auto claim battlepass",
	Default = false,
	Flag = "EconomyAutoBattlepass",
	Callback = function(Value)
		State.AutoBattlepass = Value
	end,
})

EconomyAutomation:Textbox({
	Name = "Playtime reward index",
	Default = "1",
	Placeholder = "1",
	Flag = "EconomyPlaytimeIndex",
	Callback = function(Value)
		State.PlaytimeIndex = Value
	end,
})

EconomyAutomation:Button({
	Name = "Claim playtime reward",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:ClaimPlaytimeReward()
		end
	end,
})

EconomyAutomation:Textbox({
	Name = "Achievement ID",
	Default = "",
	Placeholder = "Achievement",
	Flag = "EconomyAchievementId",
	Callback = function(Value)
		State.AchievementId = Value
	end,
})

EconomyAutomation:Button({
	Name = "Claim achievement",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:ClaimAchievement()
		end
	end,
})

EconomyAutomation:Textbox({
	Name = "Care package mask",
	Default = "",
	Placeholder = "1,2,3",
	Flag = "EconomyCarePackageMask",
	Callback = function(Value)
		State.CarePackageMask = Value
	end,
})

EconomyAutomation:Button({
	Name = "Claim care package items",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:ClaimCarePackage()
		end
	end,
})

-- Exploits / Inventory -------------------------------------------------------

local InventoryMutation = Inventory:Section({ Name = "Local inventory", Side = "Left" })
local InventoryLoadout = Inventory:Section({ Name = "Loadout event", Side = "Right" })

InventoryMutation:Textbox({
	Name = "Weapon name",
	Default = "",
	Placeholder = "Weapon",
	Flag = "InventoryWeaponName",
	Callback = function(Value)
		State.InventoryWeaponName = Value
	end,
})

InventoryMutation:Textbox({
	Name = "Skin name",
	Default = "",
	Placeholder = "Skin",
	Flag = "InventorySkinName",
	Callback = function(Value)
		State.InventorySkinName = Value
	end,
})

InventoryMutation:Textbox({
	Name = "Skin ID",
	Default = "",
	Placeholder = "Skin ID",
	Flag = "InventorySkinId",
	Callback = function(Value)
		State.InventorySkinId = Value
	end,
})

InventoryMutation:Button({
	Name = "Apply local equipment",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:ApplyLocalEquipment()
		end
	end,
})

InventoryLoadout:Textbox({
	Name = "A",
	Default = "19",
	Placeholder = "19",
	Flag = "InventoryLoadoutA",
	Callback = function(Value)
		State.LoadoutA = Value
	end,
})

InventoryLoadout:Textbox({
	Name = "B",
	Default = "1",
	Placeholder = "1",
	Flag = "InventoryLoadoutB",
	Callback = function(Value)
		State.LoadoutB = Value
	end,
})

InventoryLoadout:Textbox({
	Name = "C",
	Default = "Badges",
	Placeholder = "Badges",
	Flag = "InventoryLoadoutC",
	Callback = function(Value)
		State.LoadoutC = Value
	end,
})

InventoryLoadout:Textbox({
	Name = "D",
	Default = "None",
	Placeholder = "None",
	Flag = "InventoryLoadoutD",
	Callback = function(Value)
		State.LoadoutD = Value
	end,
})

InventoryLoadout:Textbox({
	Name = "E",
	Default = "50",
	Placeholder = "50",
	Flag = "InventoryLoadoutE",
	Callback = function(Value)
		State.LoadoutE = Value
	end,
})

InventoryLoadout:Textbox({
	Name = "T (team number)",
	Default = "1",
	Placeholder = "1",
	Flag = "InventoryLoadoutT",
	Callback = function(Value)
		State.LoadoutT = Value
	end,
})

InventoryLoadout:Button({
	Name = "Send loadout change",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:ChangeLoadout()
		end
	end,
})

-- Exploits / Anti-cheat ------------------------------------------------------

local AntiCheatInfo = AntiCheat:Section({ Name = "Tattletale", Side = "Left" })
local AntiCheatEnvironment = AntiCheat:Section({ Name = "Environment", Side = "Right" })
local AntiCheatReport = AntiCheat:Section({ Name = "Reports", Side = "Left" })

AntiCheatInfo:Toggle({
	Name = "Hide executor globals",
	Default = false,
	Flag = "AntiCheatHideGlobals",
	Callback = function(Value)
		State.HideExecutorGlobals = Value
	end,
})

AntiCheatInfo:Toggle({
	Name = "Avoid guarded hooks",
	Default = true,
	Flag = "AntiCheatAvoidHooks",
	Callback = function(Value)
		State.AvoidGuardedHooks = Value
	end,
})

AntiCheatInfo:Toggle({
	Name = "Input-only automation",
	Default = true,
	Flag = "AntiCheatInputOnly",
	Callback = function(Value)
		State.InputOnlyAutomation = Value
	end,
})

AntiCheatEnvironment:Toggle({
	Name = "Clean _G",
	Default = false,
	Flag = "AntiCheatCleanG",
	Callback = function(Value)
		State.CleanG = Value
	end,
})

AntiCheatEnvironment:Toggle({
	Name = "Clean getfenv(0)",
	Default = false,
	Flag = "AntiCheatCleanFenv",
	Callback = function(Value)
		State.CleanFenv = Value
	end,
})

AntiCheatEnvironment:Toggle({
	Name = "Suppress report loop",
	Default = false,
	Flag = "AntiCheatSuppressReport",
	Callback = function(Value)
		State.SuppressReportLoop = Value
	end,
})

AntiCheatReport:Button({
	Name = "Copy Tattletale notes",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:CopyTattletaleNotes()
		end
	end,
})

-- Exploits / UI --------------------------------------------------------------

local DebugVisuals = ExploitUI:Section({ Name = "Debug visuals", Side = "Left" })
local ConsoleAccess = ExploitUI:Section({ Name = "Console", Side = "Right" })
local SocialAbuse = ExploitUI:Section({ Name = "Social", Side = "Left" })

DebugVisuals:Toggle({
	Name = "Hitbox visualizer",
	Default = false,
	Flag = "UiHitboxVisualizer",
	Callback = function(Value)
		State.HitboxVisualizer = Value
	end,
})

DebugVisuals:Toggle({
	Name = "Zone visualizer",
	Default = false,
	Flag = "UiZoneVisualizer",
	Callback = function(Value)
		State.ZoneVisualizer = Value
	end,
})

ConsoleAccess:Toggle({
	Name = "Network debug output",
	Default = false,
	Flag = "UiNetworkDebug",
	Callback = function(Value)
		State.NetworkDebug = Value
	end,
})

SocialAbuse:Toggle({
	Name = "Chat spam",
	Default = false,
	Flag = "UiChatSpam",
	Callback = function(Value)
		State.ChatSpam = Value
	end,
})

SocialAbuse:Toggle({
	Name = "Votekick spam",
	Default = false,
	Flag = "UiVotekickSpam",
	Callback = function(Value)
		State.VotekickSpam = Value
	end,
})

SocialAbuse:Toggle({
	Name = "Map vote spam",
	Default = false,
	Flag = "UiMapVoteSpam",
	Callback = function(Value)
		State.MapVoteSpam = Value
	end,
})

SocialAbuse:Textbox({
	Name = "Chat message",
	Default = "",
	Placeholder = "Message",
	Flag = "UiChatMessage",
	Callback = function(Value)
		State.ChatMessage = Value
	end,
})

SocialAbuse:Button({
	Name = "Send chat message",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:SendChat(State.ChatMessage)
		end
	end,
})

SocialAbuse:Textbox({
	Name = "Votekick user ID",
	Default = "",
	Placeholder = "User ID",
	Flag = "UiVotekickUserId",
	Callback = function(Value)
		State.VotekickUserId = Value
	end,
})

SocialAbuse:Textbox({
	Name = "Votekick reason (number)",
	Default = "",
	Placeholder = "Reason code",
	Flag = "UiVotekickReason",
	Callback = function(Value)
		State.VotekickReason = Value
	end,
})

SocialAbuse:Button({
	Name = "Start votekick",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:StartVotekick()
		end
	end,
})

SocialAbuse:Textbox({
	Name = "Map name",
	Default = "",
	Placeholder = "Map",
	Flag = "UiMapName",
	Callback = function(Value)
		State.MapName = Value
	end,
})

SocialAbuse:Button({
	Name = "Vote for map",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:VoteForMap(State.MapName)
		end
	end,
})

-- Misc -----------------------------------------------------------------------

local MiscMain = Misc:Section({ Name = "Misc", Side = "Left" })

MiscMain:Toggle({
	Name = "Unload on death",
	Default = false,
	Flag = "MiscUnloadOnDeath",
	Callback = function(Value)
		State.UnloadOnDeath = Value
	end,
})

MiscMain:Button({
	Name = "Copy state",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:CopyState()
		end
	end,
})

MiscMain:Button({
	Name = "Unload UI",
	Callback = function()
		if Runtime and Runtime.Ready then
			Runtime:Stop()
		end
		Library:Unload()
	end,
})

-- Configs --------------------------------------------------------------------

Configs:ThemeConfig({})

-- Ready ----------------------------------------------------------------------

Library:Notification({
	Name = "Unable loaded",
	Description = "Full feature UI loaded from the GitHub repository.",
	Icon = "check",
	Duration = 5,
})

-- Runtime --------------------------------------------------------------------
-- Everything below is local to this script. The UI above only writes State;
-- the Runtime applies the corresponding Kontra action.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local GlobalTable = _G
local GlobalEnvironment = type(getfenv) == "function" and getfenv(0) or nil
local DebugGetUpvalue = type(debug) == "table" and debug.getupvalue or nil
local RawGet = rawget
local RawSet = rawset
local SetClipboard = type(setclipboard) == "function" and setclipboard
	or (type(getgenv) == "function" and getgenv().setclipboard)
local MousePress = type(mouse1press) == "function" and mouse1press
	or (type(getgenv) == "function" and getgenv().mouse1press)
local MouseRelease = type(mouse1release) == "function" and mouse1release
	or (type(getgenv) == "function" and getgenv().mouse1release)
local DrawingApi = Drawing or (type(getgenv) == "function" and getgenv().Drawing)
local GetHiddenUi = type(gethui) == "function" and gethui or (type(getgenv) == "function" and getgenv().gethui)

local function Clamp(Value, Minimum, Maximum)
	return math.max(Minimum, math.min(Maximum, Value))
end

local function Trim(Value)
	return type(Value) == "string" and string.match(Value, "^%s*(.-)%s*$") or ""
end

local function RandomChance(Percent)
	return math.random() * 100 <= Clamp(tonumber(Percent) or 0, 0, 100)
end

local function WrapAngle(Value)
	return math.atan2(math.sin(Value), math.cos(Value))
end

local ModuleCache = {}

local function FindModule(Name)
	if ModuleCache[Name] ~= nil then
		return ModuleCache[Name]
	end

	local Found = ReplicatedStorage:FindFirstChild(Name, true)

	if not Found or not Found:IsA("ModuleScript") then
		return nil
	end

	local Ok, Result = pcall(require, Found)

	if Ok and Result ~= nil then
		ModuleCache[Name] = Result
		return Result
	end

	return nil
end

local function RequirePath(Path)
	local Node = ReplicatedStorage

	for Part in string.gmatch(Path, "[^%.]+") do
		if not Node then
			return nil
		end

		Node = Node:FindFirstChild(Part)
	end

	if Node and Node:IsA("ModuleScript") then
		local Ok, Result = pcall(require, Node)

		if Ok then
			return Result
		end
	end
end

local function FindPath(Root, Path)
	local Node = Root

	for Part in string.gmatch(Path, "[^%.]+") do
		if type(Node) ~= "table" then
			return nil
		end

		Node = Node[Part]
	end

	return Node
end

local ExecutorNames = {
	"getgenv",
	"getrenv",
	"getsenv",
	"getreg",
	"getgc",
	"getupvalue",
	"getupvalues",
	"setupvalue",
	"setupevalue",
	"getrawmetatable",
	"setreadonly",
	"make_writeable",
	"make_writeable",
	"checkcaller",
	"islclosure",
	"iscclosure",
	"newcclosure",
	"hookfunction",
	"hookmetamethod",
	"replaceclosure",
	"restorefunction",
	"Drawing",
	"isfile",
	"writefile",
	"readfile",
	"appendfile",
	"listfiles",
	"delfile",
	"loadfile",
	"dofile",
	"getcustomasset",
	"identifyexecutor",
	"request",
	"http_request",
	"syn",
	"fluxus",
	"krnl",
	"secure_call",
	"setclipboard",
	"getclipboard",
	"mouse1press",
	"mouse1release",
	"mouse1click",
	"keypress",
	"keyrelease",
	"keyclick",
	"VirtualInputManager",
	"firetouchinterest",
	"fireclickdetector",
	"getconnections",
	"getnilinstances",
	"getinstances",
	"getloadedmodules",
	"getscripts",
	"getcallingscript",
	"queue_on_teleport",
	"setfpscap",
	"iswindowactive",
	"isrbxactive",
	"setrenderproperty",
	"getrenderproperty",
	"sethiddenproperty",
	"gethiddenproperty",
	"getthreadidentity",
	"setthreadidentity",
	"setidentity",
	"getidentity",
	"getscriptbytecode",
	"getscriptclosure",
	"decompile",
	"getfunctionhash",
}

local SkeletonEdges = {
	{ 1, 2 },
	{ 2, 3 },
	{ 3, 4 },
	{ 4, 5 },
	{ 5, 6 },
	{ 2, 7 },
	{ 7, 8 },
	{ 8, 9 },
	{ 3, 10 },
	{ 10, 11 },
	{ 11, 12 },
	{ 3, 13 },
	{ 13, 14 },
	{ 14, 15 },
	{ 2, 3 },
}

local HitboxNames = {
	Head = "Head",
	Neck = "UpperTorso",
	Chest = "UpperTorso",
	Stomach = "LowerTorso",
}

Runtime = {
	Ready = false,
	Started = false,
	Stopping = false,
	Disabled = false,
	Modules = ModuleCache,
	Connections = {},
	TickConnections = {},
	ConfigOriginal = {},
	ConfigValid = {},
	ConfigLast = {},
	LightingOriginal = {},
	HiddenScopes = {},
	ChamEntries = {},
	EspEntries = {},
	InstanceEsp = {},
	HitboxEntries = {},
	HitboxAdornments = {},
	Captured = {
		MousePress = MousePress,
		MouseRelease = MouseRelease,
		SetClipboard = SetClipboard,
		Drawing = DrawingApi,
	},
	Drawing = DrawingApi,
	Gui = nil,
	TriggerFired = false,
	FireMode = nil,
	LastNetworkDebug = false,
	Social = { Chat = 0, Votekick = 0, MapVote = 0, Battlepass = 0 },
}

function Runtime:GetModule(Name)
	local Cached = self.Modules[Name]

	if Cached ~= nil then
		return Cached
	end

	local Result = FindModule(Name)

	if Result ~= nil then
		self.Modules[Name] = Result
	end

	return Result
end

function Runtime:Notify(Name, Description)
	pcall(function()
		Library:Notification({
			Name = Name or "Unable",
			Description = Description or "",
			Icon = "check",
			Duration = 3,
		})
	end)
end

function Runtime:GetCharacter()
	local Controller = self.WeaponController

	if not Controller or type(Controller.GetCurrentCharacter) ~= "function" then
		return nil
	end

	local Ok, Character = pcall(Controller.GetCurrentCharacter, Controller)
	return Ok and Character or nil
end

function Runtime:GetLocalEntity()
	if self.LocalEntity then
		local Model = self.LocalEntity.Model

		if not Model or Model.Parent ~= nil then
			return self.LocalEntity
		end

		self.LocalEntity = nil
	end

	local Entities = self.Entities

	if Entities and type(Entities.GetCharacterByUserId) == "function" then
		local Ok, Entity = pcall(Entities.GetCharacterByUserId, Entities, LocalPlayer.UserId)

		if Ok and type(Entity) == "table" then
			self.LocalEntity = Entity
			return Entity
		end
	end

	if Entities and type(Entities.GetAllCategoryEntities) == "function" then
		local Ok, List = pcall(Entities.GetAllCategoryEntities, Entities, "Character")

		if Ok and type(List) == "table" then
			for _, Entity in pairs(List) do
				if type(Entity) == "table" and Entity.UserId == LocalPlayer.UserId then
					self.LocalEntity = Entity
					return Entity
				end
			end
		end
	end

	return nil
end

function Runtime:GetLocalModel()
	local Entity = self:GetLocalEntity()

	if Entity and Entity.Model then
		return Entity.Model
	end

	return LocalPlayer.Character
end

function Runtime:GetLocalTeam()
	local Entity = self:GetLocalEntity()

	if Entity and type(Entity.Data) == "table" then
		return Entity.Data.Team
	end
end

function Runtime:GetEntityPosition(Entity)
	if type(Entity) ~= "table" then
		return nil
	end

	if typeof(Entity.Position) == "Vector3" then
		return Entity.Position
	end

	if Entity.Model and type(Entity.Model.GetPivot) == "function" then
		local Ok, Pivot = pcall(Entity.Model.GetPivot, Entity.Model)

		if Ok and typeof(Pivot) == "CFrame" then
			return Pivot.Position
		end
	end
end

function Runtime:IsEnemy(Entity)
	if type(Entity) ~= "table" or not Entity.Model then
		return false
	end

	if Entity.UserId == LocalPlayer.UserId then
		return false
	end

	local LocalEntity = self:GetLocalEntity()

	if LocalEntity and Entity == LocalEntity then
		return false
	end

	local Health = Entity.Health

	if type(Health) == "number" and Health <= 0 then
		return false
	end

	local LocalTeam = self:GetLocalTeam()
	local Team = Entity.Data and Entity.Data.Team

	if LocalTeam ~= nil and Team ~= nil and tostring(LocalTeam) == tostring(Team) then
		return false
	end

	return true
end

function Runtime:GetEnemies()
	local Result = {}
	local Entities = self.Entities

	if not Entities or type(Entities.GetAllCategoryEntities) ~= "function" then
		return Result
	end

	local Ok, List = pcall(Entities.GetAllCategoryEntities, Entities, "Character")

	if not Ok or type(List) ~= "table" then
		return Result
	end

	for _, Entity in pairs(List) do
		if self:IsEnemy(Entity) then
			table.insert(Result, Entity)
		end
	end

	return Result
end

function Runtime:GetHitboxParts(Model)
	local CharacterModel = self.CharacterModel

	if CharacterModel and type(CharacterModel.GetHitboxParts) == "function" then
		local Ok, Parts = pcall(CharacterModel.GetHitboxParts, CharacterModel, Model)

		if Ok and type(Parts) == "table" then
			return Parts
		end
	end

	return {}
end

function Runtime:GetPart(Model, Name)
	local Parts = self:GetHitboxParts(Model)

	for _, Part in pairs(Parts) do
		if typeof(Part) == "Instance" and Part.Name == Name then
			return Part
		end
	end

	for _, Part in pairs(Parts) do
		if typeof(Part) == "Instance" and Part:IsA("BasePart") then
			return Part
		end
	end
end

function Runtime:IsVisible(Entity, Position)
	local Camera = workspace.CurrentCamera

	if not Camera then
		return false
	end

	local Origin = Camera.CFrame.Position
	local Delta = Position - Origin

	if Delta.Magnitude < 0.01 then
		return true
	end

	local LocalModel = self:GetLocalModel()
	local Filter = {}

	if LocalModel then
		table.insert(Filter, LocalModel)
	end

	table.insert(Filter, Camera)

	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = Filter

	local Hit = workspace:Raycast(Origin, Delta, Params)

	if not Hit then
		return true
	end

	if Hit.Instance:IsDescendantOf(Entity.Model) then
		return true
	end

	if not State.Wallbang then
		return false
	end

	local WallFilter = { LocalModel, Camera, Hit.Instance }

	local WallParams = RaycastParams.new()
	WallParams.FilterType = Enum.RaycastFilterType.Exclude
	WallParams.FilterDescendantsInstances = WallFilter

	local NextHit = workspace:Raycast(
		Hit.Position + Delta.Unit * 0.02,
		Delta.Unit * math.max(Delta.Magnitude - 0.02, 0.01),
		WallParams
	)

	if not NextHit then
		return true
	end

	if NextHit.Instance:IsDescendantOf(Entity.Model) then
		return true
	end

	local Thickness = (NextHit.Position - Hit.Position).Magnitude
	return Thickness <= Clamp(tonumber(State.WallbangThickness) or 128, 0, 500)
end

function Runtime:GetAimTarget(Fov, Mode)
	local Camera = workspace.CurrentCamera

	if not Camera then
		return nil
	end

	local Hitbox = Mode == "Legit" and (State.LegitAimbotHitbox or "Head") or (State.SilentAimHitbox or "Head")
	local Best = nil
	local BestScore = math.huge

	for _, Entity in pairs(self:GetEnemies()) do
		local Model = Entity.Model

		if Model then
			local Parts = self:GetHitboxParts(Model)
			local Candidates = {}

			if Hitbox == "Nearest" then
				for _, Part in pairs(Parts) do
					if typeof(Part) == "Instance" and Part:IsA("BasePart") then
						table.insert(Candidates, Part)
					end
				end
			else
				local Desired = HitboxNames[Hitbox] or "Head"
				local Part = nil

				for _, Item in pairs(Parts) do
					if typeof(Item) == "Instance" and Item.Name == Desired then
						Part = Item
						break
					end
				end

				if not Part and #Parts > 0 then
					Part = Parts[1]
				end

				if Part then
					table.insert(Candidates, Part)
				end
			end

			local EntityPosition = self:GetEntityPosition(Entity)

			for _, Part in pairs(Candidates) do
				local Position = Part.Position

				if State.LagCompAbuse and self.Entities and type(self.Entities.GetStateAtTime) == "function" then
					local Rewind = Clamp(tonumber(State.LagCompRewind) or 200, 0, 1000) / 1000
					local RenderTime = 0

					if type(self.Entities.GetRenderTime) == "function" then
						local Ok, Time = pcall(self.Entities.GetRenderTime, self.Entities)
						if Ok and type(Time) == "number" then
							RenderTime = Time
						end
					end

					local Ok, StatePosition =
						pcall(self.Entities.GetStateAtTime, self.Entities, Entity, RenderTime - Rewind)

					if Ok and typeof(StatePosition) == "Vector3" and EntityPosition then
						Position = StatePosition + (Part.Position - EntityPosition)
					end
				end

				local Delta = Position - Camera.CFrame.Position
				local Distance = Delta.Magnitude

				if Distance > 0.01 then
					local Angle = math.deg(math.acos(Clamp(Camera.CFrame.LookVector:Dot(Delta.Unit), -1, 1)))

					if Angle <= Fov and self:IsVisible(Entity, Position) then
						local Score = Angle + Distance * 0.001

						if Score < BestScore then
							local Horizontal = math.sqrt(Delta.X * Delta.X + Delta.Z * Delta.Z)
							local Yaw = math.atan2(-Delta.X, -Delta.Z)
							local Pitch = math.atan2(-Delta.Y, math.max(Horizontal, 0.0001))

							BestScore = Score
							Best = {
								Entity = Entity,
								Position = Position,
								Distance = Distance,
								Angle = Angle,
								Yaw = Yaw,
								Pitch = Pitch,
							}
						end
					end
				end
			end
		end
	end

	return Best
end

function Runtime:SetFire(Value)
	if not self.WeaponController then
		return
	end

	local InputOnly = State.InputOnlyAutomation ~= false
	local Press = self.Captured.MousePress
	local Release = self.Captured.MouseRelease

	if InputOnly and Press and Release then
		if Value then
			local Ok = pcall(Press)
			if Ok then
				self.FireMode = "mouse"
			end
		elseif self.FireMode == "mouse" then
			pcall(Release)
			self.FireMode = nil
		end
	else
		pcall(self.WeaponController.UpdateKeyState, self.WeaponController, "WishFire", Value and true or false)
		self.FireMode = Value and "state" or nil
	end
end

function Runtime:OnTickAim()
	self.SilentAimApplied = false
	self.LegitAimApplied = false

	if State.SilentAim then
		local Target = self:GetAimTarget(tonumber(State.SilentAimFov) or 30, "Rage")

		if Target and RandomChance(State.SilentAimHitchance) then
			local Ok, OldYaw, OldPitch = pcall(self.CameraController.GetAngles, self.CameraController)

			if Ok then
				pcall(self.CameraController.SetAngles, self.CameraController, Target.Yaw, Target.Pitch)
				self.CameraRestore = { OldYaw, OldPitch }
				self.SilentAimApplied = true
			end
		end
	elseif State.LegitAimbot then
		local Target = self:GetAimTarget(tonumber(State.LegitAimbotFov) or 8, "Legit")

		if Target then
			local Ok, CurrentYaw, CurrentPitch = pcall(self.CameraController.GetAngles, self.CameraController)

			if Ok then
				local Smoothing = Clamp(tonumber(State.LegitAimbotSmooth) or 8, 1, 30)
				local Step = 1 / Smoothing
				local Yaw = CurrentYaw + WrapAngle(Target.Yaw - CurrentYaw) * Step
				local Pitch = CurrentPitch + (Target.Pitch - CurrentPitch) * Step

				pcall(self.CameraController.SetAngles, self.CameraController, Yaw, Pitch)
				self.LegitAimApplied = true
			end
		end
	end
end

function Runtime:SetCharacterField(Character, Field, Value)
	if not self.MoveBackup or self.MoveCharacter ~= Character then
		self.MoveCharacter = Character
		self.MoveBackup = { Storage = {} }
	end

	if self.MoveBackup.Storage[Field] == nil then
		self.MoveBackup.Storage[Field] = { HasValue = Character[Field] ~= nil, Value = Character[Field] }
	end

	pcall(function()
		Character[Field] = Value
	end)
end

function Runtime:OnTickMove()
	local Character = self:GetCharacter()

	if not Character then
		return
	end

	local Current = {
		Left = Character.Left,
		Right = Character.Right,
		Forward = Character.Forward,
		Backward = Character.Backward,
	}

	if State.CounterStrafe and self.PreviousInput then
		local Amount = Clamp(tonumber(State.CounterStrafeAmount) or 100, 0, 100) / 100
		local PreviousLeft = tonumber(self.PreviousInput.Left) or 0
		local PreviousRight = tonumber(self.PreviousInput.Right) or 0
		local PreviousForward = tonumber(self.PreviousInput.Forward) or 0
		local PreviousBackward = tonumber(self.PreviousInput.Backward) or 0
		local CurrentLeft = tonumber(Current.Left) or 0
		local CurrentRight = tonumber(Current.Right) or 0
		local CurrentForward = tonumber(Current.Forward) or 0
		local CurrentBackward = tonumber(Current.Backward) or 0

		if PreviousLeft ~= 0 and CurrentLeft == 0 and CurrentRight == 0 then
			self:SetCharacterField(Character, "Right", Amount)
			self:SetCharacterField(Character, "MoveX", Amount)
		elseif PreviousRight ~= 0 and CurrentRight == 0 and CurrentLeft == 0 then
			self:SetCharacterField(Character, "Left", -Amount)
			self:SetCharacterField(Character, "MoveX", -Amount)
		end

		if PreviousForward ~= 0 and CurrentForward == 0 and CurrentBackward == 0 then
			self:SetCharacterField(Character, "Backward", Amount)
			self:SetCharacterField(Character, "MoveZ", Amount)
		elseif PreviousBackward ~= 0 and CurrentBackward == 0 and CurrentForward == 0 then
			self:SetCharacterField(Character, "Forward", -Amount)
			self:SetCharacterField(Character, "MoveZ", -Amount)
		end
	end

	self.PreviousInput = Current

	local OnGround = Character.OnGround

	if type(Character.Simulation) == "table" and Character.Simulation.OnGround ~= nil then
		OnGround = Character.Simulation.OnGround
	end

	if State.AutoStrafe and OnGround ~= true then
		local Direction = (math.floor(os.clock() * 7) % 2 == 0) and 1 or -1

		self:SetCharacterField(Character, "Left", Direction < 0 and -1 or 0)
		self:SetCharacterField(Character, "Right", Direction > 0 and 1 or 0)
		self:SetCharacterField(Character, "MoveX", Direction)

		if not self.SilentAimApplied and not self.LegitAimApplied and not State.LegitAimbot then
			local Ok, Yaw, Pitch = pcall(self.CameraController.GetAngles, self.CameraController)

			if Ok then
				local Step = State.StrafeMode == "Rage" and 0.02 or 0.008
				pcall(self.CameraController.SetAngles, self.CameraController, Yaw + Direction * Step, Pitch)

				if not self.CameraRestore then
					self.CameraRestore = { Yaw, Pitch }
				end
			end
		end
	end

	if State.AutoBhop then
		self:SetCharacterField(Character, "Jump", true)
	end

	if State.CrouchJumpAssist and (State.AutoBhop or Character.Jump) and OnGround ~= false then
		if not self.DuckRestore then
			self.DuckRestore = { Character = Character, Value = Character.Duck == true }
		end

		if type(Character.UpdateAdditionalInput) == "function" then
			pcall(Character.UpdateAdditionalInput, Character, "Duck", true)
		else
			self:SetCharacterField(Character, "Duck", true)
		end
	end
end

function Runtime:OnTickRestore()
	if self.MoveBackup and self.MoveCharacter then
		for Field, Saved in pairs(self.MoveBackup.Storage) do
			pcall(function()
				self.MoveCharacter[Field] = Saved.HasValue and Saved.Value or nil
			end)
		end

		self.MoveBackup = nil
		self.MoveCharacter = nil
	end

	if self.CameraRestore then
		pcall(self.CameraController.SetAngles, self.CameraController, self.CameraRestore[1], self.CameraRestore[2])
		self.CameraRestore = nil
	end

	if self.DuckRestore then
		local Character = self.DuckRestore.Character

		if type(Character.UpdateAdditionalInput) == "function" then
			pcall(Character.UpdateAdditionalInput, Character, "Duck", self.DuckRestore.Value)
		else
			pcall(function()
				Character.Duck = self.DuckRestore.Value
			end)
		end

		self.DuckRestore = nil
	end
end

function Runtime:OnTickTrigger()
	if not State.Triggerbot and not State.LegitTriggerbot then
		self.TriggerTarget = nil
		self.TriggerAcquired = nil
		return
	end

	local IsRage = State.Triggerbot == true
	local Fov = IsRage and (tonumber(State.SilentAimFov) or 30) or (tonumber(State.LegitAimbotFov) or 8)
	local Target = self:GetAimTarget(Fov, IsRage and "Rage" or "Legit")

	if not Target then
		self.TriggerTarget = nil
		self.TriggerAcquired = nil
		return
	end

	local Identifier = Target.Entity.Identifier or Target.Entity.Model
	local Now = os.clock()

	if self.TriggerTarget ~= Identifier then
		self.TriggerTarget = Identifier
		self.TriggerAcquired = Now
	end

	local Delay = IsRage and (tonumber(State.TriggerbotDelay) or 0) or (tonumber(State.LegitTriggerbotReaction) or 60)
	local Chance = IsRage and (tonumber(State.TriggerbotHitchance) or 90) or 100

	if self.TriggerAcquired and (Now - self.TriggerAcquired) * 1000 >= Delay then
		if RandomChance(Chance) then
			self:SetFire(true)
			self.TriggerFired = true
		end
	end
end

function Runtime:OnTickRelease()
	if self.TriggerFired then
		self:SetFire(false)
		self.TriggerFired = false
	end
end

function Runtime:PostTickChoke()
	if not State.Choke then
		return
	end

	local Amount = Clamp(tonumber(State.ChokeAmount) or 0, 0, 1000)

	if Amount <= 0 then
		return
	end

	local Now = os.clock()

	if Now < (self.NextChoke or 0) then
		return
	end

	local Deadline = Now + Amount / 1000

	repeat
	-- Deliberately burn this frame before networking flushes.
	until os.clock() >= Deadline

	self.NextChoke = os.clock() + 2
end

function Runtime:SetConfigRaw(Category, Key, Value)
	local Configuration = self.GameConfiguration

	if not Configuration or type(Configuration.Set) ~= "function" then
		return false
	end

	local Ok, Success = pcall(Configuration.Set, Category, Key, Value)
	return Ok and Success ~= false
end

function Runtime:CaptureConfig(Category, Key)
	local Full = Category .. "." .. Key

	if self.ConfigValid[Full] then
		return
	end

	local Configuration = self.GameConfiguration

	if not Configuration or type(Configuration.Get) ~= "function" then
		return
	end

	local Ok, Value = pcall(Configuration.Get, Category, Key)

	if Ok then
		self.ConfigOriginal[Full] = Value
		self.ConfigValid[Full] = true
	end
end

function Runtime:ApplyConfig(Category, Key, Value)
	local Full = Category .. "." .. Key
	self:CaptureConfig(Category, Key)

	if self.ConfigLast[Full] == Value then
		return
	end

	if self:SetConfigRaw(Category, Key, Value) then
		self.ConfigLast[Full] = Value
	end
end

function Runtime:RestoreConfig(Category, Key)
	local Full = Category .. "." .. Key

	if self.ConfigValid[Full] then
		self:ApplyConfig(Category, Key, self.ConfigOriginal[Full])
	end
end

function Runtime:UpdateConfig()
	if not self.GameConfiguration then
		return
	end

	self:ApplyConfig("Character", "MaxCommandsPerFrame", Clamp(tonumber(State.CommandRate) or 7, 1, 20))

	if State.CustomTimeScale then
		self:ApplyConfig("Game", "TimeScale", Clamp(tonumber(State.TimeScale) or 1, 0.25, 3))
	else
		self:RestoreConfig("Game", "TimeScale")
	end

	if State.IdleCommandAbuse then
		self:ApplyConfig("Network", "IdleCommand", true)
	else
		self:RestoreConfig("Network", "IdleCommand")
	end

	if State.RemoveRecoil then
		self:ApplyConfig("Weapon", "Recoil", false)
	else
		self:RestoreConfig("Weapon", "Recoil")
	end

	if State.RemoveSpread then
		self:ApplyConfig("Weapon", "Spread", false)
	else
		self:RestoreConfig("Weapon", "Spread")
	end

	if State.RemoveAimPunch or State.LegitRemoveAimPunch then
		self:ApplyConfig("Camera", "AimPunch", false)
	else
		self:RestoreConfig("Camera", "AimPunch")
	end

	if State.AutoBhop then
		self:ApplyConfig("Character", "EnableBunnyHop", true)
		self:ApplyConfig("Character", "AutoBunnyHop", true)
	else
		self:RestoreConfig("Character", "EnableBunnyHop")
		self:RestoreConfig("Character", "AutoBunnyHop")
	end
end

function Runtime:SetLighting(Key, Value)
	if self.LightingOriginal[Key] == nil then
		self.LightingOriginal[Key] = Lighting[Key]
	end

	pcall(function()
		Lighting[Key] = Value
	end)
end

function Runtime:RestoreLightingKey(Key)
	if self.LightingOriginal[Key] ~= nil then
		pcall(function()
			Lighting[Key] = self.LightingOriginal[Key]
		end)
	end
end

function Runtime:UpdateWorld()
	if State.Fullbright ~= self.LastFullbright then
		if State.Fullbright then
			self:SetLighting("Brightness", 3)
			self:SetLighting("Ambient", Color3.fromRGB(255, 255, 255))
			self:SetLighting("OutdoorAmbient", Color3.fromRGB(255, 255, 255))
			self:SetLighting("GlobalShadows", false)
		else
			self:RestoreLightingKey("Brightness")
			self:RestoreLightingKey("Ambient")
			self:RestoreLightingKey("OutdoorAmbient")
			self:RestoreLightingKey("GlobalShadows")
		end

		self.LastFullbright = State.Fullbright
	end

	if State.RemoveFog ~= self.LastRemoveFog then
		if State.RemoveFog then
			self:SetLighting("FogEnd", 1000000)
			self:SetLighting("FogStart", 0)
		else
			self:RestoreLightingKey("FogEnd")
			self:RestoreLightingKey("FogStart")
		end

		self.LastRemoveFog = State.RemoveFog
	end

	if State.CustomTimeEnabled ~= self.LastCustomTime then
		if State.CustomTimeEnabled then
			self:SetLighting("ClockTime", Clamp(tonumber(State.TimeOfDay) or 12, 0, 24))
		else
			self:RestoreLightingKey("ClockTime")
		end

		self.LastCustomTime = State.CustomTimeEnabled
	elseif State.CustomTimeEnabled then
		pcall(function()
			Lighting.ClockTime = Clamp(tonumber(State.TimeOfDay) or 12, 0, 24)
		end)
	end

	if self.CameraController then
		if State.CustomFovEnabled then
			local Fov = Clamp(tonumber(State.WorldFov) or 90, 60, 120)

			if self.AppliedFov ~= Fov then
				pcall(self.CameraController.SetFOVAmount, self.CameraController, Fov)
				self.AppliedFov = Fov
			end
		elseif self.AppliedFov ~= nil then
			pcall(self.CameraController.SetFOVAmount, self.CameraController, self.OriginalFov or 90)
			self.AppliedFov = nil
		end
	end
end

function Runtime:UpdatePostProcessing()
	if State.PostProcessingEnabled then
		if not self.PostColor then
			self.PostColor = Instance.new("ColorCorrectionEffect")
			self.PostColor.Name = "UnableColor"
			self.PostColor.Parent = Lighting
		end

		if not self.PostBloom then
			self.PostBloom = Instance.new("BloomEffect")
			self.PostBloom.Name = "UnableBloom"
			self.PostBloom.Parent = Lighting
		end

		self.PostColor.Saturation = tonumber(State.Saturation) or 1
		self.PostColor.Contrast = tonumber(State.Contrast) or 1
		self.PostBloom.Intensity = tonumber(State.Bloom) or 0.2
		self.PostBloom.Size = 24
		self.PostBloom.Threshold = 0.9
	else
		if self.PostColor then
			self.PostColor:Destroy()
			self.PostColor = nil
		end

		if self.PostBloom then
			self.PostBloom:Destroy()
			self.PostBloom = nil
		end
	end
end

function Runtime:UpdateNoClip()
	local Model = self:GetLocalModel()

	if State.NoClipVisual and Model then
		if self.NoClipModel ~= Model then
			self:ClearNoClip()
			self.NoClipModel = Model
			self.NoClipParts = {}

			for _, Part in pairs(Model:GetDescendants()) do
				if Part:IsA("BasePart") then
					self.NoClipParts[Part] = {
						CanCollide = Part.CanCollide,
						Transparency = Part.Transparency,
					}
				end
			end
		end

		for Part in pairs(self.NoClipParts) do
			pcall(function()
				Part.CanCollide = false
				Part.Transparency = 0.5
			end)
		end
	elseif self.NoClipModel then
		self:ClearNoClip()
	end
end

function Runtime:ClearNoClip()
	if self.NoClipParts then
		for Part, Saved in pairs(self.NoClipParts) do
			pcall(function()
				Part.CanCollide = Saved.CanCollide
				Part.Transparency = Saved.Transparency
			end)
		end
	end

	self.NoClipParts = nil
	self.NoClipModel = nil
end

function Runtime:GetChamsMaterial()
	local Materials = {
		ForceField = Enum.Material.ForceField,
		Neon = Enum.Material.Neon,
		Glass = Enum.Material.Glass,
		Metal = Enum.Material.Metal,
	}

	return Materials[State.EspChamsMaterial or "ForceField"] or Enum.Material.ForceField
end

function Runtime:AddChams(Entity)
	local Model = Entity.Model

	if not Model then
		return
	end

	if State.AvoidGuardedHooks then
		local Entry = self.ChamEntries[Model]

		if Entry and Entry.Parts then
			local Alpha = Clamp(tonumber(State.EspChamsTransparency) or 0.35, 0, 1)
			local Material = self:GetChamsMaterial()

			for Part in pairs(Entry.Parts) do
				pcall(function()
					Part.Material = Material
					Part.Transparency = Alpha
				end)
			end

			return
		end

		if Entry and Entry.Highlight then
			Entry.Highlight:Destroy()
			self.ChamEntries[Model] = nil
		end

		Entry = { Parts = {} }
		local Alpha = Clamp(tonumber(State.EspChamsTransparency) or 0.35, 0, 1)

		for _, Part in pairs(Model:GetDescendants()) do
			if Part:IsA("BasePart") then
				Entry.Parts[Part] = {
					Color = Part.Color,
					Material = Part.Material,
					Transparency = Part.Transparency,
				}

				pcall(function()
					Part.Color = Color3.fromRGB(255, 65, 65)
					Part.Material = self:GetChamsMaterial()
					Part.Transparency = Alpha
				end)
			end
		end

		self.ChamEntries[Model] = Entry
	else
		local Entry = self.ChamEntries[Model]

		if Entry and Entry.Highlight then
			Entry.Highlight.FillTransparency = Clamp(tonumber(State.EspChamsTransparency) or 0.35, 0, 1)
			return
		end

		if Entry and Entry.Parts then
			self:RemoveChams(Model)
		end

		local Highlight = Instance.new("Highlight")
		Highlight.Name = "UnableHighlight"
		Highlight.Adornee = Model
		Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		Highlight.FillColor = Color3.fromRGB(255, 65, 65)
		Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		Highlight.FillTransparency = Clamp(tonumber(State.EspChamsTransparency) or 0.35, 0, 1)
		Highlight.OutlineTransparency = 0.2
		Highlight.Parent = self.Gui

		self.ChamEntries[Model] = { Highlight = Highlight }
	end
end

function Runtime:RemoveChams(Model)
	local Entry = self.ChamEntries[Model]

	if not Entry then
		return
	end

	if Entry.Parts then
		for Part, Saved in pairs(Entry.Parts) do
			pcall(function()
				Part.Color = Saved.Color
				Part.Material = Saved.Material
				Part.Transparency = Saved.Transparency
			end)
		end
	end

	if Entry.Highlight then
		Entry.Highlight:Destroy()
	end

	self.ChamEntries[Model] = nil
end

function Runtime:ClearChams()
	for Model in pairs(self.ChamEntries) do
		self:RemoveChams(Model)
	end
end

function Runtime:UpdateChams()
	if State.EspChams then
		local Seen = {}

		for _, Entity in pairs(self:GetEnemies()) do
			if Entity.Model then
				Seen[Entity.Model] = true
				self:AddChams(Entity)
			end
		end

		for Model in pairs(self.ChamEntries) do
			if not Seen[Model] then
				self:RemoveChams(Model)
			end
		end
	else
		self:ClearChams()
	end
end

function Runtime:NewDrawing(Kind)
	if not self.Drawing then
		return nil
	end

	local Ok, Object = pcall(self.Drawing.new, Kind)
	return Ok and Object or nil
end

function Runtime:SetDraw(Object, Property, Value)
	if not Object then
		return
	end

	pcall(function()
		Object[Property] = Value
	end)
end

function Runtime:DestroyDraw(Object)
	if not Object then
		return
	end

	pcall(function()
		Object:Remove()
	end)
end

function Runtime:GetEspEntry(Entity)
	local Key = Entity.Identifier or Entity.Model
	local Entry = self.EspEntries[Key]

	if not Entry then
		Entry = {}
		self.EspEntries[Key] = Entry
	end

	return Entry
end

function Runtime:GetEntityName(Entity)
	local Player = Entity.UserId and Players:GetPlayerByUserId(Entity.UserId)

	if Player then
		return Player.DisplayName .. " (@" .. Player.Name .. ")"
	end

	return tostring(Entity.Identifier or Entity.UserId or "Player")
end

function Runtime:GetEntityWeapon(Entity)
	local Weapon = Entity.CurrentWeaponModel

	if typeof(Weapon) == "Instance" then
		return Weapon.Name
	end

	if type(Weapon) == "table" then
		return tostring(Weapon.Name or Weapon.Id or "Weapon")
	end

	if type(Entity.Data) == "table" then
		return tostring(Entity.Data.WeaponName or Entity.Data.Weapon or "Weapon")
	end

	return "Weapon"
end

function Runtime:GetScreenBox(Model)
	local Camera = workspace.CurrentCamera

	if not Camera or not Model then
		return nil
	end

	local Ok, BoxCFrame, BoxSize = pcall(function()
		local CFrame, Size = Model:GetBoundingBox()
		return CFrame, Size
	end)

	if not Ok or not BoxCFrame or not BoxSize then
		return nil
	end

	local MinX, MinY = math.huge, math.huge
	local MaxX, MaxY = -math.huge, -math.huge
	local Found = false

	for _, X in ipairs({ -1, 1 }) do
		for _, Y in ipairs({ -1, 1 }) do
			for _, Z in ipairs({ -1, 1 }) do
				local World = (BoxCFrame * CFrame.new(BoxSize.X / 2 * X, BoxSize.Y / 2 * Y, BoxSize.Z / 2 * Z)).Position
				local Screen, OnScreen = Camera:WorldToViewportPoint(World)

				if OnScreen and Screen.Z > 0 then
					MinX = math.min(MinX, Screen.X)
					MinY = math.min(MinY, Screen.Y)
					MaxX = math.max(MaxX, Screen.X)
					MaxY = math.max(MaxY, Screen.Y)
					Found = true
				end
			end
		end
	end

	if not Found then
		return nil
	end

	return Vector2.new(MinX, MinY), Vector2.new(MaxX - MinX, MaxY - MinY)
end

function Runtime:UpdateESP()
	local WantsESP = State.EspBoxes
		or State.EspFilledBoxes
		or State.EspNames
		or State.EspHealth
		or State.EspWeapon
		or State.EspDistance
		or State.EspSkeleton

	if not WantsESP then
		self:ClearESP()
		return
	end

	if not self.Drawing then
		self:UpdateInstanceESP()
		return
	end

	local Camera = workspace.CurrentCamera
	local Seen = {}

	for _, Entity in pairs(self:GetEnemies()) do
		local Model = Entity.Model
		local Position = self:GetEntityPosition(Entity)
		local Distance = Camera and Position and (Position - Camera.CFrame.Position).Magnitude or math.huge

		if Model and Distance <= (tonumber(State.EspMaxDistance) or 1500) then
			local BoxPosition, BoxSize = self:GetScreenBox(Model)

			if BoxPosition then
				local Entry = self:GetEspEntry(Entity)
				Seen[Entity.Identifier or Model] = true

				if State.EspBoxes then
					if not Entry.Box then
						Entry.Box = self:NewDrawing("Square")
					end
					self:SetDraw(Entry.Box, "Visible", true)
					self:SetDraw(Entry.Box, "Color", Color3.fromRGB(235, 65, 65))
					self:SetDraw(Entry.Box, "Thickness", 1)
					self:SetDraw(Entry.Box, "Filled", false)
					self:SetDraw(Entry.Box, "Position", BoxPosition)
					self:SetDraw(Entry.Box, "Size", BoxSize)
				elseif Entry.Box then
					self:SetDraw(Entry.Box, "Visible", false)
				end

				if State.EspFilledBoxes then
					if not Entry.Fill then
						Entry.Fill = self:NewDrawing("Square")
					end
					self:SetDraw(Entry.Fill, "Visible", true)
					self:SetDraw(Entry.Fill, "Color", Color3.fromRGB(235, 65, 65))
					self:SetDraw(Entry.Fill, "Transparency", 0.85)
					self:SetDraw(Entry.Fill, "Filled", true)
					self:SetDraw(Entry.Fill, "Position", BoxPosition)
					self:SetDraw(Entry.Fill, "Size", BoxSize)
				elseif Entry.Fill then
					self:SetDraw(Entry.Fill, "Visible", false)
				end

				local TextY = BoxPosition.Y - 16

				if State.EspNames then
					if not Entry.Name then
						Entry.Name = self:NewDrawing("Text")
					end
					self:SetDraw(Entry.Name, "Visible", true)
					self:SetDraw(Entry.Name, "Text", self:GetEntityName(Entity))
					self:SetDraw(Entry.Name, "Position", Vector2.new(BoxPosition.X + BoxSize.X / 2, TextY))
					self:SetDraw(Entry.Name, "Center", true)
					self:SetDraw(Entry.Name, "Outline", true)
					self:SetDraw(Entry.Name, "Size", 14)
					self:SetDraw(Entry.Name, "Color", Color3.fromRGB(255, 255, 255))
					TextY = TextY - 15
				elseif Entry.Name then
					self:SetDraw(Entry.Name, "Visible", false)
				end

				if State.EspHealth then
					if not Entry.Health then
						Entry.Health = self:NewDrawing("Text")
					end
					self:SetDraw(Entry.Health, "Visible", true)
					self:SetDraw(Entry.Health, "Text", "HP " .. tostring(math.floor(tonumber(Entity.Health) or 0)))
					self:SetDraw(Entry.Health, "Position", Vector2.new(BoxPosition.X + 2, BoxPosition.Y + 2))
					self:SetDraw(Entry.Health, "Outline", true)
					self:SetDraw(Entry.Health, "Size", 13)
					self:SetDraw(Entry.Health, "Color", Color3.fromRGB(120, 255, 120))
					TextY = TextY - 15
				elseif Entry.Health then
					self:SetDraw(Entry.Health, "Visible", false)
				end

				if State.EspWeapon then
					if not Entry.Weapon then
						Entry.Weapon = self:NewDrawing("Text")
					end
					self:SetDraw(Entry.Weapon, "Visible", true)
					self:SetDraw(Entry.Weapon, "Text", self:GetEntityWeapon(Entity))
					self:SetDraw(Entry.Weapon, "Position", Vector2.new(BoxPosition.X + 2, BoxPosition.Y + 18))
					self:SetDraw(Entry.Weapon, "Outline", true)
					self:SetDraw(Entry.Weapon, "Size", 13)
					self:SetDraw(Entry.Weapon, "Color", Color3.fromRGB(220, 220, 220))
				elseif Entry.Weapon then
					self:SetDraw(Entry.Weapon, "Visible", false)
				end

				if State.EspDistance then
					if not Entry.Distance then
						Entry.Distance = self:NewDrawing("Text")
					end
					self:SetDraw(Entry.Distance, "Visible", true)
					self:SetDraw(Entry.Distance, "Text", tostring(math.floor(Distance)) .. "m")
					self:SetDraw(
						Entry.Distance,
						"Position",
						Vector2.new(BoxPosition.X + BoxSize.X - 2, BoxPosition.Y + 18)
					)
					self:SetDraw(Entry.Distance, "Center", false)
					self:SetDraw(Entry.Distance, "Outline", true)
					self:SetDraw(Entry.Distance, "Size", 13)
					self:SetDraw(Entry.Distance, "Color", Color3.fromRGB(220, 220, 220))
				elseif Entry.Distance then
					self:SetDraw(Entry.Distance, "Visible", false)
				end

				if State.EspSkeleton then
					local Parts = self:GetHitboxParts(Model)

					if not Entry.Lines then
						Entry.Lines = {}
					end

					for Index, Edge in ipairs(SkeletonEdges) do
						local From = Parts[Edge[1]]
						local To = Parts[Edge[2]]

						if From and To then
							local Line = Entry.Lines[Index]

							if not Line then
								Line = self:NewDrawing("Line")
								Entry.Lines[Index] = Line
							end

							local FromScreen, FromOn = Camera:WorldToViewportPoint(From.Position)
							local ToScreen, ToOn = Camera:WorldToViewportPoint(To.Position)

							self:SetDraw(Line, "Visible", FromOn and ToOn and FromScreen.Z > 0 and ToScreen.Z > 0)
							self:SetDraw(Line, "From", Vector2.new(FromScreen.X, FromScreen.Y))
							self:SetDraw(Line, "To", Vector2.new(ToScreen.X, ToScreen.Y))
							self:SetDraw(Line, "Color", Color3.fromRGB(255, 80, 80))
							self:SetDraw(Line, "Thickness", 1)
						elseif Entry.Lines[Index] then
							self:SetDraw(Entry.Lines[Index], "Visible", false)
						end
					end
				elseif Entry.Lines then
					for _, Line in pairs(Entry.Lines) do
						self:SetDraw(Line, "Visible", false)
					end
				end
			end
		end
	end

	for Key, Entry in pairs(self.EspEntries) do
		if not Seen[Key] then
			for _, Object in pairs(Entry) do
				if type(Object) == "table" then
					for _, Line in pairs(Object) do
						self:DestroyDraw(Line)
					end
				else
					self:DestroyDraw(Object)
				end
			end

			self.EspEntries[Key] = nil
		end
	end
end

function Runtime:GetEntityAdornee(Entity)
	local Model = Entity.Model

	if not Model then
		return nil
	end

	return Model.PrimaryPart or Model:FindFirstChild("Head") or Model:FindFirstChildWhichIsA("BasePart") or Model
end

function Runtime:CreateInstanceESP(Entity)
	local Holder = Instance.new("BillboardGui")
	Holder.Name = "UnableESP"
	Holder.Adornee = self:GetEntityAdornee(Entity)
	Holder.AlwaysOnTop = true
	Holder.Size = UDim2.fromOffset(190, 90)
	Holder.StudsOffsetWorldSpace = Vector3.new(0, 1, 0)
	Holder.MaxDistance = tonumber(State.EspMaxDistance) or 1500
	Holder.Parent = self.Gui

	local Box = Instance.new("Frame")
	Box.Name = "Box"
	Box.BackgroundTransparency = 1
	Box.BorderSizePixel = 2
	Box.BorderColor3 = Color3.fromRGB(235, 65, 65)
	Box.Size = UDim2.fromScale(1, 1)
	Box.Parent = Holder

	local Fill = Instance.new("Frame")
	Fill.Name = "Fill"
	Fill.BackgroundColor3 = Color3.fromRGB(235, 65, 65)
	Fill.BackgroundTransparency = 0.85
	Fill.BorderSizePixel = 0
	Fill.Size = UDim2.fromScale(1, 1)
	Fill.Parent = Holder

	local Text = Instance.new("TextLabel")
	Text.Name = "Info"
	Text.BackgroundTransparency = 1
	Text.Font = Enum.Font.Gotham
	Text.TextSize = 13
	Text.TextColor3 = Color3.fromRGB(255, 255, 255)
	Text.TextStrokeTransparency = 0.5
	Text.TextXAlignment = Enum.TextXAlignment.Left
	Text.TextYAlignment = Enum.TextYAlignment.Top
	Text.Size = UDim2.fromScale(1, 1)
	Text.Parent = Holder

	return { Holder = Holder, Box = Box, Fill = Fill, Text = Text }
end

function Runtime:UpdateInstanceESP()
	local Seen = {}

	for _, Entity in pairs(self:GetEnemies()) do
		local Key = Entity.Identifier or Entity.Model
		local Position = self:GetEntityPosition(Entity)
		local Camera = workspace.CurrentCamera
		local Distance = Camera and Position and (Position - Camera.CFrame.Position).Magnitude or 0

		if Entity.Model and Distance <= (tonumber(State.EspMaxDistance) or 1500) then
			local Entry = self.InstanceEsp[Key]

			if not Entry then
				Entry = self:CreateInstanceESP(Entity)
				self.InstanceEsp[Key] = Entry
			end

			Seen[Key] = true
			Entry.Holder.Adornee = self:GetEntityAdornee(Entity)
			Entry.Holder.MaxDistance = tonumber(State.EspMaxDistance) or 1500
			Entry.Box.Visible = State.EspBoxes == true
			Entry.Fill.Visible = State.EspFilledBoxes == true
			Entry.Fill.BackgroundTransparency = 0.85

			local Lines = {}

			if State.EspNames then
				table.insert(Lines, self:GetEntityName(Entity))
			end

			if State.EspHealth then
				table.insert(Lines, "HP " .. tostring(math.floor(tonumber(Entity.Health) or 0)))
			end

			if State.EspWeapon then
				table.insert(Lines, self:GetEntityWeapon(Entity))
			end

			if State.EspDistance then
				table.insert(Lines, tostring(math.floor(Distance)) .. "m")
			end

			Entry.Text.Text = table.concat(Lines, "  ")
			Entry.Text.Visible = #Lines > 0
		end
	end

	for Key, Entry in pairs(self.InstanceEsp) do
		if not Seen[Key] then
			Entry.Holder:Destroy()
			self.InstanceEsp[Key] = nil
		end
	end
end

function Runtime:ClearESP()
	for _, Entry in pairs(self.EspEntries) do
		for _, Object in pairs(Entry) do
			if type(Object) == "table" then
				for _, Line in pairs(Object) do
					self:DestroyDraw(Line)
				end
			else
				self:DestroyDraw(Object)
			end
		end
	end

	self.EspEntries = {}

	for _, Entry in pairs(self.InstanceEsp) do
		pcall(function()
			Entry.Holder:Destroy()
		end)
	end

	self.InstanceEsp = {}
end

function Runtime:ClearHitboxes()
	for _, Object in pairs(self.HitboxEntries) do
		self:DestroyDraw(Object)
	end

	self.HitboxEntries = {}

	for _, Object in pairs(self.HitboxAdornments) do
		pcall(function()
			Object:Destroy()
		end)
	end

	self.HitboxAdornments = {}
end

function Runtime:UpdateHitboxes()
	if not State.HitboxVisualizer then
		self:ClearHitboxes()
		return
	end

	local Camera = workspace.CurrentCamera

	if not Camera then
		return
	end

	if not self.Drawing then
		local Seen = {}

		for _, Entity in pairs(self:GetEnemies()) do
			for _, Part in pairs(self:GetHitboxParts(Entity.Model)) do
				if typeof(Part) == "Instance" and Part:IsA("BasePart") then
					local Adornment = self.HitboxAdornments[Part]

					if not Adornment then
						Adornment = Instance.new("BoxHandleAdornment")
						Adornment.Name = "UnableHitbox"
						Adornment.Adornee = Part
						Adornment.Size = Vector3.new(0.06, 0.06, 0.06)
						Adornment.Color3 = Color3.fromRGB(80, 255, 130)
						Adornment.Transparency = 0.15
						Adornment.AlwaysOnTop = true
						Adornment.ZIndex = 5
						Adornment.Parent = Camera
						self.HitboxAdornments[Part] = Adornment
					end

					Seen[Part] = true
				end
			end
		end

		for Part, Adornment in pairs(self.HitboxAdornments) do
			if not Seen[Part] then
				Adornment:Destroy()
				self.HitboxAdornments[Part] = nil
			end
		end

		return
	end

	for _, Object in pairs(self.HitboxAdornments) do
		Object:Destroy()
	end

	self.HitboxAdornments = {}
	local Seen = {}

	for _, Entity in pairs(self:GetEnemies()) do
		for _, Part in pairs(self:GetHitboxParts(Entity.Model)) do
			if typeof(Part) == "Instance" and Part:IsA("BasePart") then
				local Screen, OnScreen = Camera:WorldToViewportPoint(Part.Position)
				local Object = self.HitboxEntries[Part]

				if not Object then
					Object = self:NewDrawing("Square")
					self.HitboxEntries[Part] = Object
				end

				Seen[Part] = true
				self:SetDraw(Object, "Visible", OnScreen and Screen.Z > 0)
				self:SetDraw(Object, "Color", Color3.fromRGB(80, 255, 130))
				self:SetDraw(Object, "Thickness", 1)
				self:SetDraw(Object, "Filled", false)
				self:SetDraw(Object, "Size", Vector2.new(5, 5))
				self:SetDraw(Object, "Position", Vector2.new(Screen.X - 2.5, Screen.Y - 2.5))
			end
		end
	end

	for Part, Object in pairs(self.HitboxEntries) do
		if not Seen[Part] then
			self:DestroyDraw(Object)
			self.HitboxEntries[Part] = nil
		end
	end
end

function Runtime:UpdateZones()
	if not self.DebugVisualizers then
		return
	end

	if not self.DebugStarted and State.ZoneVisualizer then
		if type(self.DebugVisualizers.Start) == "function" then
			local Ok, Error = pcall(self.DebugVisualizers.Start, self.DebugVisualizers, self)
			self.DebugStarted = Ok

			if not Ok and not self.ZoneWarned then
				self.ZoneWarned = true
				self:Notify("Zone visualizer", tostring(Error))
			end
		end
	end

	if type(self.DebugVisualizers.SetZones) == "function" then
		local Enabled = State.ZoneVisualizer == true

		if self.LastZones ~= Enabled then
			local Ok, Error = pcall(self.DebugVisualizers.SetZones, Enabled)

			if Ok then
				self.LastZones = Enabled
			elseif not self.ZoneWarned then
				self.ZoneWarned = true
				self:Notify("Zone visualizer", tostring(Error))
			end
		end
	end
end

function Runtime:SetScopeHidden(Key, Scope, Hidden)
	if not Scope then
		return
	end

	if Hidden then
		if self.HiddenScopes[Key] then
			return
		end

		local Backup = {}

		for _, Name in pairs(ExecutorNames) do
			local Value = RawGet(Scope, Name)

			if Value ~= nil then
				Backup[Name] = Value
				pcall(RawSet, Scope, Name, nil)
			end
		end

		self.HiddenScopes[Key] = Backup
	elseif self.HiddenScopes[Key] then
		local Backup = self.HiddenScopes[Key]

		for Name, Value in pairs(Backup) do
			if RawGet(Scope, Name) == nil then
				pcall(RawSet, Scope, Name, Value)
			end
		end

		self.HiddenScopes[Key] = nil
	end
end

function Runtime:UpdateGlobals()
	local HideG = State.HideExecutorGlobals or State.CleanG
	local HideFenv = State.HideExecutorGlobals or State.CleanFenv

	self:SetScopeHidden("G", GlobalTable, HideG)
	self:SetScopeHidden("Fenv", GlobalEnvironment, HideFenv)
end

function Runtime:FindTattleBucket()
	if self.TattleBucket then
		return self.TattleBucket
	end

	local Event = self:ResolveBlink("Anticheat.Tattle")
	local Fire = Event and Event.Fire

	if type(Fire) ~= "function" or not DebugGetUpvalue then
		return nil
	end

	local function Scan(Function, Depth)
		for Index = 1, 40 do
			local Name, Value = DebugGetUpvalue(Function, Index)

			if not Name then
				break
			end

			if type(Value) == "table" and Value.Counts then
				return Value
			end

			if type(Value) == "function" and Depth > 0 then
				local Found = Scan(Value, Depth - 1)
				if Found then
					return Found
				end
			end
		end
	end

	self.TattleBucket = Scan(Fire, 2)
	return self.TattleBucket
end

function Runtime:SuppressReports()
	if not State.SuppressReportLoop then
		self:RestoreTattletale()
		return
	end

	local Bucket = self:FindTattleBucket()

	if not Bucket or type(Bucket.Counts) ~= "table" then
		return
	end

	local Counts = Bucket.Counts

	if not self.TattleCounts then
		self.TattleCounts = Counts
		self.TattleMeta = getmetatable(Counts)
		self.TattleSnapshot = {}

		for Key, Value in pairs(Counts) do
			self.TattleSnapshot[Key] = Value
		end

		local OriginalIndex = self.TattleMeta and self.TattleMeta.__index
		local BlockingMeta = {}

		if self.TattleMeta then
			for Key, Value in pairs(self.TattleMeta) do
				BlockingMeta[Key] = Value
			end
		end

		BlockingMeta.__index = function(Table, Key)
			if Key == "Tattle" then
				return 100
			end

			if type(OriginalIndex) == "function" then
				return OriginalIndex(Table, Key)
			end

			if type(OriginalIndex) == "table" then
				return OriginalIndex[Key]
			end
		end

		setmetatable(Counts, BlockingMeta)
	end

	Counts.Tattle = 100
end

function Runtime:RestoreTattletale()
	if not self.TattleCounts then
		return
	end

	if self.TattleSnapshot then
		table.clear(self.TattleCounts)
		for Key, Value in pairs(self.TattleSnapshot) do
			self.TattleCounts[Key] = Value
		end
	end

	setmetatable(self.TattleCounts, self.TattleMeta)
	self.TattleCounts = nil
	self.TattleMeta = nil
	self.TattleSnapshot = nil
end

function Runtime:ResolveBlink(Path)
	if not self.Blink then
		self.Blink = self:GetModule("Blink") or RequirePath("Shared.Blink.Client")
	end

	if not self.Blink then
		return nil
	end

	local Root = self.Blink.Client or self.Blink
	return FindPath(Root, Path)
end

function Runtime:FireEvent(Path, ...)
	local Event = self:ResolveBlink(Path)

	if type(Event) ~= "table" or type(Event.Fire) ~= "function" then
		return false, "Blink event not found: " .. tostring(Path)
	end

	local Arguments = { ... }

	return pcall(function()
		Event.Fire(table.unpack(Arguments))
	end)
end

function Runtime:ActionNotify(Name, Ok, Detail)
	if Ok then
		self:Notify(Name, "Action sent.")
	else
		self:Notify(Name, tostring(Detail or "Action failed."))
	end
end

function Runtime:RedeemPromocode()
	local Code = Trim(State.Promocode)

	if Code == "" then
		return self:Notify("Economy", "Enter a promocode first.")
	end

	local Ok, Error = self:FireEvent("Gui.UsePromocode", Code)
	self:ActionNotify("Economy", Ok, Error)
end

function Runtime:OpenContainer()
	local Id = Trim(State.ContainerId)

	if Id == "" then
		return self:Notify("Economy", "Enter a container ID first.")
	end

	local Ok, Error = self:FireEvent("Gui.OpenContainer", { C = Id })
	self:ActionNotify("Economy", Ok, Error)
end

function Runtime:RevealMarketItem()
	local Id = Trim(State.MarketItemId)

	if Id == "" then
		return self:Notify("Economy", "Enter a market item ID first.")
	end

	local Ok, Error = self:FireEvent("Gui.RevealMarketItem", Id)
	self:ActionNotify("Economy", Ok, Error)
end

function Runtime:DecodeJSON(Text)
	local Ok, Value = pcall(function()
		return HttpService:JSONDecode(Text)
	end)

	if not Ok then
		return nil, Value
	end

	return Value
end

function Runtime:TradeUp()
	local Items, Error = self:DecodeJSON(State.TradeUpJson or "[]")

	if type(Items) ~= "table" or #Items == 0 then
		return self:Notify("Economy", "Trade-up JSON must be a non-empty array.")
	end

	local Ok, SendError = self:FireEvent("Gui.TradeUp", Items)
	self:ActionNotify("Economy", Ok, SendError or Error)
end

function Runtime:UpgradeItem()
	local Inventory, Error = self:DecodeJSON(State.UpgradeInventoryJson or "{}")

	if type(Inventory) ~= "table" then
		return self:Notify("Economy", "Inventory JSON is invalid: " .. tostring(Error))
	end

	local Exchange, ExchangeError = self:DecodeJSON(State.UpgradeExchangeJson or "{}")

	if type(Exchange) ~= "table" then
		return self:Notify("Economy", "Exchange JSON is invalid: " .. tostring(ExchangeError))
	end

	local Ok, SendError = self:FireEvent("Gui.Upgrade", {
		Inventory = Inventory,
		Exchange = Exchange,
	})
	self:ActionNotify("Economy", Ok, SendError)
end

function Runtime:BuyWeapon()
	local Name = Trim(State.BuyWeaponName)

	if Name == "" then
		return self:Notify("Economy", "Enter a weapon name first.")
	end

	if self.WeaponController and type(self.WeaponController.QueueBuy) == "function" then
		local Ok, Result = pcall(self.WeaponController.QueueBuy, self.WeaponController, Name)

		if Ok and Result ~= false then
			return self:Notify("Economy", "Queued purchase for " .. Name .. ".")
		end
	end

	local Enums = self:GetModule("Enums")
	local WeaponNumber = Enums and Enums.WeaponsNum and Enums.WeaponsNum[Name]

	if not WeaponNumber then
		return self:Notify("Economy", "Unknown weapon: " .. Name)
	end

	local Ok, Error = self:FireEvent("Weapon.BuyWeapon", { Drop = false, Enum = WeaponNumber })
	self:ActionNotify("Economy", Ok, Error)
end

function Runtime:RefundWeapon()
	local RefundType = Trim(State.RefundType)
	local Slot = tonumber(State.RefundSlot)

	if RefundType == "" or not Slot then
		return self:Notify("Economy", "Enter a refund type and numeric slot.")
	end

	local Ok, Error = self:FireEvent("Weapon.RefundWeapon", { Type = RefundType, Slot = Slot })
	self:ActionNotify("Economy", Ok, Error)
end

function Runtime:BuyStoreItem()
	local Container = tonumber(State.StoreContainer)
	local Item = Trim(State.StoreItem)
	local Amount = tonumber(State.StoreAmount)

	if not Container or Item == "" or not Amount then
		return self:Notify("Economy", "Enter numeric C and A values plus an item ID.")
	end

	local Ok, Error = self:FireEvent("Gui.BuyStoreItem", { C = Container, I = Item, A = Amount })
	self:ActionNotify("Economy", Ok, Error)
end

function Runtime:ClaimPlaytimeReward()
	local Index = tonumber(State.PlaytimeIndex)

	if not Index then
		return self:Notify("Economy", "Enter a numeric playtime reward index.")
	end

	local Ok, Error = self:FireEvent("Gui.ClaimPlaytimeReward", Index)
	self:ActionNotify("Economy", Ok, Error)
end

function Runtime:ClaimAchievement()
	local Id = Trim(State.AchievementId)

	if Id == "" then
		return self:Notify("Economy", "Enter an achievement ID first.")
	end

	local Ok, Error = self:FireEvent("Gui.ClaimAchievementReward", Id)
	self:ActionNotify("Economy", Ok, Error)
end

function Runtime:ClaimCarePackage()
	local Mask = {}
	local Seen = {}

	for Value in string.gmatch(State.CarePackageMask or "", "%d+") do
		local Index = tonumber(Value)

		if Index and Index >= 1 and Index <= 4 and not Seen[Index] then
			Seen[Index] = true
			Mask["Index" .. Index] = true
		end
	end

	if next(Mask) == nil then
		return self:Notify("Economy", "Enter one or more indices from 1 to 4.")
	end

	local Ok, Error = self:FireEvent("Gui.ClaimCarePackageItems", Mask)
	self:ActionNotify("Economy", Ok, Error)
end

function Runtime:ApplyLocalEquipment()
	local InventoryData = self.InventoryData
	local Weapon = Trim(State.InventoryWeaponName)
	local Skin = Trim(State.InventorySkinName)
	local SkinId = tostring(State.InventorySkinId or "")

	if not InventoryData or type(InventoryData.SetEquipped) ~= "function" then
		return self:Notify("Inventory", "InventoryData is unavailable.")
	end

	if Weapon == "" or Skin == "" then
		return self:Notify("Inventory", "Enter both a weapon and skin name.")
	end

	local Team = self:GetLocalTeam()

	if Team == nil then
		return self:Notify("Inventory", "The local team is unavailable.")
	end

	local Ok, Result = pcall(InventoryData.SetEquipped, tostring(Team), Weapon, Skin, SkinId)

	if Ok and Result ~= false then
		self:Notify("Inventory", "Updated local equipment.")
	else
		self:Notify("Inventory", "The local inventory rejected that equipment entry.")
	end
end

function Runtime:ChangeLoadout()
	local A = tonumber(State.LoadoutA)
	local B = tonumber(State.LoadoutB)
	local T = tonumber(State.LoadoutT)

	if not A or not B or not T then
		return self:Notify("Inventory", "A, B, and T must be numeric.")
	end

	local Ok, Error = self:FireEvent("Gui.ChangeLoadoutWeapon", {
		A = A,
		B = B,
		C = tostring(State.LoadoutC or ""),
		D = tostring(State.LoadoutD or ""),
		E = tostring(State.LoadoutE or ""),
		T = T,
	})

	self:ActionNotify("Inventory", Ok, Error)
end

function Runtime:ApplySkin(Name)
	local WeaponController = self.WeaponController

	if not WeaponController or type(WeaponController.GetCurrentWeapon) ~= "function" then
		return self:Notify("Skins", "WeaponController is unavailable.")
	end

	local Ok, Weapon = pcall(WeaponController.GetCurrentWeapon, WeaponController)

	if not Ok or not Weapon then
		return self:Notify("Skins", "Equip a weapon before applying a skin.")
	end

	local Viewmodel = self.Viewmodel or self:GetModule("Viewmodel")
	local Skin = Trim(Name)

	if type(Viewmodel) ~= "table" or type(Viewmodel.SetSkin) ~= "function" then
		return self:Notify("Skins", "The viewmodel skin API is unavailable.")
	end

	if Skin == "" then
		return self:Notify("Skins", "Enter a skin name first.")
	end

	local Applied, Result = pcall(Viewmodel.SetSkin, Viewmodel, Weapon, Skin)

	if Applied and Result ~= false then
		self:Notify("Skins", "Applied local skin " .. Skin .. ".")
	else
		self:Notify("Skins", "The game rejected skin " .. Skin .. ".")
	end
end

function Runtime:SetNetworkDebug(Value)
	self.LastNetworkDebug = Value == true

	if not self.Blink then
		return
	end

	local Root = self.Blink.Client or self.Blink
	local Event = Root and (Root.NetworkDebugEnabled or (Root.Gui and Root.Gui.NetworkDebugEnabled))

	if Event and type(Event.Fire) == "function" then
		pcall(Event.Fire, Value == true)
	end
end

function Runtime:FireEventConsole()
	local Path = Trim(State.EventPath)

	if Path == "" then
		return self:Notify("Packets", "Enter a Blink event path.")
	end

	local Arguments = self:DecodeJSON(State.EventArguments or "[]")

	if Arguments == nil then
		return self:Notify("Packets", "Arguments must be valid JSON.")
	end

	local List

	if type(Arguments) == "table" and (#Arguments > 0 or next(Arguments) == nil) then
		List = Arguments
	else
		List = { Arguments }
	end

	local Ok, Error = self:FireEvent(Path, table.unpack(List))

	self:ActionNotify("Packets", Ok, Error)
end

function Runtime:SendChat(Message)
	local Text = Trim(Message)

	if Text == "" then
		return
	end

	self:FireEvent("Gui.SendMessage", Text)
end

function Runtime:StartVotekick(Silent)
	local UserId = tonumber(State.VotekickUserId)
	local Reason = tonumber(State.VotekickReason)

	if not UserId or not Reason then
		if not Silent then
			self:Notify("Social", "Enter a numeric user ID and reason code.")
		end

		return
	end

	local Ok, Error = self:FireEvent("Gui.VotekickPlayer", {
		UserId = UserId,
		Reason = Reason,
	})

	if not Silent then
		self:ActionNotify("Social", Ok, Error)
	end
end

function Runtime:VoteForMap(MapName, Silent)
	local Name = Trim(MapName)

	if Name == "" then
		if not Silent then
			self:Notify("Social", "Enter a map name first.")
		end

		return
	end

	local Ok, Error = self:FireEvent("Gui.VoteForMap", Name)

	if not Silent then
		self:ActionNotify("Social", Ok, Error)
	end
end

function Runtime:UpdateSocial()
	local Now = os.clock()

	if State.ChatSpam and Now >= self.Social.Chat then
		self:SendChat(State.ChatMessage)
		self.Social.Chat = Now + 0.25
	end

	if State.VotekickSpam and Now >= self.Social.Votekick then
		self:StartVotekick(true)
		self.Social.Votekick = Now + 1.5
	end

	if State.MapVoteSpam and Now >= self.Social.MapVote then
		self:VoteForMap(State.MapName, true)
		self.Social.MapVote = Now + 1.5
	end

	if State.AutoBattlepass and Now >= self.Social.Battlepass then
		self:FireEvent("Gui.ClaimAllBattlepassRewards", nil)
		self.Social.Battlepass = Now + 30
	end
end

function Runtime:CopyText(Text)
	local Clipboard = self.Captured.SetClipboard

	if type(Clipboard) == "function" then
		local Ok = pcall(Clipboard, Text)

		if Ok then
			return true
		end
	end

	print(Text)
	return false
end

function Runtime:CopyState()
	local Ok, Json = pcall(function()
		return HttpService:JSONEncode(State)
	end)

	if not Ok then
		return self:Notify("Unable", tostring(Json))
	end

	if self:CopyText(Json) then
		self:Notify("Unable", "State copied to the clipboard.")
	else
		self:Notify("Unable", "State printed to the console.")
	end
end

function Runtime:CopyTattletaleNotes()
	local Bucket = self:FindTattleBucket()
	local Notes = table.concat({
		"Tattletale report loop: every ~4s",
		"Rate limit: 5 reports per second",
		"Bucket found: " .. tostring(Bucket ~= nil),
		"Suppression active: " .. tostring(State.SuppressReportLoop == true),
	}, "\n")

	if self:CopyText(Notes) then
		self:Notify("Anti-cheat", "Tattletale notes copied.")
	else
		self:Notify("Anti-cheat", Notes)
	end
end

function Runtime:UpdateTattletale()
	if State.SuppressReportLoop then
		local Now = os.clock()

		if Now >= (self.NextTattle or 0) then
			self:SuppressReports()
			self.NextTattle = Now + 0.2
		end
	elseif self.TattleCounts then
		self:RestoreTattletale()
	end
end

function Runtime:CreateGui()
	local Holder = nil

	if GetHiddenUi then
		local Ok, Result = pcall(GetHiddenUi)
		if Ok then
			Holder = Result
		end
	end

	if not Holder then
		local Ok, Result = pcall(function()
			return game:GetService("CoreGui")
		end)

		if Ok then
			Holder = Result
		end
	end

	local Gui = Instance.new("ScreenGui")
	Gui.Name = "UnableRuntime"
	Gui.ResetOnSpawn = false
	Gui.IgnoreGuiInset = true
	Gui.Parent = Holder
	self.Gui = Gui
end

function Runtime:ConnectTicks()
	local Dispatcher = self.Tick.OnTick

	if not Dispatcher then
		return
	end

	local function Add(Priority, SubPriority, Callback)
		local Connection = Dispatcher:Connect({
			Priority = Priority,
			SubPriority = SubPriority,
			Function = function(...)
				if not self.Ready then
					return
				end

				local Ok, Error = pcall(Callback, self, ...)

				if not Ok and not self.TickWarned then
					self.TickWarned = true
					warn("[Unable] Tick task failed: " .. tostring(Error))
				end
			end,
		})

		table.insert(self.TickConnections, Connection)
	end

	Add(0, 1, self.OnTickAim)
	Add(0, 2, self.OnTickMove)
	Add(1, 0.5, self.OnTickTrigger)
	Add(1, 1.5, self.OnTickRestore)
	Add(1, 2.5, self.OnTickRelease)

	if self.Tick.PostTick then
		local Post = self.Tick.PostTick:Connect({
			Priority = 3.5,
			SubPriority = 1,
			Function = function()
				if not self.Ready then
					return
				end

				local Ok, Error = pcall(self.PostTickChoke, self)

				if not Ok and not self.PostWarned then
					self.PostWarned = true
					warn("[Unable] PostTick task failed: " .. tostring(Error))
				end
			end,
		})

		table.insert(self.TickConnections, Post)
	end
end

function Runtime:CheckDeath()
	if not State.UnloadOnDeath or self.Unloading then
		return
	end

	local Entity = self:GetLocalEntity()

	if Entity and type(Entity.Health) == "number" and Entity.Health <= 0 then
		self.Unloading = true
		self:Stop()
		pcall(function()
			Library:Unload()
		end)
	end
end

function Runtime:Update()
	if not self.Ready then
		return
	end

	self:UpdateConfig()
	self:UpdateWorld()
	self:UpdatePostProcessing()
	self:UpdateNoClip()
	self:UpdateChams()
	self:UpdateESP()
	self:UpdateHitboxes()
	self:UpdateZones()
	self:UpdateGlobals()
	self:UpdateTattletale()
	self:UpdateSocial()
	self:CheckDeath()

	if (State.NetworkDebug == true) ~= self.LastNetworkDebug then
		self:SetNetworkDebug(State.NetworkDebug)
	end
end

function Runtime:InstallUnload()
	self.OriginalUnload = Library.Unload

	Library.Unload = function(Instance, SkipFeatures)
		Runtime:Stop()
		return Runtime.OriginalUnload(Instance, SkipFeatures)
	end
end

function Runtime:Stop()
	self.Disabled = true

	if not self.Started or self.Stopping then
		return
	end

	self.Stopping = true
	self.Ready = false
	pcall(self.OnTickRestore, self)

	pcall(self.SetFire, self, false)
	pcall(self.SetNetworkDebug, self, false)

	for _, Connection in pairs(self.Connections) do
		pcall(function()
			Connection:Disconnect()
		end)
	end

	self.Connections = {}

	for _, Connection in pairs(self.TickConnections) do
		pcall(function()
			Connection:Disconnect()
		end)
	end

	self.TickConnections = {}

	for Full in pairs(self.ConfigValid) do
		local Category, Key = string.match(Full, "^(.-)%.(.+)$")

		if Category and Key then
			local Original = self.ConfigOriginal[Full]

			if Original ~= nil then
				pcall(self.SetConfigRaw, self, Category, Key, Original)
			end
		end
	end

	for Key in pairs(self.LightingOriginal) do
		self:RestoreLightingKey(Key)
	end

	if self.AppliedFov ~= nil and self.CameraController then
		pcall(self.CameraController.SetFOVAmount, self.CameraController, self.OriginalFov or 90)
		self.AppliedFov = nil
	end

	if self.PostColor then
		self.PostColor:Destroy()
		self.PostColor = nil
	end

	if self.PostBloom then
		self.PostBloom:Destroy()
		self.PostBloom = nil
	end

	if self.DebugVisualizers and type(self.DebugVisualizers.SetZones) == "function" then
		pcall(self.DebugVisualizers.SetZones, false)
	end

	self.LastZones = false
	self:ClearChams()
	self:ClearESP()
	self:ClearHitboxes()
	self:ClearNoClip()
	self:RestoreTattletale()
	self:SetScopeHidden("G", GlobalTable, false)
	self:SetScopeHidden("Fenv", GlobalEnvironment, false)

	if self.Gui then
		self.Gui:Destroy()
		self.Gui = nil
	end

	if self.OriginalUnload then
		Library.Unload = self.OriginalUnload
	end

	self.Started = false
	self.Stopping = false
	print("[Unable] Runtime stopped.")
end

function Runtime:Start()
	if self.Started or self.Disabled then
		return
	end

	self.Started = true
	self.Tick = self:GetModule("Tick")
	self.CameraController = self:GetModule("CameraController")
	self.Entities = self:GetModule("Entities")
	self.CharacterModel = self:GetModule("CharacterModel")
	self.WeaponController = self:GetModule("WeaponController")
	self.GameConfiguration = self:GetModule("GameConfiguration")
	self.Blink = self:GetModule("Blink") or RequirePath("Shared.Blink.Client")
	self.InventoryData = self:GetModule("InventoryData")
	self.Viewmodel = self:GetModule("Viewmodel") or RequirePath("GameClient.WeaponController.Viewmodel")
	self.DebugVisualizers = self:GetModule("DebugVisualizers")
	self.Enums = self:GetModule("Enums")

	if not self.Tick or not self.Tick.OnTick or not self.CameraController then
		self.Started = false

		if not self.PendingNotice then
			self.PendingNotice = true
			self:Notify("Unable", "Waiting for the Kontra client modules to finish loading...")
		end

		task.delay(2, function()
			if not Runtime.Ready and not Runtime.Disabled then
				Runtime:Start()
			end
		end)

		return
	end

	if self.CameraController and type(self.CameraController.GetSettingsFieldOfView) == "function" then
		local Ok, Fov = pcall(self.CameraController.GetSettingsFieldOfView, self.CameraController)
		local Camera = workspace.CurrentCamera
		self.OriginalFov = Ok and tonumber(Fov) or (Camera and Camera.FieldOfView) or 70
	else
		local Camera = workspace.CurrentCamera
		self.OriginalFov = Camera and Camera.FieldOfView or 70
	end

	self.DebugStarted = false
	self:CreateGui()
	self.Ready = true
	self:ConnectTicks()

	table.insert(
		self.Connections,
		RunService.RenderStepped:Connect(function()
			local Ok, Error = pcall(self.Update, self)

			if not Ok and not self.UpdateWarned then
				self.UpdateWarned = true
				warn("[Unable] Render task failed: " .. tostring(Error))
			end
		end)
	)

	self:InstallUnload()
	self:Notify("Unable", "Kontra runtime ready. Open the menu and bind your keys.")
end

Runtime:Start()
