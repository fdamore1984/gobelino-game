class_name Player
extends Node2D
## Personaggio giocabile. Per ora è disegnato con forme geometriche:
## verrà sostituito dagli sprite definitivi.
##
## Azioni: movimento in tutte le direzioni con accelerazione e frenata,
## attacchi consecutivi in combo sempre più potenti (R1), parata tenendo
## premuto (L1), schivate concatenate con cambio di direzione (B).
## Una parata perfetta potenzia gli attacchi per qualche secondo.
## Sconfiggere nemici dà esperienza; a ogni livello aumentano i danni
## base e si sceglie un potenziamento (combo, schivate o vita).

signal health_changed(current: int, maximum: int)
signal experience_changed(current: int, needed: int, level: int)
signal leveled_up(level: int)
signal died

enum State { NORMAL, ATTACK, PARRY, DODGE, HURT, DEAD }

const RADIUS := 22.0
const START_HEALTH := 5
const SPEED := 310.0

## Da fermo si parte piano; più si va veloci, più si accelera.
const ACCELERATION_START := 600.0
const ACCELERATION_FULL := 3200.0
## Quando si lascia la direzione ci si ferma dopo un breve scivolamento.
const DECELERATION := 1300.0
## La direzione in cui si guarda ruota in modo continuo invece che a scatti.
const TURN_SPEED := 18.0

## Danni del primo colpo a livello 1, e aumento per ogni livello.
const BASE_DAMAGE := 10
const DAMAGE_PER_LEVEL := 3
## Ogni colpo consecutivo della combo fa questo in più (0.5 = +50%).
const COMBO_DAMAGE_STEP := 0.5
const START_COMBO_HITS := 3
## Dopo un attacco c'è questo tempo per continuare la combo.
const COMBO_WINDOW := 0.35
const ATTACK_WINDUP := 0.07
const ATTACK_ACTIVE := 0.1
const ATTACK_RECOVERY := 0.18
## Il colpo finale della combo ha un recupero più lungo.
const FINISHER_RECOVERY := 0.32
const ATTACK_RANGE := 80.0
const ATTACK_RANGE_PER_STEP := 10.0
const ATTACK_ARC := deg_to_rad(110.0)
const ATTACK_LUNGE_SPEED := 140.0

## Mentre si para ci si muove più lentamente.
const PARRY_SPEED_FACTOR := 0.35
## La parata copre i colpi che arrivano entro questo angolo dal davanti.
const PARRY_ARC := deg_to_rad(140.0)
## Una parata iniziata appena prima del colpo stordisce il nemico
## e potenzia gli attacchi.
const PERFECT_PARRY_WINDOW := 0.2

## Bonus della parata perfetta: attacchi più forti e più rapidi.
const EMPOWER_TIME := 4.0
const EMPOWER_DAMAGE_FACTOR := 2.0
const EMPOWER_ATTACK_SPEED := 1.7

const DODGE_SPEED := 760.0
const DODGE_TIME := 0.28
const DODGE_INVULNERABLE_TIME := 0.24
## Premendo di nuovo durante una schivata se ne concatena un'altra,
## anche in un'altra direzione, fino al numero massimo di schivate.
const START_CHAINED_DODGES := 2
const DODGE_CHAIN_MIN_TIME := 0.06
const DODGE_COOLDOWN := 0.4

const HURT_TIME := 0.25
const HURT_KNOCKBACK := 420.0
const HURT_INVULNERABLE_TIME := 0.8

const COLOR_BODY := Color(0.35, 0.75, 0.4)
const COLOR_HURT := Color(0.95, 0.35, 0.3)
const COLOR_DEAD := Color(0.4, 0.4, 0.4)
const COLOR_SHIELD := Color(0.45, 0.7, 1.0)
const COLOR_SLASH := Color(1.0, 1.0, 0.85)
const COLOR_EMPOWERED := Color(1.0, 0.8, 0.25)

var max_health := START_HEALTH
var health := START_HEALTH
var level := 1
var experience := 0
var max_combo_hits := START_COMBO_HITS
var max_chained_dodges := START_CHAINED_DODGES
var facing := Vector2.RIGHT

var _state := State.NORMAL
var _state_time := 0.0
var _velocity := Vector2.ZERO
var _target_facing := Vector2.RIGHT
var _dodge_direction := Vector2.RIGHT
var _dodges_used := 0
var _dodge_cooldown := 0.0
var _invulnerable_time := 0.0
## Colpo della combo in corso (1 = primo) e tempo rimasto per continuarla.
var _combo_step := 0
var _combo_timer := 0.0
var _attack_queued := false
var _attack_resolved := false
## Velocità dell'attacco in corso: resta quella con cui è iniziato.
var _attack_speed := 1.0
var _empowered_time := 0.0
var _block_flash := 0.0


func _physics_process(delta: float) -> void:
	_state_time += delta
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	_invulnerable_time = maxf(_invulnerable_time - delta, 0.0)
	_empowered_time = maxf(_empowered_time - delta, 0.0)
	_block_flash = maxf(_block_flash - delta, 0.0)
	_combo_timer = maxf(_combo_timer - delta, 0.0)

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	match _state:
		State.NORMAL:
			if input != Vector2.ZERO:
				_target_facing = input.normalized()
			_velocity = _accelerate(_velocity, input * SPEED, delta)
			if Input.is_action_just_pressed("dodge") and _dodge_cooldown == 0.0:
				_start_dodge(input)
			elif Input.is_action_just_pressed("attack"):
				var next_step := _combo_step + 1 if _combo_timer > 0.0 else 1
				_start_attack(next_step, input)
			elif Input.is_action_pressed("parry"):
				_change_state(State.PARRY)

		State.ATTACK:
			var windup := ATTACK_WINDUP / _attack_speed
			var active := ATTACK_ACTIVE / _attack_speed
			var is_finisher := _combo_step >= max_combo_hits
			var recovery := (FINISHER_RECOVERY if is_finisher else ATTACK_RECOVERY) / _attack_speed
			if _state_time < windup + active:
				_velocity = facing * ATTACK_LUNGE_SPEED * (1.0 + 0.2 * (_combo_step - 1))
			else:
				_velocity = _velocity.move_toward(Vector2.ZERO, DECELERATION * delta)
			if Input.is_action_just_pressed("attack"):
				_attack_queued = true
			if not _attack_resolved and _state_time >= windup:
				_attack_resolved = true
				_resolve_attack()
			if _attack_queued and not is_finisher and _state_time >= windup + active:
				# Colpo successivo della combo, appena finito quello attivo.
				_start_attack(_combo_step + 1, input)
			elif _state_time >= windup + active + recovery:
				_combo_timer = 0.0 if is_finisher else COMBO_WINDOW
				if is_finisher:
					_combo_step = 0
				if is_finisher and _attack_queued:
					# Premuto durante il recupero del colpo finale: nuova combo.
					_start_attack(1, input)
				else:
					_change_state(State.NORMAL)

		State.PARRY:
			if input != Vector2.ZERO:
				_target_facing = input.normalized()
			_velocity = _accelerate(_velocity, input * SPEED * PARRY_SPEED_FACTOR, delta)
			if Input.is_action_just_pressed("dodge") and _dodge_cooldown == 0.0:
				_start_dodge(input)
			elif not Input.is_action_pressed("parry"):
				_change_state(State.NORMAL)

		State.DODGE:
			if Input.is_action_just_pressed("dodge") and _dodges_used < max_chained_dodges \
					and _state_time >= DODGE_CHAIN_MIN_TIME:
				# Schivata concatenata: riparte a piena velocità e si può cambiare direzione.
				_dodges_used += 1
				if input != Vector2.ZERO:
					_dodge_direction = input.normalized()
					_target_facing = _dodge_direction
				_state_time = 0.0
				Sfx.play("dodge", global_position, 1.0 + 0.1 * _dodges_used)
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

	# Rotazione continua verso la direzione voluta.
	if _state != State.DEAD:
		var angle := facing.angle()
		var target := _target_facing.angle()
		facing = Vector2.from_angle(angle + clampf(angle_difference(angle, target), -TURN_SPEED * delta, TURN_SPEED * delta))

	position += _velocity * delta
	queue_redraw()


## Un nemico colpisce il giocatore. Restituisce l'esito, così il nemico
## può reagire (per esempio restare stordito dopo una parata perfetta).
func receive_hit(from: Vector2, damage: int) -> String:
	if _state == State.DEAD or _invulnerable_time > 0.0:
		return "ignored"
	if _state == State.DODGE and _state_time <= DODGE_INVULNERABLE_TIME:
		FloatingText.spawn(get_parent(), global_position, tr("FX_DODGED"), COLOR_BODY)
		return "dodged"

	var to_attacker := (from - global_position).normalized()
	if _state == State.PARRY and absf(facing.angle_to(to_attacker)) <= PARRY_ARC / 2.0:
		_block_flash = 0.2
		if _state_time <= PERFECT_PARRY_WINDOW:
			_empowered_time = EMPOWER_TIME
			FloatingText.spawn(get_parent(), global_position, tr("FX_PERFECT_PARRY"), COLOR_SHIELD)
			FloatingText.spawn(get_parent(), global_position, tr("FX_EMPOWERED"), COLOR_EMPOWERED, 28.0)
			Sfx.play("perfect", global_position)
			return "parried"
		position -= to_attacker * 12.0
		FloatingText.spawn(get_parent(), global_position, tr("FX_BLOCKED"), COLOR_SHIELD)
		Sfx.play("block", global_position)
		return "blocked"

	health = maxi(health - damage, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		_change_state(State.DEAD)
		Sfx.play("death", global_position)
		died.emit()
	else:
		_change_state(State.HURT)
		_velocity = -to_attacker * HURT_KNOCKBACK
		_invulnerable_time = HURT_INVULNERABLE_TIME
		Sfx.play("hurt", global_position)
	return "hit"


func is_dead() -> bool:
	return _state == State.DEAD


func is_empowered() -> bool:
	return _empowered_time > 0.0


## Danni del primo colpo della combo al livello attuale.
func base_damage() -> int:
	return BASE_DAMAGE + DAMAGE_PER_LEVEL * (level - 1)


## Esperienza necessaria per passare al livello successivo:
## 100 per il livello 2, 200 per il 3, e così via.
func experience_needed() -> int:
	return 100 * level


func add_experience(amount: int) -> void:
	if _state == State.DEAD:
		return
	experience += amount
	while experience >= experience_needed():
		experience -= experience_needed()
		level += 1
		Sfx.play("level_up", global_position)
		leveled_up.emit(level)
	experience_changed.emit(experience, experience_needed(), level)


## Potenziamento scelto salendo di livello: "combo", "dodge" o "health".
func apply_upgrade(upgrade: String) -> void:
	match upgrade:
		"combo":
			max_combo_hits += 1
		"dodge":
			max_chained_dodges += 1
		"health":
			max_health += 1
			health += 1
			health_changed.emit(health, max_health)


func _change_state(new_state: State) -> void:
	_state = new_state
	_state_time = 0.0


## Avvicina la velocità a quella voluta: partenza graduale che poi
## accelera, frenata con un breve scivolamento.
func _accelerate(current: Vector2, target: Vector2, delta: float) -> Vector2:
	if target == Vector2.ZERO:
		return current.move_toward(Vector2.ZERO, DECELERATION * delta)
	var speed_ratio := clampf(current.length() / SPEED, 0.0, 1.0)
	var acceleration := lerpf(ACCELERATION_START, ACCELERATION_FULL, speed_ratio)
	return current.move_toward(target, acceleration * delta)


func _start_attack(step: int, input: Vector2) -> void:
	_combo_step = clampi(step, 1, max_combo_hits)
	_attack_speed = EMPOWER_ATTACK_SPEED if is_empowered() else 1.0
	_attack_queued = false
	_attack_resolved = false
	# Si attacca subito nella direzione indicata, senza aspettare la rotazione.
	if input != Vector2.ZERO:
		_target_facing = input.normalized()
		facing = _target_facing
	Sfx.play("swing", global_position, 1.0 + 0.12 * (_combo_step - 1))
	if _combo_step > 1:
		FloatingText.spawn(get_parent(), global_position, tr("FX_COMBO") % _combo_step, COLOR_SLASH, 12.0)
	_change_state(State.ATTACK)


func _start_dodge(input: Vector2) -> void:
	# Senza direzione si schiva all'indietro rispetto a dove si guarda.
	_dodge_direction = input.normalized() if input != Vector2.ZERO else -facing
	_dodges_used = 1
	_combo_step = 0
	Sfx.play("dodge", global_position)
	_change_state(State.DODGE)


func _attack_range() -> float:
	return ATTACK_RANGE + ATTACK_RANGE_PER_STEP * (_combo_step - 1)


func _resolve_attack() -> void:
	var multiplier := 1.0 + COMBO_DAMAGE_STEP * (_combo_step - 1)
	if _attack_speed > 1.0:
		multiplier *= EMPOWER_DAMAGE_FACTOR
	var damage := roundi(base_damage() * multiplier)
	var heavy := _combo_step >= max_combo_hits
	var landed := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var offset := enemy.global_position - global_position
		if offset.length() > _attack_range() + enemy.radius:
			continue
		# A contatto si colpisce sempre, altrimenti serve essere girati verso il nemico.
		if offset.length() <= RADIUS + enemy.radius or absf(facing.angle_to(offset)) <= ATTACK_ARC / 2.0:
			enemy.take_damage(damage, offset.normalized(), heavy)
			landed = true
	if landed:
		Sfx.play("hit", global_position, 1.0 + 0.1 * (_combo_step - 1))


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
		body.a = 0.5 - 0.1 * (_dodges_used - 1)

	# Ombra, aura del potenziamento, corpo e "naso" che indica la direzione.
	draw_circle(Vector2(0, RADIUS * 0.8), RADIUS * 0.9, Color(0, 0, 0, 0.25))
	if is_empowered() and _state != State.DEAD:
		var pulse := 0.5 + 0.5 * sin(_empowered_time * 10.0)
		draw_circle(Vector2.ZERO, RADIUS + 8.0 + pulse * 4.0, Color(COLOR_EMPOWERED, 0.25))
		draw_arc(Vector2.ZERO, RADIUS + 8.0 + pulse * 4.0, 0.0, TAU, 32, Color(COLOR_EMPOWERED, 0.8), 2.0)
	draw_circle(Vector2.ZERO, RADIUS, body)
	var tip := facing * (RADIUS + 12.0)
	var side := facing.orthogonal() * 9.0
	draw_colored_polygon(PackedVector2Array([tip, facing * RADIUS * 0.6 + side, facing * RADIUS * 0.6 - side]), body.darkened(0.3))

	var windup := ATTACK_WINDUP / _attack_speed
	if _state == State.ATTACK and _state_time >= windup and _state_time < windup + ATTACK_ACTIVE / _attack_speed:
		var slash := COLOR_EMPOWERED if _attack_speed > 1.0 else COLOR_SLASH
		# I colpi successivi della combo hanno un fendente più ampio e più acceso.
		var alpha := 0.45 + 0.15 * (_combo_step - 1)
		_draw_arc_band(facing, RADIUS + 6.0, _attack_range() + RADIUS, ATTACK_ARC + 0.15 * (_combo_step - 1), Color(slash, minf(alpha, 0.9)))

	if _state == State.PARRY:
		var shield := COLOR_SHIELD
		if _state_time <= PERFECT_PARRY_WINDOW or _block_flash > 0.0:
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
