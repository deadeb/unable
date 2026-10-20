# Unable — repository notes

This repository holds the Unable Luau library. It is public.

- `Unable.lua` — the library itself.
- `example.lua` — loader example that downloads `Unable.lua` from GitHub.

## Workflow

- After every change to any file, commit it and push to `origin main`
  (`https://github.com/deadeb/unable.git`).
- `example.lua` downloads `Unable.lua` from the raw URL on `main`
  (`https://raw.githubusercontent.com/deadeb/unable/main/Unable.lua`).
- If the repository is ever made private again, `example.lua` falls back to the
  authenticated GitHub Contents API
  (`https://api.github.com/repos/deadeb/unable/contents/Unable.lua?ref=main`)
  using a token from `getgenv().UnableToken` or the git-ignored
  `UnableToken.txt`.
- The GitHub token must never be committed. `UnableToken.txt` is git-ignored.
