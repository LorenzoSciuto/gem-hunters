## Every script in the project loads. With the warnings set to errors in
## project.godot ([debug]), this also means: no unused variables, parameters,
## constants or signals, no unreachable code and no untyped declarations.
extends "res://tests/match_test.gd"

const SKIPPED_DIRS: Array[String] = [".godot", ".tools", "build"]


func _run_test() -> void:
	var scripts: Array[String] = _scripts_in("res://")
	expect(scripts.size() > 0, "no scripts found")
	for path: String in scripts:
		expect(load(path) != null, "%s does not compile" % path)
	finish()


func _scripts_in(dir: String) -> Array[String]:
	var found: Array[String] = []
	for sub: String in DirAccess.get_directories_at(dir):
		if sub not in SKIPPED_DIRS:
			found.append_array(_scripts_in(dir.path_join(sub)))
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() == "gd":
			found.append(dir.path_join(file))
	return found
