# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Gem Hunters: Tag & Trap" — a 2–4 player local split-screen 3D party game in **Godot 4.3** (GDScript, Forward Plus) by Wennovate, for kids 9+. Players grab gems in a themed maze, open gift boxes for traps/attacks, and knock gems out of rivals. Three modes: **time** (most gems when the clock ends), **score** (first to N gems), **survival** (3 lives, every attack costs a life, every `GEMS_PER_LIFE` gems buy one, at most `MAX_LIVES` (5), last one standing wins). The leader wears a crown; the final stretch of time/score matches is a "frenzy" where pickups count double.

## Commands

The Godot 4.3 binary is bundled at `.tools/Godot_v4.3-stable_linux.x86_64`. There is no test suite or linter. Release builds: `export_presets.cfg` (Linux + Windows, portable single file with embedded pck) exported by `.github/workflows/release.yml` on every PR/master push; a `v*` tag publishes a GitHub Release.

```bash
./start.sh                       # launch (prints controls); extra args pass through to Godot
./.tools/Godot_v4.3-stable_linux.x86_64 --path . -e                   # open editor
./.tools/Godot_v4.3-stable_linux.x86_64 --path . --windowed --resolution 1600x900   # windowed run
./.tools/Godot_v4.3-stable_linux.x86_64 --headless --path . --import  # re-import; surfaces parse/load-cycle errors
```

`--headless` runs print many harmless `Parameter "m" is null` / `Unicode parsing error` lines (dummy renderer). To drive the game in tests, run a `extends SceneTree` script with `-s <script.gd>`: autoloads are available, so it can call `GameManager.configure(...)`, change to `res://scenes/main/Main.tscn`, call `lock_in()` on the character selectors and save `root.get_texture().get_image()` screenshots. Such scripts must not name project classes (`MazeLevel`, `PlayerStatus`...) at compile time — they compile before the autoloads; `load()` them at runtime. Detach real gamepads in tests (`InputManager.player_joypad_map` → -1, `_apply()`, `Input.action_release` every `p*` action): a pad in someone's hands steers a test player.

## Rules (always enforced)

- **Clean code, always:** no legacy or dead code (remove what a change makes obsolete), reusable components instead of copies, compact single-purpose classes, lean files — when a script grows past a few hundred lines, split it into components (child `Node` with a `class_name`, or a `RefCounted` helper). Typed access only: no `set("field")` / `get("_private")` / `call("method")` on project classes.
- Code, identifiers, comments, file/folder names: **English only**. UI text only via localization keys in `assets/localization/strings.csv` (`keys,en,it`); Labels/Buttons may hold the key as their `text` (auto-translated) or use `tr()`.
- No magic numbers: named `const` at the top of the script, shared values in `autoloads/Constants.gd`.
- Static typing everywhere; `##` doc comments; signals between systems.
- Gameplay time is `GameManager.game_time()` (frozen in countdown, pause and game over); gameplay timers use `create_timer(t, false)` so they pause too.
- UI styling only through `resources/theme/game_theme.tres` (project theme) and its type variations (`TitleLabel`, `HeadingLabel`, `SubtleLabel`, `HudValueLabel`, `CountdownLabel`, `BannerLabel`, `BigButton`, `HudPanel`, `DialogPanel` (opaque, for modal dialogs), `BannerPanel` / `BannerPanelGood` / `BannerPanelBad`, `ItemSlot` / `ItemSlotFull` / `SuperSlot`, `KeyChip`, `ViewportGrid`) — no `theme_override_*` in scenes. Fonts are bundled in `assets/fonts/` (OFL): Nunito (body, a `FontVariation` by weight) and Lilita One (titles, numbers, BigButton); Label3D text uses `Constants.DISPLAY_FONT`.
- Stylized look: characters and interactive props use `ToonMaterials.get_material(color, outline)` (a `ShaderMaterial` on `shaders/stylized_lit.gdshader`; the outline is a dark shade of the object's colour); level architecture uses it with outline 0. Every surface shader includes `shaders/stylized_light.gdshaderinc` (soft ramp, glossy highlight, lit-side rim); skies use `stylized_sky.gdshader`. Particle bursts via `ParticleConfigs.spawn_burst(...)`, floating text via `ParticleConfigs.spawn_popup_text(...)` (shared `POPUP_*` height/colours), light pillars via `LightBeam.create(...)`.
- Avoid emoji in UI strings: the font has no emoji glyphs.

## Architecture

**Scene flow:** `MainMenu.tscn` → `GameManager.configure(players, mode, target, level_config)` → `scenes/main/Main.tscn` → `GameOverScreen.tscn` (Rematch reuses `GameManager.chosen_characters`; "Change hunters" clears them and reopens selection). In character selection, Back (pad B, P0 Esc / right click, on-screen button) unlocks a locked choice, otherwise returns to the main menu; an unlock during `READY_DELAY` cancels the pending start. The selection card only grows, so locking in never resizes it.

**Autoloads** (`autoloads/`):
- `Constants` — every enum (`GameState`, `MatchMode`, `PowerUpType`, `DebuffType`, `GemType`), group names, layers, tuning, survival tuning, `LEVEL_CONFIGS`.
- `GameManager` — **the only owner of scores and lives**. State machine LOBBY → COUNTDOWN (3-2-1) → PLAYING ⇄ PAUSED → GAME_OVER, clock, `game_time()`, win conditions, frenzy, leader. `add_gems` / `remove_gems` return the amount applied (`boost=false` for transfers so the frenzy never creates gems); survival: `lose_life` / `add_life` / `refill_lives`, `get_standings()` ranks survivors first. `halve_rivals()` for the Chaos Gem. Signals: `countdown_tick`, `timer_updated`, `score_updated`, `leader_changed`, `frenzy_started`, `match_ended`, `lives_changed`, `player_eliminated`, `chaos_gem_appeared`, `chaos_gem_taken`.
- `InputManager` — creates every `p{N}_*` action at runtime: one keyboard scheme (P0 WASD+mouse; everyone else plays with a pad) and one pad layout (face buttons = items 1-3 + super on Y, RB/RT jump, LB camera view; saved files older than `SAVE_VERSION` are migrated; P0's mouse: wheel arms a slot, left click fires, right click jumps). Rebindable from `ControlsDialog`, saved to `user://controls.cfg`. Pads go to P1..P3 in connection order; a leftover pad goes to P0.
- `AudioManager` (`play_sfx`), `LocalizationManager` (en/it).
- `UiMotion` — every Button grows a fixed few pixels on hover/focus and squishes on press; plain `PanelContainer` cards pop in; `pulse(control)` is the shared "value changed" pop.

**Match composition root:** `scenes/main/SplitScreenManager.gd` builds the arena (`MazeLevel` + `GemSpawner`, spawner *after* the level), spawns players, one `CameraRig` per `SubViewport`, HUDs, the 3-player overview (`Scoreboard`), then character selectors → `GameManager.start_match()`. In 3-4 player matches each quarter view renders its 2D layer on a larger virtual canvas (`QUARTER_UI_SCALE`), so HUDs and cards are smaller. Survival: an eliminated hunter's camera follows a survivor. `MatchOverlay` shows countdown/frenzy (3 s, then each clock shows "x2") and owns pause (Esc / Start: Resume, Restart, Main menu, Quit).

**Arenas are generated** from `LevelConfig` resources (`resources/levels/*.tres`: layout CLASSIC/ROOMS/RINGS, style CANDY/FOREST/GARDEN/ROMAN/EGYPT/WINTER, grid, colours, sky/fog, prop counts) by `scenes/level/`:
- `MazeLevel` — orchestrator + themed geometry: floor (per-zone tint), landmarks, merged wall segments, posts at wall ends/junctions, scenery, decorations; `zone_of()` / `is_outside()` (4 quadrant zones + center plaza; the HUD names them).
- `MazeGrid` — the maze as data: walls on cell edges, layout generation, plaza, connectivity repair, `gate_edges` for `MovingGate`s (picked after repair, so a closed gate never cuts the maze).
- `MazeProps` — spawn/gem/power-up markers, trampolines in dead ends, gift boxes, sprinklers, ice patches, `Portal` pairs, `MapBeacon`s, the single golden aimed return `Trampoline` outside the outer wall (`Player.launch_to()`); all props join `Constants.GROUP_PROPS`.
- `MeshBatcher` (repeated meshes → MultiMeshes per mesh/colour) and `ArenaEnvironment` (sky, light, post-processing).
New theme = new `.tres` (+ a `Style` branch in `MazeLevel` if it needs new meshes). Menus preview arenas through `ArenaBackdrop`.

**Player** (`scenes/player/`): `Player` is the body — movement, look/input, jumps, landing dust, gems in/out (`collect_gem`, `lose_gems(n, scatter)`), knockback (stuns briefly), `take_hit()` (survival life loss), teleport/launch, leader crown + `LightBeam`, `eliminate()`. Its child components:
- `Status` (`PlayerStatus`) — debuffs (`apply_debuff`, `has`), stun, buffs (`grant(Buff.BUBBLE/SHIELD/SHOES/TURBO)`, `absorb_hit()`), grace periods (`Grace.TACKLE/TRAP/PORTAL`), frozen-struggle (mash jump, never below `FREEZE_MIN_TIME`); shows ice block / dizzy stars / bubble and emits the HUD's debuff signals.
- `Items` (`PlayerItems`) — `ITEM_SLOT_COUNT` slots (`equip`, `use_item`), projectile/trap scenes as `@export`s (**not** preloads: those scenes reference `Player`, a preload is a load cycle), thunder, utilities, the character superpower (turbo / ground pound / shield / swap) and its recharge; emits the HUD's inventory signals.
- `Combat` (`PlayerCombat`) — bumps (both drop `BUMP_GEMS`, never a life), stomps (the only contact that wins: steals, costs a life in survival), robbing frozen/confused rivals by contact, ground pound; every hit goes through `_hit_feedback()` (burst, spin, popup numbers, `impact` → camera shake + HUD toast).
The shared `CharacterModel.tscn` is the visual body (also in the selection preview), procedurally animated (`set_motion`, `play_hurt` / `play_squash` / `play_cheer`). Accessories sit under `Rig/Body/Accessories/<character id>`, meshes named `Tint*` take the body colour: a character's trait is data on its `CharacterData` (speed, jumps, air jumps, knockback, gem loss, debuff/ice/superpower-time multipliers, steal bonuses; every character tunes different ones) and its `superpower` picks one of four; a new character = `CharacterData` .tres + accessory node + entry in `CharacterSelector.CHARACTERS` + `CHAR_<ID>_*` strings.

**HUD** (`scenes/ui/HUD.gd` + `scenes/ui/hud/`): the HUD shows gems, rank, zone, goal bar, clock and wires its components: `ItemPad` (slots, key chips, superpower ring, view hint), `Toast` (messages by `Toast.Tone`), `MiniMap`, `DebuffOverlay`, `LivesRow` (survival hearts). Only its own player's signals are connected to it. Item/superpower icons and name keys live in `scenes/ui/ItemCatalog.gd` (description = name key + `_DESC`), shared with the guide. `Player.notify(key, good)` explains one-off events (prank boxes).

**Gems:** `GemSpawner` keeps at most `MAX_GEMS_IN_WORLD` (fewer in survival), never within `GEM_PROP_CLEARANCE` of props, boxes or traps. The golden gem first appears `GOLDEN_GEM_RESPAWN` into the match and again that long after each pickup (survival: slower, and it refills lives to 3). Survival adds a life gem every `LIFE_GEM_INTERVAL`. The `ChaosGem` appears once per match (not in survival) and halves every rival's gems. Loose gems (`GemLoose`) are whole, blink until pickable, drift toward the nearest hunter, and their dropper can't take them back for `DROPPER_DELAY`.

**Data resources:** `CharacterData` (`resources/characters/`), `PowerUpData` (`resources/powerups/`, type + pool weight; `SurpriseBox` favours attacks for the last player and the radar for anyone not leading; some boxes are announced pranks), `LevelConfig`. Traps extend `TrapBase` (victim loses `gems_stolen`, half to the owner, rest scatters; main debuff lasts the scene's `effect_duration`, each trap holds ~2 s or more, a bubble/shield absorbs it, `TRAP_GRACE` stops chain-trapping; projectiles and ground pounds `defuse()` them). Projectiles extend `Projectile` (light aim assist; Tanky's shield reflects them; rival shots cancel out).
