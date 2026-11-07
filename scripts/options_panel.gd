class_name OptionsPanel
extends Control
## Opzioni (dal menù iniziale e da quello di pausa): lingua, difficoltà,
## vibrazione del controller, numeri dei danni, tremolio della telecamera,
## sangue e dimensione dell'interfaccia (vedi Settings). Ogni pulsante passa
## al valore successivo, subito; le opzioni valgono per tutte le partite e si
## salvano in user://settings.json. I comandi si cambiano dalla pagina dei
## comandi (pulsante Modifica, vedi ControlsPanel). Licenze apre le note di
## copyright e le licenze di Godot, dei suoi componenti e dei font
## (LicensesPanel). Funziona con mouse, touch, tastiera e controller; si
## chiude con B, Esc o il pulsante Indietro. Se i pulsanti non stanno in
## altezza (interfaccia grande) la lista scorre e segue quello selezionato.

signal closed

const COLOR_TITLE := Color(0.85, 0.75, 0.4)
const BUTTON_SIZE := Vector2(460, 46)
const FONT_SIZE := 22

var _language := Button.new()
var _difficulty := Button.new()
var _vibration := Button.new()
var _damage_numbers := Button.new()
var _shake := Button.new()
var _blood := Button.new()
var _ui_scale := Button.new()
var _licenses := Button.new()
var _back := Button.new()
var _licenses_panel := LicensesPanel.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = UiStyle.OVERLAY
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := Label.new()
	title.text = "OPTIONS_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	box.add_child(title)
	_licenses.text = "OPTIONS_LICENSES"
	_back.text = "OPTIONS_BACK"
	for button: Button in [_language, _difficulty, _vibration, _damage_numbers, _shake, _blood, _ui_scale, _licenses, _back]:
		if button not in [_licenses, _back]:
			button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.custom_minimum_size = BUTTON_SIZE
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", FONT_SIZE)
		button.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
		box.add_child(button)
	_language.pressed.connect(_on_language_pressed)
	_difficulty.pressed.connect(_cycle.bind("difficulty", Settings.DIFFICULTIES))
	_vibration.pressed.connect(_toggle.bind("vibration"))
	_damage_numbers.pressed.connect(_toggle.bind("damage_numbers"))
	_shake.pressed.connect(_cycle.bind("camera_shake", Settings.LEVELS))
	_blood.pressed.connect(_cycle.bind("blood", Settings.LEVELS))
	_ui_scale.pressed.connect(_cycle.bind("ui_scale", Settings.UI_SCALES))
	_vibration.pressed.connect(_rumble_sample)
	_licenses.pressed.connect(_on_licenses_pressed)
	_back.pressed.connect(close)
	add_child(_licenses_panel)
	_licenses_panel.closed.connect(_licenses.grab_focus)
	Settings.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	_language.text = tr("OPTIONS_LANGUAGE") % tr("LANGUAGE_NAME_" + Settings.language.to_upper())
	_difficulty.text = tr("OPTIONS_DIFFICULTY") % tr("DIFFICULTY_" + Settings.difficulty.to_upper())
	_vibration.text = tr("OPTIONS_VIBRATION") % tr("OPTION_ON" if Settings.vibration else "OPTION_OFF")
	_damage_numbers.text = tr("OPTIONS_DAMAGE_NUMBERS") % tr("OPTION_ON" if Settings.damage_numbers else "OPTION_OFF")
	_shake.text = tr("OPTIONS_SHAKE") % tr("OPTION_" + Settings.camera_shake.to_upper())
	_blood.text = tr("OPTIONS_BLOOD") % tr("OPTION_" + Settings.blood.to_upper())
	_ui_scale.text = tr("OPTIONS_UI_SCALE") % roundi(Settings.ui_scale * 100.0)


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


## Opzione a più valori: passa al successivo.
func _cycle(option: String, values: Array) -> void:
	Settings.set_option(option, Settings.next_of(values, Settings.get(option)))
	Sfx.play_ui("ui_confirm")


## Opzione sì/no.
func _toggle(option: String) -> void:
	Settings.set_option(option, not bool(Settings.get(option)))
	Sfx.play_ui("ui_confirm")


## Accendendo la vibrazione il controller vibra un attimo, per provarla.
func _rumble_sample() -> void:
	if Settings.vibration:
		Rumble.hit_dealt(true)


func _on_licenses_pressed() -> void:
	Sfx.play_ui("ui_confirm")
	_licenses_panel.open()


## Cambio di lingua: i testi dei pulsanti si rifanno (gli altri si traducono
## da soli).
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _licenses_panel.visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu") or event.is_action_pressed("dodge"):
		UiNav.consume(event)
		close()
	elif not UiNav.handle(event, get_viewport(), _language):
		return
	get_viewport().set_input_as_handled()
