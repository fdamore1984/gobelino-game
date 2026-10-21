class_name Enemy
extends Node2D
## Nemico di test, disegnato con forme geometriche.
##
## Vaga finché il giocatore non si avvicina, poi gli gira attorno con
## spostamenti laterali e scatti rapidi, finché non decide di attaccare.
## L'attacco è lento e annunciato: durante la carica a terra compare la
## zona colpita, poi il nemico scatta in avanti. Per essere meno
## prevedibile la carica ha durata variabile, a volte è una finta e a
## volte segue subito un secondo attacco più rapido.

signal died(enemy: Enemy)

enum State { WANDER, CHASE, DASH, WINDUP, STRIKE, RECOVER, STUNNED, DEAD }

const RADIUS := 24.0
const MAX_HEALTH := 3

const WANDER_SPEED := 50.0
const CHASE_SPEED := 125.0
const ACCELERATION := 900.0
const AGGRO_RANGE := 380.0
const LEASH_RANGE := 650.0
const SEPARATION_RANGE := 60.0

## Mentre aspetta di attaccare il nemico gira attorno al giocatore a questa distanza.
const ORBIT_DISTANCE := 175.0
## Ogni tanto cambia verso di rotazione o fa uno scatto laterale.
const DECISION_INTERVAL := Vector2(0.5, 1.6)
const DASH_CHANCE := 0.4
const DASH_SPEED := 480.0
const DASH_TIME := 0.18

## Distanza dal giocatore a cui il nemico inizia a caricare l'attacco.
const ATTACK_TRIGGER_RANGE := 110.0
const WINDUP_TIME := Vector2(0.6, 1.3)
## Per una parte della carica (variabile) il nemico segue il giocatore,
## poi la direzione resta bloccata: è il momento di schivare.
const WINDUP_TRACKING := Vector2(0.4, 0.75)
## Probabilità che la carica sia una finta, interrotta a metà con uno scatto.
const FEINT_CHANCE := 0.2
## Probabilità di un secondo attacco subito dopo il primo, con carica più breve.
const COMBO_CHANCE := 0.3
const COMBO_WINDUP_TIME := Vector2(0.5, 0.7)
const STRIKE_TIME := 0.16
const STRIKE_LUNGE_SPEED := 600.0
## Portata del colpo oltre al raggio del nemico, durante l'affondo.
const STRIKE_REACH := 50.0
const STRIKE_ARC := deg_to_rad(110.0)
const STRIKE_DAMAGE := 1
const RECOVER_TIME := 0.9
## Dopo un attacco aspetta un tempo a caso prima di riprovare.
const ATTACK_COOLDOWN := Vector2(0.6, 2.0)
const STUN_TIME := 1.6
const DEATH_FADE_TIME := 0.4

const COLOR_BODY := Color(0.7, 0.3, 0.55)
const COLOR_WINDUP := Color(1.0, 0.45, 0.2)
const COLOR_STUNNED := Color(0.55, 0.55, 0.8)
const COLOR_DANGER := Color(1.0, 0.25, 0.15)

var player: Player
var health := MAX_HEALTH

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
## La zona di pericolo va disegnata sotto i personaggi, non sopra.
var _telegraph := Node2D.new()


func _ready() -> void:
	add_to_group("enemies")
	_facing = Vector2.from_angle(randf() * TAU)
	_orbit_sign = [-1.0, 1.0].pick_random()
	_telegraph.z_index = -5
	_telegraph.draw.connect(_draw_telegraph)
	add_child(_telegraph)


func _physics_process(delta: float) -> void:
	_state_time += delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
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
			target_velocity = _wander_direction * WANDER_SPEED
			if player_active and distance <= AGGRO_RANGE:
				_change_state(State.CHASE)

		State.CHASE:
			if not player_active or distance > LEASH_RANGE:
				_change_state(State.WANDER)
			elif _attack_cooldown == 0.0 and distance <= ATTACK_TRIGGER_RANGE:
				_begin_windup(WINDUP_TIME, true)
			else:
				_decision_time -= delta
				if _decision_time <= 0.0:
					_decision_time = randf_range(DECISION_INTERVAL.x, DECISION_INTERVAL.y)
					if randf() < 0.5:
						_orbit_sign = -_orbit_sign
					if distance < ORBIT_DISTANCE * 1.8 and randf() < DASH_CHANCE:
						_start_dash(to_player)
				if _state == State.CHASE:
					target_velocity = _chase_direction(to_player) * CHASE_SPEED

		State.DASH:
			_velocity = _dash_direction * DASH_SPEED
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
				_change_state(State.STRIKE)

		State.STRIKE:
			_velocity = _attack_direction * STRIKE_LUNGE_SPEED
			target_velocity = _velocity
			if not _strike_resolved and player_active and _player_in_strike_zone():
				_strike_resolved = true
				if player.receive_hit(global_position, STRIKE_DAMAGE) == "parried":
					_is_combo = false
					_change_state(State.STUNNED)
			if _state == State.STRIKE and _state_time >= STRIKE_TIME:
				_velocity = _velocity * 0.2
				if not _is_combo and player_active and randf() < COMBO_CHANCE:
					_is_combo = true
					_begin_windup(COMBO_WINDUP_TIME, false)
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

		State.DEAD:
			modulate.a = 1.0 - _state_time / DEATH_FADE_TIME
			if _state_time >= DEATH_FADE_TIME:
				queue_free()
			return

	if _state in [State.WANDER, State.CHASE]:
		if target_velocity != Vector2.ZERO:
			target_velocity += _separation() * CHASE_SPEED
		_velocity = _velocity.move_toward(target_velocity, ACCELERATION * delta)
	elif _state in [State.WINDUP, State.RECOVER, State.STUNNED]:
		_velocity = _velocity.move_toward(Vector2.ZERO, ACCELERATION * delta)

	if _state in [State.WINDUP, State.STRIKE]:
		_facing = _attack_direction
	elif _state in [State.CHASE, State.DASH] and player_active:
		_facing = to_player.normalized()
	elif _velocity.length() > 5.0:
		_facing = _velocity.normalized()

	_knockback = _knockback.move_toward(Vector2.ZERO, 1200.0 * delta)
	position += (_velocity + _knockback) * delta
	queue_redraw()
	_telegraph.queue_redraw()


func take_damage(amount: int, direction: Vector2) -> void:
	if _state == State.DEAD:
		return
	health -= amount
	_hit_flash = 0.12
	_knockback = direction * 260.0
	if health <= 0:
		_change_state(State.DEAD)
		remove_from_group("enemies")
		died.emit(self)
	elif _state == State.WANDER:
		_change_state(State.CHASE)


func is_dead() -> bool:
	return _state == State.DEAD


## True se il nemico sta combattendo: in quel caso non va rimosso
## anche se il giocatore si allontana.
func is_engaged() -> bool:
	return _state != State.WANDER


func _change_state(new_state: State) -> void:
	_state = new_state
	_state_time = 0.0


## Direzione di movimento attorno al giocatore: si avvicina a spirale
## quando è pronto ad attaccare, altrimenti gli gira attorno.
func _chase_direction(to_player: Vector2) -> Vector2:
	var radial := to_player.normalized()
	var tangent := radial.orthogonal() * _orbit_sign
	var distance := to_player.length()
	if _attack_cooldown == 0.0:
		return (radial * 0.85 + tangent * 0.35).normalized()
	if distance > ORBIT_DISTANCE + 30.0:
		return (radial * 0.8 + tangent * 0.5).normalized()
	if distance < ORBIT_DISTANCE - 30.0:
		return (-radial * 0.6 + tangent * 0.7).normalized()
	return tangent


## Scatto laterale rapido, a volte un po' in avanti o all'indietro.
func _start_dash(to_player: Vector2) -> void:
	var radial := to_player.normalized()
	_dash_direction = (radial.orthogonal() * _orbit_sign + radial * randf_range(-0.4, 0.4)).normalized()
	_change_state(State.DASH)


func _begin_windup(duration_range: Vector2, can_feint: bool) -> void:
	_windup_time = randf_range(duration_range.x, duration_range.y)
	_windup_tracking = randf_range(WINDUP_TRACKING.x, WINDUP_TRACKING.y)
	_feint_at = _windup_time * randf_range(0.4, 0.7) if can_feint and randf() < FEINT_CHANCE else -1.0
	if player:
		_attack_direction = (player.global_position - global_position).normalized()
	_change_state(State.WINDUP)


func _player_in_strike_zone() -> bool:
	var offset := player.global_position - global_position
	if offset.length() > RADIUS + STRIKE_REACH + Player.RADIUS:
		return false
	return offset.length() <= RADIUS + Player.RADIUS or absf(_attack_direction.angle_to(offset)) <= STRIKE_ARC / 2.0


## Spinta per non sovrapporsi agli altri nemici.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self:
			continue
		var offset := global_position - (node as Node2D).global_position
		var distance := offset.length()
		if distance > 0.0 and distance < SEPARATION_RANGE:
			push += offset / distance * (1.0 - distance / SEPARATION_RANGE)
	return push


## Zona di pericolo: si riempie man mano che la carica procede.
func _draw_telegraph() -> void:
	if _state != State.WINDUP:
		return
	var progress := _state_time / _windup_time
	var reach := STRIKE_LUNGE_SPEED * STRIKE_TIME + RADIUS + STRIKE_REACH
	_draw_sector(_attack_direction, reach, Color(COLOR_DANGER, 0.15))
	_draw_sector(_attack_direction, reach * progress, Color(COLOR_DANGER, 0.3))


func _draw() -> void:
	var body := COLOR_BODY
	match _state:
		State.WINDUP:
			body = COLOR_BODY.lerp(COLOR_WINDUP, _state_time / _windup_time)
		State.STRIKE:
			body = COLOR_DANGER
		State.STUNNED:
			body = COLOR_STUNNED
	if _hit_flash > 0.0:
		body = Color.WHITE

	# Ombra e corpo a rombo, con un "occhio" che indica la direzione.
	draw_circle(Vector2(0, RADIUS * 0.8), RADIUS * 0.9, Color(0, 0, 0, 0.25))
	var diamond := PackedVector2Array([
		Vector2(0, -RADIUS * 1.2), Vector2(RADIUS, 0), Vector2(0, RADIUS * 1.2), Vector2(-RADIUS, 0),
	])
	draw_colored_polygon(diamond, body)
	draw_circle(_facing * RADIUS * 0.5, 5.0, Color(0.1, 0.05, 0.1))

	if _state == State.STUNNED:
		for i in 3:
			var angle := _state_time * 4.0 + TAU * i / 3.0
			draw_circle(Vector2(cos(angle) * 18.0, -RADIUS * 1.6 + sin(angle) * 5.0), 4.0, Color(1, 1, 0.5))

	# Vita residua sopra la testa.
	if health < MAX_HEALTH and _state != State.DEAD:
		var width := 40.0
		var origin := Vector2(-width / 2.0, -RADIUS * 1.2 - 14.0)
		draw_rect(Rect2(origin, Vector2(width, 6)), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(origin, Vector2(width * health / MAX_HEALTH, 6)), COLOR_DANGER)


func _draw_sector(direction: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([Vector2.ZERO])
	var steps := 16
	var start := direction.angle() - STRIKE_ARC / 2.0
	for i in steps + 1:
		points.append(Vector2.from_angle(start + STRIKE_ARC * i / steps) * radius)
	_telegraph.draw_colored_polygon(points, color)
