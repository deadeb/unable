-- Unable AutoBhop
-- Standalone, UI-free bunnyhop for Kontra.
--
-- The game only permits another jump when it sees a fresh jump press:
--     if not CFG.AutoBunnyHop and WannaJump then jump = false end
--     WannaJump = WannaJumpButton
-- Holding Jump therefore stops at the first hop while AutoBunnyHop is off.
-- This script writes an alternating Jump input, so every landing gets a new
-- press without changing any game configuration or admin-locked setting.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local ToggleKey = Enum.KeyCode.RightShift
local AutoEnable = true

local BindName = "UnableAutoBhop"
local Environment = (getgenv and getgenv()) or _G

local function ResolveModule(Path)
	local Node = ReplicatedStorage

	for Segment in string.gmatch(Path, "[^%.]+") do
		Node = Node and Node:FindFirstChild(Segment)
	end

	if not Node or not Node:IsA("ModuleScript") then
		return nil
	end

	local Ok, Result = pcall(require, Node)
	return Ok and Result or nil
end

local CharacterController
local WeaponController
local NextResolve = 0
local NextGcScan = 0

local function RefreshModules()
	if CharacterController and WeaponController then
		return
	end

	if os.clock() < NextResolve then
		return
	end

	NextResolve = os.clock() + 2
	CharacterController = CharacterController or ResolveModule("GameClient.CharacterController")
	WeaponController = WeaponController or ResolveModule("GameClient.WeaponController")
end

local function FindCharacterFromGc()
	if type(getgc) ~= "function" then
		return nil
	end

	if os.clock() < NextGcScan then
		return nil
	end

	NextGcScan = os.clock() + 2

	local Ok, Objects = pcall(getgc, true)

	if not Ok or type(Objects) ~= "table" then
		return nil
	end

	for _, Object in ipairs(Objects) do
		if type(Object) == "table" then
			local Simulation = rawget(Object, "Simulation")

			if
				Simulation
				and rawget(Object, "Jump") ~= nil
				and rawget(Object, "Maid") ~= nil
				and rawget(Object, "StepTimer") ~= nil
			then
				return Object
			end
		end
	end
end

local function GetCharacter()
	RefreshModules()

	if CharacterController and type(CharacterController.GetCharacter) == "function" then
		local Ok, Character = pcall(CharacterController.GetCharacter, CharacterController)

		if Ok and Character then
			return Character
		end
	end

	if WeaponController and type(WeaponController.GetCurrentCharacter) == "function" then
		local Ok, Character = pcall(WeaponController.GetCurrentCharacter, WeaponController)

		if Ok and Character then
			return Character
		end
	end

	if LocalPlayer:GetAttribute("Team") ~= "Spectator" then
		return FindCharacterFromGc()
	end
end

local State = {
	Enabled = AutoEnable,
	Pulse = false,
	Character = nil,
	Linked = false,
}

local function WriteJump(Character, Value)
	if not Character then
		return
	end

	pcall(function()
		Character.Jump = Value
	end)
end

local function IsOnGround(Character)
	local Simulation = Character.Simulation

	if Simulation then
		local Ground = Simulation.OnGround

		if Ground ~= nil then
			return Ground == true
		end
	end

	return Character.OnGround == true
end

local function Step()
	if not State.Enabled then
		return
	end

	local Character = GetCharacter()

	if Character ~= State.Character then
		if State.Character then
			WriteJump(State.Character, false)
		end

		State.Character = Character
		State.Pulse = false

		if Character and not State.Linked then
			State.Linked = true
			print("[Unable] AutoBhop attached to the local character.")
		elseif not Character then
			State.Linked = false
		end
	end

	if not Character then
		return
	end

	if IsOnGround(Character) then
		-- Toggle on ground. If a command is lost or arrives while the server
		-- still considers us airborne, the next ground tick supplies an edge.
		State.Pulse = not State.Pulse
		WriteJump(Character, State.Pulse)
	else
		-- Release in the air. This clears WannaJump before the next landing.
		State.Pulse = false
		WriteJump(Character, false)
	end
end

local function SetEnabled(Value, Quiet)
	Value = Value == true

	local Character = State.Character or GetCharacter()
	State.Enabled = Value
	State.Pulse = false
	State.Linked = false

	if Value then
		State.Character = nil
	else
		WriteJump(Character, false)
		State.Character = nil
	end

	if not Quiet then
		print(string.format("[Unable] AutoBhop %s (%s)", Value and "ON" or "OFF", ToggleKey.Name))
	end
end

local Previous = Environment.UnableAutoBhop

if type(Previous) == "table" and type(Previous.Unload) == "function" then
	pcall(Previous.Unload, Previous)
end

pcall(function()
	RunService:UnbindFromRenderStep(BindName)
end)

local RenderConnection
local Bound = pcall(function()
	-- Tick uses RenderPriority.First (0). Run one slot earlier so Jump is
	-- already set when Tick builds this frame's command.
	RunService:BindToRenderStep(BindName, Enum.RenderPriority.First.Value - 1, Step)
end)

if not Bound then
	RenderConnection = RunService.RenderStepped:Connect(Step)
end

local InputConnection = UserInputService.InputBegan:Connect(function(Input, GameProcessed)
	if GameProcessed then
		return
	end

	if Input.KeyCode == ToggleKey then
		SetEnabled(not State.Enabled)
	end
end)

local API = {}

function API:SetEnabled(Value)
	SetEnabled(Value)
end

function API:Toggle()
	SetEnabled(not State.Enabled)
end

function API:IsEnabled()
	return State.Enabled
end

function API:Unload()
	SetEnabled(false, true)

	if InputConnection then
		InputConnection:Disconnect()
		InputConnection = nil
	end

	if RenderConnection then
		RenderConnection:Disconnect()
		RenderConnection = nil
	end

	pcall(function()
		RunService:UnbindFromRenderStep(BindName)
	end)

	if Environment.UnableAutoBhop == API then
		Environment.UnableAutoBhop = nil
	end
end

Environment.UnableAutoBhop = API

print(string.format("[Unable] AutoBhop loaded: %s. %s toggles.", State.Enabled and "ON" or "OFF", ToggleKey.Name))
