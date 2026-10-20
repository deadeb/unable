# Unable icons

Icons come from [Lucide](https://lucide.dev) (ISC license), rendered into a
single white sprite atlas that `Unable.lua` loads at runtime. The atlas is
downloaded from this repository, written into the executor workspace and served
through `getcustomasset`, so it stays crisp at any UI scale and needs no
Roblox asset uploads.

- `atlas.png` - 8 columns of 96x96 cells (currently 34 icons, 5 rows), white
  icons on transparency.
- `svg/` - the source SVGs used to build the atlas.
- `build.js` - regenerates `atlas.png` from `lucide-static` and `sharp`.

Rebuild:

```
npm install
node build.js
```

The tile order matches the `Library.IconAtlas.Icons` map in `Unable.lua`. After
a rebuild, bump the atlas file name in that map (`atlas-1.png` -> `atlas-2.png`)
so executors do not reuse a stale cached image.

Icon names outside this set fall back to the online Lucide pack
(`Footagesus/Icons`), then to `rbxassetid://0`.
