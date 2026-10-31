class_name KeybindsPanel
extends Control
## Rimappatura dei comandi, aperta dal pulsante Modifica della pagina dei
## comandi (ControlsPanel). Per ogni azione (Keybinds.ACTIONS) c'è un pulsante per la
## tastiera, uno per il mouse e uno per il controller con i tasti attuali:
## premendolo si aspetta il nuovo tasto di quel dispositivo (per
## LISTEN_TIME secondi), che prende il posto dei precedenti e si salva
## subito. Un tasto di un altro dispositivo, o il tempo che scade, annulla.
## Se il nuovo tasto è già usato da altre azioni lo si dice (alcune lo
## condividono apposta, come salto e interazione). Con ui_clear (X, Canc,
## Backspace), il clic destro o un tocco lungo (LONG_TOUCH_TIME) sul
## pulsante l'azione resta senza tasti per quel dispositivo (non il menù di
## pausa su tutti: vedi
## Keybinds.can_clear). In fondo si torna ai
## comandi predefiniti. Funziona con mouse, touch, tastiera e controller;
## si chiude con B, Esc o il pulsante Indietro (non mentre si aspetta un
## tasto: lì ogni tasto va assegnato).

signal closed

const LISTEN_TIME := 5.0
## Subito dopo aver premuto il pulsante si ignorano i tasti: quello che lo
## ha premuto non deve diventare il nuovo comando.
const LISTEN_GUARD := 0.15
## Un tocco sullo schermo tenuto così a lungo su un pulsante lascia l'azione
## senza tasti per quel dispositivo (come il clic destro).
const LONG_TOUCH_TIME := 0.6
const COLOR_TITLE := Color(0.85, 0.75, 0.4)
const COLOR_HEADER := Color(1.0, 0.85, 0.4)
const COLOR_TEXT := Color(1, 1, 1, 0.85)
const COLOR_STATUS := Color(0.75, 0.9, 1.0)
const COLOR_WAITING := Color(1.0, 0.85, 0.4)

var _grid := GridContainer.new()
var _scroll := ScrollContainer.new()
var _intro := Label.new()
var _status := Label.new()
var _reset := Button.new()
var _back := Button.new()
## Pulsante di ogni azione e dispositivo: "azione:dispositivo" -> Button.
var _cells := {}
## Tasto atteso: azione e dispositivo ("" se non si aspetta niente) e
## tempo da quando si aspetta.
var _listen_action := ""
var _listen_device := ""
var _listen_time := 0.0
## Pulsante toccato sullo schermo ("azione:dispositivo", "" se nessuno) e da
## quanto; long_touched: il tocco lungo è già scattato.
var _touch_cell := ""
var _touch_time := 0.0
var _long_touched := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	# Opaco: sotto non si deve leggere la pagina dei comandi.
	dim.color = UiStyle.OVERLAY
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	box.add_child(_label("KEYBINDS_TITLE", 34, COLOR_TITLE))
	_intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro.custom_minimum_size = Vector2(1180, 0)
	_intro.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_intro.add_theme_font_size_override("font_size", 18)
	_intro.add_theme_color_override("font_color", COLOR_TEXT)
	box.add_child(_intro)
	var header := GridContainer.new()
	header.columns = 4
	header.add_theme_constant_override("h_separation", 12)
	header.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for key: String in ["OPTIONS_HEADER_ACTION", "OPTIONS_HEADER_KEYBOARD", "OPTIONS_HEADER_MOUSE", "OPTIONS_HEADER_CONTROLLER"]:
		var label := _label(key, 18, COLOR_HEADER)
		label.custom_minimum_size = Vector2(_column_width(key == "OPTIONS_HEADER_ACTION"), 0)
		if key == "OPTIONS_HEADER_ACTION":
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.add_child(label)
	box.add_child(header)
	# La tabella scorre e segue il pulsante selezionato (controller e tastiera).
	_scroll.custom_minimum_size = Vector2(1000, 400)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_scroll)
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 6)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	_scroll.add_child(_grid)
	for action: String in Keybinds.ACTIONS:
		var name_label := _label("BIND_ACTION_" + action.to_upper(), 18, COLOR_TEXT)
		name_label.custom_minimum_size = Vector2(_column_width(true), 0)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_grid.add_child(name_label)
		for device: String in Keybinds.DEVICES:
			var button := Button.new()
			button.custom_minimum_size = Vector2(_column_width(false), 38)
			button.add_theme_font_size_override("font_size", 17)
			button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			button.clip_text = true
			button.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
			button.pressed.connect(_listen.bind(action, device))
			button.gui_input.connect(_on_cell_input.bind(action, device))
			_grid.add_child(button)
			_cells[action + ":" + device] = button
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size = Vector2(1000, 26)
	_status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", COLOR_STATUS)
	box.add_child(_status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	for pair: Array in [[_reset, "OPTIONS_RESET"], [_back, "OPTIONS_BACK"]]:
		var button: Button = pair[0]
		button.text = pair[1]
		button.custom_minimum_size = Vector2(260, 44)
		button.add_theme_font_size_override("font_size", 22)
		button.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
		row.add_child(button)
	_reset.pressed.connect(_on_reset_pressed)
	_back.pressed.connect(close)


func _column_width(action: bool) -> float:
	return 330.0 if action else 200.0


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func open() -> void:
	_stop_listening()
	_touch_cell = ""
	_long_touched = false
	_refresh()
	_status.text = ""
	visible = true
	_scroll.scroll_vertical = 0
	var first: Button = _cells[Keybinds.ACTIONS[0] + ":keyboard"]
	first.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	_stop_listening()
	visible = false
	Sfx.play_ui("ui_move")
	closed.emit()


## Testi dei pulsanti con i tasti attuali.
func _refresh() -> void:
	_intro.text = tr("OPTIONS_CONTROLS") % Keybinds.hint("ui_clear")
	for action: String in Keybinds.ACTIONS:
		for device: String in Keybinds.DEVICES:
			var button: Button = _cells[action + ":" + device]
			button.text = Keybinds.describe([action], device)
			button.tooltip_text = button.text


## Si aspetta il nuovo tasto per l'azione e il dispositivo del pulsante premuto.
func _listen(action: String, device: String) -> void:
	_stop_listening()
	_listen_action = action
	_listen_device = device
	_listen_time = 0.0
	var button: Button = _cells[action + ":" + device]
	button.text = "…"
	Sfx.play_ui("ui_confirm")
	_update_status()


func _stop_listening() -> void:
	if _listen_action != "":
		var button: Button = _cells[_listen_action + ":" + _listen_device]
		button.text = Keybinds.describe([_listen_action], _listen_device)
	_listen_action = ""
	_listen_device = ""
	_status.remove_theme_color_override("font_color")
	_status.add_theme_color_override("font_color", COLOR_STATUS)


func _update_status() -> void:
	var seconds := ceili(LISTEN_TIME - _listen_time)
	_status.text = tr("OPTIONS_LISTEN") % [tr("OPTIONS_DEVICE_" + _listen_device.to_upper()), tr("BIND_ACTION_" + _listen_action.to_upper()), seconds]
	_status.add_theme_color_override("font_color", COLOR_WAITING)


func _process(delta: float) -> void:
	if _touch_cell != "" and not _long_touched:
		_touch_time += delta
		if _touch_time >= LONG_TOUCH_TIME:
			_long_touched = true
			var cell := _touch_cell.split(":")
			_clear(cell[0], cell[1])
	if _listen_action == "":
		return
	_listen_time += delta
	if _listen_time >= LISTEN_TIME:
		_cancel()
	else:
		_update_status()


func _cancel() -> void:
	var button: Button = _cells[_listen_action + ":" + _listen_device]
	_stop_listening()
	_status.text = tr("OPTIONS_CANCELLED")
	Sfx.play_ui("ui_move")
	button.grab_focus()


## Mentre si aspetta un tasto lo si prende prima dei pulsanti e dei menù:
## quello del dispositivo giusto diventa il nuovo comando, quello di un
## altro dispositivo annulla.
func _input(event: InputEvent) -> void:
	if not visible or _listen_action == "" or not Keybinds.is_bindable(event):
		return
	get_viewport().set_input_as_handled()
	# Il tasto non deve contare anche in gioco o nei menù finché resta premuto.
	UiNav.consume(event)
	if _listen_time < LISTEN_GUARD:
		return
	# Un tocco sullo schermo (arriva anche come clic emulato) non è un tasto del mouse.
	if Keybinds.device_of(event) != _listen_device \
			or (event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION):
		_cancel()
		return
	var action := _listen_action
	var button: Button = _cells[action + ":" + _listen_device]
	_listen_action = ""
	Keybinds.rebind(action, event)
	_stop_listening()
	_refresh()
	var shared := _shared_with(action, event)
	var text := tr("OPTIONS_BOUND") % [tr("BIND_ACTION_" + action.to_upper()), Keybinds.label(event)]
	if not shared.is_empty():
		text += "  ·  " + tr("OPTIONS_SHARED") % ", ".join(shared)
	_status.text = text
	Sfx.play_ui("ui_confirm")
	button.grab_focus()


## Altre azioni che usano lo stesso tasto (nomi da mostrare).
func _shared_with(action: String, event: InputEvent) -> Array[String]:
	var names: Array[String] = []
	for other: String in Keybinds.ACTIONS:
		if other == action:
			continue
		for bound in Keybinds.events(other, Keybinds.device_of(event)):
			if Keybinds.label(bound) == Keybinds.label(event):
				names.append(tr("BIND_ACTION_" + other.to_upper()))
				break
	return names


## Clic destro o tocco lungo su un pulsante: l'azione resta senza tasti
## per quel dispositivo. I tocchi arrivano come clic sinistri emulati: dopo
## un tocco lungo il rilascio non preme il pulsante (non si aspetta un tasto).
func _on_cell_input(event: InputEvent, action: String, device: String) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or _listen_action != "":
		return
	if mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		_clear(action, device)
	elif mouse.button_index == MOUSE_BUTTON_LEFT and mouse.device == InputEvent.DEVICE_ID_EMULATION:
		if mouse.pressed:
			_touch_cell = action + ":" + device
			_touch_time = 0.0
			_long_touched = false
		else:
			if _long_touched:
				accept_event()
			_touch_cell = ""
			_long_touched = false


func _clear(action: String, device: String) -> void:
	var action_name := tr("BIND_ACTION_" + action.to_upper())
	if not Keybinds.can_clear(action, device):
		_status.text = tr("OPTIONS_CLEAR_REQUIRED") % action_name
		Sfx.play_ui("ui_move")
		return
	Keybinds.clear(action, device)
	_refresh()
	_status.text = tr("OPTIONS_CLEARED") % [action_name, tr("OPTIONS_DEVICE_" + device.to_upper())]
	Sfx.play_ui("ui_confirm")


## Pulsante di un'azione selezionato: "azione:dispositivo" ("" se è un altro).
func _focused_cell() -> String:
	var focused := get_viewport().gui_get_focus_owner()
	for cell: String in _cells:
		if _cells[cell] == focused:
			return cell
	return ""


## Cambio di lingua: i testi scritti qui col codice si rifanno (gli altri
## si traducono da soli).
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


func _on_reset_pressed() -> void:
	_stop_listening()
	Keybinds.reset()
	_refresh()
	_status.text = tr("OPTIONS_RESET_DONE")
	Sfx.play_ui("ui_confirm")


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _listen_action != "":
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu") or event.is_action_pressed("dodge"):
		UiNav.consume(event)
		close()
	elif event.is_action_pressed("ui_clear") and _focused_cell() != "":
		UiNav.consume(event)
		var cell := _focused_cell().split(":")
		_clear(cell[0], cell[1])
	elif not UiNav.handle(event, get_viewport(), _back):
		return
	get_viewport().set_input_as_handled()
