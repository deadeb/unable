-- Decompiled with Potassium's decompiler.

local Chunks = script:WaitForChild("Chunks");
local v1 = {
    length = 3.23333335,
    limbs = { "LeftHand", "LeftLowerArm", "LeftUpperArm", "Head", "Silencer", "Slide2", "Slide1", "Mag", "Handle", "RightHand", "RightLowerArm", "RightUpperArm", "UpperTorso", "HumanoidRootPart" },
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