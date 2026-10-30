extends Node
## Salvataggi legati all'account del sito (autoload "Cloud"). Vale solo
## nella versione per il browser (Platform.is_web): la pagina di
## ufotizio.com che ospita il gioco offre l'oggetto JavaScript
## window.ufotizioCloud (contratto in docs/web.md) e qui si tengono
## allineati i file del giocatore in user:// (slot e comandi)
## con le copie sull'account. Senza quell'oggetto, o senza aver fatto
## l'accesso, i file restano solo nel browser, come nelle altre versioni.
##
## All'avvio del menù (sync) si confronta ogni file con la sua copia
## sull'account e vince la più recente: quella dell'account si scrive in
## user://, quella del browser si carica sull'account. A ogni salvataggio
## (push) e cancellazione (remove) la copia sull'account si aggiorna
## subito. L'ora di ogni file si segna in MANIFEST_PATH; per i file mai
## sincronizzati vale "saved_at" (salvataggi) o l'ora del file. Anche le
## cancellazioni hanno un'ora (sull'account restano come file "deleted"):
## così uno slot eliminato su un dispositivo non torna da un altro.

## Fine della sincronizzazione: changed è vero se sono arrivati file
## dall'account (il menù rilegge gli slot).
signal synced(changed: bool)

## Nome del gioco sull'account (lo stesso account vale per tutti i giochi
## del sito).
const GAME_ID := "gobelino"
const JS_INTERFACE := "ufotizioCloud"
const MANIFEST_PATH := "user://cloud_sync.json"
## Oltre questo tempo senza risposta si gioca coi file del browser.
const SYNC_TIMEOUT := 12.0

enum State { LOCAL, SYNCING, LINKED, FAILED }

var state := State.LOCAL
var _api: Object
## I callback di JavaScriptBridge vanno tenuti vivi finché la Promise non
## risponde.
var _loaded_callback: Object
var _failed_callback: Object
var _sync_id := 0
## Nome del file -> ora (secondi Unix) della versione nel browser.
var _manifest := {}


func _ready() -> void:
	if not Platform.is_web:
		return
	_api = JavaScriptBridge.get_interface(JS_INTERFACE)
	if FileAccess.file_exists(MANIFEST_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Dictionary:
			_manifest = parsed


## Il giocatore ha fatto l'accesso al sito: i salvataggi vanno sull'account.
func signed_in() -> bool:
	return _api != null and bool(_api.signedIn())


## Nome dell'account per il menù ("" senza accesso).
func user_name() -> String:
	return str(_api.userName()) if signed_in() else ""


func is_syncing() -> bool:
	return state == State.SYNCING


## File del giocatore da tenere sull'account.
func files() -> Array[String]:
	var names: Array[String] = []
	for index in range(1, SaveGame.SLOTS + 1):
		names.append((SaveGame.PATH % index).get_file())
	names.append(Keybinds.PATH.get_file())
	return names


## Confronta i file del browser con quelli dell'account (vedi sopra).
func sync() -> void:
	if not signed_in():
		state = State.LOCAL
		synced.emit(false)
		return
	if state == State.SYNCING:
		return
	state = State.SYNCING
	_sync_id += 1
	_loaded_callback = JavaScriptBridge.create_callback(_on_loaded.bind(_sync_id))
	_failed_callback = JavaScriptBridge.create_callback(_on_failed.bind(_sync_id))
	_api.loadFiles(GAME_ID).then(_loaded_callback, _failed_callback)
	get_tree().create_timer(SYNC_TIMEOUT, true).timeout.connect(_on_failed.bind([], _sync_id))


## Un file appena scritto in user://: si segna l'ora e si carica sull'account.
func push(file_name: String, text: String) -> void:
	if not Platform.is_web:
		return
	var time := int(Time.get_unix_time_from_system())
	_manifest[file_name] = time
	_save_manifest()
	if signed_in() and state != State.SYNCING:
		_api.saveFile(GAME_ID, file_name, text, time)


## Un file tolto da user:// (slot eliminato, comandi predefiniti): si toglie
## anche dall'account.
func remove(file_name: String) -> void:
	if not Platform.is_web:
		return
	var time := int(Time.get_unix_time_from_system())
	_manifest[file_name] = time
	_save_manifest()
	if signed_in() and state != State.SYNCING:
		_api.removeFile(GAME_ID, file_name, time)


## La Promise di loadFiles risponde con un testo JSON: nome del file ->
## {"text": contenuto, "updated_at": secondi Unix, "deleted": vero se
## cancellato}.
func _on_loaded(args: Array, sync_id: int) -> void:
	if sync_id != _sync_id or state != State.SYNCING:
		return
	var parsed: Variant = JSON.parse_string(str(args[0])) if not args.is_empty() else null
	var remote: Dictionary = parsed if parsed is Dictionary else {}
	var changed := false
	for file_name in files():
		var path := "user://" + file_name
		var entry: Variant = remote.get(file_name)
		var remote_time := int(entry.get("updated_at", 0)) if entry is Dictionary else 0
		var local_time := _local_time(file_name)
		if remote_time > local_time:
			if bool(entry.get("deleted", false)):
				if FileAccess.file_exists(path):
					DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
					changed = true
			else:
				var file := FileAccess.open(path, FileAccess.WRITE)
				if file == null:
					continue
				file.store_string(str(entry.get("text", "")))
				file.close()
				changed = true
			_manifest[file_name] = remote_time
		elif local_time > remote_time:
			if FileAccess.file_exists(path):
				_api.saveFile(GAME_ID, file_name, FileAccess.get_file_as_string(path), local_time)
			else:
				_api.removeFile(GAME_ID, file_name, local_time)
	_save_manifest()
	state = State.LINKED
	if changed:
		# I comandi arrivati dall'account valgono subito.
		Keybinds.load_saved()
	synced.emit(changed)


func _on_failed(_args: Array, sync_id: int) -> void:
	if sync_id != _sync_id or state != State.SYNCING:
		return
	state = State.FAILED
	synced.emit(false)


## Ora della versione nel browser (0 se non c'è mai stato il file; per un
## file cancellato, l'ora della cancellazione).
func _local_time(file_name: String) -> int:
	var path := "user://" + file_name
	if _manifest.has(file_name):
		return int(_manifest[file_name])
	if not FileAccess.file_exists(path):
		return 0
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and parsed.has("saved_at"):
		return int(parsed["saved_at"])
	return FileAccess.get_modified_time(path)


func _save_manifest() -> void:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_manifest))
