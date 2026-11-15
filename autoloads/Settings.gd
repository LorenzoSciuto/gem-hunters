## Settings.gd
## Static helper over user://settings.cfg (Constants.SETTINGS_PATH): each
## autoload reads and writes its own section ("ui" language, "match" last
## setup) without touching the others. Not an autoload itself.
class_name Settings
extends RefCounted


## Every key of [param section]; empty when the file or section is missing.
static func read(section: String) -> Dictionary:
	var cfg: ConfigFile = ConfigFile.new()
	var values: Dictionary = {}
	if cfg.load(Constants.SETTINGS_PATH) == OK and cfg.has_section(section):
		for key: String in cfg.get_section_keys(section):
			values[key] = cfg.get_value(section, key)
	return values


## Stores [param values] in [param section], keeping every other section.
static func write(section: String, values: Dictionary) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(Constants.SETTINGS_PATH)  # A missing file is fine: it is created.
	for key: String in values:
		cfg.set_value(section, key, values[key])
	cfg.save(Constants.SETTINGS_PATH)
