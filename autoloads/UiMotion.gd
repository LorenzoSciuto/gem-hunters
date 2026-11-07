## UiMotion.gd
## Motion layer for the whole UI, applied automatically to every node that
## enters the tree: buttons grow on hover / focus and squish when pressed, and
## cards (plain PanelContainers: menus, dialogs, selection, results) pop in
## when they appear. Scenes need no code for it.
extends Node

const HOVER_SCALE: float = 1.05
const PRESS_SCALE: float = 0.94
const HOVER_TIME: float = 0.12
const CARD_START_SCALE: float = 0.94
const CARD_TIME: float = 0.28


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is Button:
		_attach_button(node as Button)
	elif node is PanelContainer and (node as PanelContainer).theme_type_variation == &"":
		_attach_card(node as PanelContainer)


func _attach_button(button: Button) -> void:
	button.mouse_entered.connect(_scale_to.bind(button, HOVER_SCALE))
	button.focus_entered.connect(_scale_to.bind(button, HOVER_SCALE))
	button.mouse_exited.connect(func() -> void: _scale_to(button, HOVER_SCALE if button.has_focus() else 1.0))
	button.focus_exited.connect(_scale_to.bind(button, 1.0))
	button.button_down.connect(_scale_to.bind(button, PRESS_SCALE))
	button.button_up.connect(func() -> void: _scale_to(button, HOVER_SCALE if button.is_hovered() or button.has_focus() else 1.0))


func _attach_card(card: PanelContainer) -> void:
	card.visibility_changed.connect(func() -> void:
		if card.is_visible_in_tree():
			_pop_in(card))
	card.ready.connect(func() -> void:
		if card.is_visible_in_tree():
			_pop_in(card), CONNECT_ONE_SHOT)


## Containers ignore scale, so scaling around the centre never disturbs layout.
func _scale_to(control: Control, target: float) -> void:
	control.pivot_offset = control.size * 0.5
	var tween: Tween = control.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE * target, HOVER_TIME)


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
