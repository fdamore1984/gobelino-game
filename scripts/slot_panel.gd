class_name SlotPanel
extends Control
## Scelta dello slot di salvataggio dal menù iniziale. Per una nuova partita
## si può scegliere qualsiasi slot (uno già usato va confermato premendolo
## una seconda volta: la partita vecchia viene sostituita); per continuare
## solo quelli salvati. Si chiude con B, Esc o il pulsante Indietro.
##
## Gli slot sono schede affiancate in una griglia: ognuna mostra livello,
## dove si trova il giocatore, vita e danno, monete e pozioni, nemici
## sconfitti, tempo di gioco e momento del salvataggio (vedi
## SaveGame.summary). Destra e sinistra passano da uno slot all'altro, giù
## porta a Indietro.

signal chosen(slot: int)
signal closed

const COLOR_TITLE := Color(0.85, 0.75, 0.4)
const COLOR_EMPTY := Color(1, 1, 1, 0.6)
const COLOR_CONFIRM := Color(1.0, 0.6, 0.35)
const COLOR_DIM := Color(1, 1, 1, 0.55)
const CARD_SIZE := Vector2(360, 320)
const CARD_GAP := 24
## Righe di ogni scheda: nome dello slot, livello, poi i dettagli.
const LINES := 8

var _title := Label.new()
var _buttons: Array[Button] = []
## Righe di testo di ogni scheda (Label dentro il pulsante).
var _lines: Array[Array] = []
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
	var grid := GridContainer.new()
	grid.columns = SaveGame.SLOTS
	grid.add_theme_constant_override("h_separation", CARD_GAP)
	grid.add_theme_constant_override("v_separation", CARD_GAP)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	for index in range(1, SaveGame.SLOTS + 1):
		var button := Button.new()
		button.custom_minimum_size = CARD_SIZE
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.pressed.connect(_on_slot_pressed.bind(index))
		button.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
		button.focus_entered.connect(_on_slot_focused.bind(index))
		grid.add_child(button)
		_buttons.append(button)
		_lines.append(_make_card(button))
	_back.text = "CONTROLS_BACK"
	_back.custom_minimum_size = Vector2(220, 52)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.add_theme_font_size_override("font_size", 24)
	_back.pressed.connect(close)
	_back.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
	box.add_child(_back)
	# Destra e sinistra girano tra gli slot (dall'ultimo si torna al primo),
	# su e giù passano dagli slot a Indietro: la navigazione resta qui.
	for k in _buttons.size():
		var button := _buttons[k]
		button.focus_neighbor_left = _buttons[k - 1].get_path()
		button.focus_neighbor_right = _buttons[(k + 1) % _buttons.size()].get_path()
		button.focus_neighbor_top = _back.get_path()
		button.focus_neighbor_bottom = _back.get_path()
	_back.focus_neighbor_left = _back.get_path()
	_back.focus_neighbor_right = _back.get_path()


## Righe di testo dentro la scheda dello slot (non ricevono clic e tocchi:
## li prende il pulsante).
func _make_card(button: Button) -> Array[Label]:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	button.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var labels: Array[Label] = []
	for k in LINES:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 30 if k == 0 else (26 if k == 1 else 19))
		column.add_child(label)
		labels.append(label)
		if k == 1:
			# Spazio tra intestazione e dettagli.
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 6)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			column.add_child(gap)
	return labels


func open(for_new_game: bool) -> void:
	new_game = for_new_game
	_confirming = 0
	_title.text = tr("SLOTS_NEW_TITLE") if for_new_game else tr("SLOTS_LOAD_TITLE")
	_refresh()
	visible = true
	_first().grab_focus.call_deferred()
	# Da Indietro, su porta al primo slot che si può scegliere.
	_back.focus_neighbor_top = _first().get_path()
	_back.focus_neighbor_bottom = _first().get_path()


func close() -> void:
	if not visible:
		return
	visible = false
	Sfx.play_ui("ui_move")
	closed.emit()


## Testo di ogni scheda: libera, o le statistiche della partita salvata
## (con la richiesta di conferma se va sostituita).
func _refresh() -> void:
	for k in _buttons.size():
		var index := k + 1
		var button := _buttons[k]
		var info := SaveGame.summary(index)
		var texts: Array[String] = [tr("SLOT_NAME") % index]
		var colors: Array[Color] = [COLOR_TITLE]
		if info.is_empty():
			texts.append(tr("SLOT_EMPTY"))
			colors.append(COLOR_EMPTY)
			if new_game:
				texts.append(tr("SLOT_EMPTY_NEW"))
				colors.append(COLOR_DIM)
		else:
			texts.append(tr("SLOT_LEVEL") % info["level"])
			colors.append(Color.WHITE)
			if _confirming == index:
				texts.append(tr("SLOT_OVERWRITE"))
				colors.append(COLOR_CONFIRM)
			else:
				var depth: int = info["depth"]
				texts.append_array([
					tr("SLOT_PLACE_DEPTH") % depth if depth > 0 else tr("SLOT_PLACE_SURFACE"),
					tr("SLOT_HEALTH_DAMAGE") % [info["max_health"], info["damage"]],
					tr("SLOT_GOLD_POTIONS") % [info["gold"], info["potions"]],
					tr("SLOT_KILLS") % info["kills"],
					tr("SLOT_PLAYTIME") % _play_time_text(info["play_time"]),
					tr("SLOT_SAVED_AT") % info["time"],
				])
				colors.append_array([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, COLOR_DIM])
		var labels: Array = _lines[k]
		for line in labels.size():
			var label: Label = labels[line]
			label.text = texts[line] if line < texts.size() else ""
			label.add_theme_color_override("font_color", colors[line] if line < colors.size() else Color.WHITE)
		button.disabled = not new_game and info.is_empty()
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		# Gli slot che non si possono scegliere restano visibili ma spenti.
		button.modulate.a = 0.45 if button.disabled else 1.0


## Tempo di gioco come "12 min" o "1 h 05 min" (sconosciuto nei salvataggi vecchi).
func _play_time_text(seconds: float) -> String:
	if seconds < 0.0:
		return tr("SLOT_PLAYTIME_UNKNOWN")
	var minutes := floori(seconds / 60.0)
	if minutes < 60:
		return tr("SLOT_PLAYTIME_MIN") % minutes
	return tr("SLOT_PLAYTIME_HOURS") % [floori(minutes / 60.0), minutes % 60]


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
	# Scegliendo uno slot la scena cambia subito: questo pannello non c'è più.
	if is_inside_tree():
		get_viewport().set_input_as_handled()
