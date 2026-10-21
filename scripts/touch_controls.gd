extends Control
## Controlli a schermo per i dispositivi touch: levetta virtuale nella metà
## sinistra dello schermo e pulsanti azione a destra. Premono le stesse
## azioni dell'Input Map usate da tastiera e gamepad.

const STICK_RADIUS := 90.0
const BUTTON_RADIUS := 52.0
const MENU_BUTTON_RADIUS := 34.0
const COLOR_BASE := Color(1, 1, 1, 0.15)
const COLOR_ACTIVE := Color(1, 1, 1, 0.4)
const FONT_SIZE := 18

const SMALL_BUTTON_RADIUS := 40.0

## Pulsanti: azione, etichetta, posizione rispetto all'angolo in basso a
## destra e raggio.
const BUTTONS := [
	{"action": "attack", "label": "TOUCH_ATTACK", "offset": Vector2(-90, -200), "radius": BUTTON_RADIUS},
	{"action": "heavy_attack", "label": "TOUCH_HEAVY", "offset": Vector2(-210, -250), "radius": BUTTON_RADIUS},
	{"action": "parry", "label": "TOUCH_PARRY", "offset": Vector2(-210, -130), "radius": BUTTON_RADIUS},
	{"action": "dodge", "label": "TOUCH_DODGE", "offset": Vector2(-90, -80), "radius": BUTTON_RADIUS},
	{"action": "potion", "label": "TOUCH_POTION", "offset": Vector2(-330, -60), "radius": SMALL_BUTTON_RADIUS},
	{"action": "shield", "label": "TOUCH_SHIELD", "offset": Vector2(-335, -180), "radius": SMALL_BUTTON_RADIUS},
]

var _stick_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_position := Vector2.ZERO
## Indice del tocco -> azione tenuta premuta.
var _held := {}


func _ready() -> void:
	visible = Platform.use_touch_controls()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _exit_tree() -> void:
	for action: String in _held.values():
		Input.action_release(action)
	_set_stick(Vector2.ZERO)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var action := _action_at(touch.position)
			if action != "":
				_held[touch.index] = action
				Input.action_press(action)
			elif touch.position.x < size.x / 2.0 and _stick_touch == -1:
				_stick_touch = touch.index
				_stick_origin = touch.position
				_stick_position = touch.position
		elif _held.has(touch.index):
			Input.action_release(_held[touch.index])
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


func _set_stick(value: Vector2) -> void:
	_set_axis("move_left", "move_right", value.x)
	_set_axis("move_up", "move_down", value.y)


func _set_axis(negative: String, positive: String, value: float) -> void:
	for pair in [[negative, -value], [positive, value]]:
		if pair[1] > 0.0:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])


func _action_at(point: Vector2) -> String:
	if point.distance_to(_menu_button_center()) <= MENU_BUTTON_RADIUS:
		return "menu"
	for button: Dictionary in BUTTONS:
		if point.distance_to(size + button["offset"]) <= button["radius"]:
			return button["action"]
	return ""


func _menu_button_center() -> Vector2:
	return Vector2(size.x - 60, 60)


func _draw() -> void:
	var font := ThemeDB.fallback_font

	# Levetta: dove si è toccato, oppure un suggerimento in basso a sinistra.
	var origin := _stick_origin if _stick_touch != -1 else Vector2(160, size.y - 160)
	var knob := _stick_position if _stick_touch != -1 else origin
	draw_circle(origin, STICK_RADIUS, COLOR_BASE)
	draw_circle(origin + (knob - origin).limit_length(STICK_RADIUS), 36.0, COLOR_ACTIVE)

	for button: Dictionary in BUTTONS:
		var center: Vector2 = size + button["offset"]
		var pressed := Input.is_action_pressed(button["action"])
		draw_circle(center, button["radius"], COLOR_ACTIVE if pressed else COLOR_BASE)
		_draw_centered_text(font, center, tr(button["label"]))

	draw_circle(_menu_button_center(), MENU_BUTTON_RADIUS, COLOR_BASE)
	_draw_centered_text(font, _menu_button_center(), tr("TOUCH_MENU"))


func _draw_centered_text(font: Font, center: Vector2, text: String) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	draw_string(font, center + Vector2(-text_size.x / 2.0, FONT_SIZE / 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)
