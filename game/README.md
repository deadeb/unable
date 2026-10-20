# Kontra dump

Complete technical analysis of the Roblox game **[STICKERS!] Kontra** (universe `10764885410`, place `87204735676240`) at build 307, captured 2026-10-20.

- **[KONTRA_DUMP.md](KONTRA_DUMP.md)** — the full write-up: gameplay, rules, economy, maps, architecture, Blink networking, simulation, combat, aiming, anti-cheat, meta-progression, UI, event catalog and findings.
- **[dumps/](dumps/)** — raw evidence:
  - `runtime.json`, `players.json` — live match/player state at capture
  - `protocol.json` — complete Blink event registry (130 events, 17 signals), all 67 rate limits, and the runtime snapshot
  - `tree.json` — instance-tree sample
  - `map.json`, `map_zones.json` — map metadata, zones, spawns and bounds
  - `weapons.json` — all 41 weapon stat blocks
  - `script_index.json` — all 654 client modules with paths and line counts
  - `extra_index.json` — 590 additional decompiled modules
  - `Loader.lua`, `DisableRobloxStuff.lua`
  - `scripts/` — 654 decompiled client modules (402,902 lines)
  - `server/` — Blink server/types, map modifications, collision triangle, TradeUp/Achievements/Battlepass extras

Server scripts are not replicated to the client; server-only behaviour is marked **inferred** in the document. No live remotes were fired during capture.
