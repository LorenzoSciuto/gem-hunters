## OverviewCamera.gd
## Top-down orthographic camera for the spare viewport in 3-player mode.
extends Camera3D

const HEIGHT: float = 80.0
const MARGIN: float = 1.1


## Frames a square arena of side [param arena_size] centered on the origin.
func frame_arena(arena_size: float) -> void:
	projection = PROJECTION_ORTHOGONAL
	size = arena_size * MARGIN
	far = HEIGHT * 2.0
	global_position = Vector3(0.0, HEIGHT, 0.0)
	look_at(Vector3.ZERO, Vector3.FORWARD)
