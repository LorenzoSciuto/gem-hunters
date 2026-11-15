## SpawnClearance.gd
## The one placement rule of the arena: nothing appears on top of something
## else. Pickups (every gem, gift boxes), props and traps keep
## Constants.SPAWN_CLEARANCE apart on the floor plane, so two pickups are never
## grabbed in the same step. Static helper, never instanced.
class_name SpawnClearance
extends RefCounted

## While no spot is free, spawners try again this often (gameplay seconds).
const RETRY_INTERVAL: float = 1.0


## True when [param pos] is at least SPAWN_CLEARANCE (floor distance) from every
## pickup, gift box, prop and trap, except [param ignore] (the node being moved).
static func is_clear(tree: SceneTree, pos: Vector3, ignore: Node = null) -> bool:
	for group: String in [Constants.GROUP_PICKUPS, Constants.GROUP_SURPRISE_BOXES,
			Constants.GROUP_PROPS, Constants.GROUP_TRAPS]:
		for node: Node in tree.get_nodes_in_group(group):
			if node == ignore or not node is Node3D:
				continue
			var flat: Vector3 = (node as Node3D).global_position - pos
			if Vector2(flat.x, flat.z).length() < Constants.SPAWN_CLEARANCE:
				return false
	return true
