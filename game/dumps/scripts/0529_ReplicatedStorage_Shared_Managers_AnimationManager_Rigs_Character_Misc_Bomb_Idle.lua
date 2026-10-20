-- Decompiled with Potassium's decompiler.

local Chunks = script:WaitForChild("Chunks");
local v1 = {
    length = 3.333333,
    limbs = { "Handle", "Head", "HumanoidRootPart", "LeftFoot", "LeftHand", "LeftLowerArm", "LeftLowerLeg", "LeftUpperArm", "LeftUpperLeg", "LowerTorso", "RightFoot", "RightHand", "RightLowerArm", "RightLowerLeg", "RightUpperArm", "RightUpperLeg", "Slide1", "Slide2", "UpperTorso" },
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