class_name TouchAssist
extends RefCounted
## Automazioni della Modalità Touch (solo versione web, vedi
## Platform.touch_mode). Il giocatore le chiama a ogni passo di fisica
## prima di leggere i comandi (vedi Player._physics_process): premono e
## rilasciano le stesse azioni dell'Input Map di tastiera e controller.
## - Salto: automatico davanti a un dislivello che si supera con i salti
##   rimasti.
## - Pozioni: si bevono da sole quando mana o vigore finiscono; la vita a
##   zero la salva una pozione (vedi Player.receive_hit).
## - Scudo: si alza appena è carico.
## - Torcia: si accende al buio e si spegne con la luce.
## - Attacco (tasto unico tenuto premuto): combo normale, poi colpo potente,
##   poi salto e slam, finché c'è vigore; da lontano la palla di fuoco (mai
##   con un nemico vicino).
## - Parata: automatica quando non si attacca (vedi Player.receive_hit).

## Distanza entro cui un nemico è "vicino": niente palla di fuoco, si mena.
const MELEE_DISTANCE := 170.0
## Distanza massima per la palla di fuoco automatica.
const FIREBALL_DISTANCE := 620.0
## Quanto avanti (oltre il raggio) si guarda il terreno per il salto.
const JUMP_LOOK_AHEAD := 20.0
## Quota guadagnata da ogni salto, con un po' di margine (JUMP_SPEED e GRAVITY);
## sul blocco si sale già da World.STEP_TOLERANCE sotto il bordo.
const JUMP_RISE := 0.95 * Player.JUMP_SPEED * Player.JUMP_SPEED / (2.0 * Player.GRAVITY)
## Torcia: si accende sopra questo buio, si spegne sotto l'altro (con
## isteresi, così non lampeggia all'alba e al tramonto).
const TORCH_ON_DARKNESS := 0.4
const TORCH_OFF_DARKNESS := 0.3
## Dopo un salto dello slam, da questa quota si picchia giù.
const SLAM_HEIGHT := 30.0

## Giocatore in partita (per i tasti speciali, vedi TouchControls).
static var player: Player

## Azioni premute per un tocco -> passi che restano prima di rilasciarle.
## Una pressione fatta da qui risulta "appena premuta" al passo successivo,
## quindi il tocco dura due passi.
var _taps := {}
## Fase della sequenza di attacco: combo, heavy, jump, slam.
var _phase := "combo"
var _attack_was := false
var _h_bomb_was := false
var _h_bomb_jumped := false
## Passi trascorsi nella fase attuale dell'attacco.
var _phase_steps := 0
## Vigore e mana sono arrivati a zero: si beve appena si può.
var _stamina_out := false
var _mana_out := false


## Bomba H e Frenesia: il tasto compare solo quando si possono usare.
static func special_ready(kind: String) -> bool:
	if player == null or not is_instance_valid(player) or player.is_dead():
		return false
	if kind == "h_bomb":
		return player.h_bombs > 0
	if kind == "interact":
		return player.can_interact
	return player.is_frenzy_full()


func update(p: Player) -> void:
	player = p
	for action: StringName in _taps.keys():
		_taps[action] -= 1
		if _taps[action] <= 0:
			Input.action_release(action)
			_taps.erase(action)
	if p.is_dead():
		_release_all()
		return
	_auto_supplies(p)
	_auto_torch(p)
	_auto_jump(p)
	_specials(p)
	_attack(p)


func _tap(action: StringName) -> void:
	if _taps.has(action) or Input.is_action_pressed(action):
		return
	Input.action_press(action)
	_taps[action] = 2


func _release_all() -> void:
	for action: StringName in ["attack", "heavy_attack"]:
		Input.action_release(action)
	_phase = "combo"


func _auto_supplies(p: Player) -> void:
	if not p.shield_active and p.shield_cooldown == 0.0:
		_tap("shield")
	# Finiti vigore o mana si beve la pozione appena si può: fermi a terra
	# senza fare altro (vedi Player._start_drink); il vigore intanto torna da
	# solo, quindi si ricorda che era finito.
	if p.stamina <= 0.0:
		_stamina_out = true
	if p.mana < Player.SPELL_COST:
		_mana_out = true
	if p.stamina >= p.max_stamina or p.stamina_potions == 0:
		_stamina_out = false
	if p.mana >= Player.SPELL_COST or p.mana_potions == 0:
		_mana_out = false
	if not p.can_drink() or Platform.touch_attack:
		return
	if _stamina_out:
		_tap("stamina_potion")
		_stamina_out = false
	elif _mana_out:
		_tap("mana_potion")
		_mana_out = false


func _auto_torch(p: Player) -> void:
	var dark := DayNight.current.darkness() if DayNight.current else 0.0
	if not p.torch_on and dark > TORCH_ON_DARKNESS:
		p.set_torch(true)
	elif p.torch_on and dark < TORCH_OFF_DARKNESS:
		p.set_torch(false)


## Salto davanti a un gradino più alto che si riesce a superare: da terra se
## basta la quota di tutti i salti rimasti, in aria (scendendo) il salto
## successivo se serve ancora.
func _auto_jump(p: Player) -> void:
	var world := World.current
	if world == null or not p.can_auto_jump():
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length() < 0.3:
		return
	var ahead := p.position + input.normalized() * (Player.RADIUS + JUMP_LOOK_AHEAD)
	# Montagne, roccia e burroni non si superano saltando.
	if world.is_barrier(World.cell_at(ahead)):
		return
	var rise := world.elevation_at(ahead) - p.altitude()
	if rise <= World.STEP_TOLERANCE:
		return
	rise -= World.STEP_TOLERANCE
	var jumps_left := p.max_jumps - p.jumps_used()
	if jumps_left <= 0:
		return
	if not p.is_airborne():
		if rise <= JUMP_RISE * jumps_left:
			_tap("jump")
	elif p.is_descending() and rise <= JUMP_RISE * jumps_left:
		_tap("jump")


func _specials(p: Player) -> void:
	if Platform.touch_frenzy and special_ready("frenzy"):
		# Parata e attacco insieme: l'attacco speciale.
		Platform.touch_frenzy = false
		_tap("parry")
		_tap("attack")
	# Bomba H: salto e colpo potente tenuto in aria finché si tiene il tasto.
	var h_bomb := Platform.touch_h_bomb and special_ready("h_bomb")
	if h_bomb and not _h_bomb_was:
		_h_bomb_jumped = false
		if not p.is_airborne():
			_tap("jump")
			_h_bomb_jumped = true
	if h_bomb and p.is_airborne() and not Input.is_action_pressed("heavy_attack"):
		Input.action_press("heavy_attack")
	elif not Platform.touch_h_bomb and _h_bomb_was:
		Input.action_release("heavy_attack")
	_h_bomb_was = Platform.touch_h_bomb


## Attacco tenuto premuto: combo -> potente -> salto e slam, da capo.
func _attack(p: Player) -> void:
	if _h_bomb_was:
		return
	var held := Platform.touch_attack
	if not held:
		if _attack_was:
			_release_all()
		_attack_was = false
		return
	_attack_was = true
	var target := p.nearest_enemy(FIREBALL_DISTANCE)
	var distance := p.position.distance_to(target.position) if target else INF
	# Da lontano la palla di fuoco (se c'è mana), finito il colpo in corso;
	# con un nemico vicino si mena.
	if target and distance > MELEE_DISTANCE and p.mana >= Player.SPELL_COST:
		Input.action_release("attack")
		_phase = "combo"
		if p.is_idle():
			p.face(target.position - p.position)
			_tap("spell")
		return
	if target and distance <= MELEE_DISTANCE and p.is_idle():
		p.face(target.position - p.position)
	_phase_steps += 1
	var phase := _phase
	match _phase:
		"combo":
			Input.action_press("attack")
			if p.combo_complete():
				_phase = "heavy" if p.stamina >= Player.STAMINA_HEAVY else "combo"
		"heavy":
			Input.action_release("attack")
			if p.is_heavy_attack():
				_phase = "jump"
			elif p.stamina < Player.STAMINA_HEAVY:
				_phase = "combo"
			else:
				_tap("heavy_attack")
		"jump":
			if p.is_idle():
				if p.stamina >= Player.STAMINA_JUMP + Player.STAMINA_HEAVY and p.mana >= Player.AIR_SLAM_MANA:
					_tap("jump")
					_phase = "slam"
				else:
					_phase = "combo"
		"slam":
			if p.is_airborne() and p.altitude() - p.ground_elevation >= SLAM_HEIGHT:
				_tap("heavy_attack")
				_phase = "combo"
			elif _phase_steps > 6 and not p.is_airborne() and p.is_idle():
				# Il salto non è partito: si ricomincia.
				_phase = "combo"
	if _phase != phase:
		_phase_steps = 0
