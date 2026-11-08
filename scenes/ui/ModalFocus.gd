## ModalFocus.gd
## Child of a dialog: while the dialog is visible, keyboard/gamepad focus can't
## leave it, so the menu behind can't be driven (its dim layer already stops
## the mouse). Focus that escapes goes back to the last control inside. The
## dialog also draws above the menu, whose active buttons rise to z_index 1.
extends Node
class_name ModalFocus

const DIALOG_Z: int = 10

var _last_inside: Control = null


func _ready() -> void:
	(get_parent() as Control).z_index = DIALOG_Z
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _on_focus_changed(control: Control) -> void:
	var dialog: Control = get_parent() as Control
	if not dialog.is_visible_in_tree():
		return
	if dialog.is_ancestor_of(control):
		_last_inside = control
	elif is_instance_valid(_last_inside) and _last_inside.is_visible_in_tree():
		_last_inside.grab_focus.call_deferred()
