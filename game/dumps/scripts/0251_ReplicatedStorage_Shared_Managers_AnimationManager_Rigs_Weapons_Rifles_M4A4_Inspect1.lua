-- Decompiled with Potassium's decompiler.

local Children = script:GetChildren();
table.sort(Children, function(p1, p2) -- Line: 3
    return p1.Name < p2.Name;
end);
local v3 = {};

for _, v in ipairs(Children) do
    local v4 = require(v);
    table.move(v4, 1, #v4, #v3 + 1, v3);
end;

return {
    length = 5.5,
    limbs = { "RootPart", "Mag", "Left Arm", "Right Arm", "Handle", "Slide1", "Slide2" },
    events = {},
    keyframes = v3
};