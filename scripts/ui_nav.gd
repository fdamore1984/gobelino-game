class_name UiNav
## Navigazione dei menù tollerante: oltre alle azioni ui_* di Godot accetta
## croce del controller e frecce della tastiera lette direttamente, i
## comandi di gioco (WASD, levetta) e l'attacco per confermare; se nessun
## pulsante ha il focus lo riporta sul primo. Serve per esempio sullo Steam
## Deck, dove Steam può trasformare i comandi del controller in tasti
## diversi da quelli che Godot usa di solito nei menù.
##
## Lo stesso tasto serve sia nei menù sia in gioco (A conferma, salta e
## interagisce; B chiude e schiva): il tasto che chiude un menù o preme un
## pulsante viene "consumato" (consume) e in gioco non conta finché non lo si
## rilascia. Il gioco legge i tasti con game_pressed e game_held invece che
## direttamente da Input: così chiudendo la pausa con A non si salta né si
## apre la cassa lì vicino.

const _UP := ["ui_up", "move_up"]
const _DOWN := ["ui_down", "move_down"]
const _LEFT := ["ui_left", "move_left"]
const _RIGHT := ["ui_right", "move_right"]

## Azioni consumate da un menù (azione -> true): in gioco si ignorano finché
## restano premute; e frame in cui è successo l'ultima volta.
static var _consumed := {}
static var _consumed_frame := -10


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
		# Il tasto di conferma non deve arrivare anche al gioco (per esempio
		# premendo Riprendi: si tornerebbe in gioco saltando).
		consume(event)
		# ui_accept (A, Invio) lo gestisce già il pulsante da solo, al
		# rilascio: premerlo anche qui farebbe due pressioni con un tocco solo
		# (per esempio la conferma per sostituire uno slot salvato).
		if not event.is_action_pressed("ui_accept"):
			(focused as BaseButton).pressed.emit()
		return true
	return false


## Il tasto dell'evento è stato usato da un menù: tutte le azioni legate a
## quel tasto (per A: ui_accept, jump, interact) in gioco non contano
## finché non lo si rilascia.
static func consume(event: InputEvent) -> void:
	for action: StringName in InputMap.get_actions():
		if event.is_action(action, true):
			_consumed[action] = true
	_consumed_frame = Engine.get_process_frames()


## L'azione è appena stata premuta in gioco (non consumata da un menù).
static func game_pressed(action: StringName) -> bool:
	return Input.is_action_just_pressed(action) and not _is_consumed(action)


## L'azione è tenuta premuta in gioco (non consumata da un menù).
static func game_held(action: StringName) -> bool:
	return Input.is_action_pressed(action) and not _is_consumed(action)


## Combinazione di due azioni (per esempio L1 + R1 per l'attacco speciale):
## tutte e due tenute premute e almeno una appena premuta, in qualsiasi
## ordine; i tasti consumati da un menù non contano.
static func game_chord(first: StringName, second: StringName) -> bool:
	return game_held(first) and game_held(second) and (game_pressed(first) or game_pressed(second))


## Da un menù si è appena tornati in gioco (questo frame o il precedente):
## i tocchi sullo schermo che hanno chiuso il menù non devono contare.
static func just_consumed() -> bool:
	return Engine.get_process_frames() - _consumed_frame <= 1


## Da chiamare a ogni frame mentre si gioca (vedi Game): le azioni
## consumate tornano valide appena il tasto è rilasciato, così la pressione
## successiva conta di nuovo.
static func update() -> void:
	for action: StringName in _consumed.keys():
		if not Input.is_action_pressed(action) and not Input.is_action_just_pressed(action):
			_consumed.erase(action)


static func _is_consumed(action: StringName) -> bool:
	return _consumed.has(action)


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
