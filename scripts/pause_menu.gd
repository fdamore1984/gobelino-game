class_name PauseMenu
extends Control
## Menù di pausa (Start / Esc durante il gioco): riprendi, salva, comandi,
## torna al titolo. Si salva solo senza nemici vicini e stando fermi: se
## non si può, il pulsante è spento e sotto c'è il motivo.

signal save_requested
signal quit_requested

var _resume := Button.new()
var _save := Button.new()
var _controls := Button.new()
var _quit := Button.new()
var _reason := Label.new()
var _controls_panel := ControlsPanel.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := Label.new()
	title.text = "PAUSE_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.85, 0.75, 0.4))
	box.add_child(title)
	for pair: Array in [[_resume, "PAUSE_RESUME"], [_save, "PAUSE_SAVE"], [_controls, "PAUSE_CONTROLS"], [_quit, "PAUSE_QUIT"]]:
		var button: Button = pair[0]
		button.text = pair[1]
		button.custom_minimum_size = Vector2(320, 60)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", 28)
		button.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
		box.add_child(button)
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason.add_theme_font_size_override("font_size", 18)
	_reason.add_theme_color_override("font_color", Color(1.0, 0.6, 0.45))
	box.add_child(_reason)
	box.move_child(_reason, 3)
	_resume.pressed.connect(close)
	_save.pressed.connect(func() -> void: save_requested.emit())
	_controls.pressed.connect(_open_controls)
	_quit.pressed.connect(func() -> void: quit_requested.emit())
	add_child(_controls_panel)
	_controls_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_controls_panel.closed.connect(_controls.grab_focus)


func is_open() -> bool:
	return visible


## blocked: chiave del testo che spiega perché non si può salvare ("" = si può).
func open(blocked: String) -> void:
	visible = true
	get_tree().paused = true
	_save.disabled = blocked != ""
	_save.focus_mode = Control.FOCUS_NONE if _save.disabled else Control.FOCUS_ALL
	_reason.text = blocked
	_reason.visible = blocked != ""
	Sfx.play_ui("ui_confirm")
	_resume.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	Sfx.play_ui("ui_move")


## Dopo un salvataggio riuscito il pulsante si spegne: niente doppi salvataggi.
func saved() -> void:
	_save.disabled = true
	_save.focus_mode = Control.FOCUS_NONE
	_reason.text = "SAVE_DONE"
	_reason.visible = true
	_resume.grab_focus()


func _open_controls() -> void:
	Sfx.play_ui("ui_confirm")
	_controls_panel.open()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _controls_panel.visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		close()
		get_viewport().set_input_as_handled()
	elif UiNav.handle(event, get_viewport(), _resume) and is_inside_tree():
		get_viewport().set_input_as_handled()
