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
@onready var _deck_hint: Label = %DeckHint

## Ultimo comando ricevuto, mostrato per capire cosa arriva dal controller.
var _last_input := ""


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
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_start.grab_focus()
	_update_info()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_info()


func _input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and not event is InputEventMouseMotion:
		_last_input = event.as_text()
		_update_info()


func _unhandled_input(event: InputEvent) -> void:
	# Il pulsante premuto può aver già cambiato scena: in quel caso questo
	# nodo non è più nell'albero e non c'è niente da segnare.
	if UiNav.handle(event, get_viewport(), _start) and is_inside_tree():
		get_viewport().set_input_as_handled()


func _update_info() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "dev")
	var platform := OS.get_name()
	if Platform.is_steam_deck:
		platform += " (Steam Deck)"
	# Controller rilevato: aiuta a capire i problemi di input (per esempio
	# sullo Steam Deck in modalità desktop).
	var joypads := Input.get_connected_joypads()
	var controller := tr("MENU_CONTROLLER") % Input.get_joy_name(joypads[0]) if not joypads.is_empty() else tr("MENU_NO_CONTROLLER")
	_info.text = (tr("MENU_VERSION") % version) + "\n" + platform + "\n" + controller
	_deck_hint.text = tr("DECK_HINT")
	_deck_hint.visible = Platform.needs_deck_controller_hint()
	if _last_input != "":
		_info.text += "\n" + tr("MENU_LAST_INPUT") % _last_input


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_update_info()


func _on_start_pressed() -> void:
	Sfx.play_ui("ui_confirm")
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_language_pressed() -> void:
	Sfx.play_ui("ui_confirm")
	Settings.toggle_language()
