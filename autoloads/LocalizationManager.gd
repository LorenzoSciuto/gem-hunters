## LocalizationManager.gd
## Autoload that registers the CSV translations (English default, Italian)
## and switches the active locale. UI text uses tr("KEY") everywhere.
## The chosen language is saved and restored at startup.
extends Node

enum Language {
	EN, ## English (default)
	IT, ## Italian
}

signal language_changed(new_language: Language)

## Section of user://settings.cfg holding the language.
const SETTINGS_SECTION: String = "ui"

const TRANSLATIONS: Array[String] = [
	"res://assets/localization/strings.en.translation",
	"res://assets/localization/strings.it.translation",
]
const LOCALES: Dictionary = {
	Language.EN: "en",
	Language.IT: "it",
}

var _current_language: Language = Language.EN


func _ready() -> void:
	for path: String in TRANSLATIONS:
		TranslationServer.add_translation(load(path) as Translation)
	var saved: int = int(Settings.read(SETTINGS_SECTION).get("language", _current_language))
	if LOCALES.has(saved):
		_current_language = saved as Language
	TranslationServer.set_locale(LOCALES[_current_language])


func set_language(lang: Language) -> void:
	if lang == _current_language:
		return
	_current_language = lang
	TranslationServer.set_locale(LOCALES[lang])
	Settings.write(SETTINGS_SECTION, { "language": lang })
	language_changed.emit(lang)


func get_current_language() -> Language:
	return _current_language
