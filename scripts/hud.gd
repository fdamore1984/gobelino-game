class_name Hud
extends CanvasLayer
## Interfaccia del livello di test: vita, nemici sconfitti, comandi e
## messaggio di fine partita.

const HINT := "Muovi: WASD / frecce / levetta    Attacco: J / R1    Parata: K / L1 (tieni premuto)    Schivata: Spazio / B    Menu: Esc / Start"

@onready var _health: Label = %Health
@onready var _kills: Label = %Kills
@onready var _hint: Label = %Hint
@onready var _message: Label = %Message


func _ready() -> void:
	_hint.text = HINT
	# Sui dispositivi touch i comandi sono già scritti sui pulsanti a schermo.
	_hint.visible = not Platform.use_touch_controls()
	_message.visible = false


func set_health(current: int, maximum: int) -> void:
	_health.text = "Vita  %d / %d" % [current, maximum]


func set_kills(count: int) -> void:
	_kills.text = "Nemici sconfitti  %d" % count


func show_message(text: String) -> void:
	_message.text = text
	_message.visible = true
