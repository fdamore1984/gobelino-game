class_name UiNav
## Navigazione dei menù tollerante: oltre alle azioni ui_* di Godot accetta
## croce del controller e frecce della tastiera lette direttamente, i
## comandi di gioco (WASD, levetta) e l'attacco per confermare; se nessun
## pulsante ha il focus lo riporta sul primo. Serve per esempio sullo Steam
## Deck, dove Steam può trasformare i comandi del controller in tasti
## diversi da quelli che Godot usa di solito nei menù.

const _UP := ["ui_up", "move_up"]
const _DOWN := ["ui_down", "move_down"]
const _LEFT := ["ui_left", "move_left"]
const _RIGHT := ["ui_right", "move_right"]


## Da chiamare in _unhandled_input dei menù. Restituisce true se ha gestito
## l'evento. first è il pulsante da selezionare quando non c'è focus.
static func handle(event: InputEvent, viewport: Viewport, first: Control) -> bool:
	if not _is_press(event):
		return false
	var side := _direction(event)
	var confirm := _is_any(event, ["ui_accept", "attack"])
	if side == -1 and not confirm:
		return false
	var focused := viewport.gui_get_focus_owner()
	if focused == null:
		first.grab_focus()
		return true
	if side != -1:
		_move_focus(focused, side)
		return true
	if focused is BaseButton and not (focused as BaseButton).disabled:
		(focused as BaseButton).pressed.emit()
		return true
	return false


## Direzione richiesta dall'evento (SIDE_*), oppure -1.
static func _direction(event: InputEvent) -> int:
	if event is InputEventJoypadButton:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_UP: return SIDE_TOP
			JOY_BUTTON_DPAD_DOWN: return SIDE_BOTTOM
			JOY_BUTTON_DPAD_LEFT: return SIDE_LEFT
			JOY_BUTTON_DPAD_RIGHT: return SIDE_RIGHT
	if event is InputEventKey:
		match (event as InputEventKey).keycode:
			KEY_UP: return SIDE_TOP
			KEY_DOWN: return SIDE_BOTTOM
			KEY_LEFT: return SIDE_LEFT
			KEY_RIGHT: return SIDE_RIGHT
	if _is_any(event, _UP):
		return SIDE_TOP
	if _is_any(event, _DOWN):
		return SIDE_BOTTOM
	if _is_any(event, _LEFT):
		return SIDE_LEFT
	if _is_any(event, _RIGHT):
		return SIDE_RIGHT
	return -1


static func _move_focus(from: Control, side: int) -> void:
	var next: Control = from.find_valid_focus_neighbor(side as Side)
	if next == null:
		var forward := side == SIDE_BOTTOM or side == SIDE_RIGHT
		next = from.find_next_valid_focus() if forward else from.find_prev_valid_focus()
	if next:
		next.grab_focus()


## Solo la pressione vera, non le ripetizioni né il movimento continuo della levetta.
static func _is_press(event: InputEvent) -> bool:
	if event.is_echo() or not event.is_pressed():
		return false
	if event is InputEventJoypadMotion:
		# Le levette mandano molti eventi: conta solo quando superano la soglia.
		for action in _UP + _DOWN + _LEFT + _RIGHT:
			if event.is_action(action) and Input.is_action_just_pressed(action):
				return true
		return false
	return true


static func _is_any(event: InputEvent, actions: Array) -> bool:
	for action: String in actions:
		if event.is_action_pressed(action):
			return true
	return false
