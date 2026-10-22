class_name Player
extends Node2D
## Personaggio giocabile. Per ora è disegnato con forme geometriche:
## verrà sostituito dagli sprite definitivi.
##
## Azioni: movimento in tutte le direzioni con accelerazione e frenata,
## attacchi consecutivi in combo sempre più potenti (R1), attacco potente
## che chiude la combo con un bonus (L2), parata tenendo premuto (L1),
## schivate concatenate con cambio di direzione (B), salti anche multipli (A),
## corsa tenendo premuto R2, pozioni che curano (croce sinistra) e scudo
## che assorbe un colpo (croce destra).
## Schivata e parata interrompono la combo in qualsiasi momento; attaccare
## durante una schivata la interrompe e attacca subito. Salti e schivate si
## combinano; schivando mentre si corre si fa una scivolata, durante la
## quale si può attaccare (anche in combo), schivare, saltare o parare.
## Una parata perfetta potenzia gli attacchi per qualche secondo.
## Sconfiggere nemici dà esperienza; a ogni livello aumentano i danni
## base e si sceglie un potenziamento.

signal health_changed(current: int, maximum: int)
signal experience_changed(current: int, needed: int, level: int)
signal leveled_up(level: int)
signal died

enum State { NORMAL, ATTACK, PARRY, DODGE, SLIDE, HURT, DEAD }

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

## Attacco potente: più lento, più ampio e molto più forte. In fondo a una
## combo prende anche il bonus dei colpi già fatti; chiude la combo, a
## meno che non si possano concatenare altri colpi potenti.
const HEAVY_WINDUP := 0.22
const HEAVY_ACTIVE := 0.12
const HEAVY_RECOVERY := 0.35
const HEAVY_DAMAGE_FACTOR := 2.5
## Ogni colpo potente concatenato fa questo in più del precedente.
const HEAVY_CHAIN_DAMAGE_STEP := 0.5
const HEAVY_RANGE := 110.0
const HEAVY_ARC := deg_to_rad(150.0)
const HEAVY_LUNGE_SPEED := 220.0
const START_HEAVY_CHAIN := 1

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
## Premendo di nuovo durante una schivata (o subito dopo) se ne concatena
## un'altra, fino al numero massimo di schivate.
const START_CHAINED_DODGES := 2
const DODGE_CHAIN_MIN_TIME := 0.04
const DODGE_CHAIN_GRACE := 0.15
## All'inizio di ogni schivata la direzione segue ancora la levetta, così
## cambiare direzione è facile anche premendo un attimo prima di girarla.
const DODGE_STEER_TIME := 0.1
## Per la direzione delle schivate basta inclinare poco la levetta.
const DODGE_STICK_DEADZONE := 0.2
const DODGE_COOLDOWN := 0.4

## Corsa tenendo premuto R2: più veloce del passo normale. Ogni
## potenziamento aggiunge il 2% alla velocità di corsa.
const RUN_SPEED_FACTOR := 1.6
const RUN_SPEED_UPGRADE := 0.02

## Scivolata: schivando mentre si corre si scivola in avanti, rallentando.
const SLIDE_TIME := 0.55
const SLIDE_SPEED_FACTOR := 1.35
const SLIDE_INVULNERABLE_TIME := 0.25

## Salto: l'altezza è solo visiva (la visuale è dall'alto), ma in aria gli
## attacchi dei nemici passano sotto. Si parte con un salto; i
## potenziamenti permettono salti consecutivi in aria.
const JUMP_SPEED := 520.0
const GRAVITY := 1800.0
## Durante una schivata in aria si scende più piano.
const AIR_DODGE_GRAVITY_FACTOR := 0.3
## Sopra questa altezza i colpi dei nemici non arrivano.
const JUMP_EVADE_HEIGHT := 18.0
const START_JUMPS := 1

## Ogni pozione cura questi punti vita.
const POTION_HEAL := 3
const START_POTIONS := 2
## Lo scudo assorbe un colpo; poi va ricaricato. Ogni potenziamento
## riduce la ricarica del 2%.
const SHIELD_COOLDOWN := 30.0
const SHIELD_COOLDOWN_UPGRADE := 0.98

## I rovi pungono a intervalli (data/world.json); la prima volta poco dopo
## esserci entrati.
const THORNS_FIRST_DELAY := 1.0
const THORNS_INVULNERABLE_TIME := 0.4

const HURT_TIME := 0.25
const HURT_KNOCKBACK := 420.0
const HURT_INVULNERABLE_TIME := 0.8

const COLOR_BODY := Color(0.35, 0.75, 0.4)
const COLOR_HURT := Color(0.95, 0.35, 0.3)
const COLOR_DEAD := Color(0.4, 0.4, 0.4)
const COLOR_SHIELD := Color(0.45, 0.7, 1.0)
const COLOR_SLASH := Color(1.0, 1.0, 0.85)
const COLOR_HEAVY := Color(1.0, 0.5, 0.2)
const COLOR_EMPOWERED := Color(1.0, 0.8, 0.25)
const COLOR_HEAL := Color(0.5, 1.0, 0.5)
const COLOR_BUBBLE := Color(0.55, 0.85, 1.0)

var max_health := START_HEALTH
var health := START_HEALTH
var level := 1
var experience := 0
var max_combo_hits := START_COMBO_HITS
var max_heavy_chain := START_HEAVY_CHAIN
var max_chained_dodges := START_CHAINED_DODGES
var max_jumps := START_JUMPS
## Bonus alla velocità di corsa (0.02 = +2%).
var run_speed_bonus := 0.0
var max_potions := START_POTIONS
var potions := START_POTIONS
var shield_cooldown_max := SHIELD_COOLDOWN
## Ricarica dello scudo rimasta, e se lo scudo è attivo in questo momento.
var shield_cooldown := 0.0
var shield_active := false
var facing := Vector2.RIGHT

var _state := State.NORMAL
var _state_time := 0.0
var _velocity := Vector2.ZERO
var _target_facing := Vector2.RIGHT
var _dodge_direction := Vector2.RIGHT
var _dodges_used := 0
var _dodge_cooldown := 0.0
## Dopo una schivata resta un attimo per concatenarne un'altra.
var _dodge_chain_grace := 0.0
var _invulnerable_time := 0.0
## Colpi normali e colpi potenti della combo in corso, e tempo rimasto per continuarla.
var _combo_step := 0
var _heavy_step := 0
var _combo_timer := 0.0
## Attacco in corso: normale o potente.
var _attack_heavy := false
## Attacco premuto durante quello in corso: "", "attack" o "heavy".
var _queued_attack := ""
var _attack_resolved := false
## Velocità dell'attacco in corso: resta quella con cui è iniziato.
var _attack_speed := 1.0
var _empowered_time := 0.0
var _block_flash := 0.0
## Altezza da terra durante i salti e velocità verticale.
var _height := 0.0
var _height_velocity := 0.0
var _jumps_used := 0
var _slide_direction := Vector2.RIGHT
var _slide_speed := 0.0
## Slancio che resta quando si attacca durante una scivolata.
var _carry_velocity := Vector2.ZERO
## Tempo passato nei rovi dall'ultima puntura.
var _thorns_time := 0.0
## Potenziamento -> quante volte è stato scelto, nell'ordine di scelta.
var upgrades_taken := {}


func _physics_process(delta: float) -> void:
	_state_time += delta
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	_dodge_chain_grace = maxf(_dodge_chain_grace - delta, 0.0)
	_invulnerable_time = maxf(_invulnerable_time - delta, 0.0)
	_empowered_time = maxf(_empowered_time - delta, 0.0)
	_block_flash = maxf(_block_flash - delta, 0.0)
	_combo_timer = maxf(_combo_timer - delta, 0.0)
	shield_cooldown = maxf(shield_cooldown - delta, 0.0)

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dodge_input := Input.get_vector("move_left", "move_right", "move_up", "move_down", DODGE_STICK_DEADZONE)

	if _state not in [State.DEAD, State.HURT]:
		if Input.is_action_just_pressed("potion"):
			_drink_potion()
		if Input.is_action_just_pressed("shield"):
			_raise_shield()

	match _state:
		State.NORMAL:
			if input != Vector2.ZERO:
				_target_facing = input.normalized()
			var running := Input.is_action_pressed("run") and input != Vector2.ZERO
			_velocity = _accelerate(_velocity, input * (run_speed() if running else SPEED), delta)
			if Input.is_action_just_pressed("jump"):
				_jump()
			if Input.is_action_just_pressed("dodge"):
				if running and not is_airborne():
					_start_slide(input)
				elif _dodge_chain_grace > 0.0 and _dodges_used < max_chained_dodges:
					_chain_dodge(dodge_input)
				elif _dodge_cooldown == 0.0:
					_start_dodge(dodge_input)
			elif Input.is_action_just_pressed("heavy_attack"):
				_start_heavy(input)
			elif Input.is_action_just_pressed("attack"):
				_start_attack(_next_combo_step(), input)
			elif Input.is_action_pressed("parry"):
				_change_state(State.PARRY)

		State.ATTACK:
			# Schivata e parata sono sempre possibili e interrompono la combo.
			if Input.is_action_just_pressed("dodge") and _dodge_cooldown == 0.0:
				_start_dodge(dodge_input)
			elif Input.is_action_just_pressed("parry"):
				_end_combo()
				_change_state(State.PARRY)
			else:
				_update_attack(input, delta)

		State.PARRY:
			if input != Vector2.ZERO:
				_target_facing = input.normalized()
			_velocity = _accelerate(_velocity, input * SPEED * PARRY_SPEED_FACTOR, delta)
			if Input.is_action_just_pressed("dodge") and _dodge_cooldown == 0.0:
				_start_dodge(dodge_input)
			elif not Input.is_action_pressed("parry"):
				_change_state(State.NORMAL)

		State.DODGE:
			# Attaccare o parare interrompe subito la schivata.
			if Input.is_action_just_pressed("attack"):
				_end_combo()
				_start_attack(1, input)
			elif Input.is_action_just_pressed("heavy_attack"):
				_end_combo()
				_start_heavy(input)
			elif Input.is_action_just_pressed("parry"):
				_change_state(State.PARRY)
			elif Input.is_action_just_pressed("dodge") and _dodges_used < max_chained_dodges \
					and _state_time >= DODGE_CHAIN_MIN_TIME:
				_chain_dodge(dodge_input)
			elif Input.is_action_just_pressed("jump"):
				# Salto e schivata si combinano: la schivata continua in aria.
				_jump()
			elif _state_time <= DODGE_STEER_TIME and dodge_input != Vector2.ZERO:
				_dodge_direction = dodge_input.normalized()
				_target_facing = _dodge_direction
			if _state == State.DODGE:
				# Scatto rapido che rallenta verso la fine.
				var t := _state_time / DODGE_TIME
				_velocity = _dodge_direction * DODGE_SPEED * (1.0 - t * t)
				if _state_time >= DODGE_TIME:
					_dodge_cooldown = DODGE_COOLDOWN
					_dodge_chain_grace = DODGE_CHAIN_GRACE
					_change_state(State.NORMAL)

		State.SLIDE:
			# Durante la scivolata si può attaccare (continuando la combo),
			# schivare, saltare o parare: la scivolata si interrompe.
			if Input.is_action_just_pressed("attack"):
				_carry_velocity = _velocity
				_start_attack(_next_combo_step(), input)
			elif Input.is_action_just_pressed("heavy_attack"):
				_carry_velocity = _velocity
				_start_heavy(input)
			elif Input.is_action_just_pressed("dodge") and _dodge_cooldown == 0.0:
				_start_dodge(dodge_input)
			elif Input.is_action_just_pressed("jump"):
				_change_state(State.NORMAL)
				_jump()
			elif Input.is_action_just_pressed("parry"):
				_change_state(State.PARRY)
			else:
				var t := _state_time / SLIDE_TIME
				_velocity = _slide_direction * _slide_speed * (1.0 - 0.7 * t)
				if _state_time >= SLIDE_TIME:
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

	_update_height(delta)
	_move(delta)
	queue_redraw()


## Spostamento nel mondo: dirupi e ostacoli solidi fermano il personaggio,
## cespugli e rovi lo rallentano (ma non durante schivate e scivolate) e i
## rovi pungono. In aria si può saltare giù da un dirupo.
func _move(delta: float) -> void:
	var world := World.current
	if world == null:
		position += _velocity * delta
		return
	var motion := _velocity * delta
	var grounded := not is_airborne()
	if grounded and _state != State.DODGE and _state != State.SLIDE:
		motion *= world.slow_at(position, RADIUS)
	var from := position
	position = world.move(position, motion, RADIUS * 0.8, _height > JUMP_EVADE_HEIGHT)
	if not grounded:
		var drop := world.cliff_drop(from, position)
		if drop > 0:
			# Saltando giù dal dirupo si cade da più in alto.
			_height += world.face_height(drop)
	var thorns := world.ground_obstacle_at(position, RADIUS) if grounded else {}
	if not thorns.is_empty() and thorns["damage"] > 0:
		_thorns_time += delta
		if _thorns_time >= thorns["damage_interval"]:
			_thorns_time -= thorns["damage_interval"]
			_scratch(thorns["damage"])
	else:
		# Appena entrati nei rovi la prima puntura arriva dopo un attimo.
		_thorns_time = THORNS_FIRST_DELAY


## Spinta senza passare attraverso dirupi e ostacoli.
func _push(offset: Vector2) -> void:
	position = World.current.move(position, offset, RADIUS * 0.8) if World.current else position + offset


## Puntura dei rovi: toglie vita senza spinta né interruzioni.
func _scratch(damage: int) -> void:
	if _state == State.DEAD or _invulnerable_time > 0.0:
		return
	health = maxi(health - damage, 0)
	health_changed.emit(health, max_health)
	FloatingText.spawn(get_parent(), global_position, tr("FX_THORNS"), COLOR_HURT)
	if health == 0:
		_change_state(State.DEAD)
		Sfx.play("death", global_position)
		died.emit()
	else:
		_invulnerable_time = THORNS_INVULNERABLE_TIME
		Sfx.play("hurt", global_position, 1.3, -6.0)


## Salto e caduta: con più salti disponibili si può saltare di nuovo in aria.
func _update_height(delta: float) -> void:
	if _height <= 0.0 and _height_velocity <= 0.0:
		return
	var gravity := GRAVITY * (AIR_DODGE_GRAVITY_FACTOR if _state == State.DODGE else 1.0)
	_height_velocity -= gravity * delta
	_height += _height_velocity * delta
	if _height <= 0.0:
		_height = 0.0
		_height_velocity = 0.0
		_jumps_used = 0


## Avanzamento dell'attacco in corso: affondo, colpo, combo e recupero.
func _update_attack(input: Vector2, delta: float) -> void:
	var windup := (HEAVY_WINDUP if _attack_heavy else ATTACK_WINDUP) / _attack_speed
	var active := (HEAVY_ACTIVE if _attack_heavy else ATTACK_ACTIVE) / _attack_speed
	var recovery := _attack_recovery() / _attack_speed
	# Lo slancio di una scivolata si esaurisce durante l'attacco.
	_carry_velocity = _carry_velocity.move_toward(Vector2.ZERO, DECELERATION * delta)
	if _state_time < windup + active:
		var lunge := HEAVY_LUNGE_SPEED if _attack_heavy else ATTACK_LUNGE_SPEED * (1.0 + 0.2 * (_combo_step - 1))
		_velocity = (facing * lunge if _state_time >= windup * 0.5 else _velocity * 0.8) + _carry_velocity
	else:
		_velocity = _velocity.move_toward(Vector2.ZERO, DECELERATION * delta) + _carry_velocity
	# Si memorizza la pressione solo se può davvero continuare la combo:
	# alla fine della combo le pressioni in più vengono ignorate.
	if Input.is_action_just_pressed("heavy_attack") and _can_chain_heavy():
		_queued_attack = "heavy"
	elif Input.is_action_just_pressed("attack") and _can_chain_attack():
		_queued_attack = "attack"
	if not _attack_resolved and _state_time >= windup:
		_attack_resolved = true
		_resolve_attack()
	if _queued_attack != "" and _state_time >= windup + active:
		if _queued_attack == "heavy":
			_start_heavy(input)
		else:
			_start_attack(_combo_step + 1, input)
	elif _state_time >= windup + active + recovery:
		if _combo_finished():
			_end_combo()
		else:
			_combo_timer = COMBO_WINDOW
		_carry_velocity = Vector2.ZERO
		_change_state(State.NORMAL)


func _end_combo() -> void:
	_combo_step = 0
	_heavy_step = 0
	_combo_timer = 0.0
	_queued_attack = ""


## Un nemico colpisce il giocatore. Restituisce l'esito, così il nemico
## può reagire (per esempio restare stordito dopo una parata perfetta).
func receive_hit(from: Vector2, damage: int) -> String:
	if _state == State.DEAD or _invulnerable_time > 0.0:
		return "ignored"
	if (_state == State.DODGE and _state_time <= DODGE_INVULNERABLE_TIME) \
			or (_state == State.SLIDE and _state_time <= SLIDE_INVULNERABLE_TIME):
		FloatingText.spawn(get_parent(), global_position, tr("FX_DODGED"), COLOR_BODY)
		return "dodged"
	if _height > JUMP_EVADE_HEIGHT:
		FloatingText.spawn(get_parent(), global_position, tr("FX_JUMPED"), COLOR_BODY)
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
		_push(-to_attacker * 12.0)
		FloatingText.spawn(get_parent(), global_position, tr("FX_BLOCKED"), COLOR_SHIELD)
		Sfx.play("block", global_position)
		return "blocked"

	if shield_active:
		# Lo scudo assorbe un colpo da qualsiasi direzione e poi si rompe.
		shield_active = false
		_invulnerable_time = 0.3
		FloatingText.spawn(get_parent(), global_position, tr("FX_SHIELD_BLOCK"), COLOR_BUBBLE)
		Sfx.play("shield_break", global_position)
		return "shielded"

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


## Secondi rimasti del potenziamento della parata perfetta.
func empowered_time() -> float:
	return _empowered_time


func is_airborne() -> bool:
	return _height > 0.0


func run_speed() -> float:
	return SPEED * RUN_SPEED_FACTOR * (1.0 + run_speed_bonus)


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


## Potenziamento scelto salendo di livello.
func apply_upgrade(upgrade: String) -> void:
	upgrades_taken[upgrade] = upgrades_taken.get(upgrade, 0) + 1
	match upgrade:
		"combo":
			max_combo_hits += 1
		"heavy":
			max_heavy_chain += 1
		"dodge":
			max_chained_dodges += 1
		"health":
			max_health += 1
			health += 1
			health_changed.emit(health, max_health)
		"potion":
			max_potions += 1
			potions += 1
		"shield":
			shield_cooldown_max *= SHIELD_COOLDOWN_UPGRADE
			shield_cooldown = minf(shield_cooldown, shield_cooldown_max)
		"jump":
			max_jumps += 1
		"run":
			run_speed_bonus += RUN_SPEED_UPGRADE


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


## Un colpo normale può seguire solo colpi normali, fino al massimo della combo.
func _can_chain_attack() -> bool:
	return not _attack_heavy and _combo_step < max_combo_hits


## Un colpo potente può chiudere la combo o seguire altri colpi potenti,
## finché non si raggiunge il massimo di colpi potenti concatenati.
func _can_chain_heavy() -> bool:
	return _heavy_step < max_heavy_chain


func _combo_finished() -> bool:
	if _attack_heavy:
		return _heavy_step >= max_heavy_chain
	return _combo_step >= max_combo_hits and max_heavy_chain == 0


func _attack_recovery() -> float:
	if _attack_heavy:
		return HEAVY_RECOVERY
	return FINISHER_RECOVERY if _combo_step >= max_combo_hits else ATTACK_RECOVERY


func _start_attack(step: int, input: Vector2) -> void:
	_combo_step = clampi(step, 1, max_combo_hits)
	_heavy_step = 0
	_attack_heavy = false
	_begin_attack(input)
	Sfx.play("swing", global_position, 1.0 + 0.12 * (_combo_step - 1))
	if _combo_step > 1:
		FloatingText.spawn(get_parent(), global_position, tr("FX_COMBO") % _combo_step, COLOR_SLASH, 12.0)


func _start_heavy(input: Vector2) -> void:
	# Fuori dalla combo il colpo potente parte da solo, senza bonus.
	if _combo_timer == 0.0 and _state != State.ATTACK:
		_combo_step = 0
		_heavy_step = 0
	if _heavy_step >= max_heavy_chain:
		_heavy_step = 0
		_combo_step = 0
	_heavy_step += 1
	_attack_heavy = true
	_begin_attack(input)
	Sfx.play("heavy_swing", global_position, 1.0 + 0.08 * (_heavy_step - 1))
	if _combo_step > 0 or _heavy_step > 1:
		FloatingText.spawn(get_parent(), global_position, tr("FX_HEAVY"), COLOR_HEAVY, 12.0)


func _begin_attack(input: Vector2) -> void:
	_attack_speed = EMPOWER_ATTACK_SPEED if is_empowered() else 1.0
	_queued_attack = ""
	_attack_resolved = false
	_combo_timer = 0.0
	# Si attacca subito nella direzione indicata, senza aspettare la rotazione.
	if input != Vector2.ZERO:
		_target_facing = input.normalized()
		facing = _target_facing
	_change_state(State.ATTACK)


## Colpo successivo: continua la combo se c'è ancora tempo, altrimenti
## ricomincia (anche dopo un colpo potente o dopo l'ultimo colpo).
func _next_combo_step() -> int:
	var continues := _combo_timer > 0.0 and _heavy_step == 0 and _combo_step < max_combo_hits
	return _combo_step + 1 if continues else 1


func _jump() -> void:
	if _jumps_used >= max_jumps:
		return
	_jumps_used += 1
	_height_velocity = JUMP_SPEED
	Sfx.play("jump", global_position, 1.0 + 0.15 * (_jumps_used - 1))


## La scivolata parte almeno alla velocità di corsa, così funziona anche
## subito dopo un attacco, quando non si è ancora ripresa velocità.
func _start_slide(input: Vector2) -> void:
	_slide_direction = input.normalized()
	_slide_speed = maxf(_velocity.length(), run_speed()) * SLIDE_SPEED_FACTOR
	_target_facing = _slide_direction
	Sfx.play("slide", global_position)
	_change_state(State.SLIDE)


func _start_dodge(input: Vector2) -> void:
	# Senza direzione si schiva all'indietro rispetto a dove si guarda.
	_dodge_direction = input.normalized() if input != Vector2.ZERO else -facing
	_dodges_used = 1
	_carry_velocity = Vector2.ZERO
	_combo_step = 0
	_heavy_step = 0
	Sfx.play("dodge", global_position)
	_change_state(State.DODGE)


## Schivata concatenata: riparte a piena velocità, nella nuova direzione.
func _chain_dodge(input: Vector2) -> void:
	_dodges_used += 1
	if input != Vector2.ZERO:
		_dodge_direction = input.normalized()
		_target_facing = _dodge_direction
	Sfx.play("dodge", global_position, 1.0 + 0.1 * _dodges_used)
	_change_state(State.DODGE)


func _drink_potion() -> void:
	if potions == 0 or health >= max_health:
		return
	var healed := mini(POTION_HEAL, max_health - health)
	potions -= 1
	health += healed
	health_changed.emit(health, max_health)
	FloatingText.spawn(get_parent(), global_position, tr("FX_POTION") % healed, COLOR_HEAL)
	Sfx.play("potion", global_position)


func _raise_shield() -> void:
	if shield_active or shield_cooldown > 0.0:
		return
	shield_active = true
	shield_cooldown = shield_cooldown_max
	FloatingText.spawn(get_parent(), global_position, tr("FX_SHIELD_UP"), COLOR_BUBBLE)
	Sfx.play("shield_up", global_position)


func _attack_range() -> float:
	if _attack_heavy:
		return HEAVY_RANGE
	return ATTACK_RANGE + ATTACK_RANGE_PER_STEP * (_combo_step - 1)


func _attack_arc() -> float:
	if _attack_heavy:
		return HEAVY_ARC
	return ATTACK_ARC + 0.15 * (_combo_step - 1)


func _attack_damage() -> int:
	var multiplier: float
	if _attack_heavy:
		# Il colpo potente prende il bonus dei colpi normali che lo precedono
		# nella combo e cresce a ogni colpo potente concatenato.
		multiplier = HEAVY_DAMAGE_FACTOR * (1.0 + COMBO_DAMAGE_STEP * _combo_step) \
				* (1.0 + HEAVY_CHAIN_DAMAGE_STEP * (_heavy_step - 1))
	else:
		multiplier = 1.0 + COMBO_DAMAGE_STEP * (_combo_step - 1)
	if _attack_speed > 1.0:
		multiplier *= EMPOWER_DAMAGE_FACTOR
	return roundi(base_damage() * multiplier)


func _resolve_attack() -> void:
	var damage := _attack_damage()
	var heavy := _attack_heavy or _combo_step >= max_combo_hits
	var landed := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var offset := enemy.global_position - global_position
		if offset.length() > _attack_range() + enemy.radius:
			continue
		# A contatto si colpisce sempre, altrimenti serve essere girati verso il nemico.
		if offset.length() <= RADIUS + enemy.radius or absf(facing.angle_to(offset)) <= _attack_arc() / 2.0:
			enemy.take_damage(damage, offset.normalized(), heavy)
			landed = true
	if landed:
		Sfx.play("hit", global_position, 0.8 if _attack_heavy else 1.0 + 0.1 * (_combo_step - 1))


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

	# L'ombra resta a terra e si rimpicciolisce durante il salto; tutto il
	# resto sale con il personaggio. In scivolata il corpo si schiaccia.
	var shadow_scale := clampf(1.0 - _height / 160.0, 0.5, 1.0)
	draw_circle(Vector2(0, RADIUS * 0.8), RADIUS * 0.9 * shadow_scale, Color(0, 0, 0, 0.25))
	var body_scale := Vector2(1.2, 0.6) if _state == State.SLIDE else Vector2.ONE
	draw_set_transform(Vector2(0, -_height + (RADIUS * 0.4 if _state == State.SLIDE else 0.0)), 0.0, body_scale)

	# Aura del potenziamento, corpo e "naso" che indica la direzione.
	if is_empowered() and _state != State.DEAD:
		var pulse := 0.5 + 0.5 * sin(_empowered_time * 10.0)
		draw_circle(Vector2.ZERO, RADIUS + 8.0 + pulse * 4.0, Color(COLOR_EMPOWERED, 0.25))
		draw_arc(Vector2.ZERO, RADIUS + 8.0 + pulse * 4.0, 0.0, TAU, 32, Color(COLOR_EMPOWERED, 0.8), 2.0)
	draw_circle(Vector2.ZERO, RADIUS, body)
	var tip := facing * (RADIUS + 12.0)
	var side := facing.orthogonal() * 9.0
	draw_colored_polygon(PackedVector2Array([tip, facing * RADIUS * 0.6 + side, facing * RADIUS * 0.6 - side]), body.darkened(0.3))

	if _state == State.ATTACK:
		var windup := (HEAVY_WINDUP if _attack_heavy else ATTACK_WINDUP) / _attack_speed
		var active := (HEAVY_ACTIVE if _attack_heavy else ATTACK_ACTIVE) / _attack_speed
		if _attack_heavy and _state_time < windup:
			# Carica del colpo potente: un arco che si accende.
			draw_arc(Vector2.ZERO, RADIUS + 6.0, facing.angle() - HEAVY_ARC / 2.0, facing.angle() + HEAVY_ARC / 2.0, 24, Color(COLOR_HEAVY, _state_time / windup), 4.0)
		elif _state_time >= windup and _state_time < windup + active:
			var slash := COLOR_HEAVY if _attack_heavy else COLOR_SLASH
			if _attack_speed > 1.0:
				slash = COLOR_EMPOWERED
			# I colpi successivi della combo hanno un fendente più ampio e più acceso.
			var alpha := 0.8 if _attack_heavy else 0.45 + 0.15 * (_combo_step - 1)
			_draw_arc_band(facing, RADIUS + 6.0, _attack_range() + RADIUS, _attack_arc(), Color(slash, minf(alpha, 0.9)))

	if _state == State.PARRY:
		var shield := COLOR_SHIELD
		if _state_time <= PERFECT_PARRY_WINDOW or _block_flash > 0.0:
			shield = Color.WHITE
		draw_arc(Vector2.ZERO, RADIUS + 10.0, facing.angle() - PARRY_ARC / 2.0, facing.angle() + PARRY_ARC / 2.0, 24, shield, 6.0)

	# Scudo attivo: una bolla attorno al personaggio.
	if shield_active and _state != State.DEAD:
		draw_circle(Vector2.ZERO, RADIUS + 16.0, Color(COLOR_BUBBLE, 0.15))
		draw_arc(Vector2.ZERO, RADIUS + 16.0, 0.0, TAU, 40, Color(COLOR_BUBBLE, 0.7), 2.5)
	draw_set_transform(Vector2.ZERO)


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
