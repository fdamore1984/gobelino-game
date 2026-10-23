class_name InventoryPanel
extends Control
## Pannello dell'inventario (freccia su / I): monete, equipaggiamento
## indossato e oggetti raccolti, in una griglia in cui ogni oggetto occupa
## una casella; quando non ci stanno tutti la griglia scorre (levetta,
## croce, rotellina o trascinando col dito). Il pulsante sopra la griglia
## cambia l'ordine: come sono stati trovati, per potenza o per valore. Con
## A (o clic) si indossa o toglie l'equipaggiamento, si legge un libro o si
## beve una pozione; B, Esc o di nuovo I chiudono. Mentre è aperto il gioco
## è in pausa.

## Casella del negozio (vedi ShopPanel), con il prezzo sotto l'icona.
const SLOT_SIZE := Vector2(118, 104)
const ICON_SIZE := 46.0
## Griglia dell'inventario: caselle con la sola icona, quante colonne e
## quante righe si vedono prima di dover scorrere.
const COLUMNS := 8
const CELL_SIZE := Vector2(76, 76)
const CELL_ICON_SIZE := 52.0
const CELL_GAP := 8
const VISIBLE_ROWS := 4
## Ordini possibili della griglia, nell'ordine in cui il pulsante li propone.
const SORTS := ["found", "power", "value"]
const COLOR_EQUIPPED := Color(1.0, 0.85, 0.35)
const COLOR_DIM := Color(0, 0, 0, 0.7)
const COLOR_TEXT := Color(1, 1, 1, 0.8)

var player: Player

var _grid := GridContainer.new()
var _scroll := ScrollContainer.new()
var _sort_button := Button.new()
## Ordine scelto: resta lo stesso per tutta la partita.
static var _sort := "found"
## Indice in inventory.items dell'oggetto in ogni casella, nell'ordine mostrato.
var _order: Array[int] = []
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
	var title := _label("INVENTORY_TITLE", 34, Color(1.0, 0.85, 0.4))
	box.add_child(title)
	_gold.add_theme_font_size_override("font_size", 22)
	_gold.add_theme_color_override("font_color", Items.color("gold"))
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_gold)
	box.add_child(_label("INVENTORY_EQUIPPED", 18, COLOR_TEXT))
	_equipped.alignment = BoxContainer.ALIGNMENT_CENTER
	_equipped.add_theme_constant_override("separation", 12)
	box.add_child(_equipped)
	_sort_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sort_button.custom_minimum_size = Vector2(260, 0)
	_sort_button.add_theme_font_size_override("font_size", 17)
	_sort_button.pressed.connect(_on_sort_pressed)
	_sort_button.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
	box.add_child(_sort_button)
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", CELL_GAP)
	_grid.add_theme_constant_override("v_separation", CELL_GAP)
	# La griglia scorre in verticale e segue la casella selezionata.
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.custom_minimum_size = Vector2(COLUMNS * (CELL_SIZE.x + CELL_GAP) + 12, VISIBLE_ROWS * (CELL_SIZE.y + CELL_GAP))
	_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_scroll.add_child(_grid)
	box.add_child(_scroll)
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
	var first: Control = _buttons[0] if not _buttons.is_empty() else _sort_button
	if UiNav.handle(event, get_viewport(), first) and is_inside_tree():
		get_viewport().set_input_as_handled()


## Ricostruisce la griglia e rimette il fuoco sulla casella in quella
## posizione (-1: sul pulsante dell'ordine).
func _rebuild(focus_index: int) -> void:
	var inventory := player.inventory
	_gold.text = tr("INVENTORY_GOLD") % inventory.gold
	_sort_button.text = tr("INVENTORY_SORT") % tr("INVENTORY_SORT_" + _sort.to_upper())
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
	_order = sorted_indices(inventory, _sort)
	for place in _order.size():
		_buttons.append(_slot_button(_order[place], place))
	_empty.visible = _buttons.is_empty()
	_scroll.visible = not _buttons.is_empty()
	if _buttons.is_empty() or focus_index < 0:
		_details.text = ""
		_sort_button.grab_focus.call_deferred()
		return
	var target := _buttons[clampi(focus_index, 0, _buttons.size() - 1)]
	target.grab_focus.call_deferred()


## Indici degli oggetti nell'ordine scelto: come sono stati trovati, oppure
## dal più potente o dal più prezioso (a pari merito, come sono stati trovati).
static func sorted_indices(inventory: Inventory, sort: String) -> Array[int]:
	var order: Array[int] = []
	for i in inventory.items.size():
		order.append(i)
	if sort == "found":
		return order
	var keys := {}
	for i in order:
		var id := inventory.items[i]
		keys[i] = Items.power(id) if sort == "power" else float(Items.value(id))
	order.sort_custom(func(a: int, b: int) -> bool:
		return keys[a] > keys[b] or (keys[a] == keys[b] and a < b))
	return order


func _slot_button(index: int, place: int) -> Button:
	var id := player.inventory.items[index]
	var button := cell_button(id, player.inventory.is_equipped(index))
	button.pressed.connect(_on_slot_pressed.bind(index, place))
	button.focus_entered.connect(_show_details.bind(index))
	button.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
	_grid.add_child(button)
	return button


## Casella della griglia: solo l'icona, bordo dorato se l'oggetto è indossato.
static func cell_button(id: String, highlight: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = CELL_SIZE
	_style_button(button, highlight)
	var icon := ItemIcon.new()
	icon.item_id = id
	icon.custom_minimum_size = Vector2(CELL_ICON_SIZE, CELL_ICON_SIZE)
	# Al centro della casella.
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left = -CELL_ICON_SIZE / 2.0
	icon.offset_top = -CELL_ICON_SIZE / 2.0
	icon.offset_right = CELL_ICON_SIZE / 2.0
	icon.offset_bottom = CELL_ICON_SIZE / 2.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	return button


static func _style_button(button: Button, highlight: bool) -> void:
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


## Casella di un oggetto: icona e didascalia, bordo dorato se evidenziata
## (oggetto indossato). Usata anche dal negozio dei mercanti.
static func item_button(id: String, caption: String, highlight: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = SLOT_SIZE
	_style_button(button, highlight)
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


func _on_slot_pressed(index: int, place: int) -> void:
	player.use_item(index)
	Sfx.play_ui("ui_confirm")
	_rebuild(place)


func _on_sort_pressed() -> void:
	_sort = SORTS[(SORTS.find(_sort) + 1) % SORTS.size()]
	Sfx.play_ui("ui_confirm")
	_rebuild(-1)


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
