# Gem Hunters: Tag & Trap — Agent Rules

## Language Rules (ALWAYS ENFORCED)
- ALL code, variable names, function names, class names, constants, enums, signals → **English only**
- ALL comments and documentation → **English only**
- ALL file names and folder names → **English only**
- The in-game UI text uses a **localization system** (English + Italian via Godot's Translation/CSV system). Never hardcode display strings — always use `tr("KEY")`.

## Architecture Principles
- **SOLID** principles enforced at all times.
- **Single Responsibility**: one script = one concern. No god-objects.
- **Composition over inheritance**: prefer `@export` + signals over deep class hierarchies.
- **Autoloads only for true singletons**: GameManager, AudioManager, LocalizationManager.
- **Resource types** (`extends Resource`) for all data/config (PowerUpData, PlayerConfig, LevelConfig).
- **Signal-driven communication** between systems. Scripts must not directly call methods on unrelated systems; use signals or the autoload layer.
- **No magic numbers**: every constant must be named and placed in a `const` block at the top of the script.
- **Type hints everywhere**: all variables, parameters, and return types must be explicitly typed in GDScript.

## Godot 4 Specific Rules
- Use `@export` and `@onready` annotations correctly.
- Prefer `PackedScene` preloads at the top of scripts, not inside functions.
- Use `SubViewport` with `own_world_3d = false` for split-screen.
- Never use `get_node()` string paths deep into the tree; always use `@onready` or exported references.
- Group names are constants defined in a shared `Groups` autoload or constant file.
- Input actions follow the pattern `p{N}_action_name` (e.g., `p0_jump`, `p1_use_powerup`).

## Graphics & Visual Standards
- Low-poly aesthetic: flat-shaded materials, toon outline shader on all characters and interactive objects.
- Color palette: pastel/vivid (Fall Guys / Splatoon style). All colors defined in a `Theme` resource.
- All meshes use `SpatialMaterial` or `StandardMaterial3D` with `shading_mode = UNSHADED` or toon shading.
- Particle effects (`GPUParticles3D`) for every collectible interaction, hit, and power-up activation.
- All UI elements use the project's `Theme` resource — no inline style overrides.

## File & Folder Conventions
- Scenes: `PascalCase.tscn`
- Scripts: `PascalCase.gd` (matching scene name)
- Assets: `snake_case.png`, `snake_case.ogg`, etc.
- Shaders: `snake_case.gdshader`
- Resources: `snake_case.tres`
- Autoloads live in `autoloads/`
- Scenes live in `scenes/` with sub-folders per domain
- Shared constants/enums live in `autoloads/Constants.gd`

## Project: Gem Hunters
- Developer / Studio: **Wennovate**
- Genre: 3D local multiplayer (2–4 players), split-screen, couch co-op party game
- Target audience: children aged 9+, fun/chaotic, couch play
- Engine: Godot 4.3+
- Supported languages: English (default), Italian

