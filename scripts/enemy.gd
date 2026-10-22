class_name Enemy
extends Node2D
## Nemico di test, disegnato con forme geometriche. Le caratteristiche
## dipendono dal tipo, definito in data/enemies.json (vedi EnemyTypes).
##
## Vaga finché il giocatore non si avvicina, poi gli gira attorno con
## spostamenti laterali e scatti rapidi, finché non decide di attaccare.
## L'attacco è lento e annunciato: durante la carica a terra compare la
## zona colpita, poi il nemico scatta in avanti. Per essere meno
## prevedibile la carica ha durata variabile, a volte è una finta e a
## volte segue subito un secondo attacco più rapido.
## Gli evocatori restano a distanza ed evocano altri nemici: colpirli
## mentre evocano interrompe l'evocazione.

signal died(enemy: Enemy)
## Chiede alla scena di gioco di creare i nemici evocati.
signal summon_requested(summoner: Enemy, type_id: String, positions: Array[Vector2])

enum State { WANDER, CHASE, DASH, WINDUP, STRIKE, RECOVER, STUNNED, SUMMON, DEAD }

const ACCELERATION := 900.0
const LEASH_RANGE := 700.0
const SEPARATION_RANGE := 60.0
const KNOCKBACK := 260.0
const HEAVY_KNOCKBACK_FACTOR := 1.6

## Ogni tanto cambia verso di rotazione o fa uno scatto laterale.
const DECISION_INTERVAL := Vector2(0.5, 1.6)
const DASH_CHANCE := 0.4
const DASH_SPEED_FACTOR := 3.8
const DASH_TIME := 0.18

## Distanza dal bordo del giocatore a cui il nemico inizia a caricare l'attacco.
const ATTACK_TRIGGER_GAP := 64.0
## Per una parte della carica (variabile) il nemico segue il giocatore,
## poi la direzione resta bloccata: è il momento di schivare.
const WINDUP_TRACKING := Vector2(0.4, 0.75)
## Probabilità che la carica sia una finta, interrotta a metà con uno scatto.
const FEINT_CHANCE := 0.2
## Probabilità di un secondo attacco subito dopo il primo, con carica più breve.
const COMBO_CHANCE := 0.3
const COMBO_WINDUP_FACTOR := 0.6
const STRIKE_TIME := 0.16
const RECOVER_TIME := 0.9
## Dopo un attacco aspetta un tempo a caso prima di riprovare.
const ATTACK_COOLDOWN := Vector2(0.6, 2.0)
const STUN_TIME := 1.6
const DEATH_FADE_TIME := 0.4
## I nemici evocati compaiono a questa distanza dall'evocatore.
const SUMMON_DISTANCE := 70.0

const COLOR_WINDUP := Color(1.0, 0.45, 0.2)
const COLOR_STUNNED := Color(0.55, 0.55, 0.8)
const COLOR_DANGER := Color(1.0, 0.25, 0.15)
const COLOR_SUMMON := Color(0.4, 1.0, 0.9)
const COLOR_DAMAGE := Color(1.0, 1.0, 1.0)

var player: Player
var type_id := "warrior"
var radius := 24.0
var health := 40
var max_health := 40
## Esperienza data al giocatore quando viene sconfitto.
var xp_reward := 30

var _type: Dictionary
var _color := Color.WHITE
var _speed := 125.0
var _state := State.WANDER
var _state_time := 0.0
var _velocity := Vector2.ZERO
var _facing := Vector2.RIGHT
var _wander_direction := Vector2.ZERO
var _wander_time := 0.0
var _decision_time := 0.0
var _orbit_sign := 1.0
var _dash_direction := Vector2.ZERO
var _attack_direction := Vector2.RIGHT
var _attack_cooldown := 0.0
var _windup_time := 1.0
var _windup_tracking := 0.6
var _feint_at := -1.0
var _is_combo := false
var _strike_resolved := false
var _knockback := Vector2.ZERO
var _hit_flash := 0.0
var _summon_cooldown := 0.0
var _summon_positions: Array[Vector2] = []
var _minions: Array[Enemy] = []
## La zona di pericolo va disegnata sotto i personaggi, non sopra.
var _telegraph := Node2D.new()


## Imposta il tipo prima di aggiungere il nemico alla scena.
func setup(id: String) -> void:
	type_id = id
	_type = EnemyTypes.get_type(id)
	radius = _type["radius"]
	max_health = _type["health"]
	health = max_health
	xp_reward = _type["xp"]
	_speed = _type["speed"]
	var color: Array = _type["color"]
	_color = Color(color[0], color[1], color[2])
	if _type.has("summon"):
		_summon_cooldown = randf_range(1.0, 2.5)


func _ready() -> void:
	if _type.is_empty():
		setup(type_id)
	add_to_group("enemies")
	_facing = Vector2.from_angle(randf() * TAU)
	_orbit_sign = [-1.0, 1.0].pick_random()
	_telegraph.z_index = -5
	_telegraph.draw.connect(_draw_telegraph)
	add_child(_telegraph)


func _physics_process(delta: float) -> void:
	_state_time += delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_summon_cooldown = maxf(_summon_cooldown - delta, 0.0)
	_hit_flash = maxf(_hit_flash - delta, 0.0)

	var target_velocity := Vector2.ZERO
	var to_player := player.global_position - global_position if player else Vector2.INF
	var distance := to_player.length()
	var player_active := player != null and not player.is_dead()

	match _state:
		State.WANDER:
			_wander_time -= delta
			if _wander_time <= 0.0:
				_wander_time = randf_range(1.5, 3.5)
				# A volte resta fermo, a volte cammina in una direzione a caso.
				_wander_direction = Vector2.ZERO if randf() < 0.3 else Vector2.from_angle(randf() * TAU)
			target_velocity = _wander_direction * _speed * 0.4
			if player_active and distance <= _type["aggro_range"]:
				_change_state(State.CHASE)

		State.CHASE:
			if not player_active or distance > LEASH_RANGE:
				_change_state(State.WANDER)
			elif _can_summon(distance):
				_begin_summon()
			elif _attack_cooldown == 0.0 and distance <= _attack_trigger_range():
				_begin_windup(_type["windup"][0], _type["windup"][1], true)
			else:
				_decision_time -= delta
				if _decision_time <= 0.0:
					_decision_time = randf_range(DECISION_INTERVAL.x, DECISION_INTERVAL.y)
					if randf() < 0.5:
						_orbit_sign = -_orbit_sign
					if distance < _orbit_distance() * 1.8 and randf() < DASH_CHANCE:
						_start_dash(to_player)
				if _state == State.CHASE:
					target_velocity = _chase_direction(to_player) * _speed

		State.DASH:
			_velocity = _dash_direction * _speed * DASH_SPEED_FACTOR
			target_velocity = _velocity
			if _state_time >= DASH_TIME:
				_change_state(State.CHASE)

		State.WINDUP:
			if player_active and _state_time <= _windup_time * _windup_tracking:
				_attack_direction = to_player.normalized()
			if _feint_at >= 0.0 and _state_time >= _feint_at:
				_attack_cooldown = randf_range(0.3, 0.8)
				_start_dash(to_player)
			elif _state_time >= _windup_time:
				_strike_resolved = false
				Sfx.play("enemy_strike", global_position, 1.0 / sqrt(_type["mass"]))
				_change_state(State.STRIKE)

		State.STRIKE:
			_velocity = _attack_direction * float(_type["lunge_speed"])
			target_velocity = _velocity
			if not _strike_resolved and player_active and _player_in_strike_zone():
				_strike_resolved = true
				if player.receive_hit(global_position, _type["damage"]) == "parried":
					_is_combo = false
					Sfx.play("stun", global_position)
					_change_state(State.STUNNED)
			if _state == State.STRIKE and _state_time >= STRIKE_TIME:
				_velocity = _velocity * 0.2
				if not _is_combo and player_active and randf() < COMBO_CHANCE:
					_is_combo = true
					_begin_windup(_type["windup"][0] * COMBO_WINDUP_FACTOR, _type["windup"][1] * COMBO_WINDUP_FACTOR, false)
				else:
					_is_combo = false
					_change_state(State.RECOVER)

		State.RECOVER:
			if _state_time >= RECOVER_TIME:
				_attack_cooldown = randf_range(ATTACK_COOLDOWN.x, ATTACK_COOLDOWN.y)
				_change_state(State.CHASE)

		State.STUNNED:
			if _state_time >= STUN_TIME:
				_attack_cooldown = randf_range(ATTACK_COOLDOWN.x, ATTACK_COOLDOWN.y)
				_change_state(State.CHASE)

		State.SUMMON:
			if _state_time >= _type["summon"]["channel_time"]:
				var positions: Array[Vector2] = []
				for offset in _summon_positions:
					positions.append(global_position + offset)
				Sfx.play("summon_pop", global_position)
				summon_requested.emit(self, _type["summon"]["type"], positions)
				_finish_summon()

		State.DEAD:
			modulate.a = 1.0 - _state_time / DEATH_FADE_TIME
			if _state_time >= DEATH_FADE_TIME:
				queue_free()
			return

	if _state in [State.WANDER, State.CHASE]:
		if target_velocity != Vector2.ZERO:
			target_velocity += _separation() * _speed
		_velocity = _velocity.move_toward(target_velocity, ACCELERATION * delta)
	elif _state in [State.WINDUP, State.RECOVER, State.STUNNED, State.SUMMON]:
		_velocity = _velocity.move_toward(Vector2.ZERO, ACCELERATION * delta)

	if _state in [State.WINDUP, State.STRIKE]:
		_facing = _attack_direction
	elif _state in [State.CHASE, State.DASH, State.SUMMON] and player_active:
		_facing = to_player.normalized()
	elif _velocity.length() > 5.0:
		_facing = _velocity.normalized()

	_knockback = _knockback.move_toward(Vector2.ZERO, 1200.0 * delta)
	# Dirupi e ostacoli solidi fermano anche i nemici; cespugli e rovi li rallentano.
	var motion := (_velocity + _knockback) * delta
	var world := World.current
	if world:
		position = world.move(position, motion * world.slow_at(position, radius), radius * 0.8)
	else:
		position += motion
	queue_redraw()
	_telegraph.queue_redraw()


## heavy: colpo finale della combo, spinge più lontano.
func take_damage(amount: int, direction: Vector2, heavy := false) -> void:
	if _state == State.DEAD:
		return
	health -= amount
	_hit_flash = 0.12
	_knockback = direction * KNOCKBACK * (HEAVY_KNOCKBACK_FACTOR if heavy else 1.0) / float(_type["mass"])
	FloatingText.spawn(get_parent(), global_position + Vector2(randf_range(-12, 12), radius - 20.0), str(amount), COLOR_DAMAGE)
	if health <= 0:
		_change_state(State.DEAD)
		remove_from_group("enemies")
		Sfx.play("enemy_death", global_position, 1.0 / sqrt(_type["mass"]))
		died.emit(self)
	elif _state == State.SUMMON:
		# Colpire un evocatore mentre evoca interrompe l'evocazione.
		_finish_summon()
	elif _state == State.WANDER:
		_change_state(State.CHASE)


func is_dead() -> bool:
	return _state == State.DEAD


## True se il nemico sta combattendo: in quel caso non va rimosso
## anche se il giocatore si allontana.
func is_engaged() -> bool:
	return _state != State.WANDER


func add_minion(minion: Enemy) -> void:
	_minions.append(minion)


func _change_state(new_state: State) -> void:
	_state = new_state
	_state_time = 0.0


func _orbit_distance() -> float:
	return _type["orbit_distance"]


func _attack_trigger_range() -> float:
	return radius + Player.RADIUS + ATTACK_TRIGGER_GAP


func _strike_reach() -> float:
	return float(_type["lunge_speed"]) * STRIKE_TIME + radius + float(_type["strike_reach"])


func _strike_arc() -> float:
	return deg_to_rad(_type["strike_arc"])


## Direzione di movimento attorno al giocatore: si avvicina a spirale
## quando è pronto ad attaccare, altrimenti gli gira attorno. Gli
## evocatori non si avvicinano mai di loro iniziativa.
func _chase_direction(to_player: Vector2) -> Vector2:
	var radial := to_player.normalized()
	var tangent := radial.orthogonal() * _orbit_sign
	var distance := to_player.length()
	if _attack_cooldown == 0.0 and not _type.has("summon"):
		return (radial * 0.85 + tangent * 0.35).normalized()
	if distance > _orbit_distance() + 30.0:
		return (radial * 0.8 + tangent * 0.5).normalized()
	if distance < _orbit_distance() - 30.0:
		return (-radial * 0.6 + tangent * 0.7).normalized()
	return tangent


## Scatto laterale rapido, a volte un po' in avanti o all'indietro.
func _start_dash(to_player: Vector2) -> void:
	var radial := to_player.normalized()
	_dash_direction = (radial.orthogonal() * _orbit_sign + radial * randf_range(-0.4, 0.4)).normalized()
	_change_state(State.DASH)


func _begin_windup(min_time: float, max_time: float, can_feint: bool) -> void:
	_windup_time = randf_range(min_time, max_time)
	_windup_tracking = randf_range(WINDUP_TRACKING.x, WINDUP_TRACKING.y)
	_feint_at = _windup_time * randf_range(0.4, 0.7) if can_feint and randf() < FEINT_CHANCE else -1.0
	if player:
		_attack_direction = (player.global_position - global_position).normalized()
	Sfx.play("enemy_windup", global_position, 1.0 / sqrt(_type["mass"]), -4.0)
	_change_state(State.WINDUP)


func _can_summon(distance: float) -> bool:
	if not _type.has("summon") or _summon_cooldown > 0.0 or distance > LEASH_RANGE:
		return false
	# I servitori sconfitti possono essere già stati liberati: si controlla
	# con is_instance_valid prima di usarli (niente filter con parametri
	# tipizzati, che fallisce sugli oggetti liberati).
	var alive: Array[Enemy] = []
	for minion in _minions:
		if is_instance_valid(minion) and not minion.is_dead():
			alive.append(minion)
	_minions = alive
	return _minions.size() < int(_type["summon"]["max_minions"])


func _begin_summon() -> void:
	var count := mini(int(_type["summon"]["count"]), int(_type["summon"]["max_minions"]) - _minions.size())
	_summon_positions.clear()
	var start := randf() * TAU
	for i in count:
		_summon_positions.append(Vector2.from_angle(start + TAU * i / count) * SUMMON_DISTANCE)
	Sfx.play("summon", global_position)
	_change_state(State.SUMMON)


func _finish_summon() -> void:
	var cooldown: Array = _type["summon"]["cooldown"]
	_summon_cooldown = randf_range(cooldown[0], cooldown[1])
	_change_state(State.CHASE)


func _player_in_strike_zone() -> bool:
	var offset := player.global_position - global_position
	if offset.length() > radius + float(_type["strike_reach"]) + Player.RADIUS:
		return false
	return offset.length() <= radius + Player.RADIUS or absf(_attack_direction.angle_to(offset)) <= _strike_arc() / 2.0


## Spinta per non sovrapporsi agli altri nemici.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self:
			continue
		var other := node as Enemy
		var offset := global_position - other.global_position
		var distance := offset.length()
		var range := SEPARATION_RANGE + radius + other.radius - 48.0
		if distance > 0.0 and distance < range:
			push += offset / distance * (1.0 - distance / range)
	return push


## Zona di pericolo dell'attacco, che si riempie durante la carica, e
## cerchi dove compariranno i nemici evocati.
func _draw_telegraph() -> void:
	if _state == State.WINDUP:
		var progress := _state_time / _windup_time
		_draw_sector(_attack_direction, _strike_reach(), Color(COLOR_DANGER, 0.15))
		_draw_sector(_attack_direction, _strike_reach() * progress, Color(COLOR_DANGER, 0.3))
	elif _state == State.SUMMON:
		var progress: float = _state_time / _type["summon"]["channel_time"]
		for offset in _summon_positions:
			_telegraph.draw_circle(offset, 24.0, Color(COLOR_SUMMON, 0.12))
			_telegraph.draw_circle(offset, 24.0 * progress, Color(COLOR_SUMMON, 0.3))


func _draw() -> void:
	var body := _color
	match _state:
		State.WINDUP:
			body = _color.lerp(COLOR_WINDUP, _state_time / _windup_time)
		State.STRIKE:
			body = COLOR_DANGER
		State.STUNNED:
			body = COLOR_STUNNED
		State.SUMMON:
			body = _color.lerp(COLOR_SUMMON, 0.5 + 0.5 * sin(_state_time * 20.0))
	if _hit_flash > 0.0:
		body = Color.WHITE

	# Ombra, corpo con la forma del tipo e un "occhio" che indica la direzione.
	draw_circle(Vector2(0, radius * 0.8), radius * 0.9, Color(0, 0, 0, 0.25))
	draw_colored_polygon(_shape_points(), body)
	draw_circle(_facing * radius * 0.5, maxf(radius * 0.2, 4.0), Color(0.1, 0.05, 0.1))

	if _state == State.STUNNED:
		for i in 3:
			var angle := _state_time * 4.0 + TAU * i / 3.0
			draw_circle(Vector2(cos(angle) * 18.0, -radius * 1.6 + sin(angle) * 5.0), 4.0, Color(1, 1, 0.5))

	# Vita residua sopra la testa.
	if health < max_health and _state != State.DEAD:
		var width := maxf(40.0, radius * 1.8)
		var origin := Vector2(-width / 2.0, -radius * 1.2 - 14.0)
		draw_rect(Rect2(origin, Vector2(width, 6)), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(origin, Vector2(width * health / max_health, 6)), COLOR_DANGER)


func _shape_points() -> PackedVector2Array:
	match _type["shape"]:
		"triangle":
			return PackedVector2Array([Vector2(0, -radius * 1.3), Vector2(radius, radius * 0.8), Vector2(-radius, radius * 0.8)])
		"square":
			return PackedVector2Array([Vector2(-radius, -radius), Vector2(radius, -radius), Vector2(radius, radius), Vector2(-radius, radius)])
		"hexagon":
			var points := PackedVector2Array()
			for i in 6:
				points.append(Vector2.from_angle(TAU * i / 6.0) * radius * 1.1)
			return points
	return PackedVector2Array([Vector2(0, -radius * 1.2), Vector2(radius, 0), Vector2(0, radius * 1.2), Vector2(-radius, 0)])


func _draw_sector(direction: Vector2, sector_radius: float, color: Color) -> void:
	var points := PackedVector2Array([Vector2.ZERO])
	var steps := 16
	var start := direction.angle() - _strike_arc() / 2.0
	for i in steps + 1:
		points.append(Vector2.from_angle(start + _strike_arc() * i / steps) * sector_radius)
	_telegraph.draw_colored_polygon(points, color)
