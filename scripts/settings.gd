extends Node
## Impostazioni del giocatore (autoload "Settings"), salvate in user://.
## Per ora solo la lingua: italiano o inglese. Al primo avvio si usa la
## lingua del sistema, se è l'italiano, altrimenti l'inglese.

const PATH := "user://settings.cfg"
const LANGUAGES: Array[String] = ["it", "en"]

var language := ""


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		language = config.get_value("general", "language", "")
	if language not in LANGUAGES:
		language = "it" if OS.get_locale_language() == "it" else "en"
	TranslationServer.set_locale(language)


func set_language(code: String) -> void:
	language = code
	TranslationServer.set_locale(code)
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value("general", "language", code)
	config.save(PATH)


## Passa all'altra lingua disponibile.
func toggle_language() -> void:
	var next := (LANGUAGES.find(language) + 1) % LANGUAGES.size()
	set_language(LANGUAGES[next])
