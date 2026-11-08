## LevelConfig.gd
## Data resource describing one themed arena. MazeLevel.gd turns it into geometry
## at match start, so every match on the same arena gets a fresh maze.
## One .tres per theme lives in resources/levels/.
extends Resource
class_name LevelConfig

## How the maze walls are laid out.
enum Layout {
	CLASSIC,  ## Winding corridors with a few loops.
	ROOMS,    ## Corridors connecting several open plazas.
	RINGS,    ## Concentric rings with gaps (amphitheatre).
}

## Visual kit used for walls, posts and scenery.
enum Style {
	CANDY,
	FOREST,
	GARDEN,
	ROMAN,
	EGYPT,
	WINTER,
}

@export var id: String = ""
@export var name_key: String = ""
@export var description_key: String = ""

@export_group("Layout")
@export var layout: Layout = Layout.CLASSIC
@export var style: Style = Style.CANDY
## Grid size in cells. Odd numbers keep a cell exactly at the arena center.
@export var columns: int = 11
@export var rows: int = 11
@export var cell_size: float = 6.0
@export var wall_height: float = 3.0
@export var wall_thickness: float = 0.8
## Chance to knock down each remaining interior wall, creating loops to escape chasers.
@export_range(0.0, 1.0) var loop_chance: float = 0.15
## Number of open plazas carved into the maze (ROOMS layout).
@export var room_count: int = 0
## CLASSIC/ROOMS: chance the maze keeps going straight, for long corridors.
@export_range(0.0, 1.0) var corridor_bias: float = 0.0

@export_group("Gameplay props")
@export var surprise_box_count: int = 6
@export var trampoline_count: int = 3
@export var sprinkler_count: int = 0
@export var ice_patch_count: int = 0
## Quicksand pools that slow down whoever wades through.
@export var quicksand_count: int = 0
## Teleport portal pairs, placed far apart.
@export var portal_pairs: int = 2
## Map beacons: step on one to see where everyone is.
@export var map_beacon_count: int = 2
## Wall sections that open and close at random.
@export var gate_count: int = 5

@export_group("Colors")
@export var floor_color_a: Color = Color(0.5, 0.85, 0.5)
@export var floor_color_b: Color = Color(0.6, 0.9, 0.55)
@export var wall_color_a: Color = Color(1.0, 0.45, 0.6)
@export var wall_color_b: Color = Color(1.0, 1.0, 1.0)
## Extra palette for decorations (flowers, candies, gems on walls...).
@export var accent_colors: Array[Color] = [Color(1, 0.5, 0.5), Color(1, 0.9, 0.4)]
## Ground outside the maze.
@export var outer_ground_color: Color = Color(0.45, 0.75, 0.45)

@export_group("Environment")
@export var sky_top_color: Color = Color(0.25, 0.6, 1.0)
@export var sky_horizon_color: Color = Color(0.85, 0.9, 1.0)
@export var sun_color: Color = Color(1.0, 0.97, 0.9)
@export var sun_energy: float = 1.1
@export var ambient_color: Color = Color(0.7, 0.75, 0.85)
@export var ambient_energy: float = 0.35
@export var fog_density: float = 0.0
@export var fog_color: Color = Color(1, 1, 1)
## Number of scenery props scattered inside the maze (flowers, mushrooms, statues...).
@export var decoration_count: int = 30
