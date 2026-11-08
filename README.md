# Gem Hunters: Tag & Trap

A 2–4 player local split-screen 3D party game for kids 9+, made with **Godot 4.3** by Wennovate.

Hunters race through a freshly generated themed maze, grab gems, open gift boxes for items and
traps, and knock gems out of each other. English and Italian UI.

## How to play

- **Goal:** *Time Attack* (most gems when the clock hits zero) or *Gem Race* (first to the target).
  Gems are worth 1, 3 or 5; the golden gem in the center is worth 10. In the final **frenzy** every
  gem counts double.
- **Survival:** everyone starts with 3 lives and every attack costs one (3 s of safety after each
  loss). Every 10 gems buy a life, and pink life gems give one too. Last hunter standing wins.
- **Tackle:** run into a rival to knock them back and steal a gem — two from the leader, who wears
  a crown and a golden light beam visible from anywhere in the maze.
- **Items:** gift boxes fill up to 3 slots (a full inventory can't open boxes). Some boxes are
  pranks, some hold two items. 15 items: traps (cake, water balloon, speaker, banana peel,
  black box), attacks with light aim assist (spring glove, magnet, tickle ray, snowball, thunder)
  and utilities (spring shoes, bubble, jackpot, warp, radar). Traps catch their owner too.
- **Hunters:** each has a trait and a superpower that recharges every 30 s —
  Dashy *Turbo*, Bouncer *Ground Pound*, Tanky *Iron Shield*, Tricky *Swap* (with the leader).
- **Arenas:** Candy Kingdom, Enchanted Forest, Secret Garden, Roman Colosseum, Desert Temple,
  Frozen Peaks. Each is split into four colored zones with a giant landmark plus the Golden Plaza,
  and every screen names its zone so you can peek at where rivals are. Portals, map boards,
  moving gates and trampolines keep routes unpredictable.

The in-game **How to play** screen explains all of this; **Controls** shows and remaps every button.

## Controls

| Action        | P1 keyboard + mouse          | P2 keyboard     | Gamepad          |
|---------------|------------------------------|-----------------|------------------|
| Move          | W A S D                      | Arrows          | Left stick       |
| Look          | Mouse (or I J K L)           | Numpad 8 4 5 6  | Right stick      |
| Jump          | Space / right click          | Numpad 0        | RB / RT          |
| Items 1–3     | Q E R (wheel + left click)   | Numpad 7 9 1    | X A B            |
| Superpower    | F (wheel + left click)       | Numpad 3        | Y                |
| Camera view   | V                            | Numpad +        | R3               |
| Pause         | Esc                          | Esc             | Start            |

Gamepads go to P2, P3, P4 in connection order; P1 gets a pad only when every other player has one.
Menus work with the pad too (A confirm, B back). Rebinds are saved to `user://controls.cfg`;
the language and the last match setup (players, goal, arena) to `user://settings.cfg`, both
restored at startup. `user://` is `~/.local/share/gem-hunters/` on Linux
(`%APPDATA%\gem-hunters` on Windows).

## Download

Portable builds for Windows and Linux (x86_64) are on the
[Releases](https://github.com/thegoodflow/gem-hunters/releases) page: no install needed.

- **Windows:** unzip `GemHunters-windows-x86_64.zip` and run `GemHunters.exe`.
- **Linux:** `tar -xzf GemHunters-linux-x86_64.tar.gz` and run `./GemHunters.x86_64`.

Every pull request and master push builds both packages (Actions → *Build & release*); pushing a
`v*` tag (e.g. `git tag v1.0.0 && git push origin v1.0.0`) publishes them as a release. Export
presets live in `export_presets.cfg`.

## Running from source

Godot 4.3 is required. The editor binary is not in the repository (it is over GitHub's file
size limit); download **Godot 4.3 stable** (standard, not .NET) from
<https://godotengine.org/download/archive/4.3-stable/> and either:

- put it at `.tools/Godot_v4.3-stable_linux.x86_64`, or
- set `GODOT_BIN=/path/to/godot`, or
- have `godot4` / `godot` on your `PATH`.

```bash
./start.sh                                   # launch (extra args go to Godot)
./start.sh --windowed --resolution 1600x900  # windowed
godot --path . -e                            # open the editor
godot --headless --path . --import           # re-import (surfaces parse/load errors)
```

## Project layout

```
autoloads/    Constants, GameManager (scores, state, clock), InputManager, Audio, Localization
scenes/main/  Main.tscn + SplitScreenManager (match composition root)
scenes/level/ MazeLevel (generated arenas), portals, map boards, moving gates, trampolines
scenes/player/ Player, shared CharacterModel
scenes/powerups/, scenes/traps/  gift boxes, projectiles, traps
scenes/ui/    menus, HUD, character selection, How to play, Controls
resources/    CharacterData, PowerUpData and LevelConfig .tres files
assets/       UI icons and splash, audio, localization/strings.csv (en, it)
```

Coding rules (English-only code, localization keys for UI text, no magic numbers, static typing,
theme-only UI styling) are in [GEMINI.md](GEMINI.md); architecture notes are in [CLAUDE.md](CLAUDE.md).
