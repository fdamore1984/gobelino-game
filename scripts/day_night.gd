class_name DayNight
extends CanvasModulate
## Ciclo del giorno e della notte: scurisce il mondo (non l'interfaccia)
## seguendo i colori di data/world.json. Di notte serve la torcia.

const DATA := preload("res://data/world.json")

## Momento della giornata, da 0 a 1: il sole sorge e tramonta agli
## istanti sunrise e sunset di data/world.json; il ciclo dura cycle secondi.
var time := 0.0

var _settings: Dictionary = DATA.data["day_night"]
## Colore fisso al posto del ciclo (nel sotterraneo è sempre buio); con
## alfa zero vale il ciclo del giorno.
var _override := Color(0, 0, 0, 0)


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


## Il sole è in cielo (altrimenti c'è la luna).
func is_day() -> bool:
	var day_length := fposmod(float(_settings["sunset"]) - float(_settings["sunrise"]), 1.0)
	return fposmod(time - float(_settings["sunrise"]), 1.0) < day_length


## Quanto il sole (o la luna) ha percorso del cielo: 0 sorge, 1 tramonta.
func sky_progress() -> float:
	var sunrise := float(_settings["sunrise"])
	var sunset := float(_settings["sunset"])
	if is_day():
		return fposmod(time - sunrise, 1.0) / fposmod(sunset - sunrise, 1.0)
	return fposmod(time - sunset, 1.0) / fposmod(sunrise - sunset, 1.0)


## Buio del ciclo del giorno, anche nel sotterraneo (dove il colore è fisso).
func sky_darkness() -> float:
	return 1.0 - _cycle_color().v


func is_overridden() -> bool:
	return _override.a > 0.0


func set_override(value: Color) -> void:
	_override = value
	_apply()


func clear_override() -> void:
	_override = Color(0, 0, 0, 0)
	_apply()


func _apply() -> void:
	color = Color(_override, 1.0) if _override.a > 0.0 else _cycle_color()


func _cycle_color() -> Color:
	var keys: Array = _settings["colors"]
	for i in keys.size() - 1:
		var from: Array = keys[i]
		var to: Array = keys[i + 1]
		if time >= float(from[0]) and time <= float(to[0]):
			var t := inverse_lerp(float(from[0]), float(to[0]), time)
			return _color(from[1]).lerp(_color(to[1]), t)
	return Color.WHITE


static func _color(values: Array) -> Color:
	return Color(values[0], values[1], values[2])
