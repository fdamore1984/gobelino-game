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
##
## Le altre opzioni (pannello Opzioni, valgono per tutte le partite):
## difficoltà (vedi difficulty_value e la voce "difficulty" di
## data/world.json), vibrazione del controller (vedi Rumble), numeri dei
## danni sopra i nemici (vedi DamagePopups), tremolio della telecamera e
## sangue (normale, ridotto, spento: vedi shake_factor e blood_factor) e
## dimensione dell'interfaccia (vedi apply_ui_scale). Nei file delle
## versioni precedenti mancano: valgono i valori predefiniti.

## Le opzioni sono cambiate (per chi ne mostra il valore o ne dipende).
signal changed

const PATH := "user://settings.json"
## Lingue del gioco, nell'ordine in cui si scorrono in Opzioni.
const LANGUAGES := ["it", "en"]
const FALLBACK_LANGUAGE := "en"
const SITE_INTERFACE := "ufotizioCloud"
## Valori delle opzioni, nell'ordine in cui si scorrono in Opzioni.
const DIFFICULTIES := ["easy", "normal", "hard"]
const LEVELS := ["normal", "reduced", "off"]
const UI_SCALES := [0.9, 1.0, 1.15, 1.3]
## Parte del tremolio della telecamera e del sangue per ogni livello.
const LEVEL_FACTORS := {"normal": 1.0, "reduced": 0.45, "off": 0.0}
const WORLD_DATA := preload("res://data/world.json")

var language := FALLBACK_LANGUAGE
var difficulty := "normal"
var vibration := true
var damage_numbers := true
var camera_shake := "normal"
var blood := "normal"
var ui_scale := 1.0


func _ready() -> void:
	load_saved()


## Lingua, opzioni e comandi salvati (o quelli predefiniti). I valori che
## mancano o non si riconoscono restano quelli predefiniti.
func load_saved() -> void:
	language = _system_language()
	var saved := {}
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			saved = parsed
	if str(saved.get("language", "")) in LANGUAGES:
		language = str(saved["language"])
	difficulty = _pick(saved.get("difficulty"), DIFFICULTIES, "normal")
	vibration = bool(saved.get("vibration", true))
	damage_numbers = bool(saved.get("damage_numbers", true))
	camera_shake = _pick(saved.get("camera_shake"), LEVELS, "normal")
	blood = _pick(saved.get("blood"), LEVELS, "normal")
	ui_scale = float(saved.get("ui_scale", 1.0))
	if not UI_SCALES.has(ui_scale):
		ui_scale = 1.0
	var site := _site_language()
	if site != "":
		language = site
	_apply_language()
	apply_ui_scale()
	Keybinds.load_saved()
	changed.emit()


static func _pick(value: Variant, allowed: Array, fallback: String) -> String:
	return str(value) if str(value) in allowed else fallback


## Cambia un'opzione (nome della variabile e valore) e la salva.
func set_option(option: String, value: Variant) -> void:
	set(option, value)
	if option == "ui_scale":
		apply_ui_scale()
	save()
	changed.emit()


## Il valore successivo di values dopo current (per i pulsanti delle Opzioni).
static func next_of(values: Array, current: Variant) -> Variant:
	return values[(values.find(current) + 1) % values.size()]


## Salva lingua e opzioni (e nel browser le manda all'account del sito).
func save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		var text := JSON.stringify({"language": language, "difficulty": difficulty, "vibration": vibration,
				"damage_numbers": damage_numbers, "camera_shake": camera_shake, "blood": blood, "ui_scale": ui_scale}, "\t")
		file.store_string(text)
		file.close()
		Cloud.push(PATH.get_file(), text)


## Valore della difficoltà scelta (voce "difficulty" di data/world.json):
## danno dei colpi al giocatore, durata dell'invulnerabilità, grandezza
## delle orde.
func difficulty_value(key: String) -> float:
	var levels: Dictionary = WORLD_DATA.data["difficulty"]
	return float((levels.get(difficulty, levels["normal"]) as Dictionary)[key])


## Parte del tremolio della telecamera da usare (0: spento).
func shake_factor() -> float:
	return LEVEL_FACTORS[camera_shake]


## Parte del sangue da mostrare (0: niente sangue).
func blood_factor() -> float:
	return LEVEL_FACTORS[blood]


## Dimensione dell'interfaccia: tutto ciò che si disegna sullo schermo si
## ingrandisce (content_scale_factor della finestra); il mondo resta della
## stessa grandezza perché la telecamera si allontana di altrettanto (vedi
## Player._update_zoom).
func apply_ui_scale() -> void:
	if is_inside_tree():
		get_tree().root.content_scale_factor = ui_scale


## Cambia la lingua (subito, per tutti i testi) e la salva.
func set_language(code: String) -> void:
	if code not in LANGUAGES:
		return
	language = code
	_apply_language()
	save()
	changed.emit()
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
