-- Decompiled with Potassium's decompiler.

local Chunks = script:WaitForChild("Chunks");
local v1 = {
    length = 3.66666675,
    limbs = { "LeftFoot", "LeftLowerLeg", "LeftUpperLeg", "Head", "LeftHand", "LeftLowerArm", "LeftUpperArm", "Silencer", "Handle", "RightHand", "RightLowerArm", "RightUpperArm", "UpperTorso", "RightFoot", "RightLowerLeg", "RightUpperLeg", "LowerTorso", "HumanoidRootPart" },
    events = {},
    keyframes = {}
};

for i = 1, Chunks:GetAttribute("Count") do
    local _ = i;

    for _, v in ipairs(require(Chunks[tostring(i)])) do
        table.insert(v1.keyframes, v);
    end;
end;

return v1;