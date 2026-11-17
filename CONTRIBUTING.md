# Contributing to Gem Hunters

Thanks for helping! This guide explains how the game is put together and the rules every change follows. Keep pull requests small and focused, and describe what you tested.

## Setup

You need **Godot 4.3 stable** (standard build). See [Run from source](README.md#run-from-source).

```bash
./start.sh                                    # run the game
godot --path . -e                             # open the editor
godot --headless --path . --import            # re-import; shows parse and load errors
```

Before opening a PR, run the checks and play a match in each mode you touched:

```bash
GODOT=.tools/Godot_v4.3-stable_linux.x86_64 tests/run.sh
```

It runs the headless import, which must print no `SCRIPT ERROR`, then every `tests/test_*.gd`. CI runs the same script before it exports anything. A headless run prints many harmless `Parameter "m" is null` and `Unicode parsing error` lines (that's the dummy renderer).

- **Dead code is an error.** `[debug]` in `project.godot` turns these GDScript warnings into errors: unused variables, parameters, constants and signals, unreachable code, shadowed names and untyped declarations. Prefix a parameter you must accept but don't use with `_`. A signal is emitted by the class that declares it (others call a method, like `GameManager.announce_chaos_gem()`).
- **Tests** extend `tests/match_test.gd`, which starts a match and gives `expect()` / `finish()`. Add one for new rules or systems (`test_collector_rules.gd` checks rules on `GameManager` alone; `test_bots.gd` and `test_touch.gd` play a real match; `test_menu_layout.gd` checks that the menu card never changes size). `tests/` is left out of the exports.

To drive the game from a script, run a `extends SceneTree` script with `-s <script.gd>`. Autoloads are available, so it can call `GameManager.configure(...)`, change to `res://scenes/main/Main.tscn`, call `lock_in()` on the character selectors and save `root.get_texture().get_image()` screenshots. Two things to watch out for:

- Such a script compiles before the autoloads, so it can't name project classes (`MazeLevel`, `PlayerStatus`...) at compile time. `load()` them at runtime instead.
- Detach real gamepads (set every `InputManager.player_joypad_map` entry to -1, call `_apply()`, `Input.action_release` every `p*` action), or a pad in someone's hands will steer a test player.

## Releases

`.github/workflows/release.yml` exports the game with the presets in `export_presets.cfg`. It packages a Windows installer (Inno Setup, `installer/windows/`), a Linux `.deb` (`installer/linux/`) and portable zip/tar.gz builds. It runs on its own only for pushes to master, and each one is a new version: the commit is tagged `v<version>` and published as a GitHub Release. The version is `MAJOR.MINOR.PATCH`. Bump `MAJOR.MINOR` by hand in `config/version` of `project.godot`; never touch `PATCH`, the workflow counts it up from the last `v<MAJOR.MINOR>.*` tag and stamps it into the exported game. The actions and the build image are pinned to a commit hash / digest. The splash (`assets/ui/splash.png`) is committed without a version: `installer/stamp_splash.gd` writes the number next to "Wennovate" during the release build, with the glyphs of `installer/splash_version_glyphs.png`. To build any other branch, start the workflow by hand (Actions → *Build & release* → *Run workflow*). Manual runs never publish. The Windows export writes the icon and version info into the `.exe` with rcedit, and the build fails if they are missing.

**Web build.** The same project exports to the browser with the `Web` preset (`godot --headless --path . --export-release Web`, output in `build/web/`; serve that folder over HTTP to try it). Browsers run the Compatibility renderer instead of Forward Plus, so check new shaders and effects with `--rendering-method gl_compatibility` too. The export is single-threaded, so any static file server works with no special headers. Gamepads need HTTPS. Code that only makes sense on one side branches on `OS.has_feature("web")` (the Quit buttons are hidden there). On master pushes the `deploy-web` job publishes the build on GitHub Pages (https://lorenzosciuto.github.io/gem-hunters/).

## Rules

- **Clean code.** No legacy or dead code (remove whatever a change makes obsolete), reusable components instead of copies, compact single-purpose classes. When a script grows past a few hundred lines, split it into components (a child `Node` with a `class_name`, or a `RefCounted` helper).
- **Typed access only.** Don't use `set("field")`, `get("_private")` or `call("method")` on project classes. Use static typing everywhere, `##` doc comments, and signals between systems.
- **English** for code, identifiers, comments and file names. UI text only goes through localization keys in `assets/localization/strings.csv` (`keys,en,it`). A Label or Button can hold the key as its `text` (it gets translated automatically) or use `tr()`. Avoid emoji in UI strings: the fonts have no emoji glyphs. Input names shown to the player (keys, mouse and pad buttons) are translated too, through the `INPUT_*` keys. On first launch the game follows the system language (Italian or English), until the player picks one in the menu.
- **No magic numbers.** Use a named `const` at the top of the script. Shared values go in `autoloads/Constants.gd`.
- **Gameplay time** is `GameManager.game_time()`, which is frozen during the countdown, pause and game over. Gameplay timers use `create_timer(t, false)` so they pause too.
- **UI styling** only goes through `resources/theme/game_theme.tres` and its type variations: `TitleLabel`, `MenuTitleLabel`, `HeadingLabel`, `SubtleLabel`, `HudValueLabel`, `CountdownLabel`, `BannerLabel`, `BigButton`, `HudPanel`, `DialogPanel` (opaque, for modal dialogs), `BannerPanel` / `BannerPanelGood` / `BannerPanelBad`, `ItemSlot` / `ItemSlotFull` / `SuperSlot`, `KeyChip`, `ViewportGrid`. No `theme_override_*` in scenes. The bundled fonts (OFL) are Nunito for body text (a `FontVariation` by weight) and Lilita One for titles, numbers and `BigButton`. Label3D text uses `Constants.DISPLAY_FONT`.
- **Stylized look.**
  - Characters and interactive props use `ToonMaterials.get_material(color, outline)`, a `ShaderMaterial` on `shaders/stylized_lit.gdshader` whose outline is a dark shade of the object's colour. Level architecture uses it with outline 0.
  - Every surface shader includes `shaders/stylized_light.gdshaderinc` (soft ramp, glossy highlight, lit-side rim). Skies use `stylized_sky.gdshader`.
  - Effects: particle bursts with `ParticleConfigs.spawn_burst(...)`, floating text with `PopupText.spawn(...)` (popups that start together stack instead of overlapping), light pillars with `LightBeam.create(...)`.

## Architecture

**Menus.** A choice in a menu is an `OptionStepper` row (`<  value  >`): it keeps its size whatever the value, works with a thumb and with a pad, and stacks cleanly. Text that changes (descriptions) sits in a box of fixed height. A menu must not change size when something is picked.

**Scene flow.** `MainMenu.tscn` → `GameManager.configure(players, mode, target, level_config, bots)` → `scenes/main/Main.tscn` → `GameOverScreen.tscn`. *Rematch* reuses `GameManager.chosen_characters`; *Change hunters* clears them and reopens selection. In character selection, Back (pad B, Esc / right click for P1, or the on-screen button) unlocks a locked choice, or otherwise returns to the main menu. An unlock during `READY_DELAY` cancels the pending start.

### Autoloads (`autoloads/`)

- `Constants`: every enum (`GameState`, `MatchMode`, `PowerUpType`, `DebuffType`, `GemType`), group names, physics layers, tuning values and `LEVEL_CONFIGS`.
- `GameManager`: **the only owner of scores and lives**.
  - State machine LOBBY → COUNTDOWN (3-2-1) → PLAYING ⇄ PAUSED → GAME_OVER. Also owns the clock, `game_time()`, win conditions, the frenzy and the leader.
  - `add_gems` / `remove_gems` return the amount applied. Transfers pass `boost=false` so the frenzy never creates gems.
  - Bots: the last `bots` player_ids are computer-driven (`is_bot`, `get_num_humans`). At least one human always plays.
  - Survival: `lose_life` / `add_life` / `refill_lives`. `get_standings()` ranks survivors first.
  - Collector: `collections` holds each hunter's colours and the score mirrors its size. `add_gems(..., color)` adds a colour gem, or a wild one (-1: loose, stolen, jackpot) that fills a random missing colour. Every transfer moves one gem. `take_golden_gem` ends the match for a full collection and empties every collection otherwise.
  - Signals: `countdown_tick`, `timer_updated`, `score_updated`, `leader_changed`, `frenzy_started`, `match_ended`, `lives_changed`, `player_eliminated`, `collection_completed`, `collections_reset`, `chaos_gem_appeared`, `chaos_gem_taken`.
- `InputManager`: creates every `p{N}_*` action at runtime.
  - P1 plays with keyboard + mouse: wheel arms a slot, left click fires it, right click jumps.
  - Every pad model (keyed by GUID) has its own layout. A new model starts from the default: face buttons = items 1-3, Y = superpower, RB/RT = jump, LB = camera view.
  - Pads go to P2..P4 in connection order. A leftover pad goes to P1.
  - `action_name(player_id, action)` is the only place that builds a `p{N}_*` name.
  - Touch: the first screen touch sets `touch_active`. From then on P1 plays with `TouchControls` (a stick under the left thumb, drag on the right to look, a jump button, pause), which also moves the HUD's item pad under the right thumb, enlarges it and makes it tappable (`ItemPad.make_touchable`). They press P1's own actions, so nothing else changes.
  - Rebindable from `ControlsDialog` and saved to `user://controls.cfg`. Files older than `SAVE_VERSION` are migrated.
- `AudioManager` (`play_sfx`), `LocalizationManager` (en/it).
- `UiMotion`: every Button grows a few pixels on hover/focus and squishes on press, and plain `PanelContainer` cards pop in. `pulse(control)` is the shared "value changed" pop.
- `ScreenLayout`: on a tall window (a phone held upright) it turns the base canvas on its side, and on a handheld it draws the whole UI larger (up to 1.5x on a phone, 1x on a tablet). Screens read `portrait` and listen to `layout_changed`. Every screen must fit a 1280x720 canvas and a 720x1280 one.
- `RenderQuality`: phones, tablets and console browsers (Xbox: the full look loses the WebGL context there) get the lite profile (3D at 70% resolution, no multisampling, bloom or sun shadows, no small lights on gems and boxes). It is applied to nodes as they enter the tree, so scenes describe the full look only. On an integrated GPU with the Compatibility renderer a 4-hunter match goes from about 30 to about 120 fps.
- `Settings` (static helper, not an autoload): reads and writes one section of `user://settings.cfg` (language, last match setup).

### A match

`scenes/main/SplitScreenManager.gd` is the composition root. It builds the arena (`MazeLevel` + `GemSpawner`, the spawner *after* the level), spawns the players, one `CameraRig` per `SubViewport`, the HUDs and the 3-player overview (`Scoreboard`), then shows the character selectors and calls `GameManager.start_match()`.

- Only humans get a screen, a camera and a HUD (one human plays full screen). A bot gets a `PlayerBot` child and a random hunter.
- In 3-4 player matches, each quarter view renders its 2D layer on a larger virtual canvas (`QUARTER_UI_SCALE`), so HUDs are smaller.
- In survival, an eliminated hunter's camera follows a survivor.
- `MatchOverlay` shows the countdown and the frenzy, and owns the pause menu.
- On a touch screen `TouchControls` (`scenes/ui/TouchControls.gd`) is added over the match when the countdown starts.

### Arenas are generated

Arenas come from `LevelConfig` resources in `resources/levels/*.tres`. Each one sets a layout (CLASSIC/ROOMS/RINGS), a style (CANDY/FOREST/GARDEN/ROMAN/EGYPT/WINTER), the grid, colours, sky/fog and prop counts. `scenes/level/` turns them into geometry:

- `MazeGrid`: the maze as data. Walls sit on cell edges. `cell_at()` and `path()` (breadth-first) are what bots navigate with. It handles layout generation, the plaza, connectivity repair, and `gate_edges` for `MovingGate`s (picked after repair, so a closed gate never cuts the maze).
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

A bot's hunter also has a `PlayerBot` child. It picks the nearest gem or gift box, follows `MazeGrid.path()` to it by pressing its own `p{N}_move_forward` action (so debuffs and stuns apply as to a human), jumps when stuck or next to a rival, and fires items and the superpower at rivals nearby.

The shared `CharacterModel.tscn` is the visual body, also used in the selection preview. It is procedurally animated (`set_motion`, `play_hurt` / `play_squash` / `play_cheer`). A character's traits are data on its `CharacterData`, and its `superpower` picks one of four. **A new character** needs:

1. a `CharacterData` `.tres`
2. an accessory node under `Rig/Body/Accessories/<id>` (meshes named `Tint*` take the body colour)
3. an entry in `CharacterSelector.CHARACTERS`
4. `CHAR_<ID>_*` strings

### HUD (`scenes/ui/HUD.gd` + `scenes/ui/hud/`)

The HUD shows gems, rank, zone, the goal bar and the clock, and wires its components: `ItemPad`, `Toast`, `MiniMap`, `DebuffOverlay`, `LivesRow` (survival) and `CollectionRow` (collector). It only connects to its own player's signals. Item icons and name keys live in `scenes/ui/ItemCatalog.gd`, shared with the How to play screen.

### Gems, items and traps

- **Nothing spawns on top of something else.** Every gem joins `Constants.GROUP_PICKUPS`, and `SpawnClearance.is_clear()` keeps new gems and relocated gift boxes `SPAWN_CLEARANCE` away from pickups, boxes, props and traps. When no spot is free, the spawner waits and tries again.
- `GemSpawner` keeps at most `MAX_GEMS_IN_WORLD` gems (fewer in survival). It also runs the golden gem, survival life gems and the once-per-match `ChaosGem`. In collector mode every gem has one of `Constants.COLLECT_COLORS`, there is no Chaos Gem, and the golden gem appears only when a collection is complete.
- Loose gems (`GemLoose`) blink until they can be picked up, drift toward the nearest hunter, and can't go back to their dropper for `DROPPER_DELAY`.
- `PowerUpData` (type + pool weight) feeds `SurpriseBox`, which favours attacks for the last player and the radar for anyone not leading.
- Traps extend `TrapBase`: the victim loses `gems_stolen`, half go to the owner and the rest scatter. A bubble or shield absorbs a trap, and `TRAP_GRACE` stops chain-trapping.
- Projectiles extend `Projectile`: light aim assist, Tanky's shield reflects them, and rival shots cancel each other out.
