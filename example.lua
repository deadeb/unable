--[[
    Unable - full feature UI loader

    The feature UI lives in game/script/example.lua. This root loader fetches it
    from the public repository so the standard loadstring always opens the
    populated interface instead of the old empty scaffold.
]]

local FeatureUrl = "https://raw.githubusercontent.com/deadeb/unable/main/game/script/example.lua?v="
	.. tostring(os.time())

local Ok, Source = pcall(function()
	return game:HttpGet(FeatureUrl)
end)

if not Ok or type(Source) ~= "string" or #Source < 64 then
	error(
		"[Unable] Could not download the feature UI from:\n"
			.. FeatureUrl
			.. "\nCheck the URL in a browser and your executor's HTTP access.",
		0
	)
end

local Chunk, CompileError = loadstring(Source)

if not Chunk then
	error("[Unable] Failed to compile the feature UI: " .. tostring(CompileError), 0)
end

Chunk()
