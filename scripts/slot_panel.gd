class_name SlotPanel
extends Control
## Scelta dello slot di salvataggio dal menù iniziale. Per una nuova partita
## si può scegliere qualsiasi slot (uno già usato va confermato premendolo
## una seconda volta: la partita vecchia viene sostituita); per continuare
## solo quelli salvati. Si chiude con B, Esc o il pulsante Indietro.

signal chosen(slot: int)
signal closed

const COLOR_TITLE := Color(0.85, 0.75, 0.4)
const COLOR_EMPTY := Color(1, 1, 1, 0.6)
const COLOR_CONFIRM := Color(1.0, 0.6, 0.35)

var _title := Label.new()
var _buttons: Array[Button] = []
var _back := Button.new()
## true: nuova partita; false: continua.
var new_game := true
## Slot già usato in attesa della seconda pressione (0: nessuno).
var _confirming := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.04, 0.96)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", COLOR_TITLE)
	box.add_child(_title)
	for index in range(1, SaveGame.SLOTS + 1):
		var button := Button.new()
		button.custom_minimum_size = Vector2(560, 72)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", 26)
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.pressed.connect(_on_slot_pressed.bind(index))
		button.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
		button.focus_entered.connect(_on_slot_focused.bind(index))
		box.add_child(button)
		_buttons.append(button)
	_back.text = "CONTROLS_BACK"
	_back.custom_minimum_size = Vector2(220, 52)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.add_theme_font_size_override("font_size", 24)
	_back.pressed.connect(close)
	_back.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
	box.add_child(_back)


func open(for_new_game: bool) -> void:
	new_game = for_new_game
	_confirming = 0
	_title.text = tr("SLOTS_NEW_TITLE") if for_new_game else tr("SLOTS_LOAD_TITLE")
	_refresh()
	visible = true
	_first().grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	Sfx.play_ui("ui_move")
	closed.emit()


## Testo di ogni slot: libero, o livello e ora del salvataggio.
func _refresh() -> void:
	for k in _buttons.size():
		var index := k + 1
		var button := _buttons[k]
		var info := SaveGame.summary(index)
		if info.is_empty():
			button.text = tr("SLOT_EMPTY") % index
		elif _confirming == index:
			button.text = tr("SLOT_OVERWRITE") % index
		else:
			button.text = tr("SLOT_SAVED") % [index, info["level"], info["time"]]
		button.disabled = not new_game and info.is_empty()
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		var color := COLOR_CONFIRM if _confirming == index else (COLOR_EMPTY if info.is_empty() else Color.WHITE)
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_focus_color", color)


func _first() -> Control:
	for button in _buttons:
		if not button.disabled:
			return button
	return _back


func _on_slot_pressed(index: int) -> void:
	if new_game and SaveGame.exists(index) and _confirming != index:
		# Slot già usato: la seconda pressione conferma che va sostituito.
		_confirming = index
		Sfx.play_ui("ui_move")
		_refresh()
		return
	Sfx.play_ui("ui_confirm")
	chosen.emit(index)


## Spostandosi su un altro slot la richiesta di conferma si annulla.
func _on_slot_focused(index: int) -> void:
	if _confirming != 0 and _confirming != index:
		_confirming = 0
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu") or event.is_action_pressed("dodge"):
		close()
	elif not UiNav.handle(event, get_viewport(), _first()):
		return
	get_viewport().set_input_as_handled()
