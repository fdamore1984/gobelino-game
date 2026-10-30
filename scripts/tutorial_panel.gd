class_name TutorialPanel
extends Control
## Tutorial a pagine, aperto dal menù iniziale e da quello di pausa: ogni
## pagina ha un'immagine del gioco (catturata con tools/store_capture.tscn,
## vedi assets/tutorial/), un titolo e un testo che spiega una meccanica,
## Frenesia compresa. Si sfoglia con i pulsanti Indietro e Avanti (croce o
## levetta per spostarsi, A per premere) o direttamente con L1 e R1; B, il
## pulsante Chiudi o Start chiudono.
## Nei testi i tasti sono scritti come {azione} e si leggono dall'Input Map
## (vedi Keybinds): per esempio {attack} diventa R1.

signal closed

const IMAGE_DIR := "res://assets/tutorial/"
## Pagine: immagine (in IMAGE_DIR), titolo e testo (chiavi di traduzione).
const PAGES := [
	["move.png", "TUTORIAL_MOVE_TITLE", "TUTORIAL_MOVE_TEXT"],
	["combo.png", "TUTORIAL_COMBO_TITLE", "TUTORIAL_COMBO_TEXT"],
	["parry.png", "TUTORIAL_PARRY_TITLE", "TUTORIAL_PARRY_TEXT"],
	["dodge.png", "TUTORIAL_DODGE_TITLE", "TUTORIAL_DODGE_TEXT"],
	["frenzy_bar.png", "TUTORIAL_FRENZY_TITLE", "TUTORIAL_FRENZY_TEXT"],
	["frenzy_special.png", "TUTORIAL_SPECIAL_TITLE", "TUTORIAL_SPECIAL_TEXT"],
	["supplies.png", "TUTORIAL_SUPPLIES_TITLE", "TUTORIAL_SUPPLIES_TEXT"],
	["arsenal.png", "TUTORIAL_ARSENAL_TITLE", "TUTORIAL_ARSENAL_TEXT"],
	["enemies.png", "TUTORIAL_ENEMIES_TITLE", "TUTORIAL_ENEMIES_TEXT"],
	["loot.png", "TUTORIAL_LOOT_TITLE", "TUTORIAL_LOOT_TEXT"],
	["world.png", "TUTORIAL_WORLD_TITLE", "TUTORIAL_WORLD_TEXT"],
	["buildings.png", "TUTORIAL_BUILDINGS_TITLE", "TUTORIAL_BUILDINGS_TEXT"],
	["metro.png", "TUTORIAL_METRO_TITLE", "TUTORIAL_METRO_TEXT"],
	["progress.png", "TUTORIAL_PROGRESS_TITLE", "TUTORIAL_PROGRESS_TEXT"],
]
const IMAGE_SIZE := Vector2(600, 338)
const TEXT_WIDTH := 500.0
const COLOR_TITLE := Color(0.85, 0.75, 0.4)
const COLOR_PAGE_TITLE := Color(1.0, 0.55, 0.74)
const COLOR_TEXT := Color(1, 1, 1, 0.88)
const COLOR_HINT := Color(1, 1, 1, 0.55)
const COLOR_DOT := Color(1, 1, 1, 0.25)
const COLOR_DOT_CURRENT := Color(1.0, 0.55, 0.74)

var _page := 0
var _image := TextureRect.new()
var _page_title := Label.new()
var _text := Label.new()
var _counter := Label.new()
var _hint := Label.new()
var _dots := HBoxContainer.new()
var _prev := Button.new()
var _next := Button.new()
var _close := Button.new()
## Testo dei tasti tra graffe: {azione} -> nome del tasto.
var _key_pattern := RegEx.create_from_string("\\{(\\w+)\\}")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.04, 1.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	box.add_child(_label("TUTORIAL_TITLE", 34, COLOR_TITLE))
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation", 30)
	box.add_child(page)
	# Immagine incorniciata a sinistra, titolo e spiegazione a destra.
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.border_color = Color(1, 1, 1, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", style)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	page.add_child(frame)
	_image.custom_minimum_size = IMAGE_SIZE
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(_image)
	var words := VBoxContainer.new()
	words.custom_minimum_size = Vector2(TEXT_WIDTH, IMAGE_SIZE.y)
	words.add_theme_constant_override("separation", 12)
	page.add_child(words)
	_page_title.add_theme_font_size_override("font_size", 30)
	_page_title.add_theme_color_override("font_color", COLOR_PAGE_TITLE)
	_page_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	words.add_child(_page_title)
	_text.add_theme_font_size_override("font_size", 19)
	_text.add_theme_color_override("font_color", COLOR_TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_text.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	words.add_child(_text)
	# Puntini delle pagine e numero della pagina.
	var status := HBoxContainer.new()
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.add_theme_constant_override("separation", 18)
	box.add_child(status)
	_dots.add_theme_constant_override("separation", 8)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	status.add_child(_dots)
	for k in PAGES.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_dots.add_child(dot)
	_counter.add_theme_font_size_override("font_size", 18)
	_counter.add_theme_color_override("font_color", COLOR_HINT)
	_counter.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	status.add_child(_counter)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	for pair: Array in [[_prev, "TUTORIAL_PREV"], [_next, "TUTORIAL_NEXT"], [_close, "TUTORIAL_CLOSE"]]:
		var button: Button = pair[0]
		button.text = pair[1]
		button.custom_minimum_size = Vector2(220, 52)
		button.add_theme_font_size_override("font_size", 24)
		button.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
		row.add_child(button)
	# Su e giù restano sul pulsante; destra e sinistra girano sulla riga.
	var buttons: Array[Button] = [_prev, _next, _close]
	for k in buttons.size():
		buttons[k].focus_neighbor_left = buttons[(k + buttons.size() - 1) % buttons.size()].get_path()
		buttons[k].focus_neighbor_right = buttons[(k + 1) % buttons.size()].get_path()
		buttons[k].focus_neighbor_top = buttons[k].get_path()
		buttons[k].focus_neighbor_bottom = buttons[k].get_path()
	_prev.pressed.connect(_turn.bind(-1))
	_next.pressed.connect(_turn.bind(1))
	_close.pressed.connect(close)
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", COLOR_HINT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(_hint)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func is_open() -> bool:
	return visible


## Si riparte sempre dalla prima pagina.
func open() -> void:
	visible = true
	_show_page(0)
	_next.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	Sfx.play_ui("ui_move")
	closed.emit()


func page() -> int:
	return _page


func page_count() -> int:
	return PAGES.size()


## Pagina precedente (step -1) o successiva (+1), se c'è.
func _turn(step: int) -> void:
	var target := clampi(_page + step, 0, PAGES.size() - 1)
	if target == _page:
		return
	Sfx.play_ui("ui_confirm")
	_show_page(target)


func _show_page(index: int) -> void:
	_page = index
	var entry: Array = PAGES[index]
	var path: String = IMAGE_DIR + entry[0]
	# Senza l'immagine (non ancora catturata) resta la cornice vuota.
	_image.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_page_title.text = tr(entry[1])
	_text.text = _with_keys(tr(entry[2]))
	_counter.text = tr("TUTORIAL_PAGE") % [index + 1, PAGES.size()]
	for k in _dots.get_child_count():
		(_dots.get_child(k) as ColorRect).color = COLOR_DOT_CURRENT if k == index else COLOR_DOT
	_hint.text = tr("TUTORIAL_HINT") % [Keybinds.hint("parry"), Keybinds.hint("attack"), Keybinds.hint("ui_cancel")]
	# Prima e ultima pagina: il pulsante che non serve si spegne e il focus
	# passa all'altro.
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	for button: Button in [_prev, _next]:
		var off := (button == _prev and index == 0) or (button == _next and index == PAGES.size() - 1)
		button.disabled = off
		button.focus_mode = Control.FOCUS_NONE if off else Control.FOCUS_ALL
	if focused is Button and (focused as Button).disabled:
		(_next if focused == _prev else _prev).grab_focus()


## Sostituisce {azione} con il tasto del controller legato all'azione.
func _with_keys(text: String) -> String:
	var result := text
	for found in _key_pattern.search_all(text):
		result = result.replace(found.get_string(), Keybinds.hint(found.get_string(1)))
	return result


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu") or event.is_action_pressed("dodge"):
		close()
	# L1 e R1 sfogliano le pagine (R1 qui non conferma il pulsante, vedi UiNav).
	elif event.is_action_pressed("parry"):
		_turn(-1)
	elif event.is_action_pressed("attack"):
		_turn(1)
	elif not UiNav.handle(event, get_viewport(), _next if not _next.disabled else _prev):
		return
	get_viewport().set_input_as_handled()
