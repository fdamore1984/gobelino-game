extends Node
## Impostazioni del giocatore (autoload "Settings"). Il gioco è in italiano
## e in inglese: i testi stanno in data/translations.csv (colonne "it" ed
## "en"). La lingua si sceglie dal pannello Opzioni e si salva in
## user://settings.json; senza il file (prima partita, versioni precedenti)
## vale quella del sistema: italiano se è l'italiano, inglese per tutte le
## altre. All'avvio applica anche i comandi personalizzati dal giocatore
## (vedi Keybinds). Nel browser le impostazioni seguono l'account del sito
## (vedi Cloud): quando ne arrivano di nuove si rileggono (load_saved). Lì
## la lingua la sceglie il sito (window.ufotizioCloud.language(), contratto
## in docs/web.md) e vale più di quella salvata; cambiandola dalle Opzioni la
## si dice anche al sito (setLanguage), che passa alla stessa lingua.

const PATH := "user://settings.json"
## Lingue del gioco, nell'ordine in cui si scorrono in Opzioni.
const LANGUAGES := ["it", "en"]
const FALLBACK_LANGUAGE := "en"
const SITE_INTERFACE := "ufotizioCloud"

var language := FALLBACK_LANGUAGE


func _ready() -> void:
	load_saved()


## Lingua e comandi salvati (o quelli predefiniti).
func load_saved() -> void:
	language = _system_language()
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary and str(parsed.get("language", "")) in LANGUAGES:
			language = str(parsed["language"])
	var site := _site_language()
	if site != "":
		language = site
	_apply_language()
	Keybinds.load_saved()


## Cambia la lingua (subito, per tutti i testi) e la salva.
func set_language(code: String) -> void:
	if code not in LANGUAGES:
		return
	language = code
	_apply_language()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		var text := JSON.stringify({"language": language}, "\t")
		file.store_string(text)
		file.close()
		Cloud.push(PATH.get_file(), text)
	var site := _site()
	if site != null and site.get("setLanguage") != null:
		site.setLanguage(language)


## Lingua dei testi e nome del gioco nel titolo della finestra.
func _apply_language() -> void:
	TranslationServer.set_locale(language)
	get_window().title = tr("GAME_TITLE")


## La lingua successiva a quella attuale (per il pulsante delle Opzioni).
func next_language() -> String:
	return LANGUAGES[(LANGUAGES.find(language) + 1) % LANGUAGES.size()]


## Oggetto della pagina del sito (null fuori dal browser o senza sito).
func _site() -> Object:
	return JavaScriptBridge.get_interface(SITE_INTERFACE) if Platform.is_web else null


## Lingua del sito che ospita il gioco ("" se non c'è o non è del gioco).
func _site_language() -> String:
	var site := _site()
	if site == null or site.get("language") == null:
		return ""
	var code := str(site.language())
	return code if code in LANGUAGES else ""


static func _system_language() -> String:
	var system := OS.get_locale_language()
	return system if system in LANGUAGES else FALLBACK_LANGUAGE
