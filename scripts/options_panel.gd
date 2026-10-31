class_name OptionsPanel
extends Control
## Opzioni (dal menù iniziale e da quello di pausa): la lingua del gioco. Il
## pulsante passa alla lingua successiva (Settings.LANGUAGES), subito e per
## tutti i testi. I comandi si cambiano dalla pagina dei comandi (pulsante
## Modifica, vedi ControlsPanel). Funziona con mouse, touch, tastiera e
## controller; si chiude con B, Esc o il pulsante Indietro.

signal closed

const COLOR_TITLE := Color(0.85, 0.75, 0.4)

var _language := Button.new()
var _back := Button.new()


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
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)
	var title := Label.new()
	title.text = "OPTIONS_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	box.add_child(title)
	_language.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_back.text = "OPTIONS_BACK"
	for button: Button in [_language, _back]:
		button.custom_minimum_size = Vector2(320, 56)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", 26)
		button.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
		box.add_child(button)
	_language.pressed.connect(_on_language_pressed)
	_back.pressed.connect(close)
	_refresh()


func _refresh() -> void:
	_language.text = tr("OPTIONS_LANGUAGE") % tr("LANGUAGE_NAME_" + Settings.language.to_upper())


func open() -> void:
	_refresh()
	visible = true
	_language.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	Sfx.play_ui("ui_move")
	closed.emit()


func _on_language_pressed() -> void:
	Settings.set_language(Settings.next_language())
	Sfx.play_ui("ui_confirm")


## Cambio di lingua: il testo del pulsante si rifà (gli altri si traducono
## da soli).
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu") or event.is_action_pressed("dodge"):
		UiNav.consume(event)
		close()
	elif not UiNav.handle(event, get_viewport(), _language):
		return
	get_viewport().set_input_as_handled()
