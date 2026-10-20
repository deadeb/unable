# Unable — repository notes

This repository holds the Unable Luau library. It is private.

- `Unable.lua` — the library itself.
- `example.lua` — loader example that downloads `Unable.lua` from GitHub.

## Workflow

- After every change to any file, commit it and push to `origin main`
  (`https://github.com/deadeb/unable.git`).
- Because the repository is private, `example.lua` fetches `Unable.lua`
  through the authenticated GitHub Contents API
  (`https://api.github.com/repos/deadeb/unable/contents/Unable.lua?ref=main`).
- The GitHub token must never be committed. It comes from a local
  `UnableToken.txt` (git-ignored) or the empty `Token` constant in
  `example.lua`, which the operator fills in locally only.
- Untokened `game:HttpGet` on the raw URL
  (`https://raw.githubusercontent.com/deadeb/unable/main/Unable.lua`) is only
  kept as a fallback for the case the repository becomes public.
