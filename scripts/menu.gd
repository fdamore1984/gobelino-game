extends Control
## Menù iniziale: riprende una partita salvata (se ce n'è), ne avvia una
## nuova (in entrambi i casi si sceglie uno dei tre slot, SlotPanel), mostra
## i comandi (ControlsPanel) o chiude il gioco. Si usa con mouse, touch, tastiera o controller.
## In basso a sinistra mostra la versione (per riconoscere a colpo
## d'occhio le build scaricate da itch.io) e chi ha fatto il gioco.

const GAME_SCENE := "res://scenes/game.tscn"

@onready var _continue: Button = %Continue
@onready var _start: Button = %Start
@onready var _quit: Button = %Quit
@onready var _controls: Button = %Controls
@onready var _info: Label = %Info

var _controls_panel := ControlsPanel.new()
var _slot_panel := SlotPanel.new()


func _ready() -> void:
	_start.pressed.connect(_on_start_pressed)
	_continue.pressed.connect(_on_continue_pressed)
	_continue.visible = SaveGame.any_exists()
	_quit.pressed.connect(_on_quit_pressed)
	_controls.pressed.connect(_on_controls_pressed)
	add_child(_controls_panel)
	_controls_panel.closed.connect(_on_controls_closed)
	add_child(_slot_panel)
	_slot_panel.chosen.connect(_on_slot_chosen)
	_slot_panel.closed.connect(_on_slot_panel_closed)

	# Navigazione col controller: dall'ultimo pulsante si torna al primo e viceversa.
	var first := _continue if _continue.visible else _start
	_quit.focus_neighbor_bottom = first.get_path()
	first.focus_neighbor_top = _quit.get_path()

	for button: Button in [_continue, _start, _controls, _quit]:
		button.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
	first.grab_focus()
	_update_info()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_info()


func _unhandled_input(event: InputEvent) -> void:
	# Il pulsante premuto può aver già cambiato scena: in quel caso questo
	# nodo non è più nell'albero e non c'è niente da segnare.
	if _controls_panel.visible or _slot_panel.visible:
		return
	if UiNav.handle(event, get_viewport(), _continue if _continue.visible else _start) and is_inside_tree():
		get_viewport().set_input_as_handled()


## In basso a sinistra solo la versione e chi ha fatto il gioco.
func _update_info() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "dev")
	_info.text = "\n".join([tr("MENU_VERSION") % version, tr("MENU_CREDITS")])


func _on_start_pressed() -> void:
	Sfx.play_ui("ui_confirm")
	_set_buttons_active(false)
	_slot_panel.open(true)


func _on_continue_pressed() -> void:
	Sfx.play_ui("ui_confirm")
	_set_buttons_active(false)
	_slot_panel.open(false)


## Con un pannello aperto i pulsanti del menù sotto non si possono
## selezionare né premere: la navigazione resta dentro il pannello.
func _set_buttons_active(active: bool) -> void:
	for button: Button in [_continue, _start, _controls, _quit]:
		button.focus_mode = Control.FOCUS_ALL if active else Control.FOCUS_NONE
		button.disabled = not active


## Nuova partita: lo slot scelto si svuota e la partita si salverà lì.
## Continua: si carica la partita dello slot.
func _on_slot_chosen(slot: int) -> void:
	var new_game := _slot_panel.new_game
	SaveGame.slot = slot
	if new_game:
		SaveGame.delete(slot)
	else:
		var save := SaveGame.read(slot)
		if save.is_empty():
			return
		Game.pending_save = save
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_slot_panel_closed() -> void:
	_set_buttons_active(true)
	(_start if _slot_panel.new_game or not _continue.visible else _continue).grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_controls_pressed() -> void:
	Sfx.play_ui("ui_confirm")
	_set_buttons_active(false)
	_controls_panel.open()


func _on_controls_closed() -> void:
	_set_buttons_active(true)
	_controls.grab_focus()
