## UiMotion.gd
## Motion layer for the whole UI, applied automatically to every node that
## enters the tree: buttons grow on hover / focus and squish when pressed, and
## cards (plain PanelContainers: menus, dialogs, selection, results) pop in
## when they appear. Scenes need no code for it. pulse() is shared by the HUD.
extends Node

## Hover / press resize by a fixed number of pixels per side (not a percentage),
## so wide buttons never grow into their neighbours (containers keep 14 px gaps).
const HOVER_GROW_PX: float = 3.0
const PRESS_SHRINK_PX: float = -3.0
const HOVER_TIME: float = 0.12
const CARD_START_SCALE: float = 0.94
const CARD_TIME: float = 0.28
## pulse(): a quick pop to draw the eye to a value that just changed.
const PULSE_SCALE: float = 1.35
const PULSE_TIME: float = 0.15


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is Button:
		_attach_button(node as Button)
	elif node is PanelContainer and (node as PanelContainer).theme_type_variation == &"":
		_attach_card(node as PanelContainer)


func _attach_button(button: Button) -> void:
	var settle: Callable = func() -> void:
		var active: bool = button.is_hovered() or button.has_focus()
		_grow(button, HOVER_GROW_PX if active else 0.0)
	button.mouse_entered.connect(_grow.bind(button, HOVER_GROW_PX))
	button.focus_entered.connect(_grow.bind(button, HOVER_GROW_PX))
	button.mouse_exited.connect(settle)
	button.focus_exited.connect(settle)
	button.button_down.connect(_grow.bind(button, PRESS_SHRINK_PX))
	button.button_up.connect(settle)


func _attach_card(card: PanelContainer) -> void:
	card.visibility_changed.connect(func() -> void:
		if card.is_visible_in_tree():
			_pop_in(card))
	card.ready.connect(func() -> void:
		if card.is_visible_in_tree():
			_pop_in(card), CONNECT_ONE_SHOT)


## A quick pop around the centre (score changed, item received, zone entered...).
func pulse(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	var tween: Tween = control.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(control, "scale", Vector2.ONE * PULSE_SCALE, PULSE_TIME * 0.5)
	tween.tween_property(control, "scale", Vector2.ONE, PULSE_TIME * 0.5)


## Grows [param control] by up to [param px] per side (negative shrinks), around
## its centre; containers ignore scale, so layout is never disturbed. The
## active button draws above its neighbours.
func _grow(control: Control, px: float) -> void:
	control.pivot_offset = control.size * 0.5
	control.z_index = 1 if px > 0.0 else 0
	# Uniform (text never stretches), sized on the longer side: no side moves more than px.
	var target: Vector2 = Vector2.ONE * (1.0 + px * 2.0 / maxf(control.size.x, control.size.y))
	var tween: Tween = control.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", target, HOVER_TIME)


func _pop_in(card: Control) -> void:
	# Wait one frame so the container has its final size for the pivot.
	await get_tree().process_frame
	if not is_instance_valid(card):
		return
	# Keep any scale the owner set (e.g. the selector shrinking to fit a quadrant).
	var final_scale: Vector2 = card.scale
	if card.pivot_offset == Vector2.ZERO:
		card.pivot_offset = card.size * 0.5
	card.scale = final_scale * CARD_START_SCALE
	card.modulate.a = 0.0
	var tween: Tween = card.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", final_scale, CARD_TIME)
	tween.tween_property(card, "modulate:a", 1.0, CARD_TIME * 0.6)
