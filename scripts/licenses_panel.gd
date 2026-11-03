class_name LicensesPanel
extends Control
## Licenze (da Opzioni): le note di copyright e i testi di licenza che vanno
## distribuiti col gioco. Godot e i componenti di terzi che contiene (licenza
## MIT e simili) chiedono di riportarli; i testi arrivano dal motore stesso
## (Engine.get_license_text, get_copyright_info, get_license_info), quelli dei
## font da assets/fonts/OFL.txt (incluso in tutti gli export). Sono testi
## legali e restano in inglese, la lingua in cui sono scritti; titolo,
## introduzione e pulsante si traducono. Il testo si prepara alla prima
## apertura. Scorre con rotellina, trascinando col dito, su e giù di croce,
## levetta o frecce; si chiude con B, Esc o il pulsante Indietro.

signal closed

const FONTS_LICENSE := "res://assets/fonts/OFL.txt"
const COLOR_TITLE := Color(0.85, 0.75, 0.4)
const COLOR_TEXT := Color(1, 1, 1, 0.85)
const WIDTH := 1100.0
## Spazio verticale per titolo, introduzione e pulsante.
const RESERVED_HEIGHT := 210.0
## Velocità di scorrimento con croce, levetta e frecce (pixel al secondo).
const SCROLL_SPEED := 900.0

var _back := Button.new()
var _scroll := ScrollContainer.new()
var _text: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = UiStyle.OVERLAY
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := _label("LICENSES_TITLE", 34, COLOR_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var intro := _label("LICENSES_INTRO", 18, COLOR_TEXT)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_child(intro)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_scroll)
	_text = _label("", 14, COLOR_TEXT)
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH, 0)
	_scroll.add_child(_text)
	_back.text = "OPTIONS_BACK"
	_back.custom_minimum_size = Vector2(220, 44)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.add_theme_font_size_override("font_size", 24)
	_back.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
	_back.pressed.connect(close)
	box.add_child(_back)
	get_viewport().size_changed.connect(_fit)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## La parte che scorre prende tutta l'altezza libera dello schermo.
func _fit() -> void:
	var height := get_viewport_rect().size.y - RESERVED_HEIGHT
	_scroll.custom_minimum_size = Vector2(WIDTH + 16, maxf(height, 200.0))


## Tutto il testo delle licenze: Godot, i componenti di terzi con le loro
## note di copyright, i testi completi delle loro licenze e i font.
static func full_text() -> String:
	var parts: Array[String] = ["Godot Engine", Engine.get_license_text()]
	var components: Array[String] = []
	for component: Dictionary in Engine.get_copyright_info():
		for part: Dictionary in component["parts"]:
			var lines: Array[String] = [String(component["name"])]
			for holder: String in part["copyright"]:
				lines.append("  © " + holder)
			lines.append("  License: " + String(part["license"]))
			components.append("\n".join(lines))
	parts.append("Third-party components\n\n" + "\n\n".join(components))
	var licenses := Engine.get_license_info()
	for license: String in licenses:
		parts.append("License: %s\n\n%s" % [license, licenses[license]])
	if FileAccess.file_exists(FONTS_LICENSE):
		parts.append("Fonts\n\n" + FileAccess.get_file_as_string(FONTS_LICENSE).strip_edges())
	return "\n\n――――――――――\n\n".join(parts)


func open() -> void:
	if _text.text.is_empty():
		_text.text = full_text()
	_fit()
	_scroll.scroll_vertical = 0
	visible = true
	_back.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	Sfx.play_ui("ui_move")
	closed.emit()


## Su e giù (croce, levetta, frecce, W e S) fanno scorrere il testo.
func _process(delta: float) -> void:
	if not visible:
		return
	var direction := clampf(Input.get_axis("ui_up", "ui_down") + Input.get_axis("move_up", "move_down"), -1.0, 1.0)
	if direction != 0.0:
		_scroll.scroll_vertical += int(direction * SCROLL_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu") or event.is_action_pressed("dodge"):
		UiNav.consume(event)
		close()
	elif event.is_action("ui_up") or event.is_action("ui_down") or event.is_action("move_up") or event.is_action("move_down"):
		pass
	elif not UiNav.handle(event, get_viewport(), _back):
		return
	get_viewport().set_input_as_handled()
