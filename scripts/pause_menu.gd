class_name PauseMenu
extends Control
## Menù di pausa (Start / Esc durante il gioco): riprendi, salva, comandi
## (con la rimappatura dei tasti), tutorial, opzioni (lingua, OptionsPanel),
## torna al titolo
## (dopo una conferma: i progressi non salvati si perdono).
## Si salva solo senza nemici vicini (anche in movimento): se non si può, il
## pulsante è spento e sotto c'è il motivo. Il tasto che
## chiude la pausa (A su Riprendi, B, Start) è consumato (vedi UiNav.consume):
## tornati in gioco non fa saltare, schivare né interagire.

signal save_requested
signal quit_requested

var _resume := Button.new()
var _save := Button.new()
var _controls := Button.new()
var _tutorial := Button.new()
var _quit := Button.new()
var _reason := Label.new()
var _controls_panel := ControlsPanel.new()
var _options := Button.new()
var _options_panel := OptionsPanel.new()
var _tutorial_panel := TutorialPanel.new()
## Richiesta di conferma prima di tornare al titolo.
var _confirm := Control.new()
## Titolo e pulsanti della pausa: si nascondono mentre si chiede conferma.
var _main: Control
var _confirm_yes := Button.new()
var _confirm_no := Button.new()


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
	_main = center
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := Label.new()
	title.text = "PAUSE_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.85, 0.75, 0.4))
	box.add_child(title)
	for pair: Array in [[_resume, "PAUSE_RESUME"], [_save, "PAUSE_SAVE"], [_controls, "PAUSE_CONTROLS"], [_tutorial, "PAUSE_TUTORIAL"], [_options, "PAUSE_OPTIONS"], [_quit, "PAUSE_QUIT"]]:
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
	_tutorial.pressed.connect(_open_tutorial)
	_quit.pressed.connect(_open_confirm)
	add_child(_controls_panel)
	_controls_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_controls_panel.closed.connect(_controls.grab_focus)
	_options.pressed.connect(_open_options)
	add_child(_options_panel)
	_options_panel.closed.connect(_options.grab_focus)
	add_child(_tutorial_panel)
	_tutorial_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_tutorial_panel.closed.connect(_tutorial.grab_focus)
	_build_confirm()


## Finestra di conferma per tornare al titolo: avvisa che i progressi non
## salvati andranno persi; Annulla (B, Esc) torna al menù di pausa.
func _build_confirm() -> void:
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.visible = false
	add_child(_confirm)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.08, 0.97)
	style.border_color = Color(0.85, 0.75, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	margin.add_child(box)
	var message := Label.new()
	message.text = "PAUSE_QUIT_CONFIRM"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.custom_minimum_size = Vector2(460, 0)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 26)
	message.add_theme_color_override("font_color", Color(1.0, 0.8, 0.6))
	box.add_child(message)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	for pair: Array in [[_confirm_no, "PAUSE_QUIT_NO"], [_confirm_yes, "PAUSE_QUIT_YES"]]:
		var button: Button = pair[0]
		button.text = pair[1]
		button.custom_minimum_size = Vector2(200, 56)
		button.add_theme_font_size_override("font_size", 26)
		button.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
		row.add_child(button)
	# Destra e sinistra passano da un pulsante all'altro, su e giù restano lì.
	for button: Button in [_confirm_no, _confirm_yes]:
		var other := _confirm_yes if button == _confirm_no else _confirm_no
		button.focus_neighbor_left = other.get_path()
		button.focus_neighbor_right = other.get_path()
		button.focus_neighbor_top = button.get_path()
		button.focus_neighbor_bottom = button.get_path()
	_confirm_no.pressed.connect(_close_confirm)
	_confirm_yes.pressed.connect(func() -> void: quit_requested.emit())


func _open_confirm() -> void:
	Sfx.play_ui("ui_confirm")
	_confirm.visible = true
	_main.visible = false
	# Si parte da Annulla: un tocco di troppo non fa perdere la partita.
	_confirm_no.grab_focus()


func _close_confirm() -> void:
	if not _confirm.visible:
		return
	_confirm.visible = false
	_main.visible = true
	Sfx.play_ui("ui_move")
	_quit.grab_focus()


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
	_confirm.visible = false
	_main.visible = true
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


func _open_tutorial() -> void:
	Sfx.play_ui("ui_confirm")
	_tutorial_panel.open()


func _open_options() -> void:
	Sfx.play_ui("ui_confirm")
	_options_panel.open()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _controls_panel.visible or _options_panel.visible or _tutorial_panel.visible:
		return
	if _confirm.visible:
		if event.is_action_pressed("ui_cancel"):
			UiNav.consume(event)
			_close_confirm()
			get_viewport().set_input_as_handled()
		elif UiNav.handle(event, get_viewport(), _confirm_no) and is_inside_tree():
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		UiNav.consume(event)
		close()
		get_viewport().set_input_as_handled()
	elif UiNav.handle(event, get_viewport(), _resume) and is_inside_tree():
		get_viewport().set_input_as_handled()
