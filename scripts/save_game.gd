class_name SaveGame
## Salvataggi della partita: tre slot, ognuno un file JSON in user://. Il
## menù iniziale fa scegliere lo slot (nuova partita o continua) e lo
## imposta in slot; Game scrive e legge sempre quello. Il vecchio file unico
## (versioni precedenti) diventa lo slot 1 la prima volta che serve.

const SLOTS := 3
const PATH := "user://savegame_%d.json"
## File unico delle versioni precedenti.
const OLD_PATH := "user://savegame.json"

## Slot della partita in corso (da 1 a SLOTS).
static var slot := 1


static func path(index: int) -> String:
	_migrate()
	return PATH % index


static func exists(index := slot) -> bool:
	return FileAccess.file_exists(path(index))


## C'è almeno uno slot salvato.
static func any_exists() -> bool:
	for index in range(1, SLOTS + 1):
		if exists(index):
			return true
	return false


static func write(data: Dictionary) -> bool:
	var file := FileAccess.open(path(slot), FileAccess.WRITE)
	if file == null:
		return false
	data["saved_at"] = int(Time.get_unix_time_from_system())
	# Precisione piena: le posizioni servono identiche (casse aperte, totem).
	file.store_string(JSON.stringify(data, "", false, true))
	return true


static func read(index := slot) -> Dictionary:
	if not exists(index):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path(index)))
	return parsed if parsed is Dictionary else {}


static func delete(index: int) -> void:
	if exists(index):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path(index)))


## Livello del giocatore e momento del salvataggio (ora locale, "AAAA-MM-GG
## HH:MM"), per descrivere lo slot nel menù; vuoto se lo slot è libero.
static func summary(index: int) -> Dictionary:
	var data := read(index)
	if data.is_empty():
		return {}
	var player: Dictionary = data.get("player", {})
	# I salvataggi vecchi non hanno l'ora: si usa quella del file.
	var saved_at := int(data.get("saved_at", FileAccess.get_modified_time(path(index))))
	var local := saved_at + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return {"level": int(player.get("level", 1)), "time": Time.get_datetime_string_from_unix_time(local, true).left(16)}


static func _migrate() -> void:
	if FileAccess.file_exists(OLD_PATH) and not FileAccess.file_exists(PATH % 1):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(OLD_PATH), ProjectSettings.globalize_path(PATH % 1))


static func vector(values: Array) -> Vector2:
	return Vector2(values[0], values[1])


static func array(point: Vector2) -> Array:
	return [point.x, point.y]
