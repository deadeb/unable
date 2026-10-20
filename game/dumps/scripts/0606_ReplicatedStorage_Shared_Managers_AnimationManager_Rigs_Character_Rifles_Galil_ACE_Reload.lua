-- Decompiled with Potassium's decompiler.

local Chunks = script:WaitForChild("Chunks");
local v1 = {
    length = 2.5999999,
    limbs = { "RightFoot", "RightLowerLeg", "RightUpperLeg", "LeftFoot", "LeftLowerLeg", "LeftUpperLeg", "Slide1", "Mag", "Handle", "RightHand", "RightLowerArm", "RightUpperArm", "LeftHand", "LeftLowerArm", "LeftUpperArm", "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart" },
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