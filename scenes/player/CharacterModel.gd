## CharacterModel.gd
## Visual body of a character: bean body with belly, expressive face, arms,
## sneakers, per-character accessory and the leader crown.
##
## Accessories live under Rig/Body/Accessories in a node named after the
## character id (CharacterData.id); meshes whose name starts with "Tint" (ears,
## tails) take the character's body colour. A new character needs only its
## .tres and an accessory node, no code. Shared by the
## in-game Player and the selection preview. Origin is at the feet; the model
## faces +Z.
##
## Animation is procedural: the owner feeds [method set_motion] every frame and
## fires one-shot reactions ([method play_hurt], [method play_squash],
## [method play_cheer]); idle breathing and blinking run on their own.
extends Node3D
class_name CharacterModel

const BODY_OUTLINE_WIDTH: float = 0.022
const LIMB_OUTLINE_WIDTH: float = 0.015
const BELLY_LIGHTEN: float = 0.4
const HAND_LIGHTEN: float = 0.15
const SHOE_COLOR: Color = Color(0.97, 0.95, 0.92)

## Walk cycle: stride phase advances this many radians per metre travelled.
const STRIDE_RATE: float = 2.6
const STRIDE_LENGTH: float = 0.17
const STEP_LIFT: float = 0.12
const ARM_SWING: float = 0.95
## Speed at which the walk reaches full amplitude.
const RUN_REF_SPEED: float = 8.0
const MOVE_THRESHOLD: float = 0.5
const LEAN_MAX: float = 0.22
const BOB_HEIGHT: float = 0.06
## Arm pose (rotation around the forward axis, outward).
const ARM_REST_SPREAD: float = 0.18
const ARM_AIR_SPREAD: float = 2.3
const ARM_CHEER_SPREAD: float = 2.8
## Feet tuck up while airborne.
const AIR_FOOT_LIFT: float = 0.12
const AIR_STRETCH: Vector3 = Vector3(0.93, 1.08, 0.93)
const BREATHE_SPEED: float = 3.0
const BREATHE_AMOUNT: float = 0.025
const POSE_LERP: float = 14.0

const BLINK_MIN_GAP: float = 1.8
const BLINK_MAX_GAP: float = 4.5
const BLINK_TIME: float = 0.12
const EYE_CLOSED_SCALE: float = 0.12
const EYE_SQUINT_SCALE: float = 0.3
## Reactions.
const HURT_TIME: float = 0.7
const HURT_FLAIL_SPEED: float = 26.0
const HURT_FLAIL_AMOUNT: float = 0.8
const HURT_MOUTH_SCALE: float = 1.8
## A hurt hunter flashes red for a moment: clearly the one who lost the clash.
const HURT_FLASH_TIME: float = 0.4
const HURT_FLASH_COLOR: Color = Color(1.0, 0.15, 0.1)
const HURT_FLASH_MIX: float = 0.65
const SQUASH_DECAY: float = 6.0
const CHEER_JUMP_SPEED: float = 12.0
## Sad (lost the match): arms hang, the body slumps forward, eyes half shut.
const SAD_ARM_SPREAD: float = 0.04
const SAD_ARM_PITCH: float = 0.35
const SAD_LEAN: float = 0.4
const SAD_SINK: float = 0.06
const SAD_EYE_SCALE: float = 0.45
const SAD_MOUTH_SCALE: float = 0.45

@onready var rig: Node3D = $Rig
@onready var body: Node3D = $Rig/Body
@onready var torso: MeshInstance3D = $Rig/Body/Torso
@onready var belly: MeshInstance3D = $Rig/Body/Belly
@onready var crown: Node3D = $Rig/Body/Crown
@onready var mouth: MeshInstance3D = $Rig/Body/Face/Mouth
@onready var eyes: Array[Node3D] = [$Rig/Body/Face/EyeL, $Rig/Body/Face/EyeR]
@onready var arms: Array[Node3D] = [$Rig/Body/ArmL, $Rig/Body/ArmR]
@onready var feet: Array[Node3D] = [$Rig/FootL, $Rig/FootR]
@onready var accessories: Node3D = $Rig/Body/Accessories

var _base_scale: Vector3 = Vector3.ONE
var _body_rest: Vector3 = Vector3.ZERO
var _feet_rest: Array[Vector3] = []
var _mouth_rest: Vector3 = Vector3.ONE

var _speed: float = 0.0
var _grounded: bool = true
var _phase: float = 0.0
var _time: float = 0.0
var _next_blink: float = 0.0
var _hurt_left: float = 0.0
var _flash_left: float = 0.0
var _sad_left: float = 0.0
var _color: Color = Color(0.98, 0.85, 0.3)
var _cheer_left: float = 0.0
var _squash: float = 0.0


func _ready() -> void:
	_body_rest = body.position
	_mouth_rest = mouth.scale
	for foot: Node3D in feet:
		_feet_rest.append(foot.position)
	_next_blink = randf_range(BLINK_MIN_GAP, BLINK_MAX_GAP)
	_paint(_color)


## Applies color, scale and accessory for [param data].
func set_character(data: CharacterData) -> void:
	if data == null:
		return
	_color = data.color
	_paint(_color)
	_base_scale = data.mesh_scale
	rig.scale = _base_scale
	for accessory: Node in accessories.get_children():
		(accessory as Node3D).visible = accessory.name == data.id


func _paint(color: Color) -> void:
	torso.material_override = ToonMaterials.get_material(color, BODY_OUTLINE_WIDTH)
	belly.material_override = ToonMaterials.get_material(color.lightened(BELLY_LIGHTEN), 0.0)
	for arm: Node3D in arms:
		(arm.get_node("Arm") as MeshInstance3D).material_override = ToonMaterials.get_material(color, LIMB_OUTLINE_WIDTH)
		(arm.get_node("Hand") as MeshInstance3D).material_override = \
			ToonMaterials.get_material(color.lightened(HAND_LIGHTEN), LIMB_OUTLINE_WIDTH)
	for foot: Node3D in feet:
		(foot.get_node("Shoe") as MeshInstance3D).material_override = ToonMaterials.get_material(SHOE_COLOR, LIMB_OUTLINE_WIDTH)
	for part: Node in accessories.find_children("Tint*", "MeshInstance3D", true, false):
		(part as MeshInstance3D).material_override = ToonMaterials.get_material(color, LIMB_OUTLINE_WIDTH)


func set_crown_visible(shown: bool) -> void:
	crown.visible = shown


## Moves every mesh of the model onto one render layer (bit index [param layer]).
func set_render_layer(layer: int) -> void:
	for node: Node in find_children("*", "VisualInstance3D", true, false):
		(node as VisualInstance3D).layers = 1 << layer


## Feeds the locomotion state: horizontal speed (m/s) and whether the feet are down.
func set_motion(horizontal_speed: float, on_floor: bool) -> void:
	_speed = horizontal_speed
	_grounded = on_floor


## Wince: eyes squeeze shut, mouth opens, arms flail, the body flashes red.
func play_hurt() -> void:
	_hurt_left = HURT_TIME
	_flash_left = HURT_FLASH_TIME
	_paint(_color.lerp(HURT_FLASH_COLOR, HURT_FLASH_MIX))


## Pancake squash (landing, being stomped); [param amount] 0..1.
func play_squash(amount: float) -> void:
	_squash = maxf(_squash, amount)


## Arms up and happy hops, for [param duration] seconds.
func play_cheer(duration: float) -> void:
	_cheer_left = duration


## Slumped and glum, for [param duration] seconds.
func play_sad(duration: float) -> void:
	_sad_left = duration


func _process(delta: float) -> void:
	_time += delta
	_hurt_left = maxf(_hurt_left - delta, 0.0)
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_paint(_color)
	_cheer_left = maxf(_cheer_left - delta, 0.0)
	_sad_left = maxf(_sad_left - delta, 0.0)
	_squash = move_toward(_squash, 0.0, SQUASH_DECAY * delta * maxf(_squash, 0.1))
	var w: float = clampf(delta * POSE_LERP, 0.0, 1.0)

	var moving: bool = _grounded and _speed > MOVE_THRESHOLD
	var k: float = clampf(_speed / RUN_REF_SPEED, 0.0, 1.0) if moving else 0.0
	if moving:
		_phase = fmod(_phase + delta * _speed * STRIDE_RATE, TAU)
	var swing: float = sin(_phase) * k

	_pose_feet(swing, k, w)
	_pose_arms(swing, w)
	_pose_body(k, w)
	_pose_face(w)


func _pose_feet(swing: float, k: float, w: float) -> void:
	for n: int in feet.size():
		var side: float = 1.0 if n == 0 else -1.0
		var target: Vector3 = _feet_rest[n]
		if _grounded:
			target.z += swing * side * STRIDE_LENGTH
			target.y += maxf(0.0, cos(_phase) * side) * STEP_LIFT * k
		else:
			target.y += AIR_FOOT_LIFT
			target.z -= side * STRIDE_LENGTH * 0.5
		feet[n].position = feet[n].position.lerp(target, w)


func _pose_arms(swing: float, w: float) -> void:
	for n: int in arms.size():
		var side: float = -1.0 if n == 0 else 1.0
		var spread: float = ARM_REST_SPREAD
		var pitch: float = -swing * ARM_SWING * side
		if _cheer_left > 0.0:
			spread = ARM_CHEER_SPREAD + sin(_time * CHEER_JUMP_SPEED + n) * 0.2
			pitch = 0.0
		elif _hurt_left > 0.0:
			spread = ARM_AIR_SPREAD + sin(_time * HURT_FLAIL_SPEED + n * PI) * HURT_FLAIL_AMOUNT
		elif _sad_left > 0.0:
			spread = SAD_ARM_SPREAD
			pitch = SAD_ARM_PITCH
		elif not _grounded:
			spread = ARM_AIR_SPREAD
			pitch = 0.0
		var arm: Node3D = arms[n]
		arm.rotation.x = lerp_angle(arm.rotation.x, pitch, w)
		arm.rotation.z = lerp_angle(arm.rotation.z, spread * side, w)


func _pose_body(k: float, w: float) -> void:
	var bob: float = absf(sin(_phase)) * BOB_HEIGHT * k
	if _cheer_left > 0.0:
		bob = absf(sin(_time * CHEER_JUMP_SPEED)) * BOB_HEIGHT * 3.0
	var sad: bool = _sad_left > 0.0
	if sad:
		bob = -SAD_SINK
	body.position = body.position.lerp(_body_rest + Vector3.UP * bob, w)
	body.rotation.x = lerp_angle(body.rotation.x, SAD_LEAN if sad else LEAN_MAX * k, w)

	var shape: Vector3 = Vector3.ONE
	if not _grounded:
		shape = AIR_STRETCH
	elif k == 0.0:
		var breathe: float = sin(_time * BREATHE_SPEED) * BREATHE_AMOUNT
		shape = Vector3(1.0 - breathe * 0.5, 1.0 + breathe, 1.0 - breathe * 0.5)
	shape *= Vector3(1.0 + _squash * 0.6, 1.0 - _squash * 0.55, 1.0 + _squash * 0.6)
	rig.scale = rig.scale.lerp(_base_scale * shape, w)


func _pose_face(w: float) -> void:
	_next_blink -= get_process_delta_time()
	var eye_y: float = 1.0
	if _hurt_left > 0.0 or _cheer_left > 0.0:
		eye_y = EYE_SQUINT_SCALE
	elif _sad_left > 0.0:
		eye_y = SAD_EYE_SCALE
	elif _next_blink <= 0.0:
		eye_y = EYE_CLOSED_SCALE
		if _next_blink < -BLINK_TIME:
			_next_blink = randf_range(BLINK_MIN_GAP, BLINK_MAX_GAP)
	for eye: Node3D in eyes:
		eye.scale.y = lerpf(eye.scale.y, eye_y, clampf(w * 2.0, 0.0, 1.0))
	var open: float = 1.0
	if _hurt_left > 0.0 or _cheer_left > 0.0:
		open = HURT_MOUTH_SCALE
	elif _sad_left > 0.0:
		open = SAD_MOUTH_SCALE
	mouth.scale = mouth.scale.lerp(_mouth_rest * Vector3(1.0, open, 1.0), w)
