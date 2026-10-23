class_name ShopPanel
extends Control
## Negozio di un mercante (si apre toccando il suo banco). In alto ciò che
## vende: oggetti rari che nelle casse non si trovano (finiscono quando li
## si compra) e pozioni sempre disponibili. Sotto gli oggetti
## dell'inventario non indossati, da vendere a una parte del loro prezzo
## (data/world.json, "merchant"). A (o clic) compra o vende; B, Esc o I
## chiudono. Mentre è aperto il gioco è in pausa.

const COLUMNS := 8
## Righe di oggetti da vendere visibili; le altre si scorrono.
const SELL_ROWS := 2
const COLOR_TITLE := Color(1.0, 0.85, 0.4)
const COLOR_TEXT := Color(1, 1, 1, 0.8)
const COLOR_DIM := Color(0, 0, 0, 0.75)
## Gli oggetti che non ci si può permettere sono più spenti.
const COLOR_TOO_EXPENSIVE := Color(1, 1, 1, 0.45)

var player: Player

var _data: Dictionary = World.DATA.data["merchant"]
var _merchant := Vector2.INF
var _gold := Label.new()
var _buy_grid := GridContainer.new()
var _sell_grid := GridContainer.new()
var _sell_scroll := ScrollContainer.new()
var _nothing := Label.new()
var _details := Label.new()
var _close := Button.new()
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
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	box.add_child(_label("MERCHANT_TITLE", 36, COLOR_TITLE))
	_gold.add_theme_font_size_override("font_size", 22)
	_gold.add_theme_color_override("font_color", Items.color("gold"))
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_gold)
	box.add_child(_label("SHOP_BUY", 18, COLOR_TEXT))
	for grid in [_buy_grid, _sell_grid]:
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
	_buy_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_buy_grid)
	box.add_child(_label("SHOP_SELL", 18, COLOR_TEXT))
	var slot := InventoryPanel.SLOT_SIZE + Vector2(8, 8)
	_sell_scroll.custom_minimum_size = Vector2(slot.x * COLUMNS, slot.y * SELL_ROWS)
	_sell_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sell_scroll.follow_focus = true
	_sell_scroll.add_child(_sell_grid)
	box.add_child(_sell_scroll)
	_nothing.text = "SHOP_NOTHING_TO_SELL"
	_nothing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nothing.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_nothing.custom_minimum_size = _sell_scroll.custom_minimum_size
	_nothing.add_theme_color_override("font_color", COLOR_TEXT)
	box.add_child(_nothing)
	_details.custom_minimum_size = Vector2(760, 52)
	_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_font_size_override("font_size", 19)
	box.add_child(_details)
	box.add_child(_label("SHOP_HINT", 16, Color(1, 1, 1, 0.55)))
	# Per chi gioca col touch o col mouse.
	_close.text = "SHOP_CLOSE"
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close.custom_minimum_size = Vector2(180, 40)
	_close.pressed.connect(close)
	box.add_child(_close)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func is_open() -> bool:
	return visible


func open(merchant: Vector2) -> void:
	_merchant = merchant
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
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu") \
			or ((event is InputEventKey or event is InputEventAction) and event.is_action_pressed("inventory")):
		close()
		get_viewport().set_input_as_handled()
		return
	var first: Control = _buttons[0] if not _buttons.is_empty() else _close
	if UiNav.handle(event, get_viewport(), first) and is_inside_tree():
		get_viewport().set_input_as_handled()


## Prezzo a cui il mercante compra l'oggetto.
func sell_price(id: String) -> int:
	return maxi(1, floori(Items.value(id) * float(_data["sell_ratio"])))


## Oggetti in vendita: i rari rimasti e le pozioni.
func _for_sale() -> Array[String]:
	var result: Array[String] = []
	result.append_array(World.current.merchant_stock(_merchant))
	for id: String in _data["potions"]:
		result.append(id)
	return result


## Ricostruisce le griglie e rimette il fuoco sulla casella all'indice dato.
func _rebuild(focus_index: int) -> void:
	var inventory := player.inventory
	_gold.text = tr("INVENTORY_GOLD") % inventory.gold
	for child in _buy_grid.get_children() + _sell_grid.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	_buttons.clear()
	for id in _for_sale():
		var price := Items.value(id)
		var button := InventoryPanel.item_button(id, tr("SHOP_PRICE") % price, Items.get_item(id).get("shop_only", false))
		if price > inventory.gold:
			button.modulate = COLOR_TOO_EXPENSIVE
		button.pressed.connect(_buy.bind(id, _buttons.size()))
		button.focus_entered.connect(_show_buy.bind(id))
		_add(button, _buy_grid)
	for i in inventory.items.size():
		if inventory.is_equipped(i):
			continue
		var id := inventory.items[i]
		var button := InventoryPanel.item_button(id, tr("SHOP_PRICE") % sell_price(id), false)
		button.pressed.connect(_sell.bind(i, _buttons.size()))
		button.focus_entered.connect(_show_sell.bind(id))
		_add(button, _sell_grid)
	var can_sell := _sell_grid.get_child_count() > 0
	_sell_scroll.visible = can_sell
	_nothing.visible = not can_sell
	_focus.call_deferred(_buttons[clampi(focus_index, 0, _buttons.size() - 1)])


## Il fuoco arriva dopo che le griglie si sono sistemate; nel frattempo la
## casella potrebbe essere già stata sostituita.
func _focus(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree():
		button.grab_focus()


func _add(button: Button, grid: GridContainer) -> void:
	button.focus_entered.connect(Sfx.play_ui.bind("ui_move"))
	grid.add_child(button)
	_buttons.append(button)


func _buy(id: String, button_index: int) -> void:
	var price := Items.value(id)
	if price > player.inventory.gold:
		Sfx.play_ui("block")
		_details.text = "%s\n%s" % [InventoryPanel.describe(id), tr("SHOP_NOT_ENOUGH")]
		return
	player.inventory.gold -= price
	World.current.merchant_stock(_merchant).erase(id)
	player.pickup(id)
	Sfx.play_ui("coin")
	_rebuild(button_index)


func _sell(index: int, button_index: int) -> void:
	var id := player.inventory.items[index]
	player.inventory.remove(index)
	player.inventory.gold += sell_price(id)
	Sfx.play_ui("coin")
	_rebuild(button_index)


func _show_buy(id: String) -> void:
	var action := tr("SHOP_BUY_ACTION") % Items.value(id)
	if Items.value(id) > player.inventory.gold:
		action = tr("SHOP_NOT_ENOUGH")
	_details.text = "%s\n%s" % [InventoryPanel.describe(id), action]


func _show_sell(id: String) -> void:
	_details.text = "%s\n%s" % [InventoryPanel.describe(id), tr("SHOP_SELL_ACTION") % sell_price(id)]
