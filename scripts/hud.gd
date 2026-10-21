class_name Hud
extends CanvasLayer
## Interfaccia del livello di test: vita, nemici sconfitti, comandi e
## messaggio di fine partita.

@onready var _health: Label = %Health
@onready var _kills: Label = %Kills
@onready var _hint: Label = %Hint
@onready var _message: Label = %Message


func _ready() -> void:
	_hint.text = tr("HUD_HINT")
	# Sui dispositivi touch i comandi sono già scritti sui pulsanti a schermo.
	_hint.visible = not Platform.use_touch_controls()
	_message.visible = false


func set_health(current: int, maximum: int) -> void:
	_health.text = tr("HUD_HEALTH") % [current, maximum]


func set_kills(count: int) -> void:
	_kills.text = tr("HUD_KILLS") % count


func show_message(text: String) -> void:
	_message.text = text
	_message.visible = true
