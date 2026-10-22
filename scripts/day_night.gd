class_name DayNight
extends CanvasModulate
## Ciclo del giorno e della notte: scurisce il mondo (non l'interfaccia)
## seguendo i colori di data/world.json. Di notte serve la torcia.

const DATA := preload("res://data/world.json")

## Momento della giornata: 0 = alba, 0,5 = tramonto, poi la notte.
var time := 0.0

var _settings: Dictionary = DATA.data["day_night"]


func _ready() -> void:
	time = _settings["start"]
	_apply()


func _process(delta: float) -> void:
	time = fmod(time + delta / float(_settings["cycle"]), 1.0)
	_apply()


## Quanto è buio, da 0 (giorno) a 1 (notte piena).
func darkness() -> float:
	return 1.0 - color.v


func is_night() -> bool:
	return darkness() > float(_settings["night_threshold"])


func _apply() -> void:
	var keys: Array = _settings["colors"]
	for i in keys.size() - 1:
		var from: Array = keys[i]
		var to: Array = keys[i + 1]
		if time >= float(from[0]) and time <= float(to[0]):
			var t := inverse_lerp(float(from[0]), float(to[0]), time)
			color = _color(from[1]).lerp(_color(to[1]), t)
			return


static func _color(values: Array) -> Color:
	return Color(values[0], values[1], values[2])
