extends Control
## Menù iniziale: riprende la partita salvata (se c'è), ne avvia una
## nuova, mostra i comandi (ControlsPanel) o chiude il gioco. Si usa con mouse, touch, tastiera o controller.
## In basso a sinistra mostra versione e piattaforma, per riconoscere
## a colpo d'occhio le build scaricate da itch.io.

const GAME_SCENE := "res://scenes/game.tscn"

@onready var _continue: Button = %Continue
@onready var _start: Button = %Start
@onready var _quit: Button = %Quit
@onready var _controls: Button = %Controls
@onready var _info: Label = %Info
@onready var _deck_hint: Label = %DeckHint

## Ultimo comando ricevuto, mostrato per capire cosa arriva dal controller.
var _last_input := ""
var _controls_panel := ControlsPanel.new()


func _ready() -> void:
	_start.pressed.connect(_on_start_pressed)
	_continue.pressed.connect(_on_continue_pressed)
	_continue.visible = SaveGame.exists()
	_quit.pressed.connect(_on_quit_pressed)
	_controls.pressed.connect(_on_controls_pressed)
	add_child(_controls_panel)
	_controls_panel.closed.connect(_controls.grab_focus)

	# Navigazione col controller: dall'ultimo pulsante si torna al primo e viceversa.
	var first := _continue if _continue.visible else _start
	_quit.focus_neighbor_bottom = first.get_path()
	first.focus_neighbor_top = _quit.get_path()

	for button: Button in [_continue, _start, _controls, _quit]:
		button.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	first.grab_focus()
	_update_info()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_info()


func _input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and not event is InputEventMouseMotion:
		_last_input = event.as_text()
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			_last_input += " · " + tr("MENU_DEVICE") % event.device
		_update_info()


func _unhandled_input(event: InputEvent) -> void:
	# Il pulsante premuto può aver già cambiato scena: in quel caso questo
	# nodo non è più nell'albero e non c'è niente da segnare.
	if _controls_panel.visible:
		return
	if UiNav.handle(event, get_viewport(), _continue if _continue.visible else _start) and is_inside_tree():
		get_viewport().set_input_as_handled()


func _update_info() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "dev")
	var platform := OS.get_name()
	if Platform.is_steam_deck:
		platform += " (Steam Deck)"
	# Controller rilevato: aiuta a capire i problemi di input (per esempio
	# sullo Steam Deck in modalità desktop).
	var lines: Array[String] = [tr("MENU_VERSION") % version, platform]
	var joypads := Input.get_connected_joypads()
	if joypads.is_empty():
		lines.append(tr("MENU_NO_CONTROLLER"))
	for device in joypads:
		# Il GUID e se Godot conosce la disposizione dei pulsanti servono a
		# capire perché un controller ha i comandi scambiati.
		var mapping := tr("MENU_JOY_MAPPED") if Input.is_joy_known(device) else tr("MENU_JOY_UNMAPPED")
		lines.append(tr("MENU_CONTROLLER") % [device, Input.get_joy_name(device), Input.get_joy_guid(device), mapping])
	if Platform.ignores_desktop_input():
		lines.append(tr("MENU_DESKTOP_INPUT_OFF"))
	_info.text = "\n".join(lines)
	_deck_hint.text = tr("DECK_HINT")
	_deck_hint.visible = Platform.needs_deck_controller_hint()
	if _last_input != "":
		_info.text += "\n" + tr("MENU_LAST_INPUT") % _last_input


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_update_info()


func _on_start_pressed() -> void:
	Sfx.play_ui("ui_confirm")
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_continue_pressed() -> void:
	var save := SaveGame.read()
	if save.is_empty():
		_continue.visible = false
		_start.grab_focus()
		return
	Sfx.play_ui("ui_confirm")
	Game.pending_save = save
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_controls_pressed() -> void:
	Sfx.play_ui("ui_confirm")
	_controls_panel.open()
