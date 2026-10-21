extends Control
## Menù iniziale: avvia il livello di test o chiude il gioco, e permette
## di cambiare lingua. Si usa con mouse, touch, tastiera o controller.
## In basso a sinistra mostra versione e piattaforma, per riconoscere
## a colpo d'occhio le build scaricate da itch.io.

const GAME_SCENE := "res://scenes/game.tscn"

@onready var _start: Button = %Start
@onready var _quit: Button = %Quit
@onready var _language: Button = %Language
@onready var _info: Label = %Info


func _ready() -> void:
	_start.pressed.connect(_on_start_pressed)
	_quit.pressed.connect(_on_quit_pressed)
	_language.pressed.connect(_on_language_pressed)

	# Navigazione col controller: dai pulsanti centrali si scende alla lingua e viceversa.
	_quit.focus_neighbor_bottom = _language.get_path()
	_language.focus_neighbor_top = _quit.get_path()
	_language.focus_neighbor_bottom = _start.get_path()
	_start.focus_neighbor_top = _language.get_path()

	for button: Button in [_start, _quit, _language]:
		button.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
	_start.grab_focus()
	_update_info()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_info()


func _unhandled_input(event: InputEvent) -> void:
	# Se nessun pulsante ha il focus (per esempio dopo un tocco sullo
	# schermo), il primo comando del controller lo riporta su "Inizia".
	if get_viewport().gui_get_focus_owner() != null:
		return
	for action in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept"]:
		if event.is_action_pressed(action):
			_start.grab_focus()
			get_viewport().set_input_as_handled()
			return


func _update_info() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "dev")
	var platform := OS.get_name()
	if Platform.is_steam_deck:
		platform += " (Steam Deck)"
	_info.text = (tr("MENU_VERSION") % version) + "\n" + platform


func _on_start_pressed() -> void:
	Sfx.play_ui("ui_confirm")
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_language_pressed() -> void:
	Sfx.play_ui("ui_confirm")
	Settings.toggle_language()
