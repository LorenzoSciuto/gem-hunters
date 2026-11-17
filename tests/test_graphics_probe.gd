## The graphics probe (scenes/debug/GraphicsProbe) runs every step to the end.
extends "res://tests/match_test.gd"

const PROBE_SCENE: String = "res://scenes/debug/GraphicsProbe.tscn"
const STEP_SECONDS: float = 0.2


func _run_test() -> void:
	var probe: Node = (load(PROBE_SCENE) as PackedScene).instantiate()
	probe.step_seconds = STEP_SECONDS
	root.add_child(probe)
	await probe.finished
	expect(probe.get_child_count() > 0, "the probe ends on the menu backdrop")
	finish()
