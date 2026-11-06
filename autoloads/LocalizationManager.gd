## LocalizationManager.gd
## Autoload that registers the CSV translations (English default, Italian)
## and switches the active locale. UI text uses tr("KEY") everywhere.
extends Node

enum Language {
	EN, ## English (default)
	IT, ## Italian
}

signal language_changed(new_language: Language)

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
	TranslationServer.set_locale(LOCALES[_current_language])


func set_language(lang: Language) -> void:
	if lang == _current_language:
		return
	_current_language = lang
	TranslationServer.set_locale(LOCALES[lang])
	language_changed.emit(lang)


func get_current_language() -> Language:
	return _current_language
