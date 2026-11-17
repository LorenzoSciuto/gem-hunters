## LocalizationManager.gd
## Autoload that switches the active locale (English default, Italian). The
## CSV translations are registered in project.godot
## ([internationalization] locale/translations), so they are loaded before any
## scene: text set in a scene is translated when the scene is built, and would
## stay a raw key if the translations arrived later with the locale unchanged.
## UI text uses tr("KEY") everywhere.
## The chosen language is saved and restored at startup.
extends Node

enum Language {
	EN, ## English (default)
	IT, ## Italian
}

signal language_changed(new_language: Language)

## Section of user://settings.cfg holding the language.
const SETTINGS_SECTION: String = "ui"

const LOCALES: Dictionary = {
	Language.EN: "en",
	Language.IT: "it",
}

var _current_language: Language = Language.EN


func _ready() -> void:
	var saved: int = int(Settings.read(SETTINGS_SECTION).get("language", _system_language()))
	if LOCALES.has(saved):
		_current_language = saved as Language
	TranslationServer.set_locale(LOCALES[_current_language])


## First launch: the system's language when the game speaks it, else English.
func _system_language() -> Language:
	var code: String = OS.get_locale_language()
	for lang: Language in LOCALES:
		if LOCALES[lang] == code:
			return lang
	return Language.EN


func set_language(lang: Language) -> void:
	if lang == _current_language:
		return
	_current_language = lang
	TranslationServer.set_locale(LOCALES[lang])
	Settings.write(SETTINGS_SECTION, { "language": lang })
	language_changed.emit(lang)


func get_current_language() -> Language:
	return _current_language
