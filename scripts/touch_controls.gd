extends Control
## Controlli a schermo della Modalità Touch (solo versione web, vedi
## Platform.touch_mode): in alto a sinistra, sotto lo stato, Menu,
## Inventario e Mappa; in basso a sinistra la levetta virtuale; in basso a
## destra Attacco (tasto unico, vedi TouchAssist) e Schivata, più i tasti
## speciali colorati Bomba H e Frenesia, che compaiono solo quando si
## possono usare. Salto, pozioni, scudo, torcia, parata e palla di fuoco
## sono automatici (TouchAssist). Menu, Inventario, Mappa e Schivata
## premono le stesse azioni dell'Input Map di tastiera e controller.

const STICK_RADIUS := 90.0
const COLOR_BASE := Color(1, 1, 1, 0.15)
const COLOR_ACTIVE := Color(1, 1, 1, 0.4)
const COLOR_MENU := Color(1, 1, 1, 0.28)
const FONT_SIZE := 18
const TOP_RADIUS := 32.0
## Altezza dei tasti in alto, sotto il riquadro dello stato (HudStatus).
const TOP_Y := 210.0

## Tasti in alto a sinistra: azione e etichetta.
const TOP_BUTTONS := [
	{"action": "menu", "label": "TOUCH_MENU"},
	{"action": "inventory", "label": "TOUCH_INVENTORY"},
	{"action": "map", "label": "TOUCH_MAP"},
]
## Tasti in basso a destra: azione (o tasto speciale con "special"),
## etichetta, posizione rispetto all'angolo in basso a destra, raggio e,
## per gli speciali, colore.
const BUTTONS := [
	{"special": "attack", "label": "TOUCH_ATTACK", "offset": Vector2(-120, -140), "radius": 70.0},
	{"action": "dodge", "label": "TOUCH_DODGE", "offset": Vector2(-270, -80), "radius": 50.0},
	{"special": "h_bomb", "label": "TOUCH_H_BOMB", "offset": Vector2(-280, -220), "radius": 46.0, "color": Color(1.0, 0.55, 0.15, 0.55)},
	{"special": "frenzy", "label": "TOUCH_FRENZY", "offset": Vector2(-120, -300), "radius": 46.0, "color": Color(1.0, 0.18, 0.12, 0.6)},
	# Interagisci: solo vicino a qualcosa con cui interagire (vedi Player.can_interact).
	{"action": "interact", "label": "INTERACT", "offset": Vector2(-420, -100), "radius": 54.0, "color": Color(0.25, 0.75, 0.35, 0.6)},
]

var _stick_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_position := Vector2.ZERO
## Indice del tocco -> tasto tenuto premuto (azione o "special:nome").
var _held := {}


func _ready() -> void:
	visible = Platform.use_touch_controls()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(visible)
	set_process_input(visible)


func _process(_delta: float) -> void:
	# I tasti speciali compaiono e spariscono secondo il giocatore.
	queue_redraw()


func _exit_tree() -> void:
	for key: String in _held.values():
		_release(key)
	_held.clear()
	_set_stick(Vector2.ZERO)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var key := _key_at(touch.position)
			if key != "":
				_held[touch.index] = key
				_press(key)
			elif touch.position.x < size.x / 2.0 and _stick_touch == -1:
				_stick_touch = touch.index
				_stick_origin = touch.position
				_stick_position = touch.position
		elif _held.has(touch.index):
			_release(_held[touch.index])
			_held.erase(touch.index)
		elif touch.index == _stick_touch:
			_stick_touch = -1
			_set_stick(Vector2.ZERO)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_touch:
			_stick_position = drag.position
			_set_stick(((_stick_position - _stick_origin) / STICK_RADIUS).limit_length(1.0))
			queue_redraw()


func _press(key: String) -> void:
	if key.begins_with("special:"):
		Platform.set("touch_" + key.trim_prefix("special:"), true)
		return
	Input.action_press(key)
	if key in ["inventory", "map"]:
		# Inventario e mappa si aprono e si chiudono con un evento, come da tastiera.
		var open_event := InputEventAction.new()
		open_event.action = key
		open_event.pressed = true
		Input.parse_input_event(open_event)


func _release(key: String) -> void:
	if key.begins_with("special:"):
		Platform.set("touch_" + key.trim_prefix("special:"), false)
	else:
		Input.action_release(key)


func _set_stick(value: Vector2) -> void:
	_set_axis("move_left", "move_right", value.x)
	_set_axis("move_up", "move_down", value.y)


func _set_axis(negative: String, positive: String, value: float) -> void:
	for pair in [[negative, -value], [positive, value]]:
		if pair[1] > 0.0:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])


func _key_at(point: Vector2) -> String:
	for k in TOP_BUTTONS.size():
		if point.distance_to(_top_center(k)) <= TOP_RADIUS:
			return TOP_BUTTONS[k]["action"]
	for button: Dictionary in BUTTONS:
		if _shown(button) and point.distance_to(size + button["offset"]) <= button["radius"]:
			return button["action"] if button.has("action") else "special:" + button["special"]
	return ""


func _top_center(index: int) -> Vector2:
	return Vector2(16 + TOP_RADIUS + index * (TOP_RADIUS * 2 + 12), TOP_Y)


## Bomba H e Frenesia solo quando si possono usare (vedi TouchAssist).
func _shown(button: Dictionary) -> bool:
	var special: String = button.get("special", "")
	if special == "h_bomb" or special == "frenzy":
		return TouchAssist.special_ready(special)
	if button.get("action", "") == "interact":
		return TouchAssist.special_ready("interact")
	return true


func _is_down(button: Dictionary) -> bool:
	if button.has("action"):
		return Input.is_action_pressed(button["action"])
	return bool(Platform.get("touch_" + button["special"]))


func _draw() -> void:
	var font := ThemeDB.fallback_font

	# Levetta: dove si è toccato, oppure un suggerimento in basso a sinistra.
	var origin := _stick_origin if _stick_touch != -1 else Vector2(160, size.y - 160)
	var knob := _stick_position if _stick_touch != -1 else origin
	draw_circle(origin, STICK_RADIUS, COLOR_BASE)
	draw_circle(origin + (knob - origin).limit_length(STICK_RADIUS), 36.0, COLOR_ACTIVE)

	for button: Dictionary in BUTTONS:
		if not _shown(button):
			continue
		var center: Vector2 = size + button["offset"]
		var color: Color = button.get("color", COLOR_BASE)
		if _is_down(button):
			color = COLOR_ACTIVE if not button.has("color") else color.lightened(0.3)
		draw_circle(center, button["radius"], color)
		_draw_centered_text(font, center, tr(button["label"]))

	for k in TOP_BUTTONS.size():
		var top: Dictionary = TOP_BUTTONS[k]
		draw_circle(_top_center(k), TOP_RADIUS, COLOR_ACTIVE if Input.is_action_pressed(top["action"]) else COLOR_MENU)
		_draw_centered_text(font, _top_center(k), tr(top["label"]))


func _draw_centered_text(font: Font, center: Vector2, text: String) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	draw_string(font, center + Vector2(-text_size.x / 2.0, FONT_SIZE / 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)
