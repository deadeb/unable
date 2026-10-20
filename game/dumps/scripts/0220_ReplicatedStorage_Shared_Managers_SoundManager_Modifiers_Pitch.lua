-- Decompiled with Potassium's decompiler.

return function(u1) -- Line: 14
    return function(p2: table) -- Line: 15
        -- upvalues: u1 (copy)
        p2.PlaybackSpeed = p2.PlaybackSpeed * (u1.Min + (u1.Max - u1.Min) * math.random());
    end;
end;