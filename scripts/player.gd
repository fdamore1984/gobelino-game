class_name Player
extends Node2D
## Personaggio giocabile. Per ora è disegnato con forme geometriche:
## verrà sostituito dagli sprite definitivi.
##
## Azioni: movimento in tutte le direzioni, attacco (R1), parata tenendo
## premuto (L1) e schivata con invulnerabilità (B).

signal health_changed(current: int, maximum: int)
signal died

enum State { NORMAL, ATTACK, PARRY, DODGE, HURT, DEAD }

const RADIUS := 22.0
const MAX_HEALTH := 5
const SPEED := 260.0

const ATTACK_WINDUP := 0.08
const ATTACK_ACTIVE := 0.1
const ATTACK_RECOVERY := 0.2
const ATTACK_RANGE := 80.0
const ATTACK_ARC := deg_to_rad(110.0)
const ATTACK_DAMAGE := 1
const ATTACK_LUNGE_SPEED := 120.0

## Mentre si para ci si muove più lentamente.
const PARRY_SPEED_FACTOR := 0.35
## La parata copre i colpi che arrivano entro questo angolo dal davanti.
const PARRY_ARC := deg_to_rad(140.0)
## Una parata iniziata appena prima del colpo stordisce il nemico.
const PERFECT_PARRY_WINDOW := 0.2

const DODGE_SPEED := 720.0
const DODGE_TIME := 0.28
const DODGE_INVULNERABLE_TIME := 0.24
const DODGE_COOLDOWN := 0.4

const HURT_TIME := 0.25
const HURT_KNOCKBACK := 420.0
const HURT_INVULNERABLE_TIME := 0.8

const COLOR_BODY := Color(0.35, 0.75, 0.4)
const COLOR_HURT := Color(0.95, 0.35, 0.3)
const COLOR_DEAD := Color(0.4, 0.4, 0.4)
const COLOR_SHIELD := Color(0.45, 0.7, 1.0)
const COLOR_SLASH := Color(1.0, 1.0, 0.85)

var health := MAX_HEALTH
var facing := Vector2.RIGHT

var _state := State.NORMAL
var _state_time := 0.0
var _velocity := Vector2.ZERO
var _dodge_direction := Vector2.RIGHT
var _dodge_cooldown := 0.0
var _invulnerable_time := 0.0
var _attack_resolved := false
var _block_flash := 0.0


func _physics_process(delta: float) -> void:
	_state_time += delta
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	_invulnerable_time = maxf(_invulnerable_time - delta, 0.0)
	_block_flash = maxf(_block_flash - delta, 0.0)

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	match _state:
		State.NORMAL:
			if input != Vector2.ZERO:
				facing = input.normalized()
			_velocity = input * SPEED
			if Input.is_action_just_pressed("dodge") and _dodge_cooldown == 0.0:
				_start_dodge(input)
			elif Input.is_action_just_pressed("attack"):
				_change_state(State.ATTACK)
				_attack_resolved = false
			elif Input.is_action_pressed("parry"):
				_change_state(State.PARRY)

		State.ATTACK:
			if _state_time < ATTACK_WINDUP + ATTACK_ACTIVE:
				_velocity = facing * ATTACK_LUNGE_SPEED
			else:
				_velocity = Vector2.ZERO
			if not _attack_resolved and _state_time >= ATTACK_WINDUP:
				_attack_resolved = true
				_resolve_attack()
			if _state_time >= ATTACK_WINDUP + ATTACK_ACTIVE + ATTACK_RECOVERY:
				_change_state(State.NORMAL)

		State.PARRY:
			if input != Vector2.ZERO:
				facing = input.normalized()
			_velocity = input * SPEED * PARRY_SPEED_FACTOR
			if Input.is_action_just_pressed("dodge") and _dodge_cooldown == 0.0:
				_start_dodge(input)
			elif not Input.is_action_pressed("parry"):
				_change_state(State.NORMAL)

		State.DODGE:
			# Scatto rapido che rallenta verso la fine.
			var t := _state_time / DODGE_TIME
			_velocity = _dodge_direction * DODGE_SPEED * (1.0 - t * t)
			if _state_time >= DODGE_TIME:
				_dodge_cooldown = DODGE_COOLDOWN
				_change_state(State.NORMAL)

		State.HURT:
			_velocity = _velocity.move_toward(Vector2.ZERO, HURT_KNOCKBACK * 4.0 * delta)
			if _state_time >= HURT_TIME:
				_change_state(State.NORMAL)

		State.DEAD:
			_velocity = Vector2.ZERO

	position += _velocity * delta
	queue_redraw()


## Un nemico colpisce il giocatore. Restituisce l'esito, così il nemico
## può reagire (per esempio restare stordito dopo una parata perfetta).
func receive_hit(from: Vector2, damage: int) -> String:
	if _state == State.DEAD or _invulnerable_time > 0.0:
		return "ignored"
	if _state == State.DODGE and _state_time <= DODGE_INVULNERABLE_TIME:
		FloatingText.spawn(get_parent(), global_position, "Schivato!", COLOR_BODY)
		return "dodged"

	var to_attacker := (from - global_position).normalized()
	if _state == State.PARRY and absf(facing.angle_to(to_attacker)) <= PARRY_ARC / 2.0:
		_block_flash = 0.2
		if _state_time <= PERFECT_PARRY_WINDOW:
			FloatingText.spawn(get_parent(), global_position, "Parata perfetta!", COLOR_SHIELD)
			return "parried"
		position -= to_attacker * 12.0
		FloatingText.spawn(get_parent(), global_position, "Parato", COLOR_SHIELD)
		return "blocked"

	health = maxi(health - damage, 0)
	health_changed.emit(health, MAX_HEALTH)
	if health == 0:
		_change_state(State.DEAD)
		died.emit()
	else:
		_change_state(State.HURT)
		_velocity = -to_attacker * HURT_KNOCKBACK
		_invulnerable_time = HURT_INVULNERABLE_TIME
	return "hit"


func is_dead() -> bool:
	return _state == State.DEAD


func _change_state(new_state: State) -> void:
	_state = new_state
	_state_time = 0.0


func _start_dodge(input: Vector2) -> void:
	# Senza direzione si schiva all'indietro rispetto a dove si guarda.
	_dodge_direction = input.normalized() if input != Vector2.ZERO else -facing
	_change_state(State.DODGE)


func _resolve_attack() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var offset := enemy.global_position - global_position
		var reach := ATTACK_RANGE + Enemy.RADIUS
		if offset.length() > reach:
			continue
		# A contatto si colpisce sempre, altrimenti serve essere girati verso il nemico.
		if offset.length() <= RADIUS + Enemy.RADIUS or absf(facing.angle_to(offset)) <= ATTACK_ARC / 2.0:
			enemy.take_damage(ATTACK_DAMAGE, offset.normalized())


func _draw() -> void:
	var body := COLOR_BODY
	if _state == State.DEAD:
		body = COLOR_DEAD
	elif _state == State.HURT:
		body = COLOR_HURT
	# Lampeggia mentre è invulnerabile dopo un colpo.
	if _invulnerable_time > 0.0 and int(_invulnerable_time * 12.0) % 2 == 0:
		body.a = 0.35
	if _state == State.DODGE:
		body.a = 0.5

	# Ombra, corpo e "naso" che indica la direzione.
	draw_circle(Vector2(0, RADIUS * 0.8), RADIUS * 0.9, Color(0, 0, 0, 0.25))
	draw_circle(Vector2.ZERO, RADIUS, body)
	var tip := facing * (RADIUS + 12.0)
	var side := facing.orthogonal() * 9.0
	draw_colored_polygon(PackedVector2Array([tip, facing * RADIUS * 0.6 + side, facing * RADIUS * 0.6 - side]), body.darkened(0.3))

	if _state == State.ATTACK and _state_time >= ATTACK_WINDUP and _state_time < ATTACK_WINDUP + ATTACK_ACTIVE:
		_draw_arc_band(facing, RADIUS + 6.0, ATTACK_RANGE + RADIUS, ATTACK_ARC, Color(COLOR_SLASH, 0.6))

	if _state == State.PARRY:
		var shield := COLOR_SHIELD
		if _state_time <= PERFECT_PARRY_WINDOW:
			shield = Color.WHITE
		if _block_flash > 0.0:
			shield = Color.WHITE
		draw_arc(Vector2.ZERO, RADIUS + 10.0, facing.angle() - PARRY_ARC / 2.0, facing.angle() + PARRY_ARC / 2.0, 24, shield, 6.0)


## Disegna un settore circolare "a fascia" orientato verso direction.
func _draw_arc_band(direction: Vector2, inner: float, outer: float, arc: float, color: Color) -> void:
	var points := PackedVector2Array()
	var steps := 16
	var start := direction.angle() - arc / 2.0
	for i in steps + 1:
		points.append(Vector2.from_angle(start + arc * i / steps) * outer)
	for i in range(steps, -1, -1):
		points.append(Vector2.from_angle(start + arc * i / steps) * inner)
	draw_colored_polygon(points, color)
