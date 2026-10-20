# [STICKERS!] Kontra — Complete Technical Dump

**Snapshot:** 2026-10-20  
**Build observed:** place version 307, `JobId f3ccdf48-4f4c-448e-93ee-c889b266637d`, server region `DE`  
**Evidence:** live client (`lostmyledger0`, 10 players in server), 654 decompiled client `ModuleScript`s (402,902 lines), 590 additional directly-decompiled modules, instance-tree/runtime dumps, and the public Roblox game API.

This is a full description of **what Kontra is, how a match works, and how the client-visible implementation is put together** — combat, networking, prediction, anti-cheat, economy, UI, maps, and the cosmetic meta-game. Server scripts are not replicated to the client; where behaviour is server-only it is marked **inferred** rather than presented as decompiled fact. The suspicious “cheat” remotes were never fired; all observations were passive or read-only.

**Raw evidence** is in [`dumps/`](dumps/). The main source files referenced below are in [`dumps/scripts/`](dumps/scripts/) and [`dumps/server/`](dumps/server/).

---

## Contents

1. [Quick facts](#1-quick-facts)
2. [What Kontra is](#2-what-kontra-is)
3. [The match loop and rules](#3-the-match-loop-and-rules)
4. [Economy and buying](#4-economy-and-buying)
5. [Maps and world structure](#5-maps-and-world-structure)
6. [Technical architecture](#6-technical-architecture)
7. [Networking: Blink](#7-networking-blink)
8. [Simulation, movement and prediction](#8-simulation-movement-and-prediction)
9. [Combat and weapons](#9-combat-and-weapons)
10. [Aiming, camera and recoil](#10-aiming-camera-and-recoil)
11. [Anti-cheat and security](#11-anti-cheat-and-security)
12. [Meta-progression and cosmetics](#12-meta-progression-and-cosmetics)
13. [UI and HUD](#13-ui-and-hud)
14. [Remote and event catalog](#14-remote-and-event-catalog)
15. [Notable findings and limitations](#15-notable-findings-and-limitations)
16. [Appendix: evidence and file map](#16-appendix-evidence-and-file-map)

---

## 1. Quick facts

| Property | Value |
|---|---|
| Game name | `[STICKERS!] Kontra` |
| Universe / Game ID | `10764885410` |
| Root place ID | `87204735676240` |
| Creator | Group **blackcatsisreal** (`35706237`), owner `arctiffyy` |
| Created | 2026-09-02 |
| Last updated at capture | 2026-10-20 |
| Genre (Roblox API) | Shooter / Deathmatch Shooter |
| Visits at capture | 1,808,845 |
| Favorites | 27,791 |
| Concurrent players at capture | 1,209 |
| Server size | 16 |
| Implemented mode | **Casual** bomb-defusal |
| Maps at capture | `de_seaside`, `de_dust2`, `de_vertigo` |
| Rounds | First to **8**, maximum **15** |
| Round time | 135 s; 45 s buy time |
| Tick rate | **64 Hz** (max 240) |
| Netcode | Custom **Blink** binary protocol over 4 remotes |
| Anti-cheat | Client `Tattletale` + `TattleSeal`, server validation, FOW/PVS, decoy remotes |
| Meta-currency | Kredits, plus Robux-purchased credit packs and gamepasses |
| Early-alpha note | The game description explicitly says “still in Early Alpha” |

The Roblox API still labels the experience as a “Deathmatch Shooter”, but the actual replicated mode and rules are **Counter-Strike-style bomb defusal**: two teams, buy phase, economy, plant/defuse, round win by elimination, time, defuse or detonation. Deathmatch code paths exist in a few generic modules (for example aim assist checks `Gamemode == "Deathmatch"`), but no Deathmatch configuration was present in `ReplicatedStorage/Shared/Data/GamemodesConfig` at capture.

---

## 2. What Kontra is

Kontra is a Roblox tactical FPS built around the classic CS loop: a **T** team tries to plant a bomb at one of two sites while **CT** tries to stop them, and the round can end by elimination, expiry, defuse or explosion. The game is Free-to-Play, 16-player, session-based, and cosmetic-monetised. Its title advertises stickers, and the meta-game is unusually deep for an alpha: weapon skins with wear/rarity, gloves, agents, badges, stickers, charms, music kits, graffiti, name tags, kill counters, cases, trade-up/fusing, an upgrader, a battlepass, daily/weekly challenges, playtime rewards, a daily market, promo codes, and Robux gamepasses.

Three things distinguish it from a typical Roblox shooter:

1. **Source-derived movement and gunplay.** The shared simulation implements `WalkMove`, `AirMove`, air-strafing, ducking, ladders, step-up/down, fall damage, spread/inaccuracy, deterministic recoil patterns, armor penetration and wallbangs.
2. **64-tick server-authoritative simulation with prediction and lag compensation.** The client sends input commands; the server simulates them, snapshots entities, and the client reconciles. Shots are rewound to the client’s render time for hit registration.
3. **A dedicated anti-cheat layer.** `Tattletale` fingerprints the Luau environment, guarded functions, canaries, GUIs and the camera, and reports a bitmask sealed with `TattleSeal`; the server is the authority, and the client is surrounded by rate limits, decoys and fog-of-war.

### 2.1 Player-facing loop

1. Join a server. A main-menu scene (a 3D `VertigoScene` backdrop with a case and character rig) is shown over the world.
2. Choose a team (`CT`, `T`, or spectator) and vote for a map. The server advertises a server list; team switching is limited so one side cannot exceed the other by more than one player.
3. Warmup (60 s, 10,000 starting cash) runs until the match starts. Map vote/team selection is processed in warmup.
4. Preparation (5 s) and the buy phase (45 s, overlapping the first 45 s of the round) begin.
5. Play a 135 s round. T can plant; CT can defuse. The bomb fuse is 40 s.
6. Round ends on elimination, time, defuse or detonation; 5 s later the next round starts, with cash rewards and loss-streak adjustments.
7. First team to 8 round wins takes the match (max 15 rounds). A 20 s match-end screen shows stats and awards.
8. Kredits and progression are credited, and the player returns to the menu/server flow.

Casual mode is deliberately forgiving: **free Kevlar + helmet** and a **free defuse kit** for CT on every spawn, a 45-second buy window, and generous loss bonuses. The competitive pressure comes from the round economy and the weapon buy ladder, not from armor management.

### 2.2 What “STICKERS!” means in practice

Stickers are a full cosmetic category, not a one-off gimmick. The `ItemManager` contains a `Stickers` category with 31 sticker definitions (paper/holo variants, event stickers, team stickers, meme stickers), plus an `ApplySticker` / `RemoveSticker` network flow and a Sticker Capsule container. Stickers are applied to weapon skins and are part of the same inventory/economy as cases, gloves, agents and charms.

---

## 3. The match loop and rules

All of the following is from `ReplicatedStorage/Shared/Data/GamemodesConfig/Casual` (`0279_...Casual.lua`), the round-state enums in `Shared/Utility/Enums`, and the live `GameStats` configuration.

### 3.1 Round states

`Enums.RoundStates`:

`Warmup → Preparation → RoundTime → (BombPlanted) → RoundEnded → MatchEnded → Restart`

with `BombDefused` and `BombExploded` as terminal round outcomes and `Restart` for a server-initiated reset.

`SubRoundStates`: `BuyTime`, `WarmupBuyTimer`, `Nothing`.

The live `GameStats` attributes drive the HUD and buying:

- `State` — current `RoundState`
- `Time` — seconds left in the current state
- `BuyTime` — seconds left to buy
- `CanBuy` — whether buying is currently permitted
- `CTWins`, `TWins`, `CTLoseStreak`, `TLoseStreak`
- `Map`, `Gamemode`, `MapVote`
- `ServerRegion`, `KreditsBoost`

### 3.2 Exact timers

| State | Seconds |
|---|---:|
| Warmup | 60 |
| Preparation | 5 |
| RoundTime | 135 |
| RoundEnded | 5 |
| MatchEnded | 20 |
| BombPlanted | 40 |
| BombDefused | 5 |
| BombExploded | 5 |
| Restart | 1 |
| **BuyTime sub-state** | **45** |
| Warmup buy timer | `-1` (unlimited) |

### 3.3 Win conditions

| Condition | Winner | Cash |
|---|---|---|
| Eliminate all enemies | surviving team | 2,700 each |
| Time expires | CT | 2,700 each |
| Bomb defused | CT | 2,700 each |
| Bomb explodes | T | 2,700 each |
| First to 8 rounds | match winner | Kredits at match end |

`RoundsToWin = 8`, `MaxRounds = 15`. There is no halftime/team-swap logic in the replicated rules; teams remain fixed for the match unless an admin changes them. Spawn protection lasts **3 seconds**. Friendly fire is disabled (`Damage.Teammate = false`); the configured friendly-fire scale is 0.1 for bullets and 0.25 for grenades if it is ever enabled.

### 3.4 End-of-match awards

`Enums.MatchClasses` contains 40+ performance labels used for the match-end screen, including:

`Clutch King`, `Most valuable MVP`, `Workhorse`, `Carry`, `Score Master`, `Scorer`, `Valuable Player`, `Pain Train`, `Assassin`, `Sharpshooter`, `Sniper`, `Gunslinger`, `Sidearm`, `Ace of Aces`, `Ace in the Hole`, `Quadkiller`, `Quad`, `Trifecta`, `Triple`, `Entry Fragger`, `Quick Draw`, `Weapons Master`, `Weapons Trainer`, `Wall`, `Interference`, `Executioner`, `Fragger`, `Mercenary`, `Bounty Hunter`, `Bullseye`, `Tenderizer`, `Assistant`, `Old Timer`, `Ancient`, `Die Hard`, `Survivalist`, `Big Spender`, `Scavenger`, `Spender`, `Frugalist`, `Bruiser`, `Reservist`, `Armchair General`.

The MVP/badge UI is `GameClient/Gui/HUD/MVP` (575 lines) and `MatchEnd` (1,468 lines).

### 3.5 Team limits and spectators

- `TeamLimitEnabled = true`.
- Joining a team is blocked if it would make that team more than one player larger than the other.
- `Spectator` is a valid team value.
- The server has a votekick system (`Votekick` configuration + `VoteForMap` / `VotekickPlayer` GUI events), with an admin `votekick_immunity` switch.
- `CloseServer`, `Restart`, `SetState`, `SetTime`, `SetScore` and `ChangeMap` are admin-console commands, not client controls.

---

## 4. Economy and buying

### 4.1 Match cash

From `Casual.MoneySettings`:

| Setting | Value |
|---|---:|
| Starting cash | 1,000 |
| Maximum cash | 10,000 |
| Warmup cash | 10,000 |
| Team elimination | 2,700 |
| Time win (CT) | 2,700 |
| Bomb defused (CT) | 2,700 |
| Bomb exploded (T) | 2,700 |
| Bomb plant bonus | 300 |
| Bomb defuse bonus | 300 |
| Kill award multiplier | ×0.5 |

Loss-streak table (both teams), with a T bomb-plant bonus:

| Consecutive losses | Loss bonus | T bomb-plant bonus |
|---:|---:|---:|
| 1 | 1,400 | 800 |
| 2 | 1,900 | 800 |
| 3 | 2,400 | 800 |
| 4 | 2,900 | 800 |
| 5+ | 3,400 | 800 |

Weapons also carry a `KillAward` stat. Base values:

| Weapon class | Base kill award |
|---|---:|
| Rifles, pistols, SSG-08, G3SG1, SCAR-20 | 300 |
| SMGs | 600 |
| Shotguns | 900 |
| AWP | 100 |
| Knife/melee | 1,500 |
| Bomb (plant weapon) | 300 |

The mode’s `KillAwardMultiplier = 0.5` scales the applied award; the exact final cash is server-side, but the base table is fully replicated.

### 4.2 Buying

Buying is only allowed inside a buy zone (`GameConfiguration.BuyZone.Anywhere = false`) and only during the buy window. The HUD buy menu is `GameClient/Gui/HUD/Buymenu` (2,163 lines). Categories and hotkeys:

| Key | Category |
|---|---|
| 1 | Equipment |
| 2 | Pistols |
| 3 | MidTier (SMGs/shotguns) |
| 4 | Rifles |
| 5 | Grenades |

**Equipment**

| Item | Price | Notes |
|---|---:|---|
| Kevlar Vest | 650 | Armor 100; redundant in Casual because armor is free |
| Kevlar & Helmet | 1,000 | Helmet upgrade; redundant in Casual |
| Zeus Laser | — | Listed in the UI; no replicated item/weapon definition found |
| Rescue Kit | 400 | CT only; T has no Rescue Kit slot |

Because `FreeArmor = true` and `FreeDefuseKit = true`, every spawn in Casual receives 100 armor, a helmet, and (on CT) a defuse kit via `WeaponConstructor.GiveFreeEquipment`. The armor purchases are therefore legacy/competitive-mode entries.

**Weapons**

The weapon catalog is `ReplicatedStorage/Shared/Managers/WeaponManager` (41 definitions). Prices in the full table in [§9](#9-combat-and-weapons). The intended ladder is:

- **Pistols:** $200 starting pistols, $300–500 mid pistols, $700 Desert Eagle.
- **SMGs/shotguns:** $1,050–2,350.
- **Rifles:** $1,800 Galil / $1,950 FAMAS up to $2,700 AK-47, $2,900 M4s, $3,000 SG 553, $3,300 AUG, $4,750 AWP, $5,000 autosnipers.
- **Utility:** grenades are listed in the buy menu and the mode defines grenade limits, but **no grenade item/entity implementation was present in the replicated content** at capture. The same applies to the Zeus Laser. Treat those buttons as unreleased/placeholder content.

**Selling/refund/drop**

The weapon events include `BuyWeapon`, `RefundWeapon`, `PickUpWeapon`, `OnWeaponPickup`, `Drop` (via the command/weapon state), and `ForceEquip`. The buy function has a `Drop` argument (`Buy(..., true)`), so a player can buy a weapon for a teammate and drop it. Refunds are server-validated.

### 4.3 Kredits (meta-currency)

`Casual.KreditsAward`:

| Reward | Amount |
|---|---:|
| Win | 30 |
| Loss | 15 |
| MVP | +5 |
| MVP cap | 3 × 5 = +15 |
| Minimum players in match | 4 |
| Minimum damage | 50 |
| Minimum rounds played | 3 |

A player who leaves early, does under 50 damage, plays fewer than 3 rounds, or is in a match with fewer than 4 players does not receive the match Kredits. `KreditsBoost` is a multiplier attribute (observed `1`); gamepasses/events can raise it. The store also sells credit packs with bonus amounts and a limited pack that includes a gold Balisong.

---

## 5. Maps and world structure

### 5.1 Map pool and selection

`Casual.MapPool`:

1. `de_vertigo`
2. `de_seaside`
3. `de_dust2`

The live server uses a **map vote** stored as JSON in `GameStats.MapVote`. At capture:

```json
{
  "de_vertigo": { "Votes": 1 },
  "de_seaside": { "Votes": 7 }
}
```

`de_seaside` won and was loaded. `VoteForMap` / `SelectMapPreset` are client→server GUI events; the server tallies and calls `ChangeMap`.

`ReplicatedStorage/Assets/Preload` also contains `Baseplate` and `skrudge` string values, but those are not in the Casual map pool.

### 5.2 `de_seaside` (captured map)

Runtime data from `workspace.Map`:

| Property | Value |
|---|---|
| Bounds | min `(-784, -80, -780)`, max `(660, 282, 807)` |
| Size | **1,443 × 361 × 1,586 studs** |
| Buy zones | CT at `(-157, -6, -14)`, T at `(57, 14, 52)` |
| Plant volumes | A site around `(-174, 8, -76)`; B site around `(-187, 1, 106)` |
| Spawn points | 15 CT + 15 T at capture |
| Radar part | 376.96 × 1 × 376.96, attribute `Radar=rbxassetid://101589784604492` |
| Lighting | `ClockTime 9.6`, `FogEnd 10000`, `FogStart 150`, `Brightness 4`, `GeographicLatitude 221` |
| Map modules | `Modifications` (client water), `PVSCells` |

The zone folders (`Zones/Plants`, `Zones/Detects`, `Zones/BuyZones`, `Zones/Kill`) are rebuilt with the map/round; the number of detect volumes varies between loads (dozens of small `PlantDetectA/B` parts). The stable layout is a two-site seaside town: CT spawn/buy to the west, T spawn/buy to the east, A site north-west and B site south-west of the CT side.

`de_seaside` has a client-side `Water` modification module (`Assets/Maps/de_seaside/Modifications/Client/Water`) and PVS cell modules. The loaded world had **15,758 descendants** under `Geometry`, with 13,429 `Part`s, 1,084 `Model`s, 863 `WedgePart`s, 134 `MeshPart`s and 92 `UnionOperation`s at capture. That is much larger than the authored asset folder (1,433 descendants / 1,211 parts): the runtime builds/duplicates collision geometry from the compact map representation.

### 5.3 `de_dust2`

Authored asset contents at capture:

| Class | Count |
|---|---:|
| Descendants | 6,229 |
| `Part` | 4,198 |
| `WedgePart` | 1,528 |
| `MeshPart` | 3 |
| `UnionOperation` | 5 |
| `Model` | 411 |

This is the classic desert two-site map: long A, tunnels, mid, B site, and the usual connector/CT rotations. It has `PVSCells` and `PotatoSettings`, but no `Modifications` folder.

### 5.4 `de_vertigo`

Authored asset contents at capture:

| Class | Count |
|---|---:|
| Descendants | 1,555 |
| `Part` | 960 |
| `WedgePart` | 73 |
| `MeshPart` | 53 |
| `UnionOperation` | 0 |
| `Model` | 12 |

`de_vertigo` is the vertical rooftop construction-site map. It has a `Modifications` folder containing a client `Fan` module and `PVSCells`. The main-menu backdrop is a separate `Workspace/Scene/VertigoScene` built from this theme.

### 5.5 Map loading and client adaptation

When the server changes the map, it fires the Blink `OnMapAdded` / `OnMapRemoving` signals. `ClientModules/NewMapAdded` (315 lines) and its `MapLighting` (1,400), `MapAmbience` (241), `MapAmbience/Zones` (1,272) modules:

- apply per-map lighting/ambience presets,
- load `Modifications` modules (water, fans, etc.),
- rebuild zone visuals/debug geometry,
- refresh the radar and PVS data,
- adjust `Lighting`/atmosphere for the map’s time of day.

The player can override each map’s lighting through the Settings “Maps” tab, which exposes **54 options per map** (color correction, clouds, sun rays, diffuse scale, fog, time override, potato-mode environment, etc.). These are stored in `PlayerSettings.Maps[mapName]`.

### 5.6 Visibility: PVS and FOW

Each map carries `PVSCells` modules (baked potentially-visible-set data). `GameConfiguration.FOW` at capture:

| Setting | Value |
|---|---|
| Enabled | `true` |
| CullDroppedWeapons | `false` |
| PvsOnly | `false` |
| Pvs | `false` |
| BudgetMs | 4 |
| HoldMs | 1,000 |
| MaxResultAgeMs | 400 |
| FilterTeammates | `false` |
| FilterTeammateCosmetics | `false` |
| ReuseEpsilon | 0.01 |
| HiddenRefreshTicks | 1 |
| Workers | 1 |
| WorkerBudgetMs | 8 |
| WorkerTimeoutMs | 250 |
| MaxPairsPerJob | 96 |
| ShoulderBase | 0 |
| ShoulderRttScalePerMs | 0.044416 |
| ShoulderCap | 0 |
| TargetLeadMs | 50 |

So PVS data exists, but the active FOW configuration currently disables the PVS-only path and uses runtime visibility work (raycasts/occlusion) with a 4 ms budget, 1 s result hold, and one worker. Teammates are never filtered. The `Radar` configuration (`ReplicatedStorage/Radar`) mirrors this with `Pvs = false`.

The client radar (`Gui/HUD/Radar`, 1,571 lines) respects `FogCulled`: when an entity’s newest snapshot is fog-culled, the radar falls back to the **last known position** rather than the live position. This is an anti-wallhack measure. Whether the server also withholds the true position from the snapshot is not verifiable from the client alone; the flag and fallback are visible, the server’s culling implementation is not.

The `Map/Geometry` duplication and PVS blobs are also used by the collision builder: `Shared/CollisionModule/CollisionBuilder` can convert triangle/part data into collision primitives for the custom movement solver.

## 6. Technical architecture

### 6.1 Place layout

The client sees this high-level tree (trimmed):

```text
ReplicatedStorage/
├─ BLINK_RELIABLE_REMOTE            RemoteEvent
├─ BLINK_UNRELIABLE_REMOTE          UnreliableRemoteEvent
├─ BLINK_RELIABLE_FRAGMENT_REMOTE   RemoteEvent
├─ BLINK_UNRELIABLE_FRAGMENT_REMOTE UnreliableRemoteEvent
├─ Handler/                         Actor
│  └─ Loader                        Script (RunContext.Client)
├─ Shared/                          541 ModuleScripts, 283,108 lines
│  ├─ Blink/{Client, Server, Types}
│  ├─ Simulation, Movement, Collision
│  ├─ WeaponConstructor/{Bullet, Types/*}
│  ├─ Managers/{WeaponManager, ItemManager, SkinManager, SoundManager, AnimationManager}
│  ├─ Data/{GamemodesConfig/*, SettingsData, GamepassesData, CreditsPrices, ...}
│  ├─ ConsoleShared, Roles, TattleSeal
│  └─ GameConfiguration, DamageCalculation, ...
├─ GameClient/                      101 ModuleScripts, 113,398 lines
│  ├─ CameraController/*
│  ├─ CharacterController/*
│  ├─ WeaponController, Interaction, Spectate, Ragdoll, KillPrediction
│  ├─ Entities/*
│  ├─ InventoryData, ProfileData
│  └─ Gui/{HUD, MainMenu, MatchEnd}
├─ ClientModules/                    11 ModuleScripts, 6,237 lines
│  ├─ NewMapAdded/{MapLighting, MapAmbience, Zones}
│  └─ ClientModule
├─ Assets/                           maps, rigs, animations, viewmodels, effects
├─ Radar/                            Configuration (FOW/PVS/radar tuning)
├─ GameStats/                        Configuration (live match state)
├─ Votekick/                         Configuration
├─ ClientIntegrity/                  Folder + IntegrityValidate BindableEvent (created at runtime)
└─ 17 decoy remotes named GiveMoney, SilentAim, ...
Workspace/
├─ Map/{Geometry, Zones, Spawns, Radar, Modifications, LightingSettings}
├─ Characters/
├─ Debris/{Bomb, DroppedWeapons, BulletHoles, Tracers, ...}
├─ Ragdolls/
├─ Scene/{VertigoScene, Case, Rig, LightingSettings}
└─ Camera, Root
```

`ServerScriptService`, `ServerStorage` and `StarterPlayer` are not visible from the client beyond replicated child instances. `Shared/Roles` references `ServerScriptService.GameServer.RoleList`, confirming that the real server code lives there and is not replicated.

### 6.2 The loader

`ReplicatedStorage/Handler/Loader` is a `Script` with `RunContext = Client`, 236 lines. It is the entire client bootstrap:

1. Waits for `ReplicatedStorage.Shared`, `GameClient`, and `ClientModules`.
2. Recursively finds every `ModuleScript`.
3. Skips a hard-coded set (`Server`, `Types`, `MinkowskiSumInstance`, `QuickHull2`, `TrianglePart`, `Writer`, `Reader`, `Sizes`, `Crunchyroll`), everything under `Gui` and `Assets/Maps`, `WeaponConfig`, modules whose parent is `BufferScheme`/`Crunchyroll`/`AnimationManager`, and descendants of each direct child of `Shared/Managers`.
4. Requires each surviving module in dependency order, storing it by name.
5. Calls `Init(loader)`, then `Start(loader)`, then `Start2(loader)` on every module that defines them.
6. Makes the shared loader/registry available to all modules.

The loader also renames the shared `Client` module to `Network` before wiring, which is why the netcode is referred to as `Network.*` in game code (`Network.Character.Command`, `Network.Entity.AckSnapshot`, `Network.Anticheat.Tattle`, etc.).

There is an **uncalled `Scramble()` function** in the loader. It would randomize the names of remotes, services and modules at startup. It is not invoked in the observed build: all remote and service names are stable and human-readable. This is presumably an unfinished anti-exploit measure.

`StarterPlayerScripts/DisableRobloxStuff` is a separate `LocalScript` (2,683 bytes) that disables Roblox core UI — backpack, player list, chat, health, etc. — so the game can render its own HUD without Roblox chrome.

### 6.3 Module statistics

| Namespace | Files | Lines |
|---|---:|---:|
| `ReplicatedStorage/Shared` | 541 | 283,108 |
| `ReplicatedStorage/GameClient` | 101 | 113,398 |
| `ReplicatedStorage/ClientModules` | 11 | 6,237 |
| `ReplicatedStorage/Assets` | 1 | 159 |
| **Total indexed client modules** | **654** | **402,902** |

The largest client modules:

| Lines | Module |
|---:|---|
| 13,912 | `Shared/Blink/Client` — full Blink client codec, event registry, reliable/unreliable channels |
| 7,869 | `GameClient/Gui/MainMenu/SideSection/Settings` |
| 5,423 | `Shared/ProjectDecal/Primitives` |
| 4,391 | `GameClient/Gui/MainMenu/SideSection/Analytics/MatchesWeaponStats` |
| 4,346 | `.../Analytics/MatchesTimeline` |
| 4,223 | `.../Analytics/MatchesScoreboard` |
| 4,181 | `GameClient/Gui/MainMenu/MainSection/Store` |
| 3,998 | `GameClient/Gui/MainMenu/MainSection/Loadout` |
| 3,861 | `GameClient/Gui/MainMenu/Utils/Inspect` |
| 3,619 | `Shared/ConsoleShared` |
| 3,606 | `Shared/Data/SettingsData` |

Directly decompiled “extra” modules add another 590 files, including:

| Lines | Module |
|---:|---|
| 30,349 | `Shared/Blink/Server` — server-side Blink transport/event schema (~1.07 MB) |
| — | `Shared/Blink/Types` (~21 KB) |
| — | `Shared/CollisionModule/CollisionBuilder/TrianglePart`, map water/fan modifications, TradeUp, Achievements, Battlepass |

The Blink **server** and **types** modules are `ModuleScript`s inside `ReplicatedStorage/Shared/Blink`. They are skipped by the client loader but are still replicated to clients. That means the entire server transport layer (event schema, packet codec, rate limits) is readable by any client; only the game logic that consumes it is server-side. This is common in Roblox but is a meaningful information leak.

### 6.4 Client architecture

The `GameClient` tree is organized by feature, not by a single controller monolith:

- **`CharacterController`** — input sampling, command building, networking, reconciliation, camera controller, interaction, spectate, physics, footsteps, ragdoll, kill prediction, binds.
- **`WeaponController`** — weapon state, viewmodel, firing, reloading, alt-fire, inspection, effects.
- **`Entities`** — client-side entity wrappers for `Character`, `DroppedWeapon`, `Bomb`, plus snapshot interpolation and visibility.
- **`CameraController`** — `CameraInput`, `PlayerCamera`, `FollowCamera`, `Freecam`, `MobileAimAssist`, FOV/zoom, viewmodel.
- **`InventoryData` / `ProfileData`** — cosmetic inventory/equipment cache and profile/badge data.
- **`Gui`** — `HUD`, `MainMenu`, `MatchEnd`.

The **Shared** tree is where the real game rules live: `Simulation`, `Movement`, `Collision`, `WeaponConstructor`, `DamageCalculation`, `GameConfiguration`, `Data/GamemodesConfig`, `Managers` and `Blink`. The server and client run the same shared simulation code; the server is authoritative over what is accepted.

`ClientModules` is small but important: `NewMapAdded` and its lighting/ambience/zone submodules perform presentation-only map setup after `OnMapAdded`. `ClientModule` is the base class.

**Systems map.** “Authority” is inferred from the accepted events and replicated state; the actual server scripts are not visible.

| System | Authority | Primary modules |
|---|---|---|
| Round/match state | server | `Shared/Data/GamemodesConfig/Casual`, `GameStats`, `Gui/HUD/TopBar`, `Gui/MatchEnd` |
| Map loading | server picks/loads; client presents | `Workspace.Map`, `ClientModules/NewMapAdded`, map `Modifications` |
| Movement | shared simulation, server accepts | `Shared/Simulation`, `Simulation/Movement`, `Simulation/Collision`, `GameClient/CharacterController` |
| Camera / aim | client, validated for FOV | `GameClient/CameraController`, `CameraInput`, `PlayerCamera`, `MobileAimAssist`, `Shared/Simulation/Camera` |
| Weapon state / firing | shared logic, server validates | `Shared/WeaponConstructor`, `Types/GunWeapon`, `GameClient/WeaponController` |
| Bullets / damage | server authoritative, client effects | `Shared/WeaponConstructor/Bullet`, `Shared/DamageCalculation`, `GameClient/WeaponEffects`, `Gui/HUD/DamageIndicator` |
| Networking | client ↔ server | `Shared/Blink/Client`, `Shared/Blink/Server`, four Blink remotes |
| Anti-cheat | client detection, server enforcement | `GameClient/Tattletale`, `Shared/TattleSeal`, `Radar`, FOW, shot rejection |
| Economy / buying | server | `Casual` money rules, `Gui/HUD/Buymenu`, `Weapon.BuyWeapon` |
| Cosmetics / inventory | server persistence, client cache | `Managers/ItemManager`, `Managers/SkinManager`, `GameClient/InventoryData`, store/inventory UI |
| HUD / menus | client | `GameClient/Gui/HUD`, `Gui/MainMenu`, `Gui/MatchEnd` |
| Admin console | server-gated | `Shared/ConsoleShared`, `Shared/Roles`, `Gui/HUD/Console` |

### 6.5 Load order and startup

Typical startup sequence:

1. `Loader` runs, requires modules, calls `Init`.
2. Configuration modules subscribe to `GameConfiguration.Updated` and build frozen lookup tables (weapons, skins, items, settings, animations).
3. `Blink.Client` connects the four remotes and builds the event codec.
4. `Tattletale` installs canaries, snapshots guarded functions, creates `ClientIntegrity/IntegrityValidate`, and starts its report loop.
5. `CharacterController` and `CameraController` bind input, create the local simulation, and wait for `CreateCharacter`.
6. `Gui` creates the main menu.
7. The client fires `PlayerLoaded`; once the match starts, the server sends `StartGameRunning`, the map, and entity/character events; the client tears down the menu and builds the HUD.
8. On `OnMapAdded`, `NewMapAdded` applies lighting/ambience and map modifications.
9. On character creation, the client starts predicting movement, building commands, and running the weapon/camera stack.

`GameConfiguration.IsRunning` and `GameStats.State` gate most gameplay modules; the main menu is a separate scene/UI state.

---

## 7. Networking: Blink

Kontra does **not** rely on Roblox `RemoteEvent`s for gameplay. It uses **Blink**, a custom binary transport with its own event schema, sequencing, fragmentation and rate limits. The only Roblox remotes in `ReplicatedStorage` are the four Blink channels plus the decoys.

### 7.1 The four remotes

| Remote | Class | Purpose |
|---|---|---|
| `BLINK_RELIABLE_REMOTE` | `RemoteEvent` | ordered, reliable gameplay/UI events |
| `BLINK_UNRELIABLE_REMOTE` | `UnreliableRemoteEvent` | high-frequency, loss-tolerant events |
| `BLINK_RELIABLE_FRAGMENT_REMOTE` | `RemoteEvent` | fragments of reliable packets too large for one remote call |
| `BLINK_UNRELIABLE_FRAGMENT_REMOTE` | `UnreliableRemoteEvent` | fragments of unreliable packets |

`Shared/Blink/Client` is 13,912 lines; `Shared/Blink/Server` is 30,349 lines. The codec is generated from an event schema: each event has a writer/reader, field types, defaults, validation, and a per-event rate limit. Packets carry packet IDs, sequence numbers and payload lengths so the receiver can discard duplicates/out-of-order/unreliable stragglers and reassemble fragments.

Supported value types include:

- unsigned/signed integers (`u8`, `u16`, `u32`, varints),
- `float32`/`float64`,
- booleans, strings, buffers,
- `Vector2`/`Vector3`/`CFrame` (quantized),
- arrays/dictionaries and nested tables,
- `Instance` references,
- delta-encoded snapshots.

The protocol is binary and compact, but **not encrypted or authenticated** in a cryptographic sense. `TattleSeal` seals the anti-cheat report, not the gameplay channel.

### 7.2 Event schema

The registry contains **130 grouped events**:

| Group | Count | Examples |
|---|---:|---|
| `Player` | 2 | `PlayerLoaded`, `StartGameRunning` |
| `Character` | 9 | `CharacterConstantBalls`, `CharacterTemplateBalls`, `CreateCharacter`, `DestroyCharacter`, `Command`, `CommandIdle`, `CommandArray`, `HandleNewState`, `SimulationProperty` |
| `Weapon` | 10 | `CreateWeapon`, `DestroyWeapon`, `BuyWeapon`, `PickUpWeapon`, `RefundWeapon`, `ForceEquip`, `OnWeaponPickup`, `WeaponReset`, `Constant`, `Template` |
| `Gui` | 87 | buying, inventory, store, cases, settings, chat, voting, match stats, battlepass, challenges, etc. |
| `Entity` | 11 | `RequestFullUpdate`, `AckSnapshot`, `EntityVisibility`, `CreateEntity`, `DestroyEntity`, `OnPlayerConnected`, `EntitySnapshot`, `CharacterCurrentWeapon`, `CharacterWeaponInventorySlot`, `CharacterCurrentWeaponInventoryData`, `CharacterDeath` |
| `Particles` | 3 | `CreateBulletHole`, `CreateTracer`, `CreateRagdoll` |
| `Spectate` | 5 | `SpectatePosition`, `SpectateIdentifier`, `SpectateData`, `AckSpectate`, `SpectateTarget` |
| `Debug` | 2 | `ShotMarker`, `ServerShot` |
| `Anticheat` | 1 | `Tattle` |

There are also **17 top-level signal events** with no group count:

`ConfigChanged`, `Console`, `ConsoleServer`, `ServerTick`, `ClientPing`, `ServerPing`, `OnMapAdded`, `OnMapRemoving`, `RoundReset`, `RadarLeak`, `PlaySoundOnPosition`, `PlayFootstepSoundOnPosition`, `NetworkDebugStats`, `ServerPerformanceStats`, `NetworkDebugEnabled`, `SimulationConstants`, `GenerateCollision`.

Of these, `Console`, `ClientPing` and `NetworkDebugEnabled` are client→server; the other 14 are server→client. The exact direction flags, group membership and field schemas are in [`dumps/protocol.json`](dumps/protocol.json).

`Gui` is by far the largest group (87 events) because every menu action — buying a weapon, opening a case, equipping a skin, applying a sticker, voting, reporting, setting a keybind — is a typed Blink event rather than a Roblox `RemoteEvent`.

### 7.3 Rate limits

Rate limits are per event and per client, counted in one-second windows. Selected limits from the server dispatch code:

| Event | Limit |
|---|---:|
| `Player.PlayerLoaded` | 1/s |
| `Character.Command` | 300/s |
| `Character.CommandIdle` | 300/s |
| `Character.CommandArray` | 300/s |
| `Entity.AckSnapshot` | 500/s |
| `Spectate.SpectatePosition` | 20/s |
| `Anticheat.Tattle` | 5/s |
| `Weapon.BuyWeapon` | 5/s |
| `ClientPing` (top-level) | 500/s |
| `Gui.ChangePlayerSetting` | 30/s |
| `Gui.ResetPlayerSettings` | 240/s |
| `Gui.UseStarCode` | 240/s |
| `Gui.ViewmodelPreset` | 240/s |
| `Gui.SendMessage` | 15/s |
| `Gui.VoteForMap` | 15/s |

All **67** parsed per-event limits are in [`dumps/protocol.json`](dumps/protocol.json) under `rate_limits`. Exceeding a limit drops the packet and logs a warning; repeated abuse is a server-side moderation signal (not shown to the client).

### 7.4 Command pipeline (client → server)

Every simulation tick the client builds a **user command** from input and camera state. The important fields observed in `BufferScheme` and `Blink` are:

| Field | Meaning |
|---|---|
| `Forward`, `Backward`, `Left`, `Right` | movement wish direction |
| `Duck`, `Walk`, `Jump`, `PressE`, `Ping` | action buttons |
| `Yaw`, `Pitch` | camera angles, quantized to 16 bits (0–65535) |
| `ClientTick` | client simulation tick |
| `ServerTick` | last known server tick |
| `RenderTime` | client render timestamp used for lag compensation |
| `ReceivedMask` | which server states/events the command was built against |
| `WishEquip`, `ResetAck`, `WishBooleans` | weapon/equip intent and ack bookkeeping |

The client can pack up to **30 commands** into one `CommandArray` packet. It processes at most **7 commands per frame**, keeps a **4-command backup**, resends unacknowledged commands for **32 ticks**, and processes at most **12 user commands per server tick**. When no input is present it can send idle commands at **10/s**. Ping sampling runs every **64 ticks** with **16 samples**.

Shots are part of the weapon command stream, not a separate “fire” remote. A shot command is resent up to **16 times** until acknowledged; the server deduplicates by tick/shot index.

### 7.5 Snapshots (server → client)

The server sends entity snapshots over Blink with delta compression:

| Setting | Value |
|---|---|
| `SnapshotAckEvery` | 3 ticks |
| `InterpolationIntervals` | 3 ticks |
| `ClientHistorySeconds` | 1.25 s |
| `ClientHistoryMinSnapshots` | 32 |
| `SnapshotTimeout` | 0.5 s |
| `MaxExtrapolation` | 0 |
| `IdleSnapshotIntervals` | 1.5 |
| `ClockResyncThreshold` | 0.25 s |
| `ClockDriftStep` | 0.001 |
| `MaxHeadroom` | 0.125 |
| `HeadroomDecay` | 0.08 |
| `MathHitboxes` | true |

The client acknowledges every third snapshot (`AckSnapshot`). It holds at least 32 snapshots (or 1.25 s) for interpolation and lag-compensation queries. Interpolation is 3 ticks behind the server, which hides jitter at the cost of a small constant delay. No extrapolation is allowed (`MaxExtrapolation = 0`), so a dropped snapshot freezes rather than predicts through it.

### 7.6 Reconciliation

The client predicts its own character from the same command stream. When a server `HandleNewState` arrives, `CharacterReconciliation` compares the authoritative state with the predicted state at the acknowledged tick:

1. Discard acknowledged commands from the local queue.
2. Re-apply the server state.
3. Re-simulate all unacknowledged commands.
4. Compute a visual `MispredictionOffset` and blend it out over a short interval.

`CalculateMisprediction` clamps the correction between **0.1 and 4.4416 studs**. The lower bound prevents micro-jitter; the upper bound prevents a single bad snapshot from teleporting the camera. The camera renders the offset separately (`PlayerCamera.Update`), so the character/camera do not snap.

### 7.7 Lag compensation

Each command carries `RenderTime`. When the server processes a shot it calls the character/entity history:

```text
PushEntitiesToTime(..., RenderTime)
```

and traces against the rewound hitboxes. The client keeps 1.25 s / 32 snapshots; the server keeps its own equivalent history (not replicated). `MathHitboxes = true` means the server can use mathematical primitive hitboxes instead of the visual R15 parts, which is faster and less sensitive to animation state.

The shot telemetry fields exposed to the client confirm the model:

| Field | Meaning |
|---|---|
| `ShotRewindMs` | how far the server rewound for this shot |
| `ShotPingMs` | measured RTT at shot time |
| `ShotJitterMs` | RTT jitter estimate |
| `SpreadSeedReplaced` | server replaced the client’s spread seed (anti-cheat/manipulation signal) |
| `ShotRejectReason` | why a hit was rejected |

`ShotRejectReason` values observed in `Gui/Misc/Stats`:

`spawn protection`, `attacker dead`, `victim dead`, `teammate`, `no armor state`, `zero after armor`, `health unchanged`, `no character`, `no HitPoints`.

These are exactly the server-side validation gates: a shot can be traced and still rejected before damage if the attacker/victim is dead, spawn-protected, a teammate, missing character/hitpoints, or the damage calculation yields no health change.

### 7.8 Clock sync, ping and server browser

- `ServerTick` is broadcast; the client estimates server time and maintains a clock offset.
- `ClientPing` / `ServerPing` measure RTT; `PingCheckTime = 64`, `PingDataAmount = 16`.
- `Gui.RequestServerList` / `ServerListResult` power the server browser; `Gui.Ping` reports a player’s ping for display.
- `Gui.RequestMatch` / `MatchData` fetch match metadata for the menu/analytics.
- `OnMapAdded` / `OnMapRemoving` synchronize map state.
- `RoundReset` tells clients to clear per-round predictions/effects.
- `RadarLeak` is a controlled temporary radar reveal (used by certain game events/items); it is distinct from FOW.

### 7.9 Why use Blink?

The custom layer provides:

- compact binary payloads (important at 64 Hz with 16 players),
- per-event versioning and validation,
- reliable + unreliable channels,
- fragmentation for large UI/inventory payloads,
- rate limiting at the event level,
- a single choke point for anti-cheat telemetry and server logging,
- independence from Roblox’s default remote ordering/queue behaviour.

The trade-off is that every event schema and handler is code the client can decompile, and the server transport module is replicated. Blink is efficient, not secret.

---

## 8. Simulation, movement and prediction

### 8.1 Tick model

| Setting | Value |
|---|---|
| `TickRate` | 64 Hz |
| `MaxTickRate` | 240 |
| `TimeScale` | 1 |
| `LegSolveTicks` | 3 |
| `MaxCommandsPerFrame` | 7 |
| `MaxUserCmdProcessTicks` | 12 |
| `MaxCommandSpeedThreshold` | 0.35 |
| `MaxTickDelta` | 0.2 s |

The server and client both run the shared `Simulation` at 64 ticks per second. The client may render at a higher frame rate and build commands per frame; the simulation consumes them at the fixed tick. `MaxTickRate = 240` is a catch-up ceiling, not the gameplay rate.

### 8.2 Movement constants

`Shared/Simulation/Config` (`0487_...Config.lua`):

| Constant | Value |
|---|---:|
| `MaxSpeed` | 20.044 |
| `MaxVelocity` | 224.616 |
| `Speed` | 16.044 |
| `StopSpeed` | 5.552 |
| `JumpImpulse` | 20.9583404332 |
| `Friction` | 5.5 |
| `Acceleration` | 5.72 |
| `AirAcceleration` | 12 |
| `MaxAirStrafeSpeed` | 2.082 |
| `Gravity` | 58.7 |
| `LadderSpeed` | 13.88 |
| `LadderJumpOffSpeed` | 18.738 |
| `LadderDampen` | 0.2 |
| `LadderSpeedScale` | 0.78 |
| `LadderModifier` | 0.34 |
| `LadderRangeGrab` | 0.1388 |
| `LadderRangeClimbing` | 0.6940 |
| `StaminaMax` | 80 |
| `StaminaRecoveryRate` | 60 |
| `StaminaJumpCost` | 1.1527 |
| `StaminaLandCost` | 0.7205 |
| `DuckModifier` | 0.34 |
| `WalkModifier` | 0.52 |
| `MaxDuckSpeed` | 8 |
| `MinDuckSpeed` | 1.5 |
| `DuckCooldown` | 0.4 |
| `StandCameraOffset` | 2 |
| `MaxGroundSlope` | 0.7 |
| `StepSize` | `(0, 1.75, 0)` |
| `DefuseAngle` | 0.7 |
| `FlinchStackRecoveryRate` | 0.35 |

`GameConfiguration.Character`:

| Setting | Value |
|---|---|
| `StandCollisionSize` | `(2, 5, 2)` |
| `DuckCollisionSize` | `(2, 3.75, 2)` |
| `SolidPlayers` | false |
| `FallDamage` | true |
| `AutoBunnyHop` | false |
| `EnableBunnyHop` | false |
| `BunnyHopMaxSpeedFactor` | 1.1 |
| `ScopedAccelerationScale` | 1.0875 |
| `MaxFallingSpeed` | -120 |

This is a Source-style movement model scaled to Roblox studs:

- Ground acceleration/friction, a stop speed, and a separate air-acceleration model with an air-strafe cap.
- Jump impulse plus gravity; no automatic bunny hop and no bunny-hop enablement, so chaining jumps does not preserve/grow speed. Air-strafing still works within the 2.082 cap.
- Ducking shrinks the hull (5 → 3.75 studs), reduces speed through a duck-speed recovery curve, and has a cooldown.

**Air-strafe and “sub-tick”**

`AirMove` is the Source air-acceleration formula:

```text
addspeed  = min(2.082, wishspeed) - dot(velocity, wishdir)
accelspeed = min(addspeed, 12 * wishspeed * dt * (AirFrictionReduced and 0.65 or 1))
velocity  += accelspeed * wishdir
```

The networked command has only digital 8-way `Inputs` (`Forward`/`Backward`/`Left`/`Right`), `AdditionalInputs`, 16-bit `Yaw`/`Pitch`, `ClientTick`, `ServerTick`, and `RenderTime`. There is no analog `MoveX`/`MoveZ` field and no sub-tick movement timestamp; `RenderTime` is for shot/camera rewind. Every command is simulated at **1/64 s**. `MaxTickRate = 240` is a catch-up/history ceiling, not a second simulation rate. A CS2-style sub-tick strafer therefore has no input channel here; the equivalent is a tick-perfect auto-strafe that changes `Left`/`Right` and yaw once per 64 Hz command.

`EnableBunnyHop` and `AutoBunnyHop` are both `false`, so `CheckJumpButton` clamps takeoff horizontal speed to `18.044 * 1.1 = 19.8484`; a single jump can still gain speed through air-strafing, but jumps do not chain into CS-style bunny-hop acceleration. `Tattletale` guards `AirMove`/`WalkMove` themselves, not the player’s input pattern; an auto-strafe built from ordinary movement inputs does not trip those function checks. Server-side command/movement validation is the remaining unknown; `MaxCommandSpeedThreshold` exists in the replicated config, but its consumer is not in the client dump.
- Ladders have grab/climb ranges, a speed scale, jump-off impulse, and a short jump-ignore window.
- Step-up (1.75 studs), step-down, slope limit (0.7), hull broadphase and stuck checks.
- Fall damage and a terminal falling speed of -120.
- Stamina drains on jump/land and recovers at 60/s; it influences flinch/tagging but is not a conventional “sprint stamina” bar.
- `SolidPlayers = false`: players do not collide with each other, avoiding Roblox character-collision jank.

`Simulation` also drives:

- `ClampVelocity`, `WalkMove`, `AirMove`, `CheckJumpButton`, `FinishGravity`, `Duck`, `StartGravity`, `CheckFalling`, `FullNoClipMove`, `LadderMove`.
- `CategorizePosition`, ground checks, step-up/down, `ProjectVelocity`, `CheckStuck`, `UpdatePlayerHulls`.
- `Camera.BuildShotCFrame`, `BuildCameraCFrame`, `SetDuckedEyeOffset`, step-up smoothing.

These function names are explicitly guarded by `Tattletale` (`Movement`, `Simulation`, `Collision`), which tells you they are considered security-critical: if a cheat replaces `WalkMove`, `AirMove`, `Duck`, `BuildShotCFrame` or `ProcessCommand`, the client reports it.

### 8.3 Prediction and reconciliation

Client flow per frame:

1. Sample mouse/keyboard/gamepad/touch.
2. Update yaw/pitch and camera offsets.
3. Build a command with quantized angles, buttons, tick and render time.
4. Feed the command to the local simulation and store it in the pending queue.
5. Send it (or batch it) over Blink.
6. Apply weapon/camera/viewmodel effects from the predicted state.

Server flow per command:

1. Validate command age/rate/fields.
2. Apply the same movement/weapon simulation.
3. Resolve shots against rewound entities.
4. Send authoritative state/snapshot and shot telemetry.

Client reconciliation:

1. Receive `HandleNewState` with the last processed command.
2. Drop acknowledged commands.
3. Reset to server position/velocity/flags.
4. Re-run all pending commands.
5. Blend the prediction error out visually.

The 0.1–4.4416 stud clamp and the 3-tick interpolation delay are the two main anti-jitter mechanisms. The client’s camera is deliberately decoupled from the corrected character position during the blend, so a correction does not produce a visible snap.

### 8.4 Collision and map geometry

- `CollisionBuilder` (`Shared/CollisionModule`) converts map data into collision primitives.
- `UpdatePlayerHulls`, `HullBroadphase`, `HullMaxDistance = 8` bound the expensive queries.
- `StepUpProbeIterations = 2`, frame-skip optimizations, and cached ground normals reduce per-tick cost.
- `ProjectVelocity` handles sliding along surfaces.
- `MaxGroundSlope = 0.7` (~45°) prevents climbing steep surfaces.
- `SolidPlayers = false` means only world geometry and dropped entities block movement.

The loaded map’s 15,758 geometry descendants versus the 1,433 authored descendants indicates that collision/visual geometry is expanded at runtime; `CollisionBuilder` is the likely mechanism, though the exact server-side build step is not replicated.

---

## 9. Combat and weapons

### 9.1 Weapon catalog

There are **41 weapon definitions**: 31 firearms, 9 melee weapons, and the bomb. All stats below are from the replicated `WeaponManager` data (`dumps/weapons.json`).

| Weapon | Type | Price | Damage | RPM | Clip / Reserve | Kill award | Penetration | Armor ratio | Range mod |
|---|---|---:|---:|---:|---|---:|---:|---:|---:|
| Bomb | Bomb | 0 | 50 | 20 | 0 / 0 | 300 | 1 | 1 | 0.99 |
| Balisong | Melee | 0 | 50 | 150 | 0 / 0 | 1500 | 1 | 1.7 | 0.99 |
| Bat | Melee | 0 | 50 | 150 | 0 / 0 | 1500 | 1 | 1.7 | 0.99 |
| CT Knife | Melee | 0 | 50 | 150 | 0 / 0 | 1500 | 1 | 1.7 | 0.99 |
| Cleaver | Melee | 0 | 50 | 150 | 0 / 0 | 1500 | 1 | 1.7 | 0.99 |
| Jagdkommando | Melee | 0 | 50 | 150 | 0 / 0 | 1500 | 1 | 1.7 | 0.99 |
| Karambit | Melee | 0 | 50 | 150 | 0 / 0 | 1500 | 1 | 1.7 | 0.99 |
| Kukri | Melee | 0 | 50 | 150 | 0 / 0 | 1500 | 1 | 1.7 | 0.99 |
| Shadow Daggers | Melee | 0 | 50 | 150 | 0 / 0 | 1500 | 1 | 1.7 | 0.99 |
| T Knife | Melee | 0 | 50 | 150 | 0 / 0 | 1500 | 1 | 1.7 | 0.99 |
| Desert Eagle | Pistol | 700 | 53 | 240 | 7 / 35 | 300 | 2 | 1.864 | 0.85 |
| CZ75-Auto | Pistol | 500 | 31 | 600 | 12 / 12 | 300 | 1 | 1.553 | 0.85 |
| Five-seveN | Pistol | 500 | 32 | 400 | 20 / 100 | 300 | 1 | 1.823 | 0.81 |
| TEC-9 | Pistol | 500 | 33 | 500 | 18 / 90 | 300 | 1 | 1.812 | 0.79 |
| Dual Berettas | Pistol | 300 | 38 | 500 | 30 / 120 | 300 | 1 | 1.15 | 0.79 |
| P250 | Pistol | 300 | 38 | 400 | 13 / 26 | 300 | 1 | 1.28 | 0.9 |
| Glock-18 | Pistol | 200 | 30 | 400 | 20 / 120 | 300 | 1 | 0.94 | 0.85 |
| P2000 | Pistol | 200 | 35 | 353 | 13 / 52 | 300 | 1 | 1.01 | 0.91 |
| USP-S | Pistol | 200 | 35 | 353 | 12 / 24 | 300 | 1 | 1.01 | 0.91 |
| G3SG1 | Rifle | 5000 | 80 | 240 | 20 / 90 | 300 | 2.5 | 1.65 | 0.98 |
| SCAR-20 | Rifle | 5000 | 80 | 240 | 20 / 90 | 300 | 2.5 | 1.65 | 0.98 |
| AWP | Rifle | 4750 | 115 | 41 | 5 / 30 | 100 | 2.5 | 1.95 | 0.99 |
| AUG A3 | Rifle | 3300 | 28 | 600 | 30 / 90 | 300 | 2 | 1.8 | 0.98 |
| SG 553 | Rifle | 3000 | 30 | 545 | 30 / 90 | 300 | 2 | 2 | 0.98 |
| M4A1-S | Rifle | 2900 | 38 | 600 | 20 / 80 | 300 | 2 | 1.4 | 0.94 |
| M4A4 | Rifle | 2900 | 33 | 667 | 30 / 90 | 300 | 2 | 1.4 | 0.97 |
| AK-47 | Rifle | 2700 | 36 | 600 | 30 / 90 | 300 | 2 | 1.55 | 0.98 |
| Famas F1 | Rifle | 1950 | 30 | 667 | 25 / 90 | 300 | 2 | 1.4 | 0.96 |
| Galil ACE | Rifle | 1800 | 30 | 667 | 35 / 90 | 300 | 2 | 1.55 | 0.98 |
| P90 | SMG | 2350 | 26 | 857 | 50 / 100 | 300 | 1 | 1.38 | 0.86 |
| MP5-SD | SMG | 1400 | 28 | 750 | 30 / 120 | 600 | 1 | 1.25 | 0.87 |
| MP7 | SMG | 1400 | 30 | 750 | 30 / 120 | 600 | 1 | 1.25 | 0.87 |
| PPSH-41 | SMG | 1300 | 27 | 750 | 64 / 120 | 600 | 1 | 1.26 | 0.8 |
| MP9 | SMG | 1250 | 26 | 857 | 30 / 120 | 600 | 1 | 1.2 | 0.87 |
| UMP-45 | SMG | 1200 | 35 | 667 | 25 / 100 | 600 | 1 | 1.3 | 0.75 |
| MAC-10 | SMG | 1050 | 29 | 800 | 30 / 100 | 600 | 1 | 1.15 | 0.8 |
| XM1014 | Shotgun | 2000 | 20 | 171 | 7 / 32 | 600 | 1 | 1.6 | 0.7 |
| MAG-7 | Shotgun | 1300 | 30 | 71 | 5 / 32 | 900 | 1 | 1.5 | 0.45 |
| Sawed-Off | Shotgun | 1100 | 32 | 71 | 7 / 32 | 900 | 1 | 1.5 | 0.45 |
| Remington 870 | Shotgun | 1050 | 26 | 68 | 8 / 32 | 900 | 1 | 1 | 0.7 |
| SSG-08 | SniperRifle | 1700 | 88 | 48 | 10 / 90 | 300 | 2.5 | 1.7 | 0.98 |

Notes:

- `RPM` is computed from the primary `FireRate` interval (`60 / FireRate[1]`). Burst/alt-fire modes have separate timing.
- `Damage` is the base body damage before hitbox multipliers, armor and distance falloff.
- `Penetration` is the number of surfaces the bullet can pass through; it is further limited by material penetration, range and the `MinimumPenetrationStartDistance`.
- `Armor ratio` is the weapon’s armor effectiveness; the damage formula multiplies it by `ArmorRatioDivisor = 0.5`.
- The AWP is intentionally the only gun with a 100 base kill award; all other firearms are 300, SMGs 600, shotguns 900, melee 1,500.

The **bomb** is also a weapon (`Type = Bomb`, slot 8, 3 s plant, damage 500 on de_seaside/de_dust2/de_vertigo, 650 on de_mirage/unknown maps). It has a 40 s fuse, 10 s defuse, 4.303-stud defuse range, 0.05 s defuse lock-in, 1 s detonation grace, and only T can plant/pick up; only CT can defuse.

### 9.2 Weapon slots and loadout

- Slot 1: primary (rifle/SMG/shotgun/sniper)
- Slot 2: secondary (pistol)
- Slot 3: melee
- Slot 4: grenades (UI placeholder; no grenade implementation found)
- Slot 8: bomb (T only)

`WeaponLoadout` is stored as a player attribute (a JSON/array mapping) and edited through `ChangeLoadoutWeapon`. The Loadout UI (3,998 lines) manages per-team, per-slot selections; the buy menu uses the current loadout to decide which “Rifles_1..5” entries to show.

Weapon state is replicated with a compact buffer scheme. Fields observed in `Specialized`/`BufferScheme` include:

`FireDelay`, `Ammo`, `Mode`, `LastShotTime`, `Slot`, `ReserveAmmo`, `RandomSeed`, `RecoilIndex`, `NameEnum`, `BurstFireRemaining`, `SniperUnscopeAt`, `AccuracyPenalty`, `NextPlant`, `EquipDelay`, `ZoomLevel`, `AltFunctionDelay`, `InspectDelay`, `AmmoDelay`, `ReloadDelay`, `Timer`, `SavedZoom`, `SilencerDelay`.

This is a proper Source-style weapon state machine: fire delay, burst counter, scope state, reload timers, equip/inspect animations, silencer toggle, and a deterministic recoil index/seed.

### 9.3 Firing and determinism

`GunWeapon` (898 lines) is the firing core. A shot performs:

1. **Ammo/fire-rate check** against `Timer`, `FireDelay`, `NextAttackTime`.
2. **Mode selection** (primary, burst, scope, silenced).
3. **Recoil index** increment and deterministic recoil lookup.
4. **Spread/inaccuracy** calculation from stance, movement, air, duck, ladder, landing, and shot count.
5. **Bullet creation** with `RenderTime`, `RandomSeed`, damage, range, penetration and hitbox data.
6. **Local effect** (tracer, muzzle, sound, viewmodel kick, bullet hole) and a server command.

The recoil table is **64 entries per weapon**, generated from the weapon’s `Recoil.Seed` and frozen at load. `WeaponManager.RecoilTableSize = 64`. For each shot:

```text
entry = Recoil.Table[(RecoilIndex - 1) % 64 + 1]
angle = entry.Angle + variance
magnitude = entry.Magnitude + variance
```

Automatic weapons smooth between entries; the first shots use a ramp so the initial pattern is predictable. `GunWeapon` also generates the per-shot `RandomSeed` (a 16-bit xorshift-like value) that the server uses to reproduce spread. This is why the client can predict tracers/spread while the server still verifies it: both sides run the same generator with the same seed.

`SpreadSeedReplaced` in the telemetry indicates the server can override a client-supplied seed. That is a strong hint that seeds are not blindly trusted: if the seed is missing, stale, or inconsistent with the shot index, the server replaces it and records the event.

### 9.4 Spread, inaccuracy and recoil

`Weapon.Data` contains separate spread/inaccuracy values for:

- `Stand`, `Move`, `Duck`, `Jump`, `JumpInitial`, `Land`, `Ladder`, `Fire`.

`GameConfiguration.Weapon` tuning:

| Setting | Value |
|---|---:|
| `Spread` | true |
| `Recoil` | true |
| `RecoilViewPunchExtra` | 0.055 |
| `ViewRecoilTracking` | 0.45 |
| `InaccuracyMaxFallingPenalty` | 2 |
| `AirInaccuracyScale` | 1 |
| `AirAccuracyPenaltyScale` | 1 |
| `AirRecoveryTimeScale` | 4 |
| `MovementThreshold` | 0.95 |
| `JumpSpeedThreshold` | 0.25 |
| `MovementCurveExponent` | 0.25 |
| `RecoilDecayBase` | 2.302585 |
| `RecoilDecayExponetial` | 8 |
| `RecoilDecayLinear` | 18 |
| `RecoilVelocityDecay` | 4.5 |
| `RecoilDecayThreshold` | 1 |
| `RecoilDecayCoefficient` | 2 |
| `RecoilScale` | 2 |
| `SpreadScale` | 1 |
| `NonIdleSpreadScale` | 1.4 |
| `HitboxRecoilScale` | 1 |

Practical behaviour:

- Moving, jumping and falling add inaccuracy; stopping and crouching recover it.
- The first shot from a stationary rifle is highly accurate; sustained fire walks the recoil pattern.
- Landing adds a one-shot penalty; ladders are heavily penalized.
- Aim punch moves the camera; view punch is a cosmetic camera kick. The shot is built from pitch/yaw plus `(SeenAimPunch or AimPunchAngle) * RecoilScale`, while the rendered camera applies `AimPunchAngle * RecoilScale * ViewRecoilTracking` plus view punch. That split is why the crosshair can “kick” while the camera only partially follows.
- `RecoilAssist` (mobile/console only) reduces the camera recoil multiplier by up to 45%.

### 9.5 Bullet tracing, penetration and damage

`WeaponConstructor/Bullet` (≈1,000 lines) implements a multi-surface hitscan trace. The significant constants:

| Constant | Value |
|---|---:|
| `MinimumPenetrationStartDistance` | 208.2 |
| `MaxPenetrationDistance` | 6.246 |
| `PenetrationLossDivisor` | 0.1156 |
| `DistanceFallOff` | 34.7 |
| `KnifeRangeLeftClick` | 3.3312 |
| `KnifeRangeRightClick` | 2.2208 |
| `KnifeCastBoxSize` | `(0.35, 0.35, 0.35)` |
| `KnifeRewindSlack` | 8 |

Damage at distance:

```text
damage = baseDamage * RangeModifier ^ (distance / 34.7)
```

This is Source-like but uses a **34.7-stud** falloff unit rather than Source’s 500 units. A 0.98 range modifier barely drops over typical fights; a shotgun with 0.45 loses damage quickly.

Hitbox multipliers (`GameConfiguration.Damage.HitboxMultipliers`):

| Hitbox | Multiplier |
|---|---:|
| Head | **4.0** |
| UpperTorso | 1.0 |
| LowerTorso | **1.25** |
| Arms/hands | 1.0 |
| Legs/feet | **0.75** |

Armor application (`HitboxArmorApply`):

- `ApplyArmor`: head, upper torso, lower torso, arms and hands.
- `RequireHelmet`: head only.
- Legs/feet are never armored.

Armor formula (`DamageCalculation`):

```text
armorRatio = weapon.ArmorRatio * 0.5
healthDamage = damage * armorRatio
armorLoss = (damage - healthDamage) * 0.5
```

with the edge case that if armor is lower than the loss, health takes the remainder. A helmet is required for head armor; without it, a headshot applies the full 4× multiplier and no armor reduction. In Casual every player has free armor + helmet, so headshots are still 4× but the head is armored, which is why helmets matter despite the free armor.

Friendly fire is off. If enabled, bullet damage scales by 0.1, grenade damage by 0.25, and self-grenade damage by 1.0.

### 9.6 Penetration / wallbangs

The trace can pass through up to **4 surfaces**. For each surface it:

1. Finds the entry point and material.
2. Checks `Penetration` remaining, `MinimumPenetrationStartDistance` (208.2 studs) and material `PenetrationModifier` (must be ≥ 0.1).
3. Traces to the exit point (`TraceToExit`, max 6.246 studs).
4. Applies a damage/penetration loss based on material thickness and the weapon’s penetration.
5. Continues until the bullet exits, hits a character, hits the range limit, or exhausts the 4 surfaces.

Material penetration data and material variants are shared modules. This produces CS-style wallbangs through thin walls, wooden doors and site boxes, but not through thick concrete.

### 9.7 Shot validation and rejection

The server receives the shot inside the command, reconstructs the weapon state, rewinds entities to `RenderTime`, traces, and applies damage. Before damage it checks:

| Reject reason | Meaning |
|---|---|
| `spawn protection` | victim still has 3 s spawn immunity |
| `attacker dead` | shooter died before the command was processed |
| `victim dead` | target already died |
| `teammate` | friendly fire disabled |
| `no armor state` | missing armor data on the victim |
| `zero after armor` | armor formula produced 0 health damage |
| `health unchanged` | damage did not change health (already dead/immune) |
| `no character` | no character entity for the target |
| `no HitPoints` | character has no hitpoints component |

These gates, plus rate limits and command-age checks, are the real anti-cheat boundary. `Tattletale` is detection; the server is enforcement.

### 9.8 Knife, bomb and equipment

**Knife/melee**

- Primary attack range 3.3312 studs; secondary 2.2208.
- Cast box 0.35³, rewind slack 8.
- 50 base damage, 1,500 kill award, 1.7 armor ratio.
- 9 melee variants are cosmetic/loadout options (Balisong, Bat, CT/T Knife, Cleaver, Jagdkommando, Karambit, Kukri, Shadow Daggers).

**Bomb**

- T-only pickup/plant; CT-only defuse.
- Plant time 3 s (`Bomb.FireRate = {3, 0.3}`), cancel fade 0.2 s.
- 40 s blow timer.
- 10 s defuse, 4.303 stud range, 0.05 s lock-in, 1 s detonation grace.
- 500 damage on the three pool maps; 650 on de_mirage/unknown.
- Defusing is a networked `DefuseTimer`/`Defusing` state; the HUD shows a progress bar (`Gui/HUD/Defuse`, 454 lines).
- Defuse kit is free for CT in Casual (`HasDefuseKit`), but the exact kit time multiplier is server-side; the client only receives the timer.

**Armor/helmet**

- `ArmorValue` and `HasHelmet` are player attributes.
- Free armor sets armor to 100 and helmet true.
- Armor absorbs damage on head/torso/arms; legs are unarmored.
- The buy menu still sells Kevlar ($650) and Kevlar & Helmet ($1,000), which are only meaningful if `FreeArmor` is disabled in another mode.

**Rescue Kit**

- CT-only $400 equipment item. It is in `ItemManager/Equipment/Rescue Kit`; the exact revive mechanic is server-side. The T buy menu has no Rescue Kit slot.

### 9.9 Weapon effects and feedback

- `WeaponEffects.Process` handles tracers, muzzle flashes, impact effects and shells; it is guarded by `Tattletale`.
- `Particles` events: `CreateBulletHole`, `CreateTracer`, `CreateRagdoll`.
- Bullet holes live 30 s by default (`Particles.BulletholeLifetime`) and can be limited/disabled in Settings.
- Tracers can be shown for every bullet or removed entirely (settings).
- `SoundManager.Play` is guarded; sounds include footsteps, gunshots, reloads, impacts, headshot armor/flesh pain sounds (`DamageCalculation.PainSoundKeys`).
- Killfeed, damage indicators, hitmarkers and ragdolls are UI/client effects; damage numbers are not authoritative.

## 10. Aiming, camera and recoil

### 10.1 Input stack

The camera/aim stack is split into modules:

| Lines | Module | Role |
|---:|---|---|
| 579 | `GameClient/CameraController` | camera state machine, FOV/zoom, view modes |
| 340 | `CameraController/CameraInput` | mouse/touch/gamepad look, sensitivity, pitch clamp |
| 108 | `CameraController/CameraTypes/PlayerCamera` | first-person camera, view bob, aim/view punch |
| 168 | `CameraController/CameraTypes/Freecam` | free camera |
| 84 | `CameraController/CameraTypes/FollowCamera` | third-person/follow camera |
| 383 | `CameraController/MobileAimAssist` | mobile/console friction, magnetism, recoil assist |

The input module handles mouse delta, touch look, thumbstick, controller camera, inverted Y, zoom sensitivity, and FOV compensation. It clamps pitch to **±1.55334 rad (±89°)** and wraps yaw to ±π rad.

### 10.2 Sensitivity

Two modes:

**Standard (default)**

```text
yaw   += deltaX * 0.00872664619 * sensitivity * fovScale
pitch += deltaY * 0.00671951752 * sensitivity * fovScale
```

`0.00872664619 rad` = **0.5° per pixel**; `0.00671951752 rad` = **0.385° per pixel**. The default sensitivity is 1.0; the FOV scale compensates for zoom so the perceived sensitivity stays consistent.

**CS Sensitivity Enabled**

```text
yaw   += rad(deltaX * (0.022 / GameSettings.MouseSensitivity) * sensitivity * fovScale)
pitch += rad(deltaY * (0.022 / GameSettings.MouseSensitivity) * sensitivity * fovScale * invertSign)
```

This is the mathematical conversion advertised in the settings. Zoom sensitivity is a separate multiplier (default **0.7**) applied while a sniper scope is active.

### 10.3 FOV and scopes

- The Settings “Field Of View” slider is the base world FOV.
- Sniper scopes use `AltFunction = ScopeRifle` with `Mode = 2`; zoom sensitivity is applied while zoomed.
- `CameraController.ApplyFov` is a guarded function; `Tattletale` checks the camera FOV against the configured maximum.
- A FOV more than **5°** above the configured max, when it is not a legitimate zoom, sets anti-cheat bit **8192**.
- The scope overlay (`Gui/HUD/Scope`, 351 lines) is a first-person optic; the world camera FOV is reduced, not merely a 2D overlay.
- `Use Crosshair Color for Scope Dot` is a setting; scoped snipers get a scope-specific reticle.

### 10.4 Recoil, aim punch and view punch

`PlayerCamera.Update` combines:

```text
aimPunch = DecayAimPunchAngle(Simulation.AimPunchAngle, AimPunchAngleVel, dt)
viewPunch = DecayViewPunchAngle(Simulation.ViewPunchAngle, dt)
punch = aimPunch * (RecoilScale * ViewRecoilTracking) + viewPunch
punch *= (1 - recoilAssist)
camera = CFrame.fromEulerAnglesYXZ(-pitch + rad(punch.X), yaw + rad(punch.Y), rad(punch.Z))
```

with `RecoilScale = 2`, `ViewRecoilTracking = 0.45`, and `RecoilAssist = 0.45` on mobile/console. The rendered camera therefore follows **90% of the aim punch** (`2 * 0.45`) before assist, while the shot direction uses `AimPunchAngle * RecoilScale` directly (`Camera.BuildShotCFrame`). View punch is added only to the camera, not the shot.

`GameConfiguration.Camera`:

| Setting | Value |
|---|---:|
| `AimPunch` | true |
| `FlinchPunchScale` | 3 |
| `NoArmorPunchDamageScale` | 0.1 |
| `NoArmorPunchMinimumPitch` | 4 |
| `HeadshotPunchScale` | 0.2 |
| `HeadshotMinPitch` | 12 |
| `HeadshotMaximumRoll` | 9 |
| `HeadShotMinimumRoll` | -9 |
| `ChestArmorPunchAngle` | 0.025 |
| `ChestNoArmorPunchAngle` | 0.1 |
| `ChestMinimumPitch` | 4 |
| `ViewPunch` | true |
| `ViewPunchDecay` | 18 |
| `ViewPunchRollAngle` | 0 |
| `ViewPunchRollSpeed` | 200 |

Headshots produce a stronger punch; no-armor chest hits produce a larger punch than armored chest hits. The camera also has view bob on landing, step-up smoothing, and a small falling bob; these are cosmetic and do not affect the shot.

### 10.5 Aim assist (mobile/console only)

`MobileAimAssist` defaults:

| Component | Setting | Value |
|---|---|---|
| Target selection | max distance | 300 studs |
| Friction | enabled | true |
| Friction | radius | 4 |
| Friction | min angle | 0.05236 rad (3°) |
| Friction | max angle | 0.31416 rad (18°) |
| Friction | min sensitivity | 0.45 |
| Friction | max sensitivity | 1.0 |
| Magnetism | enabled | true |
| Magnetism | radius | 4 |
| Magnetism | min angle | 0.05236 rad (3°) |
| Magnetism | max angle | 0.26180 rad (15°) |
| Magnetism | stop radius | 0.6 |
| Magnetism | pull strength | 0.34907 rad (20°) |
| Magnetism | vertical scale | 0.5 |
| Magnetism | active look speed | 0.52360 rad (30°) |
| Magnetism | activity decay | 0.15 |
| Magnetism | idle activity | 0.35 |
| Recoil assist | enabled | true |
| Recoil assist | reduction | 0.45 |
| Recoil assist | requires target | false |

`AssistPlatform()` returns true only for `Mobile` and `Console`. **PC players receive no friction, magnetism or recoil assist.** The system targets enemies only (team check; Deathmatch treats everyone as an enemy), skips culled/non-primary entities, and uses the target’s position plus a 0.5-stud vertical offset for the angle calculation. Friction slows the look sensitivity when the crosshair is near an enemy; magnetism pulls it toward the target; recoil assist reduces camera kick independent of whether a target is under the crosshair.

### 10.6 Crosshair and viewmodel

- `Gui/HUD/Crosshair` (920 lines) renders a fully customizable crosshair: color, T-style, gap, outline transparency, length, thickness, dot, pixelated image, deployed-weapon gap, and per-preset settings.
- **21 crosshair options** per preset; two default presets plus user presets.
- `Gui/HUD/Scope` renders the sniper scope.
- The viewmodel has **11 settings**: X/Y/Z offset, sway removal, PBR texture removal, equip-animation removal, glove/sleeve removal, bobbing removal, texture removal, preset selection.
- Viewmodel presets are generated from every weapon that has a viewmodel asset; `CopyViewmodel` / `CopyViewmodel2` share them between players.
- `WeaponEffects` and the viewmodel are cosmetic: the shot originates from the simulated camera/hitbox, not the visible gun mesh.
- Freecam (`CameraTypes/Freecam`) and spectate have separate FOV/speed controls and are used for deathcam/spectating; `Spectate` events synchronize target/position.

### 10.7 Aiming-related anti-cheat

`Tattletale` explicitly guards:

```text
WeaponConstructor: GetSpread, GetInaccuracy, Recoil, UpdateAccuracyPenalty,
                   CalculateNextAttackTime, ProcessCommand
Camera: KickBack, UpdatePunchAngles, DecayAimPunchAngle,
        DecayViewPunchAngle, BuildShotCFrame
CameraController: ApplyFov
```

It also monitors weapon shots for impossible cadence/ammo changes and checks FOV. A silent-aim implementation that hooks `BuildShotCFrame` or rewrites spread/recoil is detectable client-side; the server-side shot validation and `SpreadSeedReplaced` telemetry provide a second layer. This does not make cheating impossible, but it raises the cost and produces evidence.

---

## 11. Anti-cheat and security

### 11.1 Layers

Kontra’s protection is defense-in-depth:

1. **Server authority** — movement, shots, damage, economy, buying, inventory, bomb state and round state are server-controlled.
2. **Command validation** — age, rate, tick window, max commands per tick, movement speed threshold, shot resend/dedup.
3. **Lag-compensated hit validation** — server rewinds to `RenderTime`, traces, applies armor/team/spawn/death gates.
4. **`Tattletale`** — client-side environment/function/instance/GUI/camera fingerprinting with a sealed report.
5. **`TattleSeal`** — challenge/response seal over the detection mask, seeded by `JobId` + `UserId`.
6. **Fog of war / PVS** — visibility culling and last-known-position radar.
7. **Rate limits** — per-event drops.
8. **Decoy remotes** — 17 inert cheat-bait remotes.
9. **Role-gated console** — admin commands require server-side roles.
10. **Obfuscation attempt** — an unused `Scramble()` in the loader.

### 11.2 Tattletale

`ReplicatedStorage/GameClient/Tattletale` (1,363 lines) is the primary client anti-cheat. It is loaded like any other client module and runs continuously.

**Guarded functions**

`Tattletale` snapshots the identity, source and arity of security-critical functions, then re-checks them:

```text
WeaponConstructor: GetSpread, GetInaccuracy, Recoil, UpdateAccuracyPenalty,
                   CalculateNextAttackTime, ProcessCommand
Camera: KickBack, UpdatePunchAngles, DecayAimPunchAngle,
        DecayViewPunchAngle, BuildShotCFrame
Movement: ClampVelocity, WalkMove, AirMove, CheckJumpButton, FinishGravity,
          Duck, StartGravity, CheckFalling, FullNoClipMove, LadderMove
CharacterReconciliation: HandleNewState
TattleSeal: Seed, Seal
CharacterNetworking: ProcessPacket, FlushPacket
Simulation: ProcessCommand, CategorizePosition
CameraController: ApplyFov
WeaponEffects: Process
SoundManager: Play
CharacterInput: BuildCommand
Collision: ProjectVelocity, DoGroundCheck, DoStepUp, DoStepDown, CheckStuck,
           UpdatePlayerHulls
Interaction: PressE
```

If a function is replaced, wrapped by an executor, or has a changed source/arity/call depth, the corresponding bit is set. On every 1-second tick, `CheckHooks` verifies each guarded function is still the exact same object and that its `debug.info(fn, "s")` source and `debug.info(fn, "a")` arity match the startup snapshot. It also verifies `debug.info` itself is unchanged and calls `RemoteEvent.FireServer` / `LocalPlayer.Kick` with invalid arguments; both must still throw, or bit **1** is set. `ProbeNext` re-runs a call-depth fingerprint on selected guarded functions by calling them through a recursive metatable (up to 2,000 frames); a changed frame count sets bit **16**. Before sending, it also checks the identity/source of `Anticheat.Tattle.Fire`; if that reporter is hooked, it sends `ClientPing.Fire(0)` instead.

`CheckLibraries` snapshots the frozen standard libraries (`string`, `table`, `math`, `bit32`, `buffer`, `coroutine`, `utf8`, `os`, `debug`, `task`, plus `CFrame`, `Vector3`, `Vector2`, `Instance`, `Ray`, `Color3`, `UDim2`), 31 global functions, seven engine methods (`game.GetService`, `game.FindFirstChild`, `game.WaitForChild`, `game.IsA`, `game.GetChildren`, `workspace.Raycast`, `workspace.GetPartBoundsInBox`) and three metamethods. Any field replacement, count change, non-native function, or unfrozen library sets bit **256**.

**Canaries**

At start it creates and monitors:

- `ReplicatedStorage/ClientIntegrity` folder
- `ReplicatedStorage/ClientIntegrity/IntegrityValidate` `BindableEvent`
- `LocalPlayer` attributes (`WalkSpeed = 16`, `JumpPower = 50`, `IsAdmin = false`, `GodMode = false`)
- `ReplicatedStorage.ClientBuild` (incremented each initialization; observed value **2**)
- `LocalPlayer.RelayTag` (dynamic challenge value; observed **1593834053** and later **805645041**)
- frozen sentinel tables, metamethods, and a set of expected services/instances

If a canary is deleted, renamed, reparented, or its attribute is changed, bit **512** is set. If `IntegrityValidate` is missing or wrongly parented, same.

**Environment scan**

`CheckEnvironment` scans `_G` (and the executor global table) for executor/cheat names. A hit sets bit **64**. The list is extensive and includes:

`hookfunction`, `hookmetamethod`, `getrawmetatable`, `getnamecallmethod`, `newcclosure`, `checkcaller`, `getgenv`, `getrenv`, `getgc`, `setreadonly`, `isreadonly`, `islclosure`, `iscclosure`, `clonefunction`, `restorefunction`, `replaceclosure`, `getconstants`, `getthreads`, `getreg`, `getinstances`, `getnilinstances`, `getscripts`, `getrunningscripts`, `getloadedmodules`, `filtergc`, `saveinstance`, `readfile`, `writefile`, `loadfile`, `listfiles`, `makefolder`, `delfile`, `cloneref`, `setrawmetatable`, `makewriteable`, `getidentity`, `setidentity`, `identifyexecutor`, `getexecutorname`, `getconnections`, `firetouchinterest`, `gethui`, `getsenv`, `getcallingscript`, `getscriptclosure`, `getscripthash`, `getcustomasset`, `getcallbackvalue`, `gethiddenproperty`, `sethiddenproperty`, `setsimulationradius`, `firesignal`, `fireclickdetector`, `fireproximityprompt`, `setclipboard`, `request`, `http_request`, `syn`, `fluxus`, `Drawing`, `crypt`, `WebSocket`, `mousemoverel`, `mouse1click`, `iswindowactive`, `isrbxactive`, `setfpscap`, `queue_on_teleport`, `getupvalues`, `setupvalue`, `getprotos`, `getstack`, `setstack`, `setstackhidden`, `trampoline_call`, `decompile`, `getscriptbytecode`, `getfunctionbytecode`, `getscriptthread`, `getscriptfromthread`, `getmodules`, `isexecutorthread`, `dumpstring`, `getallthreads`, `gettenv`, `iswritable`, `makereadonly`, `makewritable`, `setnamecallmethod`, `gethiddenproperties`, `getproperties`, `getthreadidentity`, `isnetworkowner`, `isscriptable`, `setscriptable`, `setthreadidentity`.

The live scan iterates the whole list. The known-answer probe is randomized: it picks a name, temporarily sets `_G[name] = true`, runs `CheckEnvironment`, restores the value, and verifies the expected bit fires. This self-test also exists for World, Gui, Instances, Self and other checks (see below), which prevents an executor from simply suppressing a single check.

**Known cheat GUI names**

`CheckGui` lowercases/strips a `ScreenGui` name and matches a set including:

`dex`, `darkdex`, `infiniteyield`, `simplespy`, `remotespy`, `turtlespy`, `hydroxide`, `saveinstance`, `rayfield`, `orion`, `cmdx`, `fatesadmin`, `reviz`, `owlhub`, `octospy`, `synapsex`.

Whitelisted GUIs: `GUI`, `CSGO_NetGraph`, `Lori`, `NameTags`, `TouchGui`, `ProximityPrompts`, `Freecam`, `Chat`, `BubbleChat`, plus every child present in `StarterGui` at startup. Any other `ScreenGui` sets bit **2048**; a known cheat name (or an executor global) sets **64**.

**ESP detection**

`CheckEsp` inspects `Highlight` and `BillboardGui` instances:

- The local player must be on a real team (not `Spectator`), and the marker must belong to an enemy character model.
- `Highlight.DepthMode` must be `AlwaysOnTop` to be suspicious; otherwise ignored.
- `BillboardGui.AlwaysOnTop` must be true to be suspicious.
- Such an instance sets bit **4096**.

The class watchlist also includes `SelectionBox`, `SelectionSphere`, `BoxHandleAdornment`, `SphereHandleAdornment`, `CylinderHandleAdornment`, `ConeHandleAdornment`, `LineHandleAdornment` and `ImageHandleAdornment`. This targets typical ESP implementations that draw enemy markers through walls; teammate markers are ignored.

**World check**

`CheckWorld`:

- `workspace.Gravity` must be 0. Any other value sets **16384**. (The game uses a custom character simulation, so Roblox gravity is not used for players.)
- If `VirtualUser` or `VirtualInputManager` was absent at startup and later exists, **16384** is set. (These services are the virtual-input/auto-clicker surface; the check does not reject every new service.)
- Camera FOV above the configured max + 5° (outside legitimate zoom) sets **8192**.

**Challenge probes**

`Tattletale` includes a `u145` table of active challenge functions that temporarily induce a condition and verify the corresponding check fires:

- `World`: set gravity to 1, run `CheckWorld`, restore.
- `Environment`: set a random executor global, run `CheckEnvironment`, restore.
- `Gui`: create a `ScreenGui` named `Dex`, run `CheckGui`, destroy.
- `Instances`: rename the `ClientIntegrity` folder, run `CheckInstances`, restore.
- `Self`: change a canary attribute, run `CheckSelf`, restore.
- `Hooks`: add a known-answer function pair, run `CheckHooks`, expect bit **1**.
- `Libraries`: temporarily replace a captured native method, run `CheckLibraries`, expect **256**.
- `Canaries`: force the service-cache/GC canary, run `CheckCanaries`, expect **128**.

These are effectively unit tests for the detector, executed every second (the extended set, including the `RelayTag` challenge, every fourth second). A cheat that hooks a check but not the challenge runner will fail the known-answer test.

### 11.3 Detection bitmask

| Bit | Meaning |
|---:|---|
| **1** | Hook/self/catalog: a guarded function changed, `ClientBuild`/sentinel mismatch, known-answer failure, or frozen-table mismatch |
| **2** | Superhuman fire rate: 5+ shots inside the fire-delay window with recoil index < 2, repeated across 3 bursts |
| **4** | Rapid fire: 3+ consecutive shots arriving before 80% of the weapon’s fire interval |
| **8** | Ammo increased without a refill event |
| **16** | Guarded function call depth differs from the original (executor wrapper) |
| **64** | Executor footprint: known cheat GUI name **or** an executor/global API found in `_G` |
| **128** | Canary function/metamethod/GC failure |
| **256** | Library/metatable tampering (frozen tables, `debug`, `pcall`, `getfenv`, etc.) |
| **512** | Instance/attribute canary changed: `ClientIntegrity`, `IntegrityValidate`, player attributes, expected instances |
| **1024** | Engine-error suppression: a probe that should error succeeds, indicating a hooked metamethod/`__index`/`__iter`/`__tostring` |
| **2048** | Unknown `ScreenGui` |
| **4096** | ESP-style `Highlight`/`BillboardGui` with always-on-top |
| **8192** | FOV beyond configured max + 5° outside zoom |
| **16384** | World/service tampering: gravity changed, or `VirtualUser`/`VirtualInputManager` appeared after startup |

The bitmask is a 16-bit field (`Mask`) in the report. `Shots` is a 16-bit wrapping shot counter. `Echo` is a 32-bit seal.

### 11.4 TattleSeal

`Shared/TattleSeal` (protocol `a0171d`, challenge attribute `RelayTag`) provides a lightweight integrity seal:

- `Seed(JobId, UserId)` mixes a constant (`3376506168`), the UserId, and every byte of the JobId (dashes removed) through a 32-bit xor-shift-multiply-style `Mix`.
- `Seal(seed, counter, mask, shots, challengeAttr, expectedBit)` folds the seed, counter, mask, shots, challenge value and expected bit into a 32-bit `Echo`.
- `Challenge(n)` maps a number to one of eight challenge entries (`Canaries` 128, `Hooks` 1, `Instances` 512, `Libraries` 256, `Gui` 64, `Environment` 64, `World` 16384, `Self` 1).
- A rotating `RelayTag` value on the player selects an additional challenge (observed `1593834053` and `805645041`); the client rotates its primary challenge every second, and on every fourth report also verifies the selected `RelayTag` challenge.
- The report is sent every **4 seconds** via `Anticheat.Tattle` (`Mask`, `Shots`, `Echo`), rate-limited to **5/s**.

The seal is not cryptographic authentication — the algorithm and seed inputs are client-side, and 32 bits is small. Its purpose is to make casual report forgery/replay harder and to let the server know the client executed the expected challenge code. A determined reverse engineer can reproduce it; the server-side checks remain the real defense.

### 11.5 Decoy remotes

Seventeen remotes in `ReplicatedStorage` are named like cheats but are **not used by any client script** and have **zero client connections**:

| Name | Class |
|---|---|
| `GiveMoney` | RemoteEvent |
| `SetMoney` | RemoteEvent |
| `KillPlayer` | RemoteEvent |
| `GetAdminKey` | RemoteFunction |
| `DamagePlayer` | RemoteEvent |
| `NoRecoil` | RemoteEvent |
| `AdminCommand` | RemoteEvent |
| `SetAmmo` | RemoteEvent |
| `GiveWeapon` | RemoteEvent |
| `SpeedHack` | UnreliableRemoteEvent |
| `SilentAim` | UnreliableRemoteEvent |
| `HitboxExpand` | UnreliableRemoteEvent |
| `GodMode` | UnreliableRemoteEvent |
| `SetHealth` | UnreliableRemoteEvent |
| `Teleport` | UnreliableRemoteEvent |
| `SetWalkSpeed` | UnreliableRemoteEvent |
| `UpdatePosition` | UnreliableRemoteEvent |

They are classic honeypots: a cheater who searches for “money/admin/aim” remotes will find them, fire them, and reveal themselves. They are **not wired to game logic**. Do not fire them on a live account.

Separately, `Tattletale.CheckBait` uses trap tables with `__index`, `__newindex`, `__call`, `__iter`, `__tostring`, etc. It calls engine APIs with values that should error; if a hooked metamethod suppresses the error, bit **1024** fires. This is different from the decoy remotes and runs continuously.

### 11.6 Console and admin security

`Shared/ConsoleShared` (3,619 lines) implements the developer console and **85 commands**. Access is gated by `CanUseConsole` and `Roles`:

```text
Ranks: Moderator = 1, Admin = 2, Developer = 3
Prefixes: DEV, COLLAB, MOD, WATCH, STAR, MEDIA, TESTER
```

The console checks `IsDeveloper`, rank thresholds, `AllowServerOwner`, and `sv_cheats`:

- `sv_cheats` enables local cheat commands (`Noclip`, `Freeze`, `Invisible`, `esp`, `ShowZones`, `ShowSpawns`, `net_graph`, etc.).
- `AllowServerOwner` commands additionally require the server owner flag.
- Inventory/economy commands (`AddSkin`, `SetKredits`, `WipeInventory`, `Ban`) are developer/moderator-gated.
- `Roles` also references a `ServerScriptService.GameServer.RoleList` and a separate pentest place ID (`109013281719699`).

Observed local attributes: `IsAdmin = false`, `CanUseConsole = false`. The console UI exists (1,585 lines) but is inert for a normal player.

Command categories (all 85 names):

```text
help, sv_cheats, AddServerOwner, kick, PlaceVersion, gamepad_test,
sv_arcade, NetInterp, net_graph, net_graphpos, net_graphheight,
net_graphproportionalfont, cl_showpos, esp, ShowClips, ClipColor,
ClipTransparency, ShowZones, ZoneColor, ZoneTransparency, ShowSpawns,
+move, -move, autowalk, ShowImpacts, ShowServerShots, kill, Respawn,
SetPlayerTeam, Teleport, TeleportTarget, bot_add, bot_add_difficulty,
bot_kick, bot_stop, bot_place, Noclip, Freeze, Invisible,
CharacterProperty, SimulationConstant, WeaponConstant,
TemplateSimulationConstant, TemplateWeaponConstant, TemplateReset,
Config, fow_status, Restart, EndState, SetState, SetTime, SetScore,
SetSubTime, ChangeMap, Gamemode, AddWeapon, RemoveWeapon, CloseServer,
AddSkin, RemoveSkin, AddItem, RemoveItem, AddAllSkins, AddAllItems,
AddAllGloves, WipeInventory, ResetAllData, AddGamepass, votekick_immunity,
RemoveGamepass, SetKredits, AddKredits, Ban, Mute, Vanish,
TeleportPlayer, GetServer, Unban, promo_create, promo_list, promo_info,
promo_uses, promo_enable, promo_expire, promo_delete
```

Notable commands:

- `bot_add [ct|t] [easy|normal|hard|expert|extreme] [name] [rifle|smg|sniper|shotgun|pistol] [amount]` — AI bots exist server-side.
- `ChangeMap <map> [restartgame]` — map switching.
- `AddSkin/AddItem/AddAllSkins` — inventory injection for testing.
- `SetKredits/AddKredits` — economy testing.
- `Ban/Unban/Mute` — moderation.
- `promo_*` — promo-code management with uses, expiry, playtime gate and trade lock.
- `fow_status [leaks|reset|parity|bench]` — debug fog-of-war.

The presence of `sv_cheats`, `Noclip`, `esp` and `ShowServerShots` is normal developer tooling; it is not a backdoor for players because the server gates it.

### 11.7 Security assessment

**What is strong**

- Server-authoritative movement/shots/economy/bomb.
- Lag-compensated hit validation with explicit reject reasons.
- Large, layered client detector with self-tests and a rotating seal.
- FOW/PVS/last-known-position radar.
- Per-event rate limits.
- Decoy remotes and role-gated console.

**What is weak or exposed**

- The entire client is plain Luau; no obfuscation or bytecode-only modules. Decompilation recovered 654/654 modules with zero failures.
- `Blink/Server` (30,349 lines) and `Blink/Types` are replicated in `ReplicatedStorage` and skipped only by the client loader. Any client can read the server transport schema and rate limits.
- `Scramble()` is not called; remote/service names are stable and discoverable.
- The anti-cheat is client-side by nature. `Tattletale` can be bypassed by a sufficiently careful executor; the seal is only 32 bits and its algorithm is in the client.
- `TattleSeal` is an integrity seal, not encryption; gameplay remotes are plain binary.
- `ClientBuild` was `2` at capture, suggesting the client bootstrap/Tattletale ran twice in that session. This is not necessarily exploitable, but it is worth watching for duplicate initialization bugs.
- FOW server behaviour cannot be fully verified from the client; the `FogCulled` flag and radar fallback exist, but a cheater who reads raw entity snapshots may still see more than the radar shows if the server sends positions. This is the most important thing to test from a defender’s perspective.
- The game is early alpha; placeholder/unfinished systems (grenades, Zeus) and legacy economy entries are visible.

---

## 12. Meta-progression and cosmetics

Kontra’s meta-game is large relative to its current map/mode count. The client contains a full store/inventory/case/battlepass stack.

### 12.1 Kredits and credit packs

- Kredits are earned from matches (see §4.3).
- Credit packs are Robux gamepasses (`Shared/Data/CreditsPrices`):

| Credits | Bonus | Tag |
|---:|---:|---|
| 100 | 0 | — |
| 220 | 20 | — |
| 560 | 60 | — |
| 1,150 | 150 | POPULAR |
| 2,350 | 350 | — |
| 6,000 | 1,000 | BEST VALUE |
| 12,500 | 2,500 | LIMITED + gold Balisong |

- `KreditsBoost` multiplies match earnings (observed 1).
- The game description advertises a **10% Roblox Plus discount** on Kredits purchases and a Plus badge.

### 12.2 Gamepasses

`Shared/Data/GamepassesData` includes:

| Gamepass | Credits | Effect |
|---|---:|---|
| 3x Open | 2,450 | Open up to 3 containers at once |
| 5x Open | 3,500 | Open up to 5 containers at once |
| 5x Open upgrade | 1,050 | Upgrade from 3x, requires 3x |
| Fuser Scroll | — | 1 Fuser Scroll (fuse items) |
| Name Tag | 300 | Custom weapon name |
| KillTrack | — | Kill counter on a skin |
| KillTrack Painter | 420 | Custom kill-counter color |
| KillTrack Remover | 80 | Remove a kill counter |
| Daily/Weekly/Hourly/Monthly Challenge Reroll | — | Reroll challenge slots |

There are also container-opening gamepasses with per-quantity IDs (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 25, 50, 100) for bulk opening.

### 12.3 Containers and rarity

Two containers are directly defined:

| Container | Price | Notes |
|---|---:|---|
| Mayhem Case | 100 Kredits | weapon skins, gloves, knives; rarities Mil-Spec → Exceeding Rare |
| Sticker Capsule | 80 Kredits | stickers |

Rarity tiers seen across the item/skin data:

`Stock`, `Mil-Spec`, `Restricted`, `Classified`, `Covert`, `Contraband`, `Exceeding Rare`, `Sleeve`, `Event`, `Private`, `Unknown`.

The SkinManager modules define **38 Stock**, **5 Mil-Spec**, **3 Restricted**, **3 Classified**, **6 Covert**, **8 Contraband**, **18 Exceeding Rare**, and **2 Sleeve** entries. Many weapons only have a Stock skin in the client-visible SkinManager; the case catalog references additional skins (e.g., `SCAR-20_Deep`, `Galil ACE_Ryujin`, `MAC-10_Malachite`, `AK-47_Carbon`, `AWP_Storm Front`, `Glock-18_Chumba`, `M4A1-S_Adurite`, Nebula/Crimson/Marble Fade/Vanilla knife finishes, `Fingerless` gloves).

Named non-Stock skins directly visible in SkinManager include:

- M4A4 — Lycoris Bloom
- AWP — Storm Front
- XM1014 — Purple Vector
- Arms — Galaxy Outlaw, Neko Arseniy, Masked Vice
- Balisong — Marble Fade, Gold Fairy, Gold Fairy 2
- Shadow Daggers — Marble Fade, Glass Fairy
- Karambit — Marble Fade, Glass Fairy
- Cleaver — Marble Fade

Cases use `ItemWeight = 1` for each item in the visible data; the actual rarity odds are server-side. `Rares = { "Classified", "Covert", "Exceeding Rare" }`.

### 12.4 Inventory, wear and trade locks

The inventory supports:

- weapon skins (per weapon, with rarity and kill-track flag),
- gloves (CT/T/Fingerless/Handwraps/Vanilla/Nebula/Crimson),
- agents (CT/T Agent, Neko Arseniy, event agents),
- badges (29: Alpha/Beta/Playtester/Contributor/Moderator/Overwatch/Pentester/Media/Plus/Golden Plus/event badges, etc.),
- stickers (31, paper/holo),
- charms (e.g., Aqua),
- music kits (Stock + event kits),
- graffiti (None, Halloween 2026, etc.),
- name tags,
- kill tracks and painters/removers,
- cases/containers,
- fuser scrolls.

`TradeLocked` is a player attribute and an optional argument on admin grants; items can be marked trade-locked. There is a Fuser/trade-up flow (`TradeUp`, `Upgrade`, `UpgradeResult`) and an `Inventory/Upgrader` UI (2,745 lines), but no peer-to-peer trade event was found in the 87 GUI events. “Trade-locked” is therefore an item flag, not evidence of a player trading system.

### 12.5 Battlepass, challenges, playtime and daily market

The client includes:

- **Battlepass:** `BuyBattlepass`, `BuyBattlepassTiers`, `ClaimBattlepassReward`, `ClaimAllBattlepassRewards`, `BattlepassUpdate`. UI `SideSection/Rewards/Battlepass` (2,356 lines in the extra dump).
- **Challenges:** `StartChallenge`, `AbandonChallenge`, `ClaimChallengeReward`, daily/weekly/hourly/monthly rerolls, `ChallengesUpdate`.
- **Achievements:** `ClaimAchievementReward`, `CollectedAchievementsUpdate`, UI `SideSection/Rewards/Achievements` (28,693 bytes).
- **Playtime rewards:** `ClaimPlaytimeReward`, `PlaytimeUpdate`, `PlaytimeRewardsCollectedUpdate`; group members get free playtime/daily bonuses per the game description.
- **Daily market:** `BuyDailyMarketItem`, `RevealMarketItem`; a rotating daily offer with a reveal mechanic.
- **Promo/star codes:** `UsePromocode`, `UsedCodesUpdate`, `UseStarCode`, `UsedStarCodeUpdate`, admin `promo_*` commands. `StarCodesData` has a `GamepassCut = 0.1`.
- **Bundles:** `BuyBundle`, `BuyBundleItem`, `BundlesData`.
- **Care packages:** `ClaimCarePackageItems`.
- **Analytics:** `AnalyticsUpdate`, match history, per-weapon stats, scoreboards, timelines, overview (`MatchesWeaponStats` 4,391, `MatchesTimeline` 4,346, `MatchesScoreboard` 4,223, `Overview` 3,410 lines).
- **Leaderboards:** the `Leaderboards` attribute contains sorted arrays for Wins/Kills/etc.; observed top Wins values in the hundreds.

### 12.6 Social and match flow UI

- Server browser: `RequestServerList` / `ServerListResult`, region/ping/player counts.
- Team selection with limits.
- Map vote with per-map vote counts.
- Votekick: `Votekick`, `VotekickPlayer`, admin immunity.
- Chat: global, team, system messages, `NewMessage`, `NewMessageTeam`, `GlobalMessage`, `SendMessage`, `SendTeamMessage`.
- Notifications, awards, menu notifications, container messages.
- `CopyCrosshair` / `CopyViewmodel` allow copying another player’s crosshair/viewmodel settings.
- `LeftArm` cosmetic event (viewmodel arm/sleeve).
- `MobileControls` event for mobile layout.
- `WatchAdReward` (rewarded-ad integration).
- `GiftGamepass` (gift a gamepass to another player).

---

## 13. UI and HUD

### 13.1 HUD modules

| Lines | Module | Purpose |
|---:|---|---|
| 2,616 | `HUD/Down` | downed/spectate/incapacitated state |
| 2,176 | `HUD/Score` | scoreboard, teams, players, stats |
| 2,163 | `HUD/Buymenu` | buy categories, previews, purchase/drop |
| 1,621 | `HUD/TopBar` | round timer, score, money, team status |
| 1,585 | `HUD/Console` | developer console UI |
| 1,571 | `HUD/Radar` | rotating/static radar, FOW-aware blips |
| 1,064 | `HUD/Notification` | toasts/notifications |
| 920 | `HUD/Crosshair` | customizable crosshair |
| 823 | `HUD/Died` | death screen/kill info |
| 762 | `HUD/Chat` | chat |
| 671 | `HUD/NetGraph` | net graph (ping, choke, cmd, snapshots) |
| 575 | `HUD/MVP` | MVP presentation |
| 454 | `HUD/Defuse` | defuse progress |
| 383 | `HUD/KillFeed` | kill feed |
| 361 | `HUD/Tooltips` | tooltips |
| 355 | `HUD/Vote` | map/vote UI |
| 351 | `HUD/Scope` | sniper scope overlay |
| 326 | `HUD/DamageIndicator` | directional damage |
| 283 | `HUD/PreparationGrayscale` | pre-round desaturation/overlay |

Total HUD: **19 modules, 19,060 lines**.

`NetGraph` displays network debug stats including `ShotRewindMs`, `ShotPingMs`, `ShotJitterMs`, packet rates and reject reasons; it can be positioned/scaled/font-configured through settings and console commands (`net_graph`, `net_graphpos`, etc.).

### 13.2 Main menu

`GameClient/Gui/MainMenu` (1,452 lines) plus large section modules:

| Lines | Section |
|---:|---|
| 7,869 | Settings |
| 4,181 | Store |
| 3,998 | Loadout |
| 2,930 | Inventory |
| 2,745 | Inventory/Upgrader |
| 3,861 | Utils/Inspect |
| 3,336 | Utils/CaseInspect |
| 3,130 | Utils/NetStats |
| ~10,000+ | Analytics (Overview, Matches*) |

Sections include Home, Store, Inventory, Loadout, Gamemodes, Analytics, Rewards, Settings, and the case-opening/inspection utilities. The menu is rendered over a 3D `Workspace/Scene/VertigoScene` with a `CaseMayhemModel` and a character `Rig` for previews; `Scene/LightingSettings` provides the menu lighting.

### 13.3 Match end

`GameClient/Gui/MatchEnd` (1,468 lines) shows:

- final score and winner,
- per-player scoreboard,
- `MatchEndStats` (kills/deaths/assists/damage/headshots/score),
- MVP and match class awards,
- Kredits earned and progression,
- map vote/next match flow.

`MVP` (575) handles the MVP presentation; `MatchClasses` supplies the labels.

### 13.4 Settings

The Settings UI is the largest single client module (7,869 lines). Runtime `PlayerSettings` structure:

| Category | Options |
|---|---|
| Controls → Sensitivity | 3 |
| Controls → Controller Binds | 30 |
| Controls → Keybinds | 55 |
| Controls → Mobile Buttons | 38 |
| Audio → Volume & Sound | 4 |
| Game → Radar | 8 |
| Game → Viewmodel | 11 |
| Game → Crosshair | 21 |
| Game → Gameplay | 20 |
| Game → Graphics & Visuals | 23 |
| Game → HUD & UI | 21 |
| Crosshair presets | 2 × 20 |
| Maps | 3 × 54 |

Gameplay options include FOV, interpolation ticks, recoil assist, viewmodel handedness, predicted body-shot effects, silencer detach, camera aspect ratio, and auto-equip picked-up weapons. Graphics options include character shadows, bullet-hole lifetime, tracers, ragdoll lifetime, impact smoke/sparks, nametags, and more. HUD options include topbar/HUD scale, net graph position/font, HUD color, and free inspect.

Keybinds cover movement, weapons, buy menu, console, freecam, spectate, team chat, inspect, drop, melee, grenades, and zoom. Mobile buttons cover 38 touch controls with positions/sizes/transparency and presets. Controller binds cover 30 actions with vibration strength.

Settings are persisted server-side via `ChangePlayerSetting` / `ResetPlayerSettings`, and the client keeps a local `PlayerSettings` JSON. `SettingsData` (3,606 lines) defines defaults, sliders, dropdowns, descriptions and validation.

### 13.5 Console and net tools

- `HUD/Console` (1,585) is a full in-game console with autocomplete, history, role badges and output formatting.
- `ConsoleShared` (3,619) contains command definitions, parsing, permissions and execution.
- `NetGraph` (671) + `Utils/NetStats` (3,130) visualize network state and shot telemetry.
- `fow_status` exposes FOW debug modes (`leaks`, `reset`, `parity`, `bench`).

### 13.6 UI anti-cheat interaction

`Tattletale` scans `ScreenGui`s for known cheat names/unknown GUIs and `Highlight`/`BillboardGui` for always-on-top ESP. The HUD’s own whitelisted GUIs (`GUI`, `CSGO_NetGraph`, `Lori`, `NameTags`, `TouchGui`, `ProximityPrompts`, `Freecam`, `Chat`, `BubbleChat`) are exempt so legitimate UI does not trigger false positives. Custom crosshairs/viewmodels created by the game are under the whitelisted `GUI`.

---

## 14. Remote and event catalog

### 14.1 The 87 `Gui` events

These are the typed events used by menus, inventory, store and social systems. The grouping below is exhaustive: every event in the `Gui` registry appears exactly once. Directions are mixed (`On` = client→server; `Fire*` = server→client).

**Purchasing / economy (32)**

`BuyRejected`, `BuyStoreItem`, `BuyGamepass`, `GiftGamepass`, `BuyBundle`, `BuyBundleItem`, `BuyBattlepass`, `BuyBattlepassTiers`, `BuyFuserScroll`, `OpenContainer`, `OpenContainerResult`, `BuyDailyMarketItem`, `RevealMarketItem`, `ClaimCarePackageItems`, `ClaimPlaytimeReward`, `ClaimAchievementReward`, `ClaimChallengeReward`, `ClaimBattlepassReward`, `ClaimAllBattlepassRewards`, `StartChallenge`, `AbandonChallenge`, `TradeUp`, `Upgrade`, `UpgradeResult`, `UsePromocode`, `WatchAdReward`, `UseStarCode`, `ApplySticker`, `RemoveSticker`, `ApplyKillTrack`, `RemoveKillTrack`, `ApplyKillTrackColor`.

**Cosmetics / inventory (13)**

`ApplyNameTag`, `RemoveNameTag`, `InventoryUpdate`, `InventoryAdd`, `InventoryRemove`, `InventoryEquip`, `ChangeLoadoutWeapon`, `ViewmodelPreset`, `CopyViewmodel`, `CopyViewmodel2`, `CopyCrosshair`, `CopyCrosshair2`, `LeftArm`.

**Social / match UI (20)**

`NewMessage`, `NewMessageTeam`, `GlobalMessage`, `SendMessage`, `SendTeamMessage`, `MenuNotification`, `NewAwardMessage`, `NewContainerMessage`, `Votekick`, `VotekickPlayer`, `VoteForMap`, `SelectTeam`, `SelectMapPreset`, `RequestMatch`, `MatchData`, `MatchEndStats`, `Ping`, `RequestServerList`, `ServerListResult`, `RequestProfileBadges`.

**Profile / progression / settings (22)**

`ProfileBadges`, `AnalyticsUpdate`, `ChangePlayerSetting`, `ResetPlayerSettings`, `PlayerStatsUpdate`, `PlaytimeUpdate`, `PlaytimeRewardsCollectedUpdate`, `UsedCodesUpdate`, `UsedStarCodeUpdate`, `CollectedAchievementsUpdate`, `GamepassesUpdate`, `ChallengesUpdate`, `BattlepassUpdate`, `CreditsUpdate`, `KillTrackUpdate`, `KillTrackColorUpdate`, `FuserScrollsUpdate`, `KillfeedUpdate`, `DiedUpdate`, `MVPUpdate`, `DamageIndicator`, `MobileControls`.

The exact registry count is **87** (32 + 13 + 20 + 22).

### 14.2 Key payloads

| Event | Payload |
|---|---|
| `Anticheat.Tattle` | `Mask: u16`, `Shots: u16`, `Echo: u32` |
| `Character.Command` | one user command (movement buttons, yaw/pitch, ticks, `RenderTime`, received mask) |
| `Character.CommandArray` | array of up to 30 user commands |
| `Character.HandleNewState` | authoritative character state, last processed command/tick, velocity/flags |
| `Entity.AckSnapshot` | acknowledged snapshot ID/tick |
| `Entity.EntitySnapshot` | delta-compressed entity state, `FogCulled`, position/velocity/weapon |
| `Entity.EntityVisibility` | visible/culled state |
| `Weapon.BuyWeapon` | weapon name, drop flag |
| `Weapon.PickUpWeapon` | entity/weapon identifier |
| `Gui.OpenContainer` | container ID, count |
| `Gui.OpenContainerResult` | item(s), rarity, serial/trade-lock data |
| `Gui.ChangeLoadoutWeapon` | team/slot/weapon |
| `Gui.ChangePlayerSetting` | category/key/value |
| `Gui.RequestServerList` | filters/page |
| `Gui.ServerListResult` | server list with region/players/ping |
| `Spectate.SpectateTarget` | target user/entity |
| `Debug.ShotMarker` / `ServerShot` | local/server shot visualization |
| `Particles.CreateTracer` / `CreateBulletHole` / `CreateRagdoll` | effect spawn data |

The full schema is in [`dumps/protocol.json`](dumps/protocol.json) and the 30k-line server codec in [`dumps/server/Shared.Blink.Server.lua`](dumps/server/Shared.Blink.Server.lua).

### 14.3 Decoy remotes

See §11.5. They are not part of Blink and are not in the event registry.

### 14.4 Rate-limit summary

See §7.3 for the selected limits. The complete **67-entry** per-event table is in [`dumps/protocol.json`](dumps/protocol.json) under `rate_limits`; the codec drops over-limit packets and logs a warning.

---

## 15. Notable findings and limitations

### 15.1 Findings

1. **This is a real, fairly deep CS clone, not a simple Roblox shooter.** It has Source-style movement, deterministic recoil tables, armor/penetration, lag compensation, prediction/reconciliation, a round economy and a full cosmetic meta-game.
2. **The client is completely open.** 654/654 modules decompiled cleanly; no obfuscation, no bytecode-only scripts. `Blink/Server` and `Blink/Types` are replicated despite being skipped by the loader. This is a reverse engineer’s dream and a cheater’s map.
3. **`Scramble()` is dead code.** All remote/service names are stable, which makes remote discovery trivial. If the developers intended name obfuscation, it is not active in build 307.
4. **The decoy remotes are almost certainly honeypots.** They have cheat-bait names, zero client connections and no game-code references. Firing them is a bad idea.
5. **`Tattletale` is unusually thorough for a Roblox game.** It guards the entire movement/weapon/camera/replication stack, uses known-answer self-tests, scans `_G` for ~100 executor APIs, detects ESP highlights, unknown GUIs and FOV changes, and seals reports with a rotating challenge. It is still client-side and bypassable, but it will catch naive executors and script-kiddie cheats.
6. **The server is the real anti-cheat.** Shot rejection reasons, lag-compensated rewinds, rate limits and server-side economy/bomb state mean a client-side “silent aim” still has to produce a valid command and pass damage gates.
7. **FOW is the strongest anti-wallhack layer.** The `FogCulled` flag and radar last-known-position fallback are deliberate. The open question is whether the server withholds live positions from snapshots or only flags them; that cannot be proven from the client.
8. **Casual’s free armor/helmet/kit makes the equipment economy vestigial.** The buy menu still sells armor and a Rescue Kit, but armor is auto-granted. This is a design inconsistency likely to change in competitive modes.
9. **Grenades and Zeus are placeholders.** The UI lists them; the replicated item/weapon data does not implement them. The mode even defines grenade limits (`MaxGrenades 3`, flash 2, smoke 1, HE 1, molotov/incendiary 1, decoy 1), but there is no grenade entity/projectile code in the client-visible content.
10. **The game is early alpha and growing fast.** The API shows creation on 2026-09-02 and ~1.8M visits by 2026-10-20. Build 307 already has 41 weapons, 3 maps, a battlepass, cases, a daily market and a 1,000+ line anti-cheat module; expect rapid change.
11. **Deathmatch remnants exist.** Aim assist checks `Gamemode == "Deathmatch"`, and the UI has a Gamemodes section, but only Casual is configured. Future modes are likely.
12. **The server was in DE at capture with 10 players.** Region, map vote and match state are all client-visible; the server browser and `ServerRegion` attribute make region selection possible.
13. **`ClientBuild = 2`.** The initialization counter incremented twice in the observed session. This could be a reload, a duplicated loader, or normal development behaviour; it is a useful fingerprint but not a vulnerability by itself.

### 15.2 Limitations of this dump

- **Server scripts are not replicated.** Enforcement logic, ban durations, economy persistence, case odds, matchmaking, FOW server culling, defuse-kit multiplier and bot AI are inferred or described only by their client-visible interfaces.
- **The map zone counts changed between reads.** Zone folders are rebuilt with the map/round, so counts (plants/detects/spawns) vary. The stable facts are the map bounds, buy zones, site positions, spawn regions and radar size.
- **Exact damage after armor and the `KillAwardMultiplier` application are server-side.** The formulas and base values are replicated; the final integers depend on server rounding and order of operations.
- **Container odds are server-side.** The visible `ItemWeight` values are all 1; rarity weights/drop tables live on the server.
- **No live-server interference was performed.** Suspicious remotes were never fired, no state was modified, and no players were targeted. The analysis is passive plus local decompilation.
- **Snapshot date.** Everything here is build 307 / 2026-10-20; later updates may change names, stats, maps and anti-cheat bits.

---

## 16. Appendix: evidence and file map

### 16.1 Deliverables

| Path | Contents |
|---|---|
| `KONTRA_DUMP.md` | this document |
| `dumps/runtime.json` | live `GameStats`, local player attributes, runtime state |
| `dumps/protocol.json` | complete Blink event registry (130 events, 17 signals), all 67 rate limits, and the runtime `GameStats`/attribute snapshot |
| `dumps/players.json` | players in the captured server (user IDs/names omitted from this document) |
| `dumps/tree.json` | instance-tree sample (12,310 entries) |
| `dumps/map.json` | `de_seaside` map metadata, zones, lighting, radar, geometry summary |
| `dumps/map_zones.json` | live zone/spawn positions and bounds |
| `dumps/weapons.json` | all 41 weapon stat blocks |
| `dumps/script_index.json` | all 654 client modules, paths, classes, line counts |
| `dumps/extra_index.json` | the 590 directly-decompiled extra modules |
| `dumps/info.json` | capture metadata |
| `dumps/Loader.lua` | decompiled client loader |
| `dumps/DisableRobloxStuff.lua` | Roblox UI removal script |
| `dumps/scripts/` | 654 decompiled client modules (25 MB) |
| `dumps/server/` | Blink server/types, map modification, collision triangle, TradeUp/Achievements/Battlepass extras |

### 16.2 Key source files

| Concern | File |
|---|---|
| Client bootstrap | `dumps/Loader.lua` |
| Shared config | `dumps/scripts/0467_ReplicatedStorage_Shared_GameConfiguration.lua` |
| Casual rules | `dumps/scripts/0279_ReplicatedStorage_Shared_Data_GamemodesConfig_Casual.lua` |
| Movement constants | `dumps/scripts/0487_ReplicatedStorage_Shared_Simulation_Config.lua` |
| Simulation | `dumps/scripts/0486_ReplicatedStorage_Shared_Simulation.lua` |
| Camera math | `dumps/scripts/0488_ReplicatedStorage_Shared_Simulation_Camera.lua` |
| Weapon core | `dumps/scripts/0460_ReplicatedStorage_Shared_WeaponConstructor_Types_GunWeapon.lua` |
| Bullet/penetration | `dumps/scripts/0479_ReplicatedStorage_Shared_WeaponConstructor_Bullet.lua` |
| Damage/armor | `dumps/scripts/0459_ReplicatedStorage_Shared_DamageCalculation.lua` |
| Anticheat | `dumps/scripts/0418_ReplicatedStorage_GameClient_Tattletale.lua` |
| Seal | `dumps/scripts/0452_ReplicatedStorage_Shared_TattleSeal.lua` |
| Blink client | `dumps/scripts/0245_ReplicatedStorage_Shared_Blink_Client.lua` |
| Blink server | `dumps/server/Shared.Blink.Server.lua` |
| Camera input | `dumps/scripts/0406_ReplicatedStorage_GameClient_CameraController_CameraInput.lua` |
| Aim assist | `dumps/scripts/0407_ReplicatedStorage_GameClient_CameraController_MobileAimAssist.lua` |
| First-person camera | `dumps/scripts/0410_ReplicatedStorage_GameClient_CameraController_CameraTypes_PlayerCamera.lua` |
| Console | `dumps/scripts/0470_ReplicatedStorage_Shared_ConsoleShared.lua` |
| Roles | `dumps/scripts/0458_ReplicatedStorage_Shared_Roles.lua` |

### 16.3 Reproduction

The raw dump was produced with a local executor capable of `decompile`, `getscripts`, `getloadedmodules`, `getconnections` and file I/O:

1. Enumerate every `ModuleScript` under `ReplicatedStorage` and decompile it.
2. Read live `GameStats`, player attributes and `workspace.Map`.
3. Enumerate remote connections with `getconnections` (all decoys had zero).
4. Decompile 590 additional loaded modules to recover `Blink/Server`, `Blink/Types`, map modifications and UI sections that the indexed loader skipped.
5. Combine with the public Roblox API for game metadata.

No remote was fired and no game state was modified during capture.

### 16.4 Glossary

| Term | Meaning |
|---|---|
| **Blink** | Kontra’s custom binary network layer |
| **Tattletale** | client anti-cheat detector |
| **TattleSeal** | 32-bit challenge/response seal for Tattletale reports |
| **FOW** | fog of war; visibility culling of enemy entities |
| **PVS** | potentially visible set; baked visibility cells |
| **Command** | one tick of client input (movement, angles, buttons) |
| **Snapshot** | server entity state used for interpolation/lag comp |
| **Tick** | 1/64 s simulation step |
| **Reconciliation** | re-simulating pending commands after a server correction |
| **Rewind** | server restoring entity hitboxes to the client’s render time |
| **Kredits** | meta-currency earned from matches |
| **Case/container** | loot box opened for cosmetics |
| **Fuser/TradeUp** | combine items into a higher-tier item |
| **Upgrader** | probabilistic item upgrade UI |
| **MVP/class** | end-of-match performance award |
| **Bomb** | the T-side objective weapon/entity |
| **Casual** | the only configured mode at capture |

---

*End of dump. Snapshot: 2026-10-20, build 307.*


