-- Decompiled with Potassium's decompiler.

local v1 = {};

for _, child in script:GetChildren() do
    for i, v in require(child) do
        v1[i] = v;
    end;
end;

return v1;