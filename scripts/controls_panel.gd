class_name ControlsPanel
extends Control
## Elenco dei comandi, aperto dal menù iniziale: azioni con i tasti di
## tastiera, mouse e controller (quelli scelti dal giocatore, letti
## dall'Input Map con Keybinds: si aggiornano a ogni apertura) e gli
## attacchi speciali. Si chiude con B, Esc o il pulsante Indietro.

signal closed

## Righe: testo e gruppi di azioni; i tasti dei gruppi sono separati da
## un punto ("I / Tab · C"). Il movimento ha una riga a parte (vedi _move_keys).
const ROWS := [
	["CONTROLS_ATTACK", [["attack"]]], ["CONTROLS_HEAVY", [["heavy_attack"]]],
	["CONTROLS_PARRY", [["parry"]]], ["CONTROLS_DODGE", [["dodge"]]], ["CONTROLS_JUMP", [["jump"], ["interact"]]],
	["CONTROLS_RUN", [["run"]]], ["CONTROLS_FOCUS", [["focus"]]], ["CONTROLS_SPELL", [["spell"]]],
	["CONTROLS_SHIELD", [["shield"]]], ["CONTROLS_POTION", [["potion"]]], ["CONTROLS_MANA", [["mana_potion"]]],
	["CONTROLS_STAMINA_POTION", [["stamina_potion"]]], ["CONTROLS_INVENTORY", [["inventory"], ["inventory_sort"]]],
	["CONTROLS_MAP", [["map"]]], ["CONTROLS_LOCK", [["lock_on"]]], ["CONTROLS_MENU", [["menu"]]],
]
const MOVE_ACTIONS := ["move_up", "move_left", "move_down", "move_right"]
const SPECIALS := ["CONTROLS_SPECIAL_MIXED", "CONTROLS_SPECIAL_CHARGED", "CONTROLS_SPECIAL_AIR", "CONTROLS_SPECIAL_PLUNGE", "CONTROLS_SPECIAL_DASH"]
const COLOR_TITLE := Color(0.85, 0.75, 0.4)
const COLOR_HEADER := Color(1.0, 0.85, 0.4)
const COLOR_TEXT := Color(1, 1, 1, 0.85)
const COLOR_KEY := Color(0.75, 0.9, 1.0)

var _back := Button.new()
var _grid := GridContainer.new()


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
	box.add_theme_constant_override("separation", 6)
	center.add_child(box)
	box.add_child(_label("CONTROLS_TITLE", 34, COLOR_TITLE, true))
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 30)
	_grid.add_theme_constant_override("v_separation", 0)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_grid)
	box.add_child(_label("CONTROLS_SPECIAL_TITLE", 22, COLOR_HEADER, true))
	# Righe fitte, perché tutto stia anche a 720 pixel di altezza.
	var specials := VBoxContainer.new()
	specials.add_theme_constant_override("separation", 0)
	box.add_child(specials)
	for key: String in SPECIALS:
		specials.add_child(_label(key, 17, COLOR_TEXT, true))
	if Platform.use_touch_controls():
		specials.add_child(_label("CONTROLS_TOUCH", 17, COLOR_KEY, true))
	_back.text = "CONTROLS_BACK"
	_back.custom_minimum_size = Vector2(220, 44)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.add_theme_font_size_override("font_size", 24)
	_back.pressed.connect(close)
	box.add_child(_back)


## Riempie la tabella con i tasti attuali.
func _fill() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_add_row([tr("CONTROLS_HEADER_ACTION"), tr("OPTIONS_HEADER_KEYBOARD"), tr("OPTIONS_HEADER_MOUSE"), tr("OPTIONS_HEADER_CONTROLLER")], true)
	_add_row([tr("CONTROLS_MOVE"), _move_keys("keyboard"), Keybinds.describe(["move_click"], "mouse"), _move_keys("controller")], false)
	for row: Array in ROWS:
		var cells := [tr(row[0])]
		for device: String in Keybinds.DEVICES:
			cells.append(_keys(row[1], device))
		_add_row(cells, false)


## Tasti dei gruppi di azioni di una riga per un dispositivo.
func _keys(groups: Array, device: String) -> String:
	var parts: Array[String] = []
	for group: Array in groups:
		if Keybinds.events(group[0], device).is_empty():
			continue
		var text := Keybinds.describe(group, device)
		if text not in parts:
			parts.append(text)
	return " · ".join(parts) if not parts.is_empty() else tr("BIND_NONE")


## Movimento: i primi tasti delle quattro direzioni ("W A S D"), o la
## levetta se le direzioni sono i suoi due assi.
func _move_keys(device: String) -> String:
	var labels: Array[String] = []
	var axes := {}
	for action: String in MOVE_ACTIONS:
		var found := Keybinds.events(action, device)
		if found.is_empty():
			continue
		labels.append(Keybinds.label(found[0]))
		if found[0] is InputEventJoypadMotion:
			axes[(found[0] as InputEventJoypadMotion).axis] = true
	if axes.size() == 2 and axes.has(JOY_AXIS_LEFT_X) and axes.has(JOY_AXIS_LEFT_Y) and labels.size() == 4:
		return tr("BIND_LEFT_STICK")
	if axes.size() == 2 and axes.has(JOY_AXIS_RIGHT_X) and axes.has(JOY_AXIS_RIGHT_Y) and labels.size() == 4:
		return tr("BIND_RIGHT_STICK")
	return " ".join(labels) if not labels.is_empty() else tr("BIND_NONE")


## Una riga della tabella: descrizione e tasti di tastiera, mouse, controller.
func _add_row(cells: Array, header: bool) -> void:
	for i in cells.size():
		var color := COLOR_HEADER if header else (COLOR_TEXT if i == 0 else COLOR_KEY)
		var label := _label(cells[i], 18 if header else 16, color, false)
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_grid.add_child(label)


func _label(text: String, font_size: int, color: Color, centered: bool) -> Label:
	var label := Label.new()
	label.text = text
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func open() -> void:
	_fill()
	visible = true
	_back.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	Sfx.play_ui("ui_move")
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu") or event.is_action_pressed("dodge"):
		close()
	elif not UiNav.handle(event, get_viewport(), _back):
		return
	get_viewport().set_input_as_handled()
