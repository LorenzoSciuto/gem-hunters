## The translations are loaded before the autoloads are ready, so text set in
## a scene is translated when the scene is built (else it stays a raw key when
## the saved language is also the system's).
extends "res://tests/match_test.gd"

var _locales_at_start: PackedStringArray = []


func _initialize() -> void:
	_locales_at_start = TranslationServer.get_loaded_locales()
	super()


func _run_test() -> void:
	for locale: String in ["en", "it"]:
		expect(locale in _locales_at_start, "the %s translation is not loaded at startup" % locale)
	finish()
