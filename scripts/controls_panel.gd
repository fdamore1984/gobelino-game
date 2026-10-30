class_name ControlsPanel
extends Control
## Elenco dei comandi, aperto dal menù iniziale e da quello di pausa: azioni
## con i tasti di tastiera, mouse e controller (quelli scelti dal giocatore,
## letti dall'Input Map con Keybinds: si aggiornano a ogni apertura) e gli
## attacchi speciali. Le descrizioni vanno a capo entro WIDTH, così la
## tabella sta tutta nello schermo (anche nel browser, a 1280×720); se non
## sta in altezza scorre (rotellina, trascinando col dito, su e giù di
## croce, levetta o frecce). Modifica apre la rimappatura dei tasti
## (KeybindsPanel); si chiude con B, Esc o il pulsante Indietro.

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
const SPECIALS := ["CONTROLS_SPECIAL_FRENZY", "CONTROLS_SPECIAL_MIXED", "CONTROLS_SPECIAL_CHARGED", "CONTROLS_SPECIAL_AIR", "CONTROLS_SPECIAL_PLUNGE", "CONTROLS_SPECIAL_DASH"]
const COLOR_TITLE := Color(0.85, 0.75, 0.4)
const COLOR_HEADER := Color(1.0, 0.85, 0.4)
const COLOR_TEXT := Color(1, 1, 1, 0.85)
const COLOR_KEY := Color(0.75, 0.9, 1.0)
## Larghezza della tabella e delle sue colonne (descrizione e tasti di un
## dispositivo); le colonne sono separate da COLUMN_GAP.
const WIDTH := 1180.0
const ACTION_WIDTH := 520.0
const KEY_WIDTH := 200.0
const COLUMN_GAP := 20
## Spazio verticale per titolo e pulsanti: il resto è della parte che scorre.
const RESERVED_HEIGHT := 150.0
## Velocità di scorrimento con croce, levetta e frecce (pixel al secondo).
const SCROLL_SPEED := 700.0

var _back := Button.new()
var _edit := Button.new()
var _grid := GridContainer.new()
var _scroll := ScrollContainer.new()
var _keybinds := KeybindsPanel.new()
## Riga dell'attacco speciale della Frenesia, coi tasti scelti dal giocatore.
var _frenzy: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	# Opaco: sotto non si deve leggere il menù.
	dim.color = Color(0.04, 0.05, 0.04)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	center.add_child(box)
	box.add_child(_label("CONTROLS_TITLE", 34, COLOR_TITLE, true))
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.custom_minimum_size = Vector2(WIDTH, 0)
	_scroll.add_child(content)
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", COLUMN_GAP)
	_grid.add_theme_constant_override("v_separation", 2)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(_grid)
	content.add_child(_label("CONTROLS_SPECIAL_TITLE", 22, COLOR_HEADER, true))
	var specials := VBoxContainer.new()
	specials.add_theme_constant_override("separation", 2)
	content.add_child(specials)
	for key: String in SPECIALS:
		var label := _wrapped(_label(key, 17, COLOR_TEXT, true), WIDTH)
		if key == "CONTROLS_SPECIAL_FRENZY":
			# L'attacco speciale è parata + attacco insieme: tasti dall'Input
			# Map, scritti a ogni apertura (vedi _fill).
			_frenzy = label
			label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		specials.add_child(label)
	if Platform.use_touch_controls():
		specials.add_child(_wrapped(_label("CONTROLS_TOUCH", 17, COLOR_KEY, true), WIDTH))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	for pair: Array in [[_edit, "CONTROLS_EDIT"], [_back, "CONTROLS_BACK"]]:
		var button: Button = pair[0]
		button.text = pair[1]
		button.custom_minimum_size = Vector2(220, 44)
		button.add_theme_font_size_override("font_size", 24)
		button.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
		row.add_child(button)
	_edit.pressed.connect(_open_keybinds)
	_back.pressed.connect(close)
	add_child(_keybinds)
	_keybinds.closed.connect(_on_keybinds_closed)
	get_viewport().size_changed.connect(_fit)


## La parte che scorre prende tutta l'altezza libera dello schermo.
func _fit() -> void:
	var height := get_viewport_rect().size.y - RESERVED_HEIGHT
	_scroll.custom_minimum_size = Vector2(WIDTH + 16, maxf(height, 200.0))


## Riempie la tabella con i tasti attuali, nella lingua attuale.
func _fill() -> void:
	_frenzy.text = tr("CONTROLS_SPECIAL_FRENZY") % [Keybinds.hint("parry"), Keybinds.hint("attack")]
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
		var label := _wrapped(_label(cells[i], 18 if header else 16, color, false), ACTION_WIDTH if i == 0 else KEY_WIDTH)
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


## Il testo va a capo entro la larghezza data.
func _wrapped(label: Label, width: float) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	return label


func open() -> void:
	_fill()
	_fit()
	_scroll.scroll_vertical = 0
	visible = true
	_back.grab_focus.call_deferred()


func _open_keybinds() -> void:
	Sfx.play_ui("ui_confirm")
	_keybinds.open()


## Tornando dalla rimappatura la tabella mostra i tasti nuovi.
func _on_keybinds_closed() -> void:
	_fill()
	_edit.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	Sfx.play_ui("ui_move")
	closed.emit()


## Su e giù (croce, levetta, frecce, W e S) fanno scorrere la tabella;
## destra e sinistra passano da Modifica a Indietro.
func _process(delta: float) -> void:
	if not visible or _keybinds.visible:
		return
	var direction := clampf(Input.get_axis("ui_up", "ui_down") + Input.get_axis("move_up", "move_down"), -1.0, 1.0)
	if direction != 0.0:
		_scroll.scroll_vertical += int(direction * SCROLL_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _keybinds.visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu") or event.is_action_pressed("dodge"):
		close()
	elif event.is_action("ui_up") or event.is_action("ui_down") or event.is_action("move_up") or event.is_action("move_down"):
		pass
	elif not UiNav.handle(event, get_viewport(), _back):
		return
	get_viewport().set_input_as_handled()
