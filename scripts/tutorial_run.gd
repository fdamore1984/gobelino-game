class_name TutorialRun
extends Node
## Tutorial giocabile (dal tutorial del menù iniziale, vedi TutorialPanel):
## una partita a parte, senza salvataggi (Game.tutorial_mode), che spiega
## le meccaniche una alla volta. I passi stanno in data/tutorial.json, con
## due percorsi: controller o tastiera e mouse ("desktop") e Modalità Touch
## del browser ("touch", vedi Platform.touch_mode). In alto al centro un
## riquadro dice cosa fare (i tasti tra graffe si leggono dall'Input Map,
## come nel tutorial a pagine) e il passo si chiude da solo quando il
## giocatore ci riesce (vedi Player.action_done), abbatte i nemici del
## passo o cammina abbastanza; i passi di sola spiegazione si chiudono con
## Avanti ({interact}). Salta passa al passo dopo. In tutorial il goblin
## non muore (Player.immortal), è sempre giorno, non arrivano altri nemici né
## orde e i nemici non danno esperienza né bottino. Alla fine si torna al
## menù.

## Si torna al menù da sé finito l'ultimo passo, dopo questi secondi.
const END_DELAY := 1.5
## Il passo appena superato resta segnato per questi secondi.
const DONE_TIME := 0.9
## Nemici del passo di nuovo, se muoiono tutti prima che ci si riesca.
const RESPAWN_DELAY := 1.5
## Distanza dal giocatore delle pozioni di un passo (vedi _prepare).
const SUPPLY_DISTANCE := 260.0
## Ora del giorno fissa (vedi DayNight.time).
const DAY_TIME := 0.3
## Il riquadro sta in alto, tra lo stato (a sinistra, fino a PANEL_LEFT) e
## l'orologio, centrato quando lo schermo è abbastanza largo.
const PANEL_WIDTH := 520.0
const PANEL_LEFT := 404.0
const COLOR_TITLE := Color(1.0, 0.55, 0.74)
const COLOR_TEXT := UiStyle.CREAM
const COLOR_PROGRESS := Color(0.75, 0.9, 1.0)
const COLOR_DONE := Color(0.5, 1.0, 0.55)
const DATA := preload("res://data/tutorial.json")

## Il tutorial è finito: Game torna al menù.
signal finished

var game: Game
var player: Player
var day_night: DayNight

var _steps: Array = []
var _index := -1
var _count := 0
var _walked := 0.0
var _last_position := Vector2.ZERO
var _enemies: Array = []
## Se i nemici del passo muoiono prima che il giocatore ci riesca (per
## esempio quelli da agganciare), ne arrivano altri dopo questi secondi.
var _respawn_time := 0.0
## Secondi in cui si mostra il passo appena superato (0: nessuno).
var _done_time := 0.0
var _panel := PanelContainer.new()
var _title := Label.new()
var _text := Label.new()
var _progress := Label.new()
var _next := Button.new()
var _skip := Button.new()
var _key_pattern := RegEx.create_from_string("\\{(\\w+)\\}")


func _ready() -> void:
	_steps = DATA.data["touch" if Platform.touch_mode else "desktop"]
	player.immortal = true
	player.action_done.connect(_on_action_done)
	_build_panel()
	_start_step(0)


## Il riquadro va nell'HUD, sotto il menù di pausa e gli altri pannelli.
func panel() -> Control:
	return _panel


func _build_panel() -> void:
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := UiStyle.box(Color(UiStyle.PANEL, 0.92), 16, 3, 5.0, UiStyle.INK)
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	for pair: Array in [[_title, 22, COLOR_TITLE], [_text, 19, COLOR_TEXT], [_progress, 17, COLOR_PROGRESS]]:
		var label: Label = pair[0]
		label.add_theme_font_size_override("font_size", pair[1])
		label.add_theme_color_override("font_color", pair[2])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(PANEL_WIDTH - 28.0, 0)
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		box.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for pair: Array in [[_skip, "TUTORIAL_PLAY_SKIP"], [_next, "TUTORIAL_PLAY_NEXT"]]:
		var button: Button = pair[0]
		button.text = pair[1]
		# Niente focus: A e Invio restano al gioco (salto, interazione).
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(150, 44)
		button.add_theme_font_size_override("font_size", 20)
		row.add_child(button)
	_next.pressed.connect(_advance)
	_skip.pressed.connect(_advance)


func _process(delta: float) -> void:
	_panel.position = Vector2(maxf((_panel.get_viewport_rect().size.x - _panel.size.x) / 2.0, PANEL_LEFT), 12.0)
	if day_night:
		day_night.time = DAY_TIME
	if _done_time > 0.0:
		_done_time -= delta
		if _done_time <= 0.0:
			_start_step(_index + 1)
		return
	if _index < 0 or _index >= _steps.size():
		return
	var step: Dictionary = _steps[_index]
	match step["goal"]:
		"move":
			_walked += player.position.distance_to(_last_position)
			_last_position = player.position
			_count = int(_walked)
			if _walked >= float(step.get("amount", 1)):
				_complete()
		"kill":
			_count = _enemies.size() - _alive()
			if _count >= _enemies.size():
				_complete()
		"info":
			if UiNav.game_pressed("interact"):
				_advance()
		_:
			_respawn_if_needed(step, delta)
	_update_progress()


func _on_action_done(kind: String) -> void:
	if _done_time > 0.0 or _index < 0 or _index >= _steps.size():
		return
	var step: Dictionary = _steps[_index]
	if kind != step["goal"]:
		return
	_count += 1
	if _count >= int(step.get("amount", 1)):
		_complete()


func _complete() -> void:
	Sfx.play_ui("ui_confirm")
	_done_time = DONE_TIME
	_progress.text = tr("TUTORIAL_PLAY_DONE_STEP")
	_progress.add_theme_color_override("font_color", COLOR_DONE)


## Avanti (passi di spiegazione) o Salta: subito al passo dopo.
func _advance() -> void:
	if _done_time > 0.0:
		return
	Sfx.play_ui("ui_move")
	_start_step(_index + 1)


func _start_step(index: int) -> void:
	_done_time = 0.0
	_index = index
	if _index >= _steps.size():
		_panel.visible = false
		get_tree().create_timer(END_DELAY).timeout.connect(finished.emit)
		return
	var step: Dictionary = _steps[_index]
	_count = 0
	_walked = 0.0
	_last_position = player.position
	_prepare(step.get("setup", {}))
	_enemies.clear()
	_spawn(step.get("spawn", {}))
	var last := _index == _steps.size() - 1
	_title.text = tr("TUTORIAL_PLAY_TITLE") % [_index + 1, _steps.size()]
	_text.text = _with_keys(tr(step["text"]))
	_next.visible = step["goal"] == "info"
	_next.text = "TUTORIAL_PLAY_END" if last else "TUTORIAL_PLAY_NEXT"
	_skip.visible = step["goal"] != "info"
	_progress.remove_theme_color_override("font_color")
	_progress.add_theme_color_override("font_color", COLOR_PROGRESS)
	_update_progress()


## Nemici del passo, in cerchio attorno al giocatore.
func _spawn(spawn: Dictionary) -> void:
	_respawn_time = RESPAWN_DELAY
	for i in int(spawn.get("count", 0)):
		var angle := TAU * i / float(spawn["count"]) + randf_range(-0.3, 0.3)
		var enemy := game.spawn_tutorial_enemy(spawn["type"], player.position + Vector2.from_angle(angle) * float(spawn["distance"]))
		_enemies.append(enemy)


## Servono nemici per riuscirci (palla di fuoco, runa, aggancio, Frenesia) ma
## sono già tutti a terra: ne arrivano altri.
func _respawn_if_needed(step: Dictionary, delta: float) -> void:
	if not step.has("spawn") or _alive() > 0:
		return
	_respawn_time -= delta
	if _respawn_time <= 0.0:
		_enemies.clear()
		_spawn(step["spawn"])


## Nemici del passo ancora vivi (quelli abbattuti spariscono dopo un po').
func _alive() -> int:
	var alive := 0
	for enemy: Variant in _enemies:
		if is_instance_valid(enemy) and not (enemy as Enemy).is_dead():
			alive += 1
	return alive


## Risorse del passo: mana e vigore pieni, rune del cataclisma (id
## "h_bomb"), Frenesia piena, un po' di vita tolta e pozioni a terra da
## raccogliere ("supplies": id delle pozioni, che saltano fuori a
## SUPPLY_DISTANCE pixel dal giocatore).
func _prepare(setup: Dictionary) -> void:
	if setup.get("mana", false):
		player.mana = player.max_mana
	if setup.get("stamina", false):
		player.stamina = player.max_stamina
	if setup.has("h_bombs"):
		player.h_bombs = maxi(player.h_bombs, int(setup["h_bombs"]))
	if setup.has("hurt"):
		player.health = maxi(mini(player.health, player.max_health - int(setup["hurt"])), 1)
		player.health_changed.emit(player.health, player.max_health)
	var supplies: Array = setup.get("supplies", [])
	for k in supplies.size():
		var angle := TAU * k / float(supplies.size()) + randf_range(-0.4, 0.4)
		game.spawn_tutorial_supply(supplies[k], player.position + Vector2.from_angle(angle) * SUPPLY_DISTANCE)
	# La Frenesia resta piena per tutto il passo (da sola calerebbe).
	player.keep_frenzy = setup.get("frenzy", false)
	if player.keep_frenzy:
		player.frenzy = Player.FRENZY_MAX
		player.frenzy_changed.emit(player.frenzy, Player.FRENZY_MAX)


func _update_progress() -> void:
	if _done_time > 0.0 or _index < 0 or _index >= _steps.size():
		return
	var step: Dictionary = _steps[_index]
	var text := ""
	match step["goal"]:
		"info":
			text = "" if Platform.touch_mode else _with_keys(tr("TUTORIAL_PLAY_CONTINUE"))
		"move":
			text = "%d%%" % mini(roundi(100.0 * _walked / float(step.get("amount", 1))), 100)
		"kill":
			text = tr("TUTORIAL_PLAY_KILLS") % [_count, _enemies.size()]
		_:
			var amount := int(step.get("amount", 1))
			text = "%d / %d" % [_count, amount] if amount > 1 else ""
	_progress.text = text
	_progress.visible = text != ""


## Sostituisce {azione} con i tasti legati all'azione (vedi Keybinds.hint).
func _with_keys(text: String) -> String:
	var result := text
	for found in _key_pattern.search_all(text):
		result = result.replace(found.get_string(), Keybinds.hint(found.get_string(1)))
	return result
