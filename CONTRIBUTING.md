# Contributing to Gem Hunters

Thanks for helping! This guide explains how the game is put together and the rules every change follows. Keep pull requests small and focused, and describe what you tested.

## Setup

You need **Godot 4.3 stable** (standard build). See [Run from source](README.md#run-from-source).

```bash
./start.sh                                    # run the game
godot --path . -e                             # open the editor
godot --headless --path . --import            # re-import; shows parse and load errors
```

There is no automated test suite. Before opening a PR, run the headless import (it must print no `SCRIPT ERROR`) and play a match in each mode you touched. A headless run prints many harmless `Parameter "m" is null` and `Unicode parsing error` lines (that's the dummy renderer).

To drive the game from a script, run a `extends SceneTree` script with `-s <script.gd>`. Autoloads are available, so it can call `GameManager.configure(...)`, change to `res://scenes/main/Main.tscn`, call `lock_in()` on the character selectors and save `root.get_texture().get_image()` screenshots. Two things to watch out for:

- Such a script compiles before the autoloads, so it can't name project classes (`MazeLevel`, `PlayerStatus`...) at compile time. `load()` them at runtime instead.
- Detach real gamepads (set every `InputManager.player_joypad_map` entry to -1, call `_apply()`, `Input.action_release` every `p*` action), or a pad in someone's hands will steer a test player.

## Releases

`.github/workflows/release.yml` exports the game with the presets in `export_presets.cfg`. It packages a Windows installer (Inno Setup, `installer/windows/`), a Linux `.deb` (`installer/linux/`) and portable zip/tar.gz builds on every pull request. On master, a new `config/version` in `project.godot` tags the commit `v<version>` and publishes a GitHub Release. The version lives only in that one place.

## Rules

- **Clean code.** No legacy or dead code (remove whatever a change makes obsolete), reusable components instead of copies, compact single-purpose classes. When a script grows past a few hundred lines, split it into components (a child `Node` with a `class_name`, or a `RefCounted` helper).
- **Typed access only.** Don't use `set("field")`, `get("_private")` or `call("method")` on project classes. Use static typing everywhere, `##` doc comments, and signals between systems.
- **English** for code, identifiers, comments and file names. UI text only goes through localization keys in `assets/localization/strings.csv` (`keys,en,it`). A Label or Button can hold the key as its `text` (it gets translated automatically) or use `tr()`. Avoid emoji in UI strings: the fonts have no emoji glyphs.
- **No magic numbers.** Use a named `const` at the top of the script. Shared values go in `autoloads/Constants.gd`.
- **Gameplay time** is `GameManager.game_time()`, which is frozen during the countdown, pause and game over. Gameplay timers use `create_timer(t, false)` so they pause too.
- **UI styling** only goes through `resources/theme/game_theme.tres` and its type variations: `TitleLabel`, `HeadingLabel`, `SubtleLabel`, `HudValueLabel`, `CountdownLabel`, `BannerLabel`, `BigButton`, `HudPanel`, `DialogPanel` (opaque, for modal dialogs), `BannerPanel` / `BannerPanelGood` / `BannerPanelBad`, `ItemSlot` / `ItemSlotFull` / `SuperSlot`, `KeyChip`, `ViewportGrid`. No `theme_override_*` in scenes. The bundled fonts (OFL) are Nunito for body text (a `FontVariation` by weight) and Lilita One for titles, numbers and `BigButton`. Label3D text uses `Constants.DISPLAY_FONT`.
- **Stylized look.**
  - Characters and interactive props use `ToonMaterials.get_material(color, outline)`, a `ShaderMaterial` on `shaders/stylized_lit.gdshader` whose outline is a dark shade of the object's colour. Level architecture uses it with outline 0.
  - Every surface shader includes `shaders/stylized_light.gdshaderinc` (soft ramp, glossy highlight, lit-side rim). Skies use `stylized_sky.gdshader`.
  - Effects: particle bursts with `ParticleConfigs.spawn_burst(...)`, floating text with `PopupText.spawn(...)`, light pillars with `LightBeam.create(...)`.

## Architecture

**Scene flow.** `MainMenu.tscn` → `GameManager.configure(players, mode, target, level_config)` → `scenes/main/Main.tscn` → `GameOverScreen.tscn`. *Rematch* reuses `GameManager.chosen_characters`; *Change hunters* clears them and reopens selection. In character selection, Back (pad B, Esc / right click for P1, or the on-screen button) unlocks a locked choice, or otherwise returns to the main menu. An unlock during `READY_DELAY` cancels the pending start.

### Autoloads (`autoloads/`)

- `Constants`: every enum (`GameState`, `MatchMode`, `PowerUpType`, `DebuffType`, `GemType`), group names, physics layers, tuning values and `LEVEL_CONFIGS`.
- `GameManager`: **the only owner of scores and lives**.
  - State machine LOBBY → COUNTDOWN (3-2-1) → PLAYING ⇄ PAUSED → GAME_OVER. Also owns the clock, `game_time()`, win conditions, the frenzy and the leader.
  - `add_gems` / `remove_gems` return the amount applied. Transfers pass `boost=false` so the frenzy never creates gems.
  - Survival: `lose_life` / `add_life` / `refill_lives`. `get_standings()` ranks survivors first.
  - Signals: `countdown_tick`, `timer_updated`, `score_updated`, `leader_changed`, `frenzy_started`, `match_ended`, `lives_changed`, `player_eliminated`, `chaos_gem_appeared`, `chaos_gem_taken`.
- `InputManager`: creates every `p{N}_*` action at runtime.
  - P1 plays with keyboard + mouse: wheel arms a slot, left click fires it, right click jumps.
  - Every pad model (keyed by GUID) has its own layout. A new model starts from the default: face buttons = items 1-3, Y = superpower, RB/RT = jump, LB = camera view.
  - Pads go to P2..P4 in connection order. A leftover pad goes to P1.
  - Rebindable from `ControlsDialog` and saved to `user://controls.cfg`. Files older than `SAVE_VERSION` are migrated.
- `AudioManager` (`play_sfx`), `LocalizationManager` (en/it).
- `UiMotion`: every Button grows a few pixels on hover/focus and squishes on press, and plain `PanelContainer` cards pop in. `pulse(control)` is the shared "value changed" pop.
- `Settings` (static helper, not an autoload): reads and writes one section of `user://settings.cfg` (language, last match setup).

### A match

`scenes/main/SplitScreenManager.gd` is the composition root. It builds the arena (`MazeLevel` + `GemSpawner`, the spawner *after* the level), spawns the players, one `CameraRig` per `SubViewport`, the HUDs and the 3-player overview (`Scoreboard`), then shows the character selectors and calls `GameManager.start_match()`.

- In 3-4 player matches, each quarter view renders its 2D layer on a larger virtual canvas (`QUARTER_UI_SCALE`), so HUDs are smaller.
- In survival, an eliminated hunter's camera follows a survivor.
- `MatchOverlay` shows the countdown and the frenzy, and owns the pause menu.

### Arenas are generated

Arenas come from `LevelConfig` resources in `resources/levels/*.tres`. Each one sets a layout (CLASSIC/ROOMS/RINGS), a style (CANDY/FOREST/GARDEN/ROMAN/EGYPT/WINTER), the grid, colours, sky/fog and prop counts. `scenes/level/` turns them into geometry:

- `MazeGrid`: the maze as data. Walls sit on cell edges. It handles layout generation, the plaza, connectivity repair, and `gate_edges` for `MovingGate`s (picked after repair, so a closed gate never cuts the maze).
- `MazeLevel`: the orchestrator. It builds the floor (tinted per zone), merged wall segments, gates and post positions, and answers `zone_of()` / `is_outside()` (4 quadrant zones + the center plaza; the HUD names them).
- `MazeScenery`: themed set dressing. Landmarks, posts, trees, the scenery ring and corner decorations.
- `MazeProps`: everything players interact with. Spawn/gem/power-up markers, trampolines in dead ends, gift boxes, sprinklers, ice patches, `Portal` pairs, `MapBeacon`s, and the golden return `Trampoline` outside the outer wall. All props join `Constants.GROUP_PROPS`.
- `MeshBatcher` turns repeated meshes into MultiMeshes per mesh and colour. `ArenaEnvironment` sets up the sky, light and post-processing.

A new theme is a new `.tres`, plus a `Style` branch in `MazeLevel` / `MazeScenery` if it needs new meshes. The menus preview arenas through `ArenaBackdrop`.

### Player (`scenes/player/`)

`Player` is the body: movement, jumps, landing dust, gems in and out (`collect_gem`, `lose_gems(n, scatter)`), knockback, `take_hit()` (life loss in survival), teleport/launch, the leader crown + `LightBeam`, and `eliminate()`. Its child components:

- `Look` (`PlayerLook`): stick and mouse look, the first/third-person view (`view_changed`), P1's mouse buttons.
- `Status` (`PlayerStatus`): debuffs (`apply_debuff`, `has`), stun, buffs (`grant(Buff.BUBBLE/SHIELD/SHOES/TURBO)`, `absorb_hit()`), grace periods, the frozen struggle. It shows the ice block, dizzy stars and bubble, and emits the HUD's debuff signals.
- `Items` (`PlayerItems`): `ITEM_SLOT_COUNT` slots (`equip`, `use_item`), the character superpower and its recharge. Projectile/trap scenes are `@export`s, **not** preloads: those scenes reference `Player`, so a preload would create a load cycle.
- `Combat` (`PlayerCombat`): bumps (both players drop `BUMP_GEMS`, never a life), stomps (the only contact that wins), robbing frozen/confused rivals, the ground pound. Every hit goes through `_hit_feedback()`.

The shared `CharacterModel.tscn` is the visual body, also used in the selection preview. It is procedurally animated (`set_motion`, `play_hurt` / `play_squash` / `play_cheer`). A character's traits are data on its `CharacterData`, and its `superpower` picks one of four. **A new character** needs:

1. a `CharacterData` `.tres`
2. an accessory node under `Rig/Body/Accessories/<id>` (meshes named `Tint*` take the body colour)
3. an entry in `CharacterSelector.CHARACTERS`
4. `CHAR_<ID>_*` strings

### HUD (`scenes/ui/HUD.gd` + `scenes/ui/hud/`)

The HUD shows gems, rank, zone, the goal bar and the clock, and wires its components: `ItemPad`, `Toast`, `MiniMap`, `DebuffOverlay` and `LivesRow`. It only connects to its own player's signals. Item icons and name keys live in `scenes/ui/ItemCatalog.gd`, shared with the How to play screen.

### Gems, items and traps

- `GemSpawner` keeps at most `MAX_GEMS_IN_WORLD` gems (fewer in survival), clear of props and traps. It also runs the golden gem, survival life gems and the once-per-match `ChaosGem`.
- Loose gems (`GemLoose`) blink until they can be picked up, drift toward the nearest hunter, and can't go back to their dropper for `DROPPER_DELAY`.
- `PowerUpData` (type + pool weight) feeds `SurpriseBox`, which favours attacks for the last player and the radar for anyone not leading.
- Traps extend `TrapBase`: the victim loses `gems_stolen`, half go to the owner and the rest scatter. A bubble or shield absorbs a trap, and `TRAP_GRACE` stops chain-trapping.
- Projectiles extend `Projectile`: light aim assist, Tanky's shield reflects them, and rival shots cancel each other out.
