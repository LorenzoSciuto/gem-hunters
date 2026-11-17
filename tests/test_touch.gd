## Touch controls, driven by synthetic screen touches: the stick moves the
## hunter, a drag on the right turns it, the jump button jumps, an item slot
## fires its item and the pause button pauses.
extends "res://tests/match_test.gd"

const STICK_PUSH: float = 160.0
const LOOK_DRAG: float = 200.0
## Canvas pixels per window pixel (the headless window is tiny).
var _scale: Vector2 = Vector2.ONE


func _run_test() -> void:
	input.touch_active = true
	var players: Array[Node] = await start_match(2, constants.MatchMode.TIME, 1)
	var hunter: CharacterBody3D = players[0]
	var controls: Node = root.find_children("*", "TouchControls", true, false)[0]
	var canvas: Vector2 = root.get_visible_rect().size
	_scale = Vector2(root.size) / canvas

	var stick_at: Vector2 = Vector2(300.0, canvas.y - 300.0)
	var start: Vector3 = hunter.global_position
	_touch(0, stick_at, true)
	_drag(0, stick_at, stick_at + Vector2.UP * STICK_PUSH)
	await wait(0.8)
	expect(start.distance_to(hunter.global_position) > 1.0, "the stick moves the hunter")

	var look_at: Vector2 = Vector2(canvas.x * 0.7, 300.0)
	var yaw: float = hunter.rotation.y
	_touch(1, look_at, true)
	_drag(1, look_at, look_at + Vector2.RIGHT * LOOK_DRAG)
	await wait(0.2)
	expect(not is_equal_approx(hunter.rotation.y, yaw), "a drag on the right turns the hunter")

	_touch(1, look_at, false)
	_touch(0, stick_at, false)
	await wait(0.5)
	expect(hunter.velocity.length() < 0.5, "releasing the stick stops the hunter")

	var jump_at: Vector2 = controls._jump_center()
	_touch(2, jump_at, true)
	await wait(0.1)
	expect(hunter.velocity.y > 0.0, "the jump button jumps")
	_touch(2, jump_at, false)

	hunter.items.equip(constants.PowerUpType.UTILITY_BUBBLE)
	await wait(0.6)
	var slot: Control = controls.item_pad._slots[0]
	var slot_at: Vector2 = slot.get_global_transform_with_canvas() * (slot.size * 0.5)
	_touch(3, slot_at, true)
	await wait(0.2)
	_touch(3, slot_at, false)
	expect(hunter.items.has_free_slot() and hunter.items._slots[0] == constants.PowerUpType.NONE,
		"tapping an item slot uses the item")

	controls.pause_requested.emit()
	await process_frame
	expect(paused, "the pause button pauses the match")
	paused = false
	finish()


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = at * _scale
	event.pressed = pressed
	Input.parse_input_event(event)


func _drag(index: int, from: Vector2, to: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = to * _scale
	event.relative = (to - from) * _scale
	Input.parse_input_event(event)
