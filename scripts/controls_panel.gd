class_name ControlsPanel
extends Control
## Elenco dei comandi, aperto dal menù iniziale: azioni con tastiera e
## controller (ogni riga di data/translations.csv è "azione | tastiera |
## controller") e gli attacchi speciali. Si chiude con B, Esc o il
## pulsante Indietro.

signal closed

const ROWS := [
	"CONTROLS_MOVE", "CONTROLS_ATTACK", "CONTROLS_HEAVY", "CONTROLS_PARRY", "CONTROLS_DODGE",
	"CONTROLS_JUMP", "CONTROLS_RUN", "CONTROLS_FOCUS", "CONTROLS_SPELL", "CONTROLS_SHIELD", "CONTROLS_POTION",
	"CONTROLS_MANA", "CONTROLS_TORCH", "CONTROLS_INVENTORY", "CONTROLS_MAP", "CONTROLS_LOCK", "CONTROLS_MENU",
]
const SPECIALS := ["CONTROLS_SPECIAL_LEAP", "CONTROLS_SPECIAL_AIR", "CONTROLS_SPECIAL_PLUNGE", "CONTROLS_SPECIAL_DASH"]
const COLOR_TITLE := Color(0.85, 0.75, 0.4)
const COLOR_HEADER := Color(1.0, 0.85, 0.4)
const COLOR_TEXT := Color(1, 1, 1, 0.85)
const COLOR_KEY := Color(0.75, 0.9, 1.0)

var _back := Button.new()


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
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 0)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	_add_row(grid, "CONTROLS_HEADER", true)
	for key: String in ROWS:
		_add_row(grid, key, false)
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


## Una riga della tabella: il testo tradotto diviso in tre colonne.
func _add_row(grid: GridContainer, key: String, header: bool) -> void:
	var cells := tr(key).split("|")
	for i in 3:
		var text := cells[i].strip_edges() if i < cells.size() else ""
		var color := COLOR_HEADER if header else (COLOR_TEXT if i == 0 else COLOR_KEY)
		var label := _label(text, 18 if header else 16, color, false)
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		grid.add_child(label)


func _label(text: String, font_size: int, color: Color, centered: bool) -> Label:
	var label := Label.new()
	label.text = text
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func open() -> void:
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
