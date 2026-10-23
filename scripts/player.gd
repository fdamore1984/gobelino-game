class_name Player
extends Node2D
## Personaggio giocabile. Per ora è disegnato con forme geometriche:
## verrà sostituito dagli sprite definitivi.
##
## Azioni: movimento in tutte le direzioni con accelerazione e frenata,
## attacchi consecutivi in combo sempre più potenti (R1), attacco potente
## che chiude la combo con un bonus (L2), parata tenendo premuto (L1),
## schivate concatenate con cambio di direzione (B), salti anche multipli (A),
## corsa tenendo premuto R2, palla di fuoco che insegue i nemici (X, costa
## mana), scudo che assorbe un colpo (Y), pozioni di vita (croce sinistra)
## e di mana (croce destra), torcia (croce giù). Il colpo potente si carica
## tenendo premuto, fino al doppio del danno. Equipaggiamento e libri
## dell'inventario migliorano le caratteristiche (vedi Inventory).
## Schivata e parata interrompono la combo in qualsiasi momento; attaccare
## durante una schivata la interrompe e attacca subito. Salti e schivate si
## combinano; schivando mentre si corre si fa una scivolata, durante la
## quale si può attaccare (anche in combo), schivare, saltare o parare.
## Una parata perfetta potenzia gli attacchi per qualche secondo.
## Con R3 si aggancia il nemico più vicino: il personaggio lo guarda sempre,
## gli attacchi e la palla di fuoco vanno verso di lui; premendo di nuovo si
## passa al nemico vicino successivo.
## Tenendo premuto R1 si continua ad attaccare; in aria R1 fa un attacco
## aereo. Attacchi a terra, che colpiscono tutti i nemici attorno: un colpo
## potente subito dopo una combo di colpi normali fa saltare e colpire il
## terreno (anche tutti i colpi potenti concatenati dopo); il colpo potente
## in aria fa piombare a terra, durante uno scatto in aria con un colpo più
## ampio.
## Sconfiggere nemici dà esperienza; a ogni livello aumentano i danni
## base e si sceglie un potenziamento.

signal health_changed(current: int, maximum: int)
signal experience_changed(current: int, needed: int, level: int)
signal leveled_up(level: int)
signal died

enum State { NORMAL, ATTACK, PARRY, DODGE, SLIDE, HURT, DEAD, SLAM, FALL, RECOIL }

const RADIUS := 22.0
const START_HEALTH := 5
const SPEED := 310.0

## Da fermo si parte piano; più si va veloci, più si accelera.
const ACCELERATION_START := 600.0
const ACCELERATION_FULL := 2800.0
## Quando si lascia la direzione ci si ferma dopo un breve scivolamento.
const DECELERATION := 1100.0
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
const ATTACK_WINDUP := 0.13
const ATTACK_ACTIVE := 0.15
const ATTACK_RECOVERY := 0.28
## Il colpo finale della combo ha un recupero più lungo.
const FINISHER_RECOVERY := 0.42
## I colpi normali colpiscono sempre la stessa area davanti al personaggio.
const ATTACK_RANGE := 85.0
const ATTACK_ARC := deg_to_rad(115.0)
## Movimenti dei colpi normali a terra, a turno (ogni colpo è diverso dal
## precedente): fendente, rovescio, colpo dall'alto, affondo.
const ATTACK_STYLES := ["slash", "backhand", "chop", "thrust"]
## Rotazione del corpo che accompagna fendente e rovescio.
const ATTACK_TWIST := 0.18
const ATTACK_LUNGE_SPEED := 140.0
## Durante un attacco ci si muove a questa frazione della velocità normale.
const ATTACK_MOVE_FACTOR := 0.55

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
## Attacco aereo: i colpi normali in aria fendono un arco più ampio,
## arrivano anche ai nemici sotto di sé fino a AIR_ATTACK_REACH e, mentre si
## colpisce, si scende più piano.
const AIR_ATTACK_ARC := deg_to_rad(200.0)
const AIR_ATTACK_REACH := 110.0
const AIR_ATTACK_GRAVITY_FACTOR := 0.45
## Attacchi a terra: il colpo potente diventa un salto con colpo sul
## terreno ("leap") dopo almeno SLAM_MIN_COMBO colpi normali; il colpo
## potente in aria fa piombare a terra ("plunge"), durante uno scatto in
## aria con un colpo più ampio ("dash").
const SLAM_MIN_COMBO := 2
const SLAM_LEAP_SPEED := 620.0
const SLAM_LEAP_FORWARD := 160.0
const SLAM_GRAVITY := 2600.0
## In picchiata ci si ferma un attimo in aria, poi si scende veloci.
const SLAM_HANG := 0.1
const SLAM_DIVE_SPEED := 650.0
const SLAM_RECOVERY := 0.32
## Se per qualche motivo non si tocca terra, l'impatto arriva comunque.
const SLAM_MAX_TIME := 2.0
const SLAM_RADIUS := {"leap": 140.0, "plunge": 105.0, "dash": 165.0}
const SLAM_LEAP_DAMAGE_FACTOR := 0.8
const PLUNGE_DAMAGE_FACTOR := 1.6
const DASH_SLAM_DAMAGE_FACTOR := 2.4
## Aggancio del bersaglio: nemici entro LOCK_RANGE; oltre LOCK_BREAK_RANGE
## si sgancia. La telecamera si sposta verso il bersaglio di questa parte
## della distanza, fino a LOCK_CAMERA_MAX.
const LOCK_RANGE := 650.0
const LOCK_BREAK_RANGE := 900.0
const LOCK_CAMERA_SHARE := 0.3
const LOCK_CAMERA_MAX := 170.0
## All'impatto la telecamera trema, sempre meno.
const CAMERA_SHAKE := 9.0
const CAMERA_SHAKE_DECAY := 4.0

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

const DODGE_SPEED := 620.0
const DODGE_TIME := 0.28
const DODGE_INVULNERABLE_TIME := 0.24
## Premendo di nuovo durante una schivata (o subito dopo) se ne concatena
## un'altra, fino al numero massimo di schivate.
const START_CHAINED_DODGES := 1
const DODGE_CHAIN_MIN_TIME := 0.04
const DODGE_CHAIN_GRACE := 0.15
## All'inizio di ogni schivata la direzione segue ancora la levetta, così
## cambiare direzione è facile anche premendo un attimo prima di girarla.
const DODGE_STEER_TIME := 0.1
## Poi la schivata curva verso la direzione della levetta a questa velocità.
const DODGE_TURN_RATE := 10.0
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

## Salto: serve per salire sui blocchi più alti del terreno (vedi World)
## e in aria gli attacchi dei nemici passano sotto. Si parte con un salto;
## i potenziamenti permettono salti consecutivi in aria.
const JUMP_SPEED := 480.0
## In aria la velocità orizzontale scende a questa parte.
const AIR_SPEED_FACTOR := 0.85
const GRAVITY := 1800.0
## A terra la schivata è una capriola; in aria è uno scatto nella direzione
## di movimento, durante il quale si scende più piano.
const AIR_DODGE_GRAVITY_FACTOR := 0.3
const ROLL_CURL := 0.45
const AIR_DASH_TRAIL := 3
## Sopra questa altezza i colpi dei nemici non arrivano.
const JUMP_EVADE_HEIGHT := 18.0
## Colpi dati e ricevuti arrivano solo tra chi sta più o meno alla stessa
## altezza (per esempio non a un nemico sul gradino di sotto).
const HIT_HEIGHT_REACH := 40.0
## La telecamera segue con dolcezza l'altezza del terreno e anticipa un
## poco la direzione di movimento.
const CAMERA_HEIGHT_FOLLOW := 6.0
const CAMERA_SMOOTHING := 7.0
const CAMERA_LOOK_AHEAD := 0.18
const CAMERA_LOOK_AHEAD_MAX := 70.0
const CAMERA_LOOK_AHEAD_FOLLOW := 2.5
## Il corpo si inclina nella direzione di corsa e si schiaccia atterrando.
const LEAN_ANGLE := 0.12
const SQUASH_AMOUNT := 0.22
const SQUASH_RECOVERY := 5.0
const START_JUMPS := 1

## Mana: serve per le magie e si ricarica piano da solo.
const START_MANA := 60.0
const MANA_REGEN := 2.0
const MANA_UPGRADE := 20.0
const MANA_POTION_RESTORE := 40.0
const START_MANA_POTIONS := 1
const MAX_MANA_POTIONS := 2
## Palla di fuoco: costo, attesa tra un lancio e l'altro, danni (crescono
## con il livello e con i potenziamenti della magia, +20% ciascuno).
const SPELL_COST := 20.0
const SPELL_COOLDOWN := 0.45
const FIREBALL_DAMAGE := 18
const FIREBALL_DAMAGE_PER_LEVEL := 4
const SPELL_UPGRADE := 0.2

## Tenendo premuto il colpo potente si carica: in questo tempo arriva al
## massimo, che raddoppia il danno.
const HEAVY_CHARGE_TIME := 0.9

## Torcia: luce attorno al personaggio, utile di notte.
const TORCH_COLOR := Color(1.0, 0.78, 0.45)
const TORCH_ENERGY := 1.15
const TORCH_SCALE := 1.9

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

## Rimbalzo contro ostacoli e pareti: solo sopra BOUNCE_MIN_SPEED verso
## l'ostacolo, con una parte della velocità d'urto (al massimo BOUNCE_MAX_SPEED).
const BOUNCE_MIN_SPEED := 200.0
const BOUNCE_FACTOR := 0.45
const BOUNCE_MAX_SPEED := 180.0

## Colpo parato dalla guardia di un nemico: la combo si interrompe e si
## viene respinti indietro per REPEL_TIME secondi (schivata e parata restano
## possibili).
const REPEL_SPEED := 420.0
const REPEL_TIME := 0.35
const COLOR_GUARD_SPARK := Color(0.8, 0.9, 1.0)

const HURT_TIME := 0.25
const HURT_KNOCKBACK := 420.0
const HURT_INVULNERABLE_TIME := 0.8

## Gambe: il corpo sta sopra di LEG_LENGTH; i passi seguono la velocità.
const LEG_LENGTH := 14.0
const WALK_CYCLE := 0.08
const STRIDE := 7.0
## Spada: lunghezza e larghezza della lama (il colpo potente usa una spada più grande).
const SWORD_LENGTH := 46.0
const HEAVY_SWORD_LENGTH := 58.0
const SWORD_WIDTH := 5.0

const COLOR_BODY := Color(0.35, 0.75, 0.4)
## Burroni: cadendoci si precipita per FALL_TIME secondi, poi si riappare
## sul bordo (l'ultimo punto sicuro) perdendo vita (data/world.json). Si
## cade quando si scende sotto il bordo di FALL_DEPTH pixel.
const FALL_TIME := 0.8
const FALL_DEPTH := 48.0
const COLOR_HURT := Color(0.95, 0.35, 0.3)
const COLOR_DEAD := Color(0.4, 0.4, 0.4)
const COLOR_SHIELD := Color(0.45, 0.7, 1.0)
const COLOR_SLASH := Color(1.0, 1.0, 0.85)
const COLOR_HEAVY := Color(1.0, 0.5, 0.2)
const COLOR_EMPOWERED := Color(1.0, 0.8, 0.25)
const COLOR_HEAL := Color(0.5, 1.0, 0.5)
const COLOR_BUBBLE := Color(0.55, 0.85, 1.0)
const COLOR_MANA := Color(0.45, 0.65, 1.0)
const COLOR_FLAME := Color(1.0, 0.6, 0.2)

var max_health := START_HEALTH
## Vita massima senza l'equipaggiamento (cresce con i potenziamenti).
var _base_max_health := START_HEALTH
var mana := START_MANA
var max_mana := START_MANA
var _base_max_mana := START_MANA
var mana_potions := START_MANA_POTIONS
var max_mana_potions := MAX_MANA_POTIONS
## Bonus alla potenza della magia dai potenziamenti (0.2 = +20%).
var spell_bonus := 0.0
var inventory := Inventory.new()
var torch_on := false
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
@onready var _camera: Camera2D = get_node_or_null("Camera")
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
## C'è un elemento con cui interagire qui vicino (lo decide Game).
var can_interact := false
## Cresce a ogni attacco di spada (non gli attacchi a terra): i nemici lo
## guardano per decidere se alzare la guardia (vedi Enemy).
var attack_serial := 0
## L'attacco in corso è partito in aria (attacco aereo).
var _air_attack := false
## Movimento del colpo normale in corso (indice in ATTACK_STYLES).
var _attack_style := 0
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
## Movimento durante l'attacco, senza l'affondo del colpo.
var _walk_velocity := Vector2.ZERO
## Verso del fendente in corso (+1 o -1): cambia a ogni attacco.
var _swing_sign := 1.0
## Fase del passo per l'animazione delle gambe.
var _walk_phase := 0.0
## Schiacciamento dopo un atterraggio (0-1) e anticipo della telecamera.
var _squash := 0.0
var _look_ahead := Vector2.ZERO
var _camera_height := 0.0
var _spell_cooldown := 0.0
## La schivata in corso è uno scatto in aria (altrimenti è una capriola).
var _air_dash := false
## Attacco a terra in corso: "leap", "plunge" o "dash", e se ha già toccato terra.
var _slam_kind := ""
var _slam_landed := false
## Tremolio della telecamera (0-1).
var _shake := 0.0
## Ultimo punto a terra fuori dai burroni e la sua altezza: si riappare lì.
var _safe_position := Vector2.ZERO
var _safe_altitude := 0.0
## Nemico agganciato (null se nessuno) e il suo mirino.
var lock_target: Enemy
var _lock_marker := LockMarker.new()
## Carica del colpo potente (0-1) e se il tasto è ancora tenuto premuto.
var _charge := 0.0
var _charging := false
var _torch := PointLight2D.new()
## Tempo passato nei rovi dall'ultima puntura.
var _thorns_time := 0.0
## Potenziamento -> quante volte è stato scelto, nell'ordine di scelta.
var upgrades_taken := {}
## Altezza del terreno sotto il personaggio (vedi World.elevation_at).
var ground_elevation := 0.0


func _ready() -> void:
	if not _lock_marker.is_inside_tree():
		add_child(_lock_marker)
	if not _torch.is_inside_tree():
		_torch.texture = LightTexture.get_texture()
		_torch.color = TORCH_COLOR
		_torch.energy = TORCH_ENERGY
		_torch.texture_scale = TORCH_SCALE
		_torch.enabled = torch_on
		add_child(_torch)
	if World.current:
		ground_elevation = World.current.elevation_at(position)
	_safe_position = position
	_safe_altitude = ground_elevation
	if _camera:
		_camera_height = -ground_elevation
		_camera.position = Vector2(0, _camera_height)
		_camera.position_smoothing_enabled = true
		_camera.position_smoothing_speed = CAMERA_SMOOTHING
		_camera.reset_smoothing()


func _physics_process(delta: float) -> void:
	_state_time += delta
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	_dodge_chain_grace = maxf(_dodge_chain_grace - delta, 0.0)
	_invulnerable_time = maxf(_invulnerable_time - delta, 0.0)
	_empowered_time = maxf(_empowered_time - delta, 0.0)
	_block_flash = maxf(_block_flash - delta, 0.0)
	_combo_timer = maxf(_combo_timer - delta, 0.0)
	shield_cooldown = maxf(shield_cooldown - delta, 0.0)
	_spell_cooldown = maxf(_spell_cooldown - delta, 0.0)
	if _state != State.DEAD:
		mana = minf(mana + MANA_REGEN * delta, max_mana)

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dodge_input := Input.get_vector("move_left", "move_right", "move_up", "move_down", DODGE_STICK_DEADZONE)

	if _state not in [State.DEAD, State.HURT]:
		if Input.is_action_just_pressed("potion"):
			_drink_potion()
		if Input.is_action_just_pressed("shield"):
			_raise_shield()
		if Input.is_action_just_pressed("mana_potion"):
			_drink_mana_potion()
		if Input.is_action_just_pressed("spell"):
			_cast_fireball(input)
	if _state != State.DEAD:
		if Input.is_action_just_pressed("lock_on"):
			_cycle_lock()
		_update_lock()
	if Input.is_action_just_pressed("torch") and _state != State.DEAD:
		torch_on = not torch_on
		_torch.enabled = torch_on
		Sfx.play("torch", global_position)

	match _state:
		State.NORMAL:
			if input != Vector2.ZERO:
				_target_facing = input.normalized()
			_face_lock()
			var running := Input.is_action_pressed("run") and input != Vector2.ZERO
			# In aria si avanza un po' più piano: il salto porta meno lontano.
			var air := AIR_SPEED_FACTOR if is_airborne() else 1.0
			_velocity = _accelerate(_velocity, input * (run_speed() if running else walk_speed()) * air, delta)
			if _jump_pressed():
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
			elif Input.is_action_just_pressed("attack") or Input.is_action_pressed("attack"):
				# Tenendo premuto si continua ad attaccare (anche un tocco rapidissimo
				# conta); in aria è un attacco aereo.
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
			_face_lock()
			_velocity = _accelerate(_velocity, input * walk_speed() * PARRY_SPEED_FACTOR, delta)
			if Input.is_action_just_pressed("dodge") and _dodge_cooldown == 0.0:
				_start_dodge(dodge_input)
			elif not Input.is_action_pressed("parry"):
				_change_state(State.NORMAL)

		State.DODGE:
			# Attaccare o parare interrompe subito la schivata; il colpo
			# potente durante lo scatto in aria fa piombare a terra con un
			# colpo ampio, quello normale è un attacco aereo.
			if Input.is_action_just_pressed("heavy_attack"):
				_end_combo()
				if is_airborne() and _air_dash:
					_start_slam("dash", input)
				else:
					_start_heavy(input)
			elif Input.is_action_just_pressed("attack"):
				_end_combo()
				_start_attack(1, input)
			elif Input.is_action_just_pressed("parry"):
				_change_state(State.PARRY)
			elif Input.is_action_just_pressed("dodge") and _dodges_used < max_chained_dodges \
					and _state_time >= DODGE_CHAIN_MIN_TIME:
				_chain_dodge(dodge_input)
			elif _jump_pressed():
				# Salto e schivata si combinano: la schivata continua in aria come scatto.
				_jump()
				_air_dash = true
			elif dodge_input != Vector2.ZERO:
				# La schivata segue la levetta per tutta la sua durata: subito
				# all'inizio, poi curvando verso la nuova direzione.
				var wanted := dodge_input.normalized()
				if _state_time <= DODGE_STEER_TIME:
					_dodge_direction = wanted
				else:
					_dodge_direction = Vector2.from_angle(lerp_angle(_dodge_direction.angle(), wanted.angle(), minf(DODGE_TURN_RATE * delta, 1.0)))
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
			elif _jump_pressed():
				_change_state(State.NORMAL)
				_jump()
			elif Input.is_action_just_pressed("parry"):
				_change_state(State.PARRY)
			else:
				var t := _state_time / SLIDE_TIME
				_velocity = _slide_direction * _slide_speed * (1.0 - 0.7 * t)
				if _state_time >= SLIDE_TIME:
					_change_state(State.NORMAL)

		State.SLAM:
			_update_slam(input, delta)

		State.RECOIL:
			_velocity = _velocity.move_toward(Vector2.ZERO, DECELERATION * 1.5 * delta)
			if Input.is_action_just_pressed("dodge") and _dodge_cooldown == 0.0:
				_start_dodge(dodge_input)
			elif Input.is_action_just_pressed("parry"):
				_change_state(State.PARRY)
			elif _state_time >= REPEL_TIME:
				_change_state(State.NORMAL)

		State.FALL:
			_velocity = _velocity.move_toward(Vector2.ZERO, DECELERATION * delta)
			if _state_time >= FALL_TIME:
				_climb_out_of_ravine()

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
	_walk_phase += _velocity.length() * delta * WALK_CYCLE
	if torch_on:
		# La fiamma tremola.
		# La luce è un'ellisse a terra centrata sotto il personaggio.
		_torch.position = Vector2(0, -ground_elevation + RADIUS * 0.6)
		_torch.energy = TORCH_ENERGY * randf_range(0.92, 1.05)
	_squash = move_toward(_squash, 0.0, SQUASH_RECOVERY * delta)
	if _camera:
		# Mentre si precipita nel burrone la telecamera resta al bordo.
		if _state != State.FALL:
			_camera_height = lerpf(_camera_height, -ground_elevation, minf(CAMERA_HEIGHT_FOLLOW * delta, 1.0))
		var ahead := (_velocity * CAMERA_LOOK_AHEAD).limit_length(CAMERA_LOOK_AHEAD_MAX)
		if lock_target:
			# Agganciato: la telecamera tiene in vista anche il bersaglio.
			ahead = ((lock_target.global_position - global_position) * LOCK_CAMERA_SHARE).limit_length(LOCK_CAMERA_MAX)
		_look_ahead = _look_ahead.lerp(ahead, minf(CAMERA_LOOK_AHEAD_FOLLOW * delta, 1.0))
		_camera.position = Vector2(0, _camera_height) + _look_ahead
		# Il tremolio va sullo scostamento, che non viene ammorbidito.
		_shake = move_toward(_shake, 0.0, CAMERA_SHAKE_DECAY * delta)
		_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * CAMERA_SHAKE * _shake * _shake
	queue_redraw()


## Spostamento nel mondo: si sale sui blocchi più alti solo saltando
## abbastanza in alto, si scende dai gradini cadendo; gli ostacoli solidi
## fermano il personaggio, cespugli e rovi lo rallentano (ma non durante
## schivate e scivolate) e i rovi pungono.
func _move(delta: float) -> void:
	var world := World.current
	if world == null:
		position += _velocity * delta
		return
	var motion := _velocity * delta
	var grounded := not is_airborne()
	if grounded and _state != State.DODGE and _state != State.SLIDE:
		motion *= world.slow_at(position, RADIUS)
	var altitude := world.elevation_at(position) + _height
	var start := position
	position = world.move(position, motion, RADIUS * 0.8, _height, true)
	ground_elevation = world.elevation_at(position)
	# Una luce bianca nel punto in cui si tocca quello che blocca il
	# movimento (ostacoli, blocchi di terreno troppo alti da salire) e,
	# sbattendoci contro, un piccolo rimbalzo.
	world.highlight_contacts(position, RADIUS * 0.8, altitude)
	_bounce(motion - (position - start), delta)
	# L'altezza dal terreno cambia con il terreno sotto: scendendo da un
	# gradino si cade, salendo su un blocco si atterra sopra.
	_height = altitude - ground_elevation
	if (grounded and absf(_height) <= World.STEP_TOLERANCE) or _height < 0.0:
		_height = 0.0
		if _height_velocity <= 0.0:
			_land()
	# Burroni: chi scende sotto il bordo precipita; a terra altrove si
	# ricorda il punto sicuro per riapparire.
	if world.kind_of(World.cell_at(position)) == World.Kind.RAVINE:
		if _state not in [State.FALL, State.DEAD] and altitude() < _safe_altitude - FALL_DEPTH:
			_fall_into_ravine()
	elif not is_airborne():
		_safe_position = position
		_safe_altitude = ground_elevation
	var thorns := world.ground_obstacle_at(position, RADIUS) if grounded else {}
	if not thorns.is_empty() and thorns["damage"] > 0:
		_thorns_time += delta
		if _thorns_time >= thorns["damage_interval"]:
			_thorns_time -= thorns["damage_interval"]
			_scratch(thorns["damage"])
	else:
		# Appena entrati nei rovi la prima puntura arriva dopo un attimo.
		_thorns_time = THORNS_FIRST_DELAY


## Urto: la parte del movimento fermata da un ostacolo o da una parete fa
## rimbalzare indietro di poco, se ci si andava contro abbastanza veloci
## (così spingendo contro un muro non si rimbalza di continuo).
func _bounce(blocked: Vector2, delta: float) -> void:
	if _state != State.NORMAL or delta <= 0.0:
		return
	var impact := blocked.length() / delta
	if impact < BOUNCE_MIN_SPEED:
		return
	var away := -blocked / blocked.length()
	_velocity += away * (maxf(_velocity.dot(-away), 0.0) + minf(impact * BOUNCE_FACTOR, BOUNCE_MAX_SPEED))


## Spinta senza passare attraverso dirupi e ostacoli.
func _push(offset: Vector2) -> void:
	position = World.current.move(position, offset, RADIUS * 0.8) if World.current else position + offset


## Puntura dei rovi: toglie vita senza spinta né interruzioni.
func _scratch(damage: int) -> void:
	if _state == State.DEAD or _invulnerable_time > 0.0:
		return
	health = maxi(health - damage, 0)
	health_changed.emit(health, max_health)
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
	if _state == State.ATTACK and _air_attack and _height_velocity < 0.0:
		gravity *= AIR_ATTACK_GRAVITY_FACTOR
	if _state == State.SLAM and not _slam_landed:
		gravity = 0.0 if _slam_kind != "leap" and _state_time < SLAM_HANG else SLAM_GRAVITY
	_height_velocity -= gravity * delta
	_height += _height_velocity * delta
	if _height <= 0.0:
		# Più forte la caduta, più il corpo si schiaccia atterrando.
		_squash = clampf(-_height_velocity / 900.0, 0.0, 1.0)
		_height = 0.0
		_land()


func _land() -> void:
	_height_velocity = 0.0
	_jumps_used = 0
	if _state == State.SLAM and not _slam_landed:
		_slam_impact()


## Avanzamento dell'attacco in corso: affondo, colpo, combo e recupero.
func _update_attack(input: Vector2, delta: float) -> void:
	var windup := (HEAVY_WINDUP if _attack_heavy else ATTACK_WINDUP) / _attack_speed
	var active := (HEAVY_ACTIVE if _attack_heavy else ATTACK_ACTIVE) / _attack_speed
	var recovery := _attack_recovery() / _attack_speed
	if _charging:
		# Finché si tiene premuto, il colpo potente resta in carica.
		if Input.is_action_pressed("heavy_attack") and _state_time >= windup * 0.9:
			var was_full := _charge >= 1.0
			_charge = minf(_charge + delta / HEAVY_CHARGE_TIME, 1.0)
			_state_time = windup * 0.9
			if _charge >= 1.0 and not was_full:
				Sfx.play("charge_full", global_position)
		elif not Input.is_action_pressed("heavy_attack"):
			_charging = false
	# Lo slancio di una scivolata si esaurisce durante l'attacco.
	_carry_velocity = _carry_velocity.move_toward(Vector2.ZERO, DECELERATION * delta)
	# Mentre si attacca ci si può muovere (più piano) in qualsiasi
	# direzione; il colpo resta nella direzione in cui è partito, con un
	# piccolo affondo in avanti.
	_walk_velocity = _accelerate(_walk_velocity, input * walk_speed() * ATTACK_MOVE_FACTOR, delta)
	var lunge := Vector2.ZERO
	# Durante la carica del colpo potente si resta fermi sul posto (ci si
	# può solo spostare piano); l'affondo parte al rilascio.
	if _state_time >= windup * 0.5 and _state_time < windup + active and not _charging:
		lunge = facing * (HEAVY_LUNGE_SPEED if _attack_heavy else ATTACK_LUNGE_SPEED * (1.0 + 0.2 * (_combo_step - 1)))
	_velocity = _walk_velocity + lunge + _carry_velocity
	# Si memorizza la pressione solo se può davvero continuare la combo:
	# alla fine della combo le pressioni in più vengono ignorate.
	if Input.is_action_just_pressed("heavy_attack") and _can_chain_heavy():
		_queued_attack = "heavy"
	elif _can_chain_attack() and (Input.is_action_just_pressed("attack") \
			or (Input.is_action_pressed("attack") and _queued_attack == "" and _state_time >= windup)):
		# Tenendo premuto il tasto, il colpo successivo parte da solo.
		_queued_attack = "attack"
	if not _attack_resolved and _state_time >= windup:
		_attack_resolved = true
		_resolve_attack()
		# Parato dalla guardia di un nemico: si è stati respinti.
		if _state != State.ATTACK:
			return
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
		_velocity = _walk_velocity
		_change_state(State.NORMAL)


func _end_combo() -> void:
	_combo_step = 0
	_heavy_step = 0
	_combo_timer = 0.0
	_queued_attack = ""


## Un nemico colpisce il giocatore. Restituisce l'esito, così il nemico
## può reagire (per esempio restare stordito dopo una parata perfetta).
func receive_hit(from: Vector2, damage: int) -> String:
	if _state in [State.DEAD, State.FALL] or _invulnerable_time > 0.0:
		return "ignored"
	if (_state == State.DODGE and _state_time <= DODGE_INVULNERABLE_TIME) \
			or (_state == State.SLIDE and _state_time <= SLIDE_INVULNERABLE_TIME):
		return "dodged"
	# Sopra il nemico (saltando o su un gradino più alto) il colpo passa sotto.
	var attacker_height := World.current.elevation_at(from) if World.current else 0.0
	var above := altitude() - attacker_height
	if above > JUMP_EVADE_HEIGHT:
		if not is_airborne():
			return "ignored"
		return "dodged"
	if above < -HIT_HEIGHT_REACH:
		return "ignored"

	var to_attacker := (from - global_position).normalized()
	if _state == State.PARRY and absf(facing.angle_to(to_attacker)) <= PARRY_ARC / 2.0:
		_block_flash = 0.2
		if _state_time <= PERFECT_PARRY_WINDOW:
			_empowered_time = EMPOWER_TIME
			Sfx.play("perfect", global_position)
			return "parried"
		_push(-to_attacker * 12.0)
		Sfx.play("block", global_position)
		return "blocked"

	if shield_active:
		# Lo scudo assorbe un colpo da qualsiasi direzione e poi si rompe.
		shield_active = false
		_invulnerable_time = 0.3
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


## Risatina da goblin, per esempio dopo aver sconfitto un boss.
func laugh() -> void:
	Sfx.play("giggle", global_position)


## Salto richiesto: vicino a un elemento con cui interagire, il tasto che
## salta e interagisce insieme (A) serve a interagire (vedi Game).
func _jump_pressed() -> bool:
	return Input.is_action_just_pressed("jump") and not (can_interact and Input.is_action_just_pressed("interact"))


## L'attacco è in corso (i nemici possono alzare la guardia).
func is_attacking() -> bool:
	return _state == State.ATTACK


## Un nemico in guardia (in from) ha parato il colpo: la combo si
## interrompe e si viene respinti indietro, con un lampo e un suono di metallo.
func _repel(from: Vector2) -> void:
	_end_combo()
	_charging = false
	_carry_velocity = Vector2.ZERO
	_velocity = (global_position - from).normalized() * REPEL_SPEED
	_shake = maxf(_shake, 0.35)
	_change_state(State.RECOIL)
	Sfx.play("block", global_position)
	HitFeedback.hit(get_tree(), 0.07)


## Completamente fermo, a terra e senza fare niente: si può salvare.
func is_still() -> bool:
	return _state == State.NORMAL and not is_airborne() and _velocity.length() < 5.0


func _fall_into_ravine() -> void:
	_end_combo()
	lock_target = null
	_change_state(State.FALL)
	Sfx.play("jump", global_position, 0.5, -4.0)


## Dopo la caduta si riappare sul bordo, perdendo un po' di vita.
func _climb_out_of_ravine() -> void:
	teleport(_safe_position)
	var data: Dictionary = World.DATA.data["terrain"]
	health = maxi(health - int(data["ravine_damage"]), 0)
	health_changed.emit(health, max_health)
	if health == 0:
		_change_state(State.DEAD)
		Sfx.play("death", global_position)
		died.emit()
	else:
		_invulnerable_time = HURT_INVULNERABLE_TIME
		Sfx.play("hurt", global_position)


## Spostamento istantaneo (entrando o uscendo da una caverna, caricando una
## partita): niente scie, slanci o telecamera che insegue da lontano.
func teleport(at: Vector2) -> void:
	position = at
	_velocity = Vector2.ZERO
	_walk_velocity = Vector2.ZERO
	_carry_velocity = Vector2.ZERO
	_height = 0.0
	_height_velocity = 0.0
	_change_state(State.NORMAL)
	ground_elevation = World.current.elevation_at(at) if World.current else 0.0
	_safe_position = at
	_safe_altitude = ground_elevation
	reset_physics_interpolation()
	if _camera:
		_camera_height = -ground_elevation
		_look_ahead = Vector2.ZERO
		_camera.position = Vector2(0, _camera_height)
		_camera.reset_physics_interpolation()
		_camera.reset_smoothing()


## Aggancia il nemico più vicino; se ce n'è già uno passa al successivo
## per distanza, e se non ce ne sono altri sgancia.
func _cycle_lock() -> void:
	var candidates := _lock_candidates()
	if candidates.is_empty():
		lock_target = null
	elif lock_target == null or not candidates.has(lock_target):
		lock_target = candidates[0]
	elif candidates.size() == 1:
		lock_target = null
	else:
		lock_target = candidates[(candidates.find(lock_target) + 1) % candidates.size()]
	_lock_marker.target = lock_target
	Sfx.play_ui("ui_move" if lock_target else "ui_confirm")


## Nemici vivi entro LOCK_RANGE, dal più vicino.
func _lock_candidates() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy and not enemy.is_dead() and enemy.global_position.distance_to(global_position) <= LOCK_RANGE:
			result.append(enemy)
	result.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
	return result


## Se il bersaglio muore si passa al più vicino; se si allontana troppo si sgancia.
func _update_lock() -> void:
	if lock_target == null:
		return
	if not is_instance_valid(lock_target) or lock_target.is_dead():
		var candidates := _lock_candidates()
		lock_target = candidates[0] if not candidates.is_empty() else null
	elif lock_target.global_position.distance_to(global_position) > LOCK_BREAK_RANGE:
		lock_target = null
	_lock_marker.target = lock_target


## Con un bersaglio agganciato si guarda verso di lui. Restituisce true se
## c'è un bersaglio.
func _face_lock() -> bool:
	if lock_target == null:
		return false
	var to_target := lock_target.global_position - global_position
	if to_target.length() > 1.0:
		_target_facing = to_target.normalized()
	return true


## Stato da salvare: livello, caratteristiche, potenziamenti e inventario.
func save_state() -> Dictionary:
	return {
		"level": level, "experience": experience, "health": health, "base_max_health": _base_max_health,
		"mana": mana, "base_max_mana": _base_max_mana, "potions": potions, "max_potions": max_potions,
		"mana_potions": mana_potions, "max_mana_potions": max_mana_potions, "spell_bonus": spell_bonus,
		"max_combo_hits": max_combo_hits, "max_heavy_chain": max_heavy_chain,
		"max_chained_dodges": max_chained_dodges, "max_jumps": max_jumps, "run_speed_bonus": run_speed_bonus,
		"shield_cooldown_max": shield_cooldown_max, "torch_on": torch_on, "upgrades_taken": upgrades_taken,
		"items": inventory.items, "equipped": inventory.equipped, "gold": inventory.gold, "learned": inventory.learned,
	}


## Ripristina lo stato salvato (i numeri dal JSON arrivano come decimali).
## I campi mancanti (salvataggi di versioni precedenti) restano come sono.
func load_state(data: Dictionary) -> void:
	level = int(data.get("level", level))
	experience = int(data.get("experience", experience))
	_base_max_health = int(data.get("base_max_health", _base_max_health))
	_base_max_mana = float(data.get("base_max_mana", _base_max_mana))
	potions = int(data.get("potions", potions))
	max_potions = int(data.get("max_potions", max_potions))
	mana_potions = int(data.get("mana_potions", mana_potions))
	max_mana_potions = int(data.get("max_mana_potions", max_mana_potions))
	spell_bonus = float(data.get("spell_bonus", spell_bonus))
	max_combo_hits = int(data.get("max_combo_hits", max_combo_hits))
	max_heavy_chain = int(data.get("max_heavy_chain", max_heavy_chain))
	max_chained_dodges = int(data.get("max_chained_dodges", max_chained_dodges))
	max_jumps = int(data.get("max_jumps", max_jumps))
	run_speed_bonus = float(data.get("run_speed_bonus", run_speed_bonus))
	shield_cooldown_max = float(data.get("shield_cooldown_max", shield_cooldown_max))
	torch_on = bool(data.get("torch_on", torch_on))
	_torch.enabled = torch_on
	upgrades_taken.clear()
	var taken: Dictionary = data.get("upgrades_taken", {})
	for key: String in taken:
		upgrades_taken[key] = int(taken[key])
	# Le schivate di partenza sono cambiate (da 2 a 1): si ricalcolano dai
	# potenziamenti scelti, se il salvataggio li ha.
	if data.has("upgrades_taken"):
		max_chained_dodges = START_CHAINED_DODGES + int(upgrades_taken.get("dodge", 0))
	# Oggetti che questa versione non conosce più vengono scartati.
	inventory.items.clear()
	var known: Dictionary = Items.DATA.data["items"]
	var kept := {}
	var saved_items: Array = data.get("items", [])
	for k in saved_items.size():
		if known.has(saved_items[k]):
			kept[k] = inventory.items.size()
			inventory.items.append(saved_items[k])
	inventory.equipped.clear()
	var equipped: Dictionary = data.get("equipped", {})
	for slot: String in equipped:
		if kept.has(int(equipped[slot])):
			inventory.equipped[slot] = kept[int(equipped[slot])]
	inventory.gold = int(data.get("gold", inventory.gold))
	inventory.learned = (data.get("learned", {}) as Dictionary).duplicate()
	_refresh_stats()
	health = clampi(int(data.get("health", max_health)), 1, max_health)
	mana = clampf(float(data.get("mana", max_mana)), 0.0, max_mana)
	health_changed.emit(health, max_health)
	experience_changed.emit(experience, experience_needed(), level)


func is_empowered() -> bool:
	return _empowered_time > 0.0


## Secondi rimasti del potenziamento della parata perfetta.
func empowered_time() -> float:
	return _empowered_time


## Altezza dei piedi sullo schermo: terreno più salto.
func altitude() -> float:
	return ground_elevation + _height


func is_airborne() -> bool:
	return _height > 0.0


## Velocità del passo, con il bonus degli stivali.
func walk_speed() -> float:
	return SPEED * (1.0 + inventory.bonus("speed"))


func run_speed() -> float:
	return walk_speed() * RUN_SPEED_FACTOR * (1.0 + run_speed_bonus)


## Danni della palla di fuoco.
func spell_damage() -> int:
	var base := FIREBALL_DAMAGE + FIREBALL_DAMAGE_PER_LEVEL * (level - 1)
	return roundi(base * (1.0 + spell_bonus + inventory.bonus("spell")))


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
			_base_max_health += 1
			health += 1
			_refresh_stats()
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
		"mana":
			_base_max_mana += MANA_UPGRADE
			mana += MANA_UPGRADE
			_refresh_stats()
		"spell":
			spell_bonus += SPELL_UPGRADE


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


func _start_heavy(input: Vector2) -> void:
	# In aria il colpo potente fa piombare a terra.
	if is_airborne():
		_start_slam("plunge", input)
		return
	# Fuori dalla combo il colpo potente parte da solo, senza bonus.
	if _combo_timer == 0.0 and _state not in [State.ATTACK, State.SLAM]:
		_combo_step = 0
		_heavy_step = 0
	if _heavy_step >= max_heavy_chain:
		_heavy_step = 0
		_combo_step = 0
	_heavy_step += 1
	# Dopo una combo di colpi normali il colpo potente diventa un salto con
	# colpo sul terreno (anche i colpi potenti concatenati dopo).
	if _combo_step >= SLAM_MIN_COMBO and not is_airborne():
		_start_slam("leap", input)
		return
	_attack_heavy = true
	_begin_attack(input)
	_charging = true
	Sfx.play("heavy_swing", global_position, 1.0 + 0.08 * (_heavy_step - 1))


func _begin_attack(input: Vector2) -> void:
	_attack_speed = EMPOWER_ATTACK_SPEED if is_empowered() else 1.0
	_charge = 0.0
	_charging = false
	_air_attack = is_airborne()
	attack_serial += 1
	if _state != State.ATTACK:
		_walk_velocity = _velocity.limit_length(walk_speed() * ATTACK_MOVE_FACTOR)
		# In aria lo slancio del salto (o dello scatto) continua e si esaurisce piano.
		if _air_attack:
			_carry_velocity = _velocity - _walk_velocity
	# I fendenti si alternano: una volta da sinistra, una da destra; i colpi
	# normali a terra cambiano movimento a ogni colpo.
	_swing_sign = -_swing_sign
	if not _attack_heavy and not _air_attack:
		_attack_style = (_attack_style + 1) % ATTACK_STYLES.size()
	_queued_attack = ""
	_attack_resolved = false
	_combo_timer = 0.0
	# Si attacca subito nella direzione indicata (o verso il bersaglio
	# agganciato), senza aspettare la rotazione.
	if input != Vector2.ZERO:
		_target_facing = input.normalized()
		facing = _target_facing
	if _face_lock():
		facing = _target_facing
	_change_state(State.ATTACK)


## Colpo successivo: continua la combo se c'è ancora tempo, altrimenti
## ricomincia (anche dopo un colpo potente o dopo l'ultimo colpo).
func _next_combo_step() -> int:
	var continues := _combo_timer > 0.0 and _heavy_step == 0 and _combo_step < max_combo_hits
	return _combo_step + 1 if continues else 1


## Inizia un attacco a terra: salto (leap) o sosta in aria prima di
## piombare giù (plunge, dash).
func _start_slam(kind: String, input: Vector2) -> void:
	_slam_kind = kind
	_slam_landed = false
	_attack_heavy = kind == "leap"
	_attack_speed = EMPOWER_ATTACK_SPEED if is_empowered() else 1.0
	_charge = 0.0
	_charging = false
	_queued_attack = ""
	_combo_timer = 0.0
	_carry_velocity = Vector2.ZERO
	if kind == "dash":
		_target_facing = _dodge_direction
	elif input != Vector2.ZERO:
		_target_facing = input.normalized()
	if kind != "dash":
		_face_lock()
	facing = _target_facing
	if kind == "leap":
		_height_velocity = SLAM_LEAP_SPEED
		Sfx.play("jump", global_position, 0.8)
	else:
		_height_velocity = 0.0
	Sfx.play("heavy_swing", global_position, 0.85)
	_change_state(State.SLAM)


## Attacco a terra: salita (o sosta in aria), discesa e, toccato terra,
## l'impatto (vedi _land); poi un breve recupero. Si può già chiedere il
## colpo potente successivo della catena.
func _update_slam(input: Vector2, delta: float) -> void:
	if Input.is_action_just_pressed("heavy_attack") and _slam_kind == "leap" and _can_chain_heavy():
		_queued_attack = "heavy"
	if not _slam_landed:
		if _slam_kind != "leap" and _state_time >= SLAM_HANG and _height_velocity > -SLAM_DIVE_SPEED:
			_height_velocity = -SLAM_DIVE_SPEED
		# In aria ci si sposta piano; lo scatto continua nella sua direzione.
		var target := input * walk_speed() * ATTACK_MOVE_FACTOR
		if _slam_kind == "dash":
			target = _dodge_direction * DODGE_SPEED * 0.45
		elif _slam_kind == "leap":
			target += facing * SLAM_LEAP_FORWARD
		_velocity = _velocity.move_toward(target, ACCELERATION_FULL * delta)
		if _state_time >= SLAM_MAX_TIME:
			_slam_impact()
		return
	_velocity = _velocity.move_toward(Vector2.ZERO, DECELERATION * 2.0 * delta)
	if _state_time < SLAM_RECOVERY / _attack_speed:
		return
	if _queued_attack == "heavy":
		_start_heavy(input)
		return
	if _slam_kind == "leap" and _can_chain_heavy():
		_combo_timer = COMBO_WINDOW
	else:
		_end_combo()
	_change_state(State.NORMAL)


## Il colpo tocca terra: danni a tutti i nemici nel raggio, onda d'urto,
## un attimo di fermo e la telecamera che trema.
func _slam_impact() -> void:
	_slam_landed = true
	_state_time = 0.0
	_squash = 1.0
	_shake = 1.0
	var radius: float = SLAM_RADIUS[_slam_kind]
	var damage := _slam_damage()
	var landed := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead() or absf(enemy.ground_elevation - ground_elevation) > HIT_HEIGHT_REACH:
			continue
		var offset := enemy.global_position - global_position
		if offset.length() > radius + enemy.radius:
			continue
		var direction := offset.normalized() if offset != Vector2.ZERO else facing
		enemy.take_damage(damage, direction, true)
		HitSpark.spawn(get_parent(), enemy.global_position - direction * enemy.radius * 0.8, enemy.ground_elevation + enemy.radius * 0.5, 40.0, COLOR_HEAVY)
		landed = true
	GroundFx.shockwave(global_position, ground_elevation, radius)
	Sfx.play("fireball_hit", global_position, 0.6)
	if landed:
		Sfx.play("hit", global_position, 0.7)
		HitFeedback.hit(get_tree(), 0.14)


func _slam_damage() -> int:
	if _slam_kind == "leap":
		return roundi(_attack_damage() * SLAM_LEAP_DAMAGE_FACTOR)
	var multiplier := PLUNGE_DAMAGE_FACTOR if _slam_kind == "plunge" else DASH_SLAM_DAMAGE_FACTOR
	if _attack_speed > 1.0:
		multiplier *= EMPOWER_DAMAGE_FACTOR
	return roundi(base_damage() * multiplier * (1.0 + inventory.bonus("damage")))


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
	# Senza direzione a terra si rotola all'indietro; in aria si scatta in avanti.
	_set_air_dash()
	_dodge_direction = input.normalized() if input != Vector2.ZERO else (facing if _air_dash else -facing)
	_dodges_used = 1
	_carry_velocity = Vector2.ZERO
	_combo_step = 0
	_heavy_step = 0
	Sfx.play("dodge", global_position)
	_change_state(State.DODGE)


## In aria la schivata è uno scatto: si smette di cadere e si scivola nell'aria.
func _set_air_dash() -> void:
	_air_dash = is_airborne()
	if _air_dash:
		_height_velocity = maxf(_height_velocity, 0.0)


## Schivata concatenata: riparte a piena velocità, nella nuova direzione.
func _chain_dodge(input: Vector2) -> void:
	_dodges_used += 1
	_set_air_dash()
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
	Sfx.play("potion", global_position)


func _drink_mana_potion() -> void:
	if mana_potions == 0 or mana >= max_mana:
		return
	mana_potions -= 1
	mana = minf(mana + MANA_POTION_RESTORE, max_mana)
	Sfx.play("mana_potion", global_position)


## Palla di fuoco verso dove si guarda (o si punta la levetta): poi
## insegue da sola il nemico più vicino.
func _cast_fireball(input: Vector2) -> void:
	if _spell_cooldown > 0.0:
		return
	if mana < SPELL_COST:
		_spell_cooldown = SPELL_COOLDOWN
		return
	mana -= SPELL_COST
	_spell_cooldown = SPELL_COOLDOWN
	var fireball := Fireball.new()
	fireball.direction = input.normalized() if input != Vector2.ZERO else facing
	if lock_target:
		fireball.target = lock_target
		fireball.direction = (lock_target.global_position - global_position).normalized()
	fireball.damage = spell_damage()
	fireball.altitude = ground_elevation
	fireball.position = position + fireball.direction * RADIUS
	get_parent().add_child(fireball)
	Sfx.play("fireball", global_position)


## Raccoglie un oggetto: le monete vanno nel borsello, le pozioni nella
## cintura se c'è posto, il resto nell'inventario.
func pickup(id: String, amount := 1) -> void:
	match id:
		"gold":
			inventory.gold += amount
			Sfx.play("coin", global_position)
			return
		"potion_health":
			if potions < max_potions:
				potions += 1
				Sfx.play("pickup", global_position)
				return
		"potion_mana":
			if mana_potions < max_mana_potions:
				mana_potions += 1
				Sfx.play("pickup", global_position)
				return
	inventory.add(id)
	Sfx.play("pickup", global_position)


## Usa un oggetto dell'inventario: indossa o toglie l'equipaggiamento,
## legge i libri (bonus permanente), beve le pozioni.
func use_item(index: int) -> void:
	var id := inventory.items[index]
	match Items.category(id):
		"book":
			inventory.learn(id)
			inventory.remove(index)
			Sfx.play("level_up", global_position, 1.3)
		"potion":
			var heal := int(Items.stat(id, "heal"))
			var restore := Items.stat(id, "restore_mana")
			if (heal > 0 and health >= max_health) or (restore > 0.0 and mana >= max_mana):
				return
			health = mini(health + heal, max_health)
			mana = minf(mana + restore, max_mana)
			health_changed.emit(health, max_health)
			inventory.remove(index)
			Sfx.play("potion" if heal > 0 else "mana_potion", global_position)
		_:
			inventory.toggle_equip(index)
			Sfx.play("block", global_position, 1.4, -8.0)
	_refresh_stats()


## Ricalcola vita e mana massimi con equipaggiamento e libri.
func _refresh_stats() -> void:
	var old_max_health := max_health
	max_health = _base_max_health + int(inventory.bonus("health"))
	health = clampi(health + maxi(max_health - old_max_health, 0), 1 if health > 0 else 0, max_health)
	var old_max_mana := max_mana
	max_mana = _base_max_mana + inventory.bonus("mana")
	mana = clampf(mana + maxf(max_mana - old_max_mana, 0.0), 0.0, max_mana)
	health_changed.emit(health, max_health)


func _raise_shield() -> void:
	if shield_active or shield_cooldown > 0.0:
		return
	shield_active = true
	shield_cooldown = shield_cooldown_max
	Sfx.play("shield_up", global_position)


func _attack_range() -> float:
	if _attack_heavy:
		return HEAVY_RANGE
	return ATTACK_RANGE


func _attack_arc() -> float:
	if _attack_heavy:
		return HEAVY_ARC
	if _air_attack:
		return AIR_ATTACK_ARC
	return ATTACK_ARC


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
	# Carica del colpo potente (fino al doppio) e bonus dell'arma.
	multiplier *= (1.0 + _charge) * (1.0 + inventory.bonus("damage"))
	return roundi(base_damage() * multiplier)


func _resolve_attack() -> void:
	var damage := _attack_damage()
	var heavy := _attack_heavy or _combo_step >= max_combo_hits
	var landed := false
	# In aria si arriva anche ai nemici sotto di sé.
	var reach_below := AIR_ATTACK_REACH if _air_attack or is_airborne() else HIT_HEIGHT_REACH
	var blocked_by: Enemy = null
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var rise := altitude() - enemy.ground_elevation
		if rise < -HIT_HEIGHT_REACH or rise > reach_below:
			continue
		var offset := enemy.global_position - global_position
		if offset.length() > _attack_range() + enemy.radius:
			continue
		# A contatto si colpisce sempre, altrimenti serve essere girati verso il nemico.
		if offset.length() <= RADIUS + enemy.radius or absf(facing.angle_to(offset)) <= _attack_arc() / 2.0:
			if enemy.blocks(global_position):
				# La guardia para il colpo: lampo nel punto d'incontro.
				blocked_by = enemy
				HitSpark.spawn(get_parent(), enemy.global_position - offset.normalized() * (enemy.radius + 10.0),
						enemy.ground_elevation + enemy.radius * 0.9, 56.0, COLOR_GUARD_SPARK)
				continue
			enemy.take_damage(damage, offset.normalized(), heavy)
			landed = true
			# Scintilla nel punto di contatto, sul lato del nemico rivolto verso di noi.
			var contact := enemy.global_position - offset.normalized() * enemy.radius * 0.8
			HitSpark.spawn(get_parent(), contact, enemy.ground_elevation + enemy.radius * 0.9,
					40.0 if _attack_heavy else 28.0, COLOR_HEAVY if _attack_heavy else COLOR_SLASH)
	if blocked_by:
		_repel(blocked_by.global_position)
	if landed:
		Sfx.play("hit", global_position, 0.8 if _attack_heavy else 1.0 + 0.1 * (_combo_step - 1))
		# Un attimo di fermo: si sente il colpo (più lungo per il colpo potente).
		if _attack_heavy:
			HitFeedback.hit(get_tree(), 0.12 + 0.05 * _charge)
		else:
			HitFeedback.hit(get_tree(), 0.1 if _combo_step >= max_combo_hits else 0.09)


func _draw() -> void:
	var body := COLOR_BODY
	if _state == State.DEAD:
		body = COLOR_DEAD
	elif _state == State.HURT:
		body = COLOR_HURT
	# Lampeggia mentre è invulnerabile dopo un colpo.
	if _invulnerable_time > 0.0 and int(_invulnerable_time * 12.0) % 2 == 0:
		body.a = 0.35
	# Precipitando in un burrone svanisce nel buio.
	self_modulate.a = 1.0 - clampf(_state_time / FALL_TIME, 0.0, 1.0) if _state == State.FALL else 1.0

	# L'ombra resta a terra e si rimpicciolisce durante il salto; tutto il
	# resto sale con il personaggio. In scivolata il corpo si schiaccia.
	var shadow_scale := clampf(1.0 - _height / 160.0, 0.5, 1.0)
	Shapes.disc(self, Vector2(0, RADIUS * 0.8 - ground_elevation), RADIUS * 0.9 * shadow_scale, Color(0, 0, 0, 0.25))
	var body_scale := Vector2(1.2, 0.6) if _state == State.SLIDE else Vector2.ONE
	var lift := -altitude() + (RADIUS * 0.4 if _state == State.SLIDE else 0.0)
	draw_set_transform(Vector2(0, lift), 0.0, body_scale)
	# Gambe: camminano quando ci si muove, raccolte in aria e in scivolata.
	var walking := _velocity.length() > 20.0 and not is_airborne() and _state != State.DEAD
	var rolling := _state == State.DODGE and not _air_dash
	var dashing := _state == State.DODGE and _air_dash
	if dashing:
		# Scatto in aria: immagini che restano indietro lungo la traiettoria.
		for k in range(AIR_DASH_TRAIL, 0, -1):
			Shapes.disc(self, -_dodge_direction * k * 16.0 + Vector2(0, -LEG_LENGTH), RADIUS * (1.0 - 0.15 * k), Color(body, 0.35 / k))
	if _state != State.SLIDE and not rolling:
		var foot_y := RADIUS * 0.85 - (6.0 if is_airborne() else 0.0)
		BodyParts.draw_legs(self, -LEG_LENGTH + RADIUS * 0.55, foot_y, 8.0, 6.0, _walk_phase,
				_velocity.normalized(), STRIDE if walking else 0.0, body.darkened(0.35))
	# Il corpo ondeggia camminando, si inclina nella direzione di corsa, si
	# allunga salendo e si schiaccia atterrando.
	var bob := absf(sin(_walk_phase)) * 2.5 if walking else 0.0
	var lean := clampf(_velocity.x / run_speed(), -1.0, 1.0) * LEAN_ANGLE if _state != State.DEAD else 0.0
	var squash := Vector2(1.0 + SQUASH_AMOUNT * _squash, 1.0 - SQUASH_AMOUNT * _squash)
	if _height_velocity > 200.0:
		squash = Vector2(0.92, 1.08)
	var rotation_angle := lean
	var body_lift := lift - LEG_LENGTH - bob
	if rolling:
		# Capriola: il corpo raccolto fa un giro completo nel verso del movimento.
		var t := clampf(_state_time / DODGE_TIME, 0.0, 1.0)
		rotation_angle = TAU * ease(t, 0.7) * (1.0 if _dodge_direction.x >= 0.0 else -1.0)
		body_lift = lift - LEG_LENGTH * ROLL_CURL
		squash = Vector2(1.05, 0.92)
	elif dashing:
		squash = Vector2(1.15, 0.88)
	var pose := _attack_body_pose()
	rotation_angle += pose[0]
	squash *= pose[1]
	draw_set_transform(Vector2(0, body_lift), rotation_angle, body_scale * squash)

	# Aura del potenziamento, corpo e "naso" che indica la direzione.
	if is_empowered() and _state != State.DEAD:
		var pulse := 0.5 + 0.5 * sin(_empowered_time * 10.0)
		Shapes.disc(self, Vector2.ZERO, RADIUS + 8.0 + pulse * 4.0, Color(COLOR_EMPOWERED, 0.25))
		draw_arc(Vector2.ZERO, RADIUS + 8.0 + pulse * 4.0, 0.0, TAU, 32, Color(COLOR_EMPOWERED, 0.8), 2.0)
	Shapes.disc(self, Vector2.ZERO, RADIUS, body)
	var tip := facing * (RADIUS + 12.0)
	var side := facing.orthogonal() * 9.0
	draw_primitive(PackedVector2Array([tip, facing * RADIUS * 0.6 + side, facing * RADIUS * 0.6 - side]), PackedColorArray([body.darkened(0.3)]), PackedVector2Array())

	if _state != State.DEAD:
		_draw_sword()
		if torch_on:
			_draw_torch()

	# Scudo attivo: una bolla attorno al personaggio.
	if shield_active and _state != State.DEAD:
		Shapes.disc(self, Vector2.ZERO, RADIUS + 16.0, Color(COLOR_BUBBLE, 0.15))
		draw_arc(Vector2.ZERO, RADIUS + 16.0, 0.0, TAU, 40, Color(COLOR_BUBBLE, 0.7), 2.5)
	draw_set_transform(Vector2.ZERO)


## Spada: a riposo è tenuta di lato; nell'attacco si porta indietro durante
## la carica e poi fende l'arco del colpo, alternando il verso a ogni
## attacco, lasciando una scia.
func _draw_sword() -> void:
	var tint := Color.WHITE
	if inventory.equipped.has("weapon"):
		tint = Items.color(inventory.items[inventory.equipped["weapon"]]).lightened(0.3)
	if is_empowered():
		tint = Color(1.0, 0.95, 0.7)
	if _state == State.SLAM:
		_draw_slam_sword(tint)
		return
	if _state == State.PARRY:
		# In parata la spada è di traverso davanti al corpo: si illumina
		# all'inizio (quando la parata sarebbe perfetta) e quando para un colpo.
		var across := -facing.orthogonal()
		var center := facing * RADIUS * 0.95
		if _state_time <= PERFECT_PARRY_WINDOW or _block_flash > 0.0:
			Shapes.disc(self, center, 14.0, Color(COLOR_SHIELD, 0.45))
			tint = Color(1.3, 1.3, 1.4)
		BodyParts.draw_sword(self, center - across * SWORD_LENGTH * 0.45, across.angle(), SWORD_LENGTH, SWORD_WIDTH, tint)
		return
	if _state != State.ATTACK:
		var rest := facing.angle() + 0.6
		BodyParts.draw_sword(self, facing.orthogonal() * RADIUS * 0.8, rest, SWORD_LENGTH, SWORD_WIDTH, tint)
		return
	if not _attack_heavy and not _air_attack:
		_draw_attack_sword(tint)
		return
	var windup := (HEAVY_WINDUP if _attack_heavy else ATTACK_WINDUP) / _attack_speed
	var active := (HEAVY_ACTIVE if _attack_heavy else ATTACK_ACTIVE) / _attack_speed
	var arc := _attack_arc()
	var start := facing.angle() - _swing_sign * arc / 2.0
	var end := facing.angle() + _swing_sign * arc / 2.0
	var angle := end
	if _state_time < windup:
		# Carica: la spada si porta un po' più indietro.
		angle = start - _swing_sign * 0.35 * _state_time / windup
		if _attack_heavy:
			draw_arc(Vector2.ZERO, RADIUS + 6.0, facing.angle() - arc / 2.0, facing.angle() + arc / 2.0, 24, Color(COLOR_HEAVY, _state_time / windup), 4.0)
			if _charge > 0.0:
				# Carica: un anello che si riempie e diventa bianco al massimo.
				var ring := Color.WHITE if _charge >= 1.0 else COLOR_HEAVY
				draw_arc(Vector2.ZERO, RADIUS + 14.0, -PI / 2.0, -PI / 2.0 + TAU * _charge, 32, ring, 4.0)
	elif _state_time < windup + active:
		angle = lerpf(start, end, ease((_state_time - windup) / active, 0.6))
		var slash := COLOR_HEAVY if _attack_heavy else COLOR_SLASH
		if _attack_speed > 1.0:
			slash = COLOR_EMPOWERED
		# I colpi successivi della combo hanno una scia più accesa.
		var alpha := 0.85 if _attack_heavy else 0.5 + 0.15 * (_combo_step - 1)
		BodyParts.draw_trail(self, Vector2.ZERO, start, angle, RADIUS + 6.0, _attack_range() + RADIUS, Color(slash, minf(alpha, 0.9)))
	var length := HEAVY_SWORD_LENGTH if _attack_heavy else SWORD_LENGTH
	BodyParts.draw_sword(self, Vector2.from_angle(angle) * RADIUS * 0.8, angle, length, SWORD_WIDTH * (1.3 if _attack_heavy else 1.0), tint)


## Colpo normale a terra: carica (la spada si porta indietro e la punta
## luccica), colpo con la scia e accompagnamento che si spegne tornando in
## guardia. Il movimento cambia a ogni colpo (ATTACK_STYLES), l'area colpita
## è sempre la stessa, mostrata da un velo chiaro mentre si colpisce.
func _draw_attack_sword(tint: Color) -> void:
	var windup := ATTACK_WINDUP / _attack_speed
	var active := ATTACK_ACTIVE / _attack_speed
	var recovery := _attack_recovery() / _attack_speed
	var phase := 0
	var t := clampf(_state_time / windup, 0.0, 1.0)
	if _state_time >= windup + active:
		phase = 2
		t = clampf((_state_time - windup - active) / recovery, 0.0, 1.0)
	elif _state_time >= windup:
		phase = 1
		t = (_state_time - windup) / active
	var forward := facing.angle()
	var half := ATTACK_ARC / 2.0
	var reach := _attack_range() + RADIUS
	var slash := COLOR_EMPOWERED if _attack_speed > 1.0 else COLOR_SLASH
	var trail_alpha := minf(0.55 + 0.12 * (_combo_step - 1), 0.9)
	var rest := forward + 0.6
	var angle := forward
	var hand := Vector2.ZERO
	var length := SWORD_LENGTH
	match ATTACK_STYLES[_attack_style]:
		"slash", "backhand":
			# Fendente da un lato all'altro (il rovescio nel verso opposto).
			var side := 1.0 if ATTACK_STYLES[_attack_style] == "slash" else -1.0
			var from := forward - side * half
			var to := forward + side * half
			match phase:
				0:
					angle = lerp_angle(rest, from - side * 0.6, ease(t, 0.5))
				1:
					angle = lerpf(from - side * 0.6, to, ease(t, 0.45))
					BodyParts.draw_trail(self, Vector2.ZERO, from, clampf(angle, minf(from, to), maxf(from, to)), RADIUS + 6.0, reach, Color(slash, trail_alpha))
				2:
					# Accompagnamento oltre la fine dell'arco, poi in guardia.
					angle = lerpf(to, to + side * 0.4, ease(minf(t / 0.35, 1.0), 0.5)) if t < 0.35 \
							else lerp_angle(to + side * 0.4, rest, ease((t - 0.35) / 0.65, 2.0))
					BodyParts.draw_trail(self, Vector2.ZERO, from, to, RADIUS + 6.0, reach, Color(slash, trail_alpha * 0.5 * (1.0 - t)))
			hand = Vector2.from_angle(angle) * RADIUS * 0.8
		"chop":
			# Dall'alto: la spada si alza sopra la testa e cala in avanti.
			var up := -PI / 2.0
			var down := up + wrapf(forward - up, -PI, PI)
			match phase:
				0:
					angle = lerp_angle(rest, up - 0.25, ease(t, 0.5))
					hand = Vector2(0, -RADIUS * 0.9 * ease(t, 0.5))
				1:
					angle = lerpf(up - 0.25, down, ease(t, 0.35))
					hand = Vector2(0, -RADIUS * 0.9 * (1.0 - t)) + facing * RADIUS * 0.6 * t
					length = SWORD_LENGTH * (1.0 + 0.15 * t)
					BodyParts.draw_trail(self, Vector2.ZERO, up, angle, RADIUS * 0.5, reach, Color(slash, trail_alpha * 0.8))
				2:
					angle = down if t < 0.4 else lerp_angle(down, rest, ease((t - 0.4) / 0.6, 2.0))
					hand = facing * RADIUS * 0.6 * (1.0 - t)
					length = SWORD_LENGTH * 1.15
			if hand == Vector2.ZERO:
				hand = Vector2.from_angle(angle) * RADIUS * 0.8
		"thrust":
			# Affondo: la spada si ritrae, poi scatta dritta in avanti.
			var side_offset := facing.orthogonal() * RADIUS * 0.5
			match phase:
				0:
					angle = lerp_angle(rest, forward, ease(t, 0.5))
					hand = side_offset - facing * RADIUS * 0.5 * ease(t, 0.5)
				1:
					angle = forward
					hand = side_offset.lerp(Vector2.ZERO, t) + facing * lerpf(-RADIUS * 0.5, RADIUS * 0.9, ease(t, 0.3))
					length = SWORD_LENGTH * (1.0 + 0.3 * t)
					# Scia dritta lungo la lama.
					var tip := hand + facing * length
					var width := facing.orthogonal() * 7.0 * (1.0 - t * 0.5)
					draw_primitive(PackedVector2Array([facing * RADIUS * 0.5 + width, tip + width * 0.3, tip - width * 0.3, facing * RADIUS * 0.5 - width]),
							PackedColorArray([Color(slash, trail_alpha)]), PackedVector2Array())
				2:
					angle = forward if t < 0.3 else lerp_angle(forward, rest, ease((t - 0.3) / 0.7, 2.0))
					hand = facing * RADIUS * 0.9 * (1.0 - t)
					length = SWORD_LENGTH * (1.3 - 0.3 * t)
	# Area colpita: un velo chiaro su tutto l'arco, uguale per ogni movimento.
	if phase == 1:
		BodyParts.draw_trail(self, Vector2.ZERO, forward - half, forward + half, RADIUS + 6.0, reach, Color(slash, 0.16 * (1.0 - t)))
	BodyParts.draw_sword(self, hand, angle, length, SWORD_WIDTH, tint)
	# Alla fine della carica la punta della spada luccica.
	if phase == 0 and t > 0.6:
		var tip := hand + Vector2.from_angle(angle) * length
		var glint := (t - 0.6) / 0.4
		draw_line(tip - Vector2(7, 0) * glint, tip + Vector2(7, 0) * glint, Color(1, 1, 1, glint), 2.0)
		draw_line(tip - Vector2(0, 7) * glint, tip + Vector2(0, 7) * glint, Color(1, 1, 1, glint), 2.0)


## Il corpo accompagna i colpi normali a terra: ruota con fendente e
## rovescio, si allunga caricando il colpo dall'alto e si schiaccia
## calandolo. Restituisce la rotazione in più e la scala.
func _attack_body_pose() -> Array:
	if _state != State.ATTACK or _attack_heavy or _air_attack:
		return [0.0, Vector2.ONE]
	var windup := ATTACK_WINDUP / _attack_speed
	var active := ATTACK_ACTIVE / _attack_speed
	var style: String = ATTACK_STYLES[_attack_style]
	var side := 1.0 if style == "slash" else -1.0
	var screen_side := side * (1.0 if facing.x >= 0.0 else -1.0)
	if _state_time < windup:
		var t := ease(_state_time / windup, 0.5)
		if style == "chop":
			return [0.0, Vector2(1.0 - 0.06 * t, 1.0 + 0.08 * t)]
		if style == "thrust":
			return [0.0, Vector2(1.0 + 0.05 * t, 1.0 - 0.04 * t)]
		return [-screen_side * ATTACK_TWIST * t, Vector2.ONE]
	var t := clampf((_state_time - windup) / (active * 2.0), 0.0, 1.0)
	if style == "chop":
		return [0.0, Vector2(1.0 + 0.1 * (1.0 - t), 1.0 - 0.1 * (1.0 - t))]
	if style == "thrust":
		return [0.0, Vector2.ONE]
	return [screen_side * ATTACK_TWIST * (1.0 - t), Vector2.ONE]


## Attacco a terra: spada alzata sopra la testa in salita, che cala con una
## scia scendendo e resta piantata nel terreno dopo l'impatto. Gli angoli
## sono pensati guardando a destra e specchiati guardando a sinistra.
func _draw_slam_sword(tint: Color) -> void:
	var mirror := facing.x < 0.0
	var raised := -PI / 2.0 - 0.5
	var down := PI / 2.0 - 0.35
	var angle := raised
	if _slam_landed:
		angle = down
	elif _height_velocity < 0.0:
		angle = lerpf(raised, down, clampf(-_height_velocity / 900.0, 0.0, 1.0))
		var start := PI - raised if mirror else raised
		var end := PI - angle if mirror else angle
		BodyParts.draw_trail(self, Vector2.ZERO, start, end, RADIUS + 6.0, HEAVY_SWORD_LENGTH + RADIUS, Color(COLOR_HEAVY, 0.7))
	if mirror:
		angle = PI - angle
	BodyParts.draw_sword(self, Vector2.from_angle(angle) * RADIUS * 0.8, angle, HEAVY_SWORD_LENGTH, SWORD_WIDTH * 1.3, tint)


## Torcia nell'altra mano: bastone e fiamma che tremola.
func _draw_torch() -> void:
	var hand := -facing.orthogonal() * RADIUS * 0.9
	var top := hand + Vector2(0, -18)
	draw_line(hand + Vector2(0, 6), top, Color(0.4, 0.26, 0.14), 4.0)
	var flicker := randf_range(0.85, 1.15)
	Shapes.disc(self, top + Vector2(0, -4), 7.0 * flicker, Color(COLOR_FLAME, 0.85))
	Shapes.disc(self, top + Vector2(0, -6), 4.0 * flicker, Color(1.0, 0.95, 0.6))
