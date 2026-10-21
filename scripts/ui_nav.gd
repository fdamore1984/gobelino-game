class_name UiNav
## Navigazione dei menù tollerante: oltre alle azioni ui_* di Godot accetta
## anche i comandi di gioco (WASD, levetta, attacco), e se nessun pulsante
## ha il focus lo riporta sul primo. Serve per esempio sullo Steam Deck in
## modalità desktop, dove Steam può trasformare i comandi del controller in
## tasti diversi da quelli che Godot usa di solito nei menù.


## Da chiamare in _unhandled_input dei menù. Restituisce true se ha gestito
## l'evento. first è il pulsante da selezionare quando non c'è focus.
static func handle(event: InputEvent, viewport: Viewport, first: Control) -> bool:
	if not _is_press(event):
		return false
	var focused := viewport.gui_get_focus_owner()
	if focused == null:
		if _is_any(event, ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "move_up", "move_down", "move_left", "move_right", "attack"]):
			first.grab_focus()
			return true
		return false
	if _is_any(event, ["move_down", "move_right"]):
		_move_focus(focused, SIDE_BOTTOM)
		return true
	if _is_any(event, ["move_up", "move_left"]):
		_move_focus(focused, SIDE_TOP)
		return true
	if _is_any(event, ["attack"]) and focused is BaseButton and not (focused as BaseButton).disabled:
		(focused as BaseButton).pressed.emit()
		return true
	return false


static func _move_focus(from: Control, side: Side) -> void:
	var next: Control = from.find_valid_focus_neighbor(side)
	if next == null:
		next = from.find_next_valid_focus() if side == SIDE_BOTTOM else from.find_prev_valid_focus()
	if next:
		next.grab_focus()


## Solo la pressione vera, non le ripetizioni né il movimento continuo della levetta.
static func _is_press(event: InputEvent) -> bool:
	if event.is_echo() or not event.is_pressed():
		return false
	if event is InputEventJoypadMotion:
		# Le levette mandano molti eventi: conta solo quando superano la soglia.
		for action in ["move_up", "move_down", "move_left", "move_right", "ui_up", "ui_down", "ui_left", "ui_right"]:
			if event.is_action(action) and Input.is_action_just_pressed(action):
				return true
		return false
	return true


static func _is_any(event: InputEvent, actions: Array) -> bool:
	for action: String in actions:
		if event.is_action_pressed(action):
			return true
	return false
