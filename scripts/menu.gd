extends Control
## Menù iniziale: avvia il livello di test o chiude il gioco.
## In basso a sinistra mostra versione e piattaforma, per riconoscere
## a colpo d'occhio le build scaricate da itch.io.

const GAME_SCENE := "res://scenes/game.tscn"

@onready var _start: Button = %Start
@onready var _quit: Button = %Quit
@onready var _info: Label = %Info


func _ready() -> void:
	_start.pressed.connect(_on_start_pressed)
	_quit.pressed.connect(_on_quit_pressed)
	# Il focus iniziale permette di usare il menù anche solo col controller.
	_start.grab_focus()

	var version: String = ProjectSettings.get_setting("application/config/version", "dev")
	var platform := OS.get_name()
	if Platform.is_steam_deck:
		platform += " (Steam Deck)"
	_info.text = "Versione %s\n%s" % [version, platform]


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
