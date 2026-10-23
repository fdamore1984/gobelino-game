class_name SaveGame
## Salvataggio della partita in un file JSON in user:// (uno solo). Lo
## scrive e lo legge Game; il menù iniziale offre "Continue" se esiste.

const PATH := "user://savegame.json"


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func write(data: Dictionary) -> bool:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return false
	# Precisione piena: le posizioni servono identiche (casse aperte, totem).
	file.store_string(JSON.stringify(data, "", false, true))
	return true


static func read() -> Dictionary:
	if not exists():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if parsed is Dictionary else {}


static func vector(values: Array) -> Vector2:
	return Vector2(values[0], values[1])


static func array(point: Vector2) -> Array:
	return [point.x, point.y]
