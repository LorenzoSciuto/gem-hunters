# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Gem Hunters: Tag & Trap" — a 2–4 player local split-screen 3D party game in **Godot 4.3** (GDScript, Forward Plus) by Wennovate, for kids 9+. Players grab gems in a themed maze, open gift boxes for traps/attacks, and knock gems out of rivals. A match is won on **time** (most gems when the clock ends) or **score** (first to N gems); the leader wears a crown and the final stretch is a "frenzy" where pickups count double.

## Commands

The Godot 4.3 binary is bundled at `.tools/Godot_v4.3-stable_linux.x86_64`. There is no test suite, linter or build step.

```bash
./start.sh                       # launch (prints controls); extra args pass through to Godot
./.tools/Godot_v4.3-stable_linux.x86_64 --path . -e                   # open editor
./.tools/Godot_v4.3-stable_linux.x86_64 --path . --windowed --resolution 1600x900   # windowed run
./.tools/Godot_v4.3-stable_linux.x86_64 --headless --path . --import  # re-import; surfaces parse/load-cycle errors
```

`--headless` runs print many harmless `Parameter "m" is null` / `Unicode parsing error` lines (dummy renderer). To drive the game in tests, run a `extends SceneTree` script with `-s <script.gd>`: autoloads are available, so it can call `GameManager.configure(...)`, change to `res://scenes/main/Main.tscn`, call `lock_in()` on the character selectors and save `root.get_texture().get_image()` screenshots.

## Rules (from GEMINI.md — always enforced)

- Code, identifiers, comments, file/folder names: **English only**. UI text only via localization keys in `assets/localization/strings.csv` (`keys,en,it`); Labels/Buttons may hold the key as their `text` (auto-translated) or use `tr()`.
- No magic numbers: named `const` at the top of the script, shared values in `autoloads/Constants.gd`.
- Static typing everywhere; `##` doc comments; signals between systems.
- UI styling only through `resources/theme/game_theme.tres` (project theme) and its type variations (`TitleLabel`, `HeadingLabel`, `SubtleLabel`, `HudValueLabel`, `CountdownLabel`, `BannerLabel`, `BigButton`, `HudPanel`, `BannerPanel`, `ViewportGrid`) — no `theme_override_*` in scenes.
- Toon look: characters and interactive props use `ToonMaterials.get_material(color, outline)`; level architecture uses it with outline 0 (the inverted-hull outline breaks up on long thin boxes). Particle bursts for interactions via `ParticleConfigs.spawn_burst(...)`.
- Avoid emoji in UI strings: the font has no emoji glyphs.

## Architecture

**Scene flow:** `MainMenu.tscn` → `GameManager.configure(players, mode, target, level_config)` → `scenes/main/Main.tscn` → `GameOverScreen.tscn` (Rematch reuses `GameManager.chosen_characters` and skips character selection).

**Autoloads** (`autoloads/`):
- `Constants` — every enum (`GameState`, `MatchMode`, `PowerUpType`, `DebuffType`, `GemType`), group names, layers, tuning, `LEVEL_CONFIGS` (arena list).
- `GameManager` — **the only owner of gem scores**. State machine LOBBY → COUNTDOWN (3-2-1) → PLAYING ⇄ PAUSED → GAME_OVER, clock, win condition, frenzy, leader tracking. `add_gems(pid, n, boost)` / `remove_gems` return the amount actually applied; `boost=false` for transfers between players so the frenzy never creates gems. Signals: `countdown_tick`, `timer_updated`, `score_updated`, `leader_changed`, `frenzy_started`, `match_ended`.
- `InputManager` — creates every `p{N}_*` action at runtime (none live in `project.godot`): two keyboard schemes (P0 WASD+mouse, P1 arrows+numpad) and one pad layout (face buttons = items 1-3 + super on Y, RB/RT jump; P0's mouse: wheel arms a slot, left click fires, right click jumps). Button actions are rebindable from the main-menu `ControlsDialog` and saved to `user://controls.cfg`. Pads go to P1..P3 in connection order; only a leftover pad goes to P0. Also adds pad A/B to `ui_accept`/`ui_cancel` so menus work with a pad.
- `AudioManager` (`play_sfx(SoundEffect)`), `LocalizationManager` (en/it).

**Match composition root:** `scenes/main/SplitScreenManager.gd`. Builds the arena (`MazeLevel` + `GemSpawner`, spawner *after* the level so it finds the gem markers), spawns players, one `CameraRig` per `SubViewport` (shared `World3D`), HUDs, the 3-player overview panel (ortho camera + `Scoreboard`), then character selectors → `GameManager.start_match()`. `MatchOverlay` (CanvasLayer, `PROCESS_MODE_ALWAYS`) shows countdown/frenzy and owns pause (Esc / Start).

**Arenas are generated:** `resources/levels/*.tres` are `LevelConfig` resources (layout CLASSIC/ROOMS/RINGS, style CANDY/FOREST/GARDEN/ROMAN/EGYPT/WINTER, grid size, colors, sky/fog, prop counts). `scenes/level/MazeLevel.gd` turns one into geometry each match: wall grid (`_east`/`_south` per cell) → connectivity repair → environment → floor → merged wall segments → themed posts (only at wall ends/junctions) → scenery → spawn markers (groups `spawn_points`, `gem_spawns`, `powerup_spawns`) → props (trampolines in dead ends, surprise boxes, sprinklers, ice patches, `Portal` pairs, `MapBeacon`s). `MovingGate`s replace random walls picked *after* connectivity repair, so a closed gate never cuts the maze. Radar items and map beacons call `Player.reveal_map()` → the HUD's mini-map. Each arena is split into 4 quadrant zones + the center plaza (`MazeLevel.zone_of(pos, config)`): per-zone floor tint and a giant landmark outside each corner, and the HUD names the player's zone, so split screens show where rivals are. Repeated meshes are batched into MultiMeshes per (mesh, color). Odd grid sizes keep a cell at the origin, where the golden gem spawns. New theme = new `.tres` (+ a `Style` branch in `MazeLevel` if it needs new meshes). Menus show the selected arena through `scenes/ui/ArenaBackdrop`.

**Player** (`scenes/player/Player.gd`, `class_name Player`): third-person camera on a `SpringArm3D` with a first-person toggle (`p{N}_toggle_view`); in first person the body is hidden only from that player's camera via render layer `MODEL_LAYER_BASE + id` (name tags use `NAME_TAG_LAYER_BASE + id` the same way). Debuffs are expiry times (`apply_debuff(type, duration)`, bubble absorbs one). Items go into `Constants.ITEM_SLOT_COUNT` slots (a full inventory can't open gift boxes) and are used per slot; each character's superpower (by `trait_type`: turbo / ground pound / shield / swap) recharges in `SUPERPOWER_COOLDOWN`. There is no sprint (speed only from Spring Shoes / Dashy's Turbo); running into a rival tackles them (steals 1 gem, 2 from the leader, then a short grace period). The leader wears a crown and a golden light beam visible over the walls. `lose_gems(n, scatter)`: `scatter=true` bursts loose gems (pickup delay so the victim can't regrab), `false` returns them to a thief. Visual body is the shared `CharacterModel.tscn` (also used by the selection preview). Spawnable scenes (gems, traps, projectiles) are `@export`s set in `Player.tscn`, **not** preloads — those scenes reference `Player`, and a preload creates a load cycle (`Parse Error: Busy`).

**Menus:** `MainMenu` hosts `HowToPlayDialog` (goal / hunters + superpowers / items / arena pages) and `ControlsDialog`. Item and superpower icons + name keys live in `scenes/ui/ItemCatalog.gd` (description key = name key + `_DESC`), shared by the HUD and the guide. Hits between hunters go through `Player._hit_feedback()` (burst, spin, floating `ParticleConfigs.spawn_popup_text`, `impact` signal → camera shake + HUD banner).

**Data resources:** `CharacterData` (`resources/characters/`), `PowerUpData` (`resources/powerups/`, type + pool weight; `SurpriseBox` favors attacks for the player in last place), `LevelConfig`. Traps extend `TrapBase` (victim loses `gems_stolen`, half goes to the owner, rest scatters; after `ARM_DELAY` they catch their own owner too); projectiles extend `Projectile` (light aim assist: they curve toward a rival within range and a cone ahead).
