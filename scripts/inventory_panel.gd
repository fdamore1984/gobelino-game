class_name InventoryPanel
extends Control
## Pannello dell'inventario (freccia su / I): monete, equipaggiamento
## indossato e oggetti raccolti. Con A (o clic) si indossa o toglie
## l'equipaggiamento, si legge un libro o si beve una pozione; B, Esc o di
## nuovo I chiudono. Mentre è aperto il gioco è in pausa.

const COLUMNS := 6
const SLOT_SIZE := Vector2(118, 104)
const ICON_SIZE := 46.0
const COLOR_EQUIPPED := Color(1.0, 0.85, 0.35)
const COLOR_DIM := Color(0, 0, 0, 0.7)
const COLOR_TEXT := Color(1, 1, 1, 0.8)

var player: Player

var _grid := GridContainer.new()
var _gold := Label.new()
var _equipped := HBoxContainer.new()
var _details := Label.new()
var _empty := Label.new()
var _buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = COLOR_DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := _label("INVENTORY_TITLE", 40, Color(1.0, 0.85, 0.4))
	box.add_child(title)
	_gold.add_theme_font_size_override("font_size", 22)
	_gold.add_theme_color_override("font_color", Items.color("gold"))
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_gold)
	box.add_child(_label("INVENTORY_EQUIPPED", 18, COLOR_TEXT))
	_equipped.alignment = BoxContainer.ALIGNMENT_CENTER
	_equipped.add_theme_constant_override("separation", 12)
	box.add_child(_equipped)
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_grid)
	_empty.text = "INVENTORY_EMPTY"
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_theme_color_override("font_color", COLOR_TEXT)
	box.add_child(_empty)
	_details.custom_minimum_size = Vector2(700, 56)
	_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_font_size_override("font_size", 19)
	box.add_child(_details)
	box.add_child(_label("INVENTORY_HINT", 16, Color(1, 1, 1, 0.55)))


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	get_tree().paused = true
	Sfx.play_ui("ui_confirm")
	_rebuild(0)


func close() -> void:
	visible = false
	get_tree().paused = false
	Sfx.play_ui("ui_move")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# La freccia su del controller serve a muoversi: chiudono B, Esc, Start,
	# i tasti I / Tab e il pulsante a schermo.
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu") \
			or ((event is InputEventKey or event is InputEventAction) and event.is_action_pressed("inventory")):
		close()
		get_viewport().set_input_as_handled()
		return
	var first: Control = _buttons[0] if not _buttons.is_empty() else self
	if not _buttons.is_empty() and UiNav.handle(event, get_viewport(), first) and is_inside_tree():
		get_viewport().set_input_as_handled()


## Ricostruisce la griglia e rimette il fuoco sull'oggetto all'indice dato.
func _rebuild(focus_index: int) -> void:
	var inventory := player.inventory
	_gold.text = tr("INVENTORY_GOLD") % inventory.gold
	for child in _grid.get_children():
		child.queue_free()
	for child in _equipped.get_children():
		child.queue_free()
	_buttons.clear()
	for slot: String in Items.EQUIPMENT:
		var icon := ItemIcon.new()
		icon.custom_minimum_size = Vector2(44, 44)
		if inventory.equipped.has(slot):
			icon.item_id = inventory.items[inventory.equipped[slot]]
		var frame := PanelContainer.new()
		frame.add_child(icon)
		_equipped.add_child(frame)
	for i in inventory.items.size():
		_buttons.append(_slot_button(i))
	_empty.visible = _buttons.is_empty()
	if _buttons.is_empty():
		_details.text = ""
		return
	var target := _buttons[clampi(focus_index, 0, _buttons.size() - 1)]
	target.grab_focus.call_deferred()


func _slot_button(index: int) -> Button:
	var id := player.inventory.items[index]
	var button := item_button(id, Items.name_key(id), player.inventory.is_equipped(index))
	button.pressed.connect(_on_slot_pressed.bind(index))
	button.focus_entered.connect(_show_details.bind(index))
	button.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
	_grid.add_child(button)
	return button


## Casella di un oggetto: icona e didascalia, bordo dorato se evidenziata
## (oggetto indossato). Usata anche dal negozio dei mercanti.
static func item_button(id: String, caption: String, highlight: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = SLOT_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.1, 0.95)
	style.set_corner_radius_all(8)
	style.set_border_width_all(3 if highlight else 1)
	style.border_color = COLOR_EQUIPPED if highlight else Color(1, 1, 1, 0.2)
	var focus := style.duplicate() as StyleBoxFlat
	focus.border_color = Color.WHITE
	focus.set_border_width_all(4)
	focus.bg_color = Color(0.18, 0.21, 0.16, 0.98)
	for state: String in ["normal", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("hover", focus)
	button.add_theme_stylebox_override("focus", focus)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := ItemIcon.new()
	icon.item_id = id
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var name_label := Label.new()
	name_label.text = caption
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", COLOR_EQUIPPED if highlight else COLOR_TEXT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	button.add_child(box)
	return button


func _on_slot_pressed(index: int) -> void:
	player.use_item(index)
	Sfx.play_ui("ui_confirm")
	_rebuild(index)


## Nome, effetti e cosa fa A sull'oggetto selezionato.
func _show_details(index: int) -> void:
	var id := player.inventory.items[index]
	var action := "INVENTORY_USE_EQUIP"
	match Items.category(id):
		"book":
			action = "INVENTORY_USE_READ"
		"potion":
			action = "INVENTORY_USE_DRINK"
		_:
			if player.inventory.is_equipped(index):
				action = "INVENTORY_USE_UNEQUIP"
	_details.text = "%s\n%s" % [describe(id), tr(action)]


## Nome ed effetti dell'oggetto, tradotti.
static func describe(id: String) -> String:
	var effects: Array[String] = []
	for key: String in ["damage", "health", "speed", "mana", "spell", "heal", "restore_mana"]:
		var value := Items.stat(id, key)
		if value == 0.0:
			continue
		var shown := roundi(value * 100.0) if key in ["damage", "speed", "spell"] else roundi(value)
		effects.append(TranslationServer.translate("STAT_" + key.to_upper()) % shown)
	return "%s — %s" % [TranslationServer.translate(Items.name_key(id)), ", ".join(effects)]
