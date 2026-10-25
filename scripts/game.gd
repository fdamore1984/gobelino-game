class_name Game
extends Node2D
## Livello di test del gameplay: un mondo senza limiti generato a caso
## (blocchi a gradini su più altezze e ostacoli naturali, vedi World) con nemici di vari
## tipi sparsi a caso attorno al giocatore: pochi ai primi livelli, sempre di
## più salendo (vedi EnemyTypes.population). I nemici troppo lontani vengono
## rimossi e ne compaiono di nuovi fuori dallo schermo, così ce ne sono
## sempre. Gestisce anche esperienza, livelli e scelta dei potenziamenti.
##
## Toccando il totem al centro di un'arena parte una sfida di
## sopravvivenza (parametri in data/challenge.json): per 30 secondi
## arrivano ondate di nemici, più numerose e forti salendo di livello, da
## un'ellisse attorno al totem (il cerchio visto sul terreno isometrico).
## Superarla dà esperienza e una pozione.
##
## Toccando una cassa la si apre: escono monete e oggetti a caso
## (data/items.json), adatti al livello, da raccogliere passandoci sopra.
##
## Toccando il banco di un mercante si apre il suo negozio (ShopPanel):
## per riaprirlo bisogna prima allontanarsi.
##
## Entrando in una caverna delle montagne si scende in un sotterraneo
## (Dungeon) di 2-5 piani: su ogni piano si cerca la scala per scendere,
## all'ultimo c'è il boss; la scala d'arrivo riporta in superficie.
##
## La partita si salva da sola ogni 5 minuti ed entrando in una caverna,
## nemici presenti compresi (tipo, posizione e vita): caricandola ritornano
## quelli, non nemici nuovi a caso;
## dal menù di pausa si salva a mano, ma solo senza nemici vicini e stando
## fermi. Vicino al bordo del territorio già generato il gioco si ferma un
## attimo per generarne altro (vedi World).

const MENU_SCENE := "res://scenes/menu.tscn"

## All'avvio i nemici sono sparsi a questa distanza dal giocatore.
const START_SPAWN_RANGE := Vector2(450.0, 1300.0)
## Poi ricompaiono fuori dall'inquadratura.
const SPAWN_RANGE := Vector2(850.0, 1400.0)
const DESPAWN_DISTANCE := 2000.0
const MAINTAIN_INTERVAL := 1.0
const GAME_OVER_DELAY := 2.5
const COLOR_XP := Color(0.6, 0.9, 1.0)
const CHALLENGE := preload("res://data/challenge.json")
## Distanza dal totem entro cui l'HUD suggerisce di toccarlo.
const TOTEM_HINT_DISTANCE := 220.0
## Distanza dal mercante entro cui l'HUD suggerisce di toccarlo.
const MERCHANT_HINT_DISTANCE := 260.0
const AUTOSAVE_INTERVAL := 300.0
const SAVE_VERSION := 1
## Tempo per frame dedicato a generare il territorio, in microsecondi.
const REGION_STEP_USEC := 12000
## Si interagisce con gli elementi entro questa distanza dal bordo del personaggio.
const INTERACT_REACH := 34.0
## Distanza dagli ingressi entro cui l'HUD suggerisce cosa fare.
const PASSAGE_HINT_DISTANCE := 200.0
## Nemici più vicini di così impediscono di salvare.
const SAVE_SAFE_DISTANCE := 700.0
## Arrivando su un piano si compare a questa distanza dal passaggio nella parete.
const ARRIVAL_DISTANCE := 70.0

## Partita da riprendere al prossimo avvio della scena (la imposta il menù).
static var pending_save := {}

@onready var _world: World = $World
@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player
@onready var _hud: Hud = $HUD
@onready var _day_night: DayNight = $DayNight
@onready var _minimap: Control = $HUD/Minimap

var _kills := 0
var _maintain_timer := MAINTAIN_INTERVAL
## Livelli guadagnati per cui va ancora scelto il potenziamento.
var _pending_level_ups := 0
## Sfida in corso: centro dell'arena (Vector2.INF se nessuna), tempo
## rimasto, ondate ancora da far arrivare e nemici della sfida.
var _challenge_arena := Vector2.INF
var _challenge_time := 0.0
var _challenge_waves: Array = []
var _challenge_enemies: Array[Enemy] = []
## Elemento con cui si può interagire ora (vuoto se nessuno, vedi _update_interaction).
var _interactable := {}
var _dungeon_data: Dictionary = World.DATA.data["dungeon"]
var _autosave_timer := AUTOSAVE_INTERVAL
## Il salvataggio automatico è dovuto e aspetta il momento giusto.
var _autosave_pending := false
## Caverna da cui si è scesi (Vector2.INF in superficie), quanti piani ha
## il suo sotterraneo e dove si torna in superficie.
var _cave := Vector2.INF
var _cave_levels := 0
var _surface_return := Vector2.ZERO
var _boss: Enemy
## Si sta preparando il territorio dietro la schermata d'attesa.
var loading := false


func _ready() -> void:
	_world.entities = _entities
	# Effetti a terra (sangue, corpi, onde d'urto) tra il terreno e i personaggi.
	var ground_fx := GroundFx.new()
	add_child(ground_fx)
	move_child(ground_fx, _entities.get_index())
	_world.player = _player
	_player.health_changed.connect(_hud.set_health)
	_player.experience_changed.connect(_hud.set_experience)
	_player.leveled_up.connect(_on_player_leveled_up)
	_player.died.connect(_on_player_died)
	_hud.upgrade_chosen.connect(_on_upgrade_chosen)
	_hud.interact_pressed.connect(_interact)
	_hud.player = _player
	_hud.day_night = _day_night
	_hud.set_health(_player.health, _player.max_health)
	_hud.set_experience(_player.experience, _player.experience_needed(), _player.level)
	_hud.set_kills(_kills)
	_hud.pause_menu.save_requested.connect(_on_save_requested)
	_hud.pause_menu.quit_requested.connect(_back_to_menu)
	var save := pending_save
	pending_save = {}
	if not save.is_empty():
		_load(save)
		return
	await _prepare_region(tr("LOADING_LANDS"))
	_populate(START_SPAWN_RANGE)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("menu") and not get_tree().paused:
		_hud.pause_menu.open(_save_block_reason())
		return
	if not get_tree().paused and _world.near_region_edge(_player.position):
		_prepare_region(tr("LOADING_LANDS"))
		return
	_update_challenge(delta)
	_update_interaction()
	_update_autosave(delta)
	# Nel sotterraneo i nemici sono quelli del piano: non ne arrivano altri.
	_maintain_timer -= delta
	if _maintain_timer <= 0.0 and _cave == Vector2.INF:
		_maintain_timer = MAINTAIN_INTERVAL
		_maintain_enemies()


func _maintain_enemies() -> void:
	var alive := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.is_queued_for_deletion():
			continue
		var far := enemy.global_position.distance_to(_player.global_position) > DESPAWN_DISTANCE
		if far and not enemy.is_engaged():
			enemy.queue_free()
		else:
			alive += 1
	for i in EnemyTypes.population(_player.level) - alive:
		_spawn_enemy(EnemyTypes.pick_random(_player.level), _random_position(SPAWN_RANGE))


## Nemici a caso attorno al giocatore, quanti ne vuole il suo livello.
func _populate(distance_range: Vector2) -> void:
	for i in EnemyTypes.population(_player.level):
		_spawn_enemy(EnemyTypes.pick_random(_player.level), _random_position(distance_range))


func _update_challenge(delta: float) -> void:
	var data: Dictionary = CHALLENGE.data
	if _challenge_arena == Vector2.INF:
		if _player.is_dead() or get_tree().paused:
			return
		var arena := _world.arena_near(_player.position)
		if arena != Vector2.INF and _world.totem_state(arena) == "ready" \
				and _player.position.distance_to(arena) < TOTEM_HINT_DISTANCE:
			_hud.show_challenge(tr("CHALLENGE_HINT"))
		elif _player.position.distance_to(_world.merchant_near(_player.position)) < MERCHANT_HINT_DISTANCE:
			_hud.show_challenge(tr("MERCHANT_HINT"))
		elif _passage_hint() != "":
			_hud.show_challenge(tr(_passage_hint()))
		else:
			_hud.hide_challenge()
		return
	_challenge_time -= delta
	var elapsed: float = float(data["duration"]) - _challenge_time
	while not _challenge_waves.is_empty() and elapsed >= float(_challenge_waves[0]):
		_challenge_waves.pop_front()
		_spawn_challenge_wave()
	var alive := 0
	for enemy in _challenge_enemies:
		if is_instance_valid(enemy) and not enemy.is_dead():
			alive += 1
	_hud.show_challenge(tr("CHALLENGE_STATUS") % [ceili(_challenge_time), alive])
	if _player.is_dead():
		_world.set_totem_state(_challenge_arena, "used")
		_challenge_arena = Vector2.INF
		_hud.hide_challenge()
	elif _challenge_time <= 0.0:
		_finish_challenge()


## Elemento con cui si può interagire qui vicino (cassa chiusa, mercante,
## totem pronto, ingresso di una caverna, scala, uscita): sopra compare il
## tasto con "Interact" e solo premendolo (A / E, o toccando il
## suggerimento) succede qualcosa. Il tasto A serve anche a saltare: vicino
## a un elemento interagisce invece di saltare (vedi Player.can_interact).
func _update_interaction() -> void:
	_interactable = _find_interactable()
	_player.can_interact = not _interactable.is_empty()
	if _interactable.is_empty():
		_hud.hide_interact()
		return
	var at: Vector2 = _interactable["position"]
	_hud.show_interact(at - Vector2(0, _world.elevation_at(at) + float(_interactable["height"])))
	if Input.is_action_just_pressed("interact"):
		_interact()


func _find_interactable() -> Dictionary:
	if _player.is_dead() or _challenge_arena != Vector2.INF:
		return {}
	var at := _player.position
	var reach := Player.RADIUS + INTERACT_REACH
	var chest := _world.chest_touched(at, reach)
	if not chest.is_empty():
		return {"type": "chest", "position": chest["position"], "height": 44.0}
	var merchant := _world.merchant_touched(at, reach)
	if merchant != Vector2.INF:
		return {"type": "merchant", "position": merchant, "height": 120.0}
	var totem := _world.totem_touched(at, reach)
	if totem != Vector2.INF and _world.totem_state(totem) == "ready":
		return {"type": "totem", "position": totem, "height": 100.0}
	for type_id: String in (["cave"] if _cave == Vector2.INF else ["stairs", "exit"]):
		var passage := _world.touched(type_id, at, reach)
		if not passage.is_empty() and not (type_id == "cave" and _world.is_cave_cleared(passage["position"])):
			return {"type": type_id, "position": passage["position"], "height": 96.0}
	return {}


## Interagisce con l'elemento vicino (premendo il tasto o toccando il suggerimento).
func _interact() -> void:
	if _interactable.is_empty() or get_tree().paused:
		return
	var target := _interactable
	_interactable = {}
	_hud.hide_interact()
	var at: Vector2 = target["position"]
	match target["type"]:
		"chest":
			_open_chest(at)
		"merchant":
			_hud.open_shop(at)
		"totem":
			_start_challenge(at)
		"cave":
			_enter_cave(at)
		"stairs":
			Sfx.play("summon", _player.global_position, 0.8)
			_go_to_depth(_world.dungeon.depth + 1, Vector2.INF)
		"exit":
			Sfx.play("level_up", _player.global_position, 0.8)
			_leave_dungeon()


func _open_chest(at: Vector2) -> void:
	_world.open_chest(at)
	Sfx.play("chest_open", at)
	var data := Items.chest_data()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var drops: Array[Array] = []
	var gold: Array = data["gold"]
	drops.append(["gold", rng.randi_range(gold[0], gold[1]) + int(data["gold_per_level"]) * (_player.level - 1)])
	var count: Array = data["items"]
	for i in rng.randi_range(count[0], count[1]):
		var id := Items.pick_random(_player.level, rng)
		drops.append([id, rng.randi_range(5, 15) + 2 * _player.level if id == "gold" else 1])
	# Gli oggetti saltano fuori dalla cassa a ventaglio, verso il giocatore.
	_drop_loot(at, drops)


# --- Territorio, caverne e sotterraneo ----------------------------------

## Genera la regione attorno al giocatore e mostra i pezzi visibili, con il
## gioco in pausa e la schermata d'attesa con l'avanzamento (text): all'avvio,
## caricando una partita, passando tra superficie e sotterraneo e vicino al
## bordo della zona già generata. Il lavoro è diviso su più frame, così la
## schermata resta viva; chi deve aspettare la fine usa await.
func _prepare_region(text: String, setup := Callable()) -> void:
	loading = true
	get_tree().paused = true
	_hud.show_loading(text, 0.0)
	# Prima si lascia disegnare la schermata d'attesa, poi si prepara il
	# posto (setup: per esempio il piano del sotterraneo) e il territorio.
	await get_tree().process_frame
	await get_tree().process_frame
	if setup.is_valid():
		setup.call()
		await get_tree().process_frame
	_world.begin_region(_player.position)
	while not _world.is_region_ready():
		_hud.show_loading(text, _world.generate_region(REGION_STEP_USEC))
		await get_tree().process_frame
	_hud.show_loading(text, 1.0)
	await get_tree().process_frame
	_world.refresh_now()
	_minimap.call("reset")
	await get_tree().process_frame
	_hud.hide_loading()
	get_tree().paused = false
	loading = false


## Suggerimento vicino a un ingresso (chiave del testo, "" se nessuno).
func _passage_hint() -> String:
	for pair: Array in [["cave", "CAVE_HINT"], ["stairs", "STAIRS_HINT"], ["exit", "EXIT_HINT"]]:
		var found := _world.touched(pair[0], _player.position, PASSAGE_HINT_DISTANCE)
		if not found.is_empty():
			if pair[0] == "cave" and _world.is_cave_cleared(found["position"]):
				return "CAVE_CLEARED"
			return pair[1]
	return ""


func _enter_cave(at: Vector2) -> void:
	_cave = at
	_cave_levels = Dungeon.levels_for(_cave_seed())
	_surface_return = _player.position
	Sfx.play("summon", _player.global_position, 0.7)
	await _go_to_depth(1, Vector2.INF)
	# Autosalvataggio entrando nella caverna.
	_autosave_pending = true


## Seme del sotterraneo della caverna: sempre lo stesso per la stessa caverna.
func _cave_seed() -> int:
	return hash([_world.seed_value, roundi(_cave.x), roundi(_cave.y)])


## Porta il giocatore a un piano del sotterraneo (vicino alla scala
## d'arrivo, o in at se viene da un salvataggio), con i suoi nemici e,
## all'ultimo piano, il boss. saved: nemici di un salvataggio da rimettere
## al posto di quelli nuovi (null se non ci sono).
func _go_to_depth(depth: int, at: Vector2, saved: Variant = null) -> void:
	await _prepare_region(tr("LOADING_DEPTHS") % [depth, _cave_levels], _enter_depth.bind(depth, at))
	var dungeon := _world.dungeon
	if saved is Array:
		_restore_enemies(saved)
	else:
		_spawn_dungeon_enemies(dungeon)
		if dungeon.is_last() and not _world.is_cave_cleared(_cave):
			_spawn_boss(dungeon)
	_hud.flash_challenge(tr("DUNGEON_LEVEL") % [depth, dungeon.levels])


## Prepara il piano (dietro la schermata d'attesa): sotterraneo nuovo e
## giocatore davanti al passaggio d'arrivo (o in at).
func _enter_depth(depth: int, at: Vector2) -> void:
	_clear_level()
	var dungeon := Dungeon.new(hash([_cave_seed(), depth]), depth, _cave_levels)
	_world.set_dungeon(dungeon)
	if at == Vector2.INF or not dungeon.is_floor(World.cell_at(at)):
		# All'arrivo, o se il salvataggio è di una versione in cui il piano era diverso.
		at = _world.in_front_of_wall(dungeon.arrival, dungeon.arrival_side, ARRIVAL_DISTANCE)
	_player.teleport(at)
	_day_night.set_override(World._color(_dungeon_data["darkness"]))


func _leave_dungeon() -> void:
	await _prepare_region(tr("LOADING_SURFACE"), _return_to_surface)
	_populate(SPAWN_RANGE)


func _return_to_surface() -> void:
	_clear_level()
	_world.set_dungeon(null)
	_day_night.clear_override()
	_player.teleport(_surface_return)
	_cave = Vector2.INF


## Toglie nemici, bottino a terra, sangue e corpi del posto che si lascia.
func _clear_level() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("loot"):
		node.queue_free()
	if GroundFx.current:
		GroundFx.current.clear()
	_boss = null
	_hud.show_boss(null)


## Nemici nelle caverne del piano (non in quella d'arrivo né nell'arena),
## più forti scendendo.
func _spawn_dungeon_enemies(dungeon: Dungeon) -> void:
	var per_room: Array = _dungeon_data["enemies_per_room"]
	for i in range(1, dungeon.rooms.size()):
		var room: Dictionary = dungeon.rooms[i]
		if room["center"] == dungeon.arena:
			continue
		var cells := dungeon.room_cells(room)
		for k in mini(randi_range(per_room[0], per_room[1]), cells.size()):
			var cell: Vector2i = cells.pop_at(randi() % cells.size())
			_spawn_enemy(EnemyTypes.pick_random(_player.level + dungeon.depth - 1), World.cell_center(cell))


## Il boss al centro dell'arena, più forte quanto più alto è il livello del giocatore.
func _spawn_boss(dungeon: Dungeon) -> void:
	var boss := _spawn_enemy(_dungeon_data["boss"], dungeon.arena_center())
	var factor := 1.0 + float(_dungeon_data["boss_health_per_level"]) * (_player.level - 1)
	boss.max_health = roundi(boss.max_health * factor)
	boss.health = boss.max_health
	boss.xp_reward = roundi(boss.xp_reward * factor)
	boss.damage += floori((_player.level - 1) / float(_dungeon_data["boss_damage_per_levels"]))
	_setup_boss(boss, dungeon)


## Il boss (nuovo o da un salvataggio) resta chiuso nella sua arena, con la
## sua barra della vita.
func _setup_boss(boss: Enemy, dungeon: Dungeon) -> void:
	boss.confine(dungeon.arena_center(), dungeon.arena_radius - float(_dungeon_data.get("boss_arena_margin", 1.5)))
	boss.died.connect(_on_boss_died)
	_boss = boss
	_hud.show_boss(boss)


## Boss sconfitto: monete, oggetti speciali e uno raro; il goblin ride, la
## caverna è completata e nella parete dell'arena compare l'uscita.
func _on_boss_died(boss: Enemy) -> void:
	_world.cleared_caves[_cave] = true
	var gold: Array = _dungeon_data["boss_reward_gold"]
	var drops: Array[Array] = [["gold", int(gold[0]) + int(gold[1]) * _player.level]]
	# Oggetti speciali che lasciano solo i boss, e uno raro dei mercanti.
	var special := Items.boss_items()
	special.shuffle()
	for k in mini(int(_dungeon_data["boss_reward_items"]), special.size()):
		drops.append([special[k], 1])
	var rare := Items.shop_items()
	drops.append([rare[randi() % rare.size()], 1])
	_drop_loot(boss.global_position, drops)
	var dungeon := _world.dungeon
	_world.add_obstacle(_world.make_wall_obstacle("exit", dungeon.arena_exit, dungeon.arena_exit_side))
	_player.laugh()
	_hud.flash_challenge(tr("BOSS_DEFEATED"))
	Sfx.play("level_up", boss.global_position)


## Oggetti che saltano fuori a ventaglio da at, verso il giocatore.
func _drop_loot(at: Vector2, drops: Array[Array]) -> void:
	var away := (_player.position - at).normalized()
	for i in drops.size():
		var loot := Loot.new()
		loot.item_id = drops[i][0]
		loot.amount = drops[i][1]
		loot.player = _player
		var angle := away.angle() + (i - (drops.size() - 1) / 2.0) * 0.7
		loot.launch(at, _world.free_position_near(at + Vector2.from_angle(angle) * 60.0, 10.0))
		_entities.add_child(loot)


# --- Salvataggi --------------------------------------------------------

## Salvataggio automatico ogni AUTOSAVE_INTERVAL secondi ed entrando in una
## caverna: con le stesse regole del salvataggio dal menù per i nemici
## vicini (si aspetta che non ce ne siano più), mai durante una sfida, da
## morti, in aria o cadendo in un burrone. Intanto resta in attesa.
func _update_autosave(delta: float) -> void:
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_pending = true
		_autosave_timer = AUTOSAVE_INTERVAL
	if _autosave_pending and _can_autosave():
		_save(tr("SAVE_AUTO"))


func _can_autosave() -> bool:
	return _save_block_reason() in ["", "SAVE_BLOCKED_MOVING"] and not _player.is_airborne() and not _player.is_falling()


func _save(message: String) -> void:
	_autosave_timer = AUTOSAVE_INTERVAL
	_autosave_pending = false
	if SaveGame.write(_save_data()):
		_hud.flash_challenge(message)


## Perché adesso non si può salvare dal menù (chiave del testo, "" se si può).
func _save_block_reason() -> String:
	if _player.is_dead():
		return "SAVE_BLOCKED_DEAD"
	if _challenge_arena != Vector2.INF:
		return "SAVE_BLOCKED_CHALLENGE"
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if not enemy.is_dead() and enemy.global_position.distance_to(_player.global_position) < SAVE_SAFE_DISTANCE:
			return "SAVE_BLOCKED_ENEMIES"
	if not _player.is_still():
		return "SAVE_BLOCKED_MOVING"
	return ""


func _on_save_requested() -> void:
	if _save_block_reason() != "":
		return
	_save(tr("SAVE_DONE"))
	_hud.pause_menu.saved()


func _save_data() -> Dictionary:
	var data := {
		"version": SAVE_VERSION, "seed": _world.seed_value, "time": _day_night.time, "kills": _kills,
		"position": SaveGame.array(_player.position), "player": _player.save_state(), "world": _world.save_state(),
		"enemies": _enemies_state(),
	}
	if _cave != Vector2.INF:
		data["dungeon"] = {
			"cave": SaveGame.array(_cave), "levels": _cave_levels, "depth": _world.dungeon.depth,
			"return": SaveGame.array(_surface_return),
		}
	return data


## Nemici vivi da salvare (tipo, posizione esatta, vita e il resto, vedi Enemy.save_state).
func _enemies_state() -> Array:
	var result := []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if not enemy.is_dead() and not enemy.is_queued_for_deletion():
			result.append(enemy.save_state())
	return result


## Rimette i nemici salvati al loro posto, con la loro vita (il boss di
## nuovo chiuso nell'arena). I tipi che non esistono più si saltano; se il
## terreno è cambiato si cerca un posto libero lì vicino.
func _restore_enemies(saved: Array) -> void:
	var boss_allowed := _world.dungeon != null and _world.dungeon.is_last() and not _world.is_cave_cleared(_cave)
	for entry: Variant in saved:
		if not (entry is Dictionary) or not entry.has("position") or not EnemyTypes.exists(str(entry.get("type", ""))):
			continue
		var type_id := str(entry["type"])
		# Il boss torna solo nella sua arena, se non è già stato sconfitto.
		if EnemyTypes.get_type(type_id).get("boss", false) and not boss_allowed:
			continue
		var enemy := Enemy.new()
		enemy.setup(type_id)
		enemy.load_state(entry)
		enemy.player = _player
		if _world.is_barrier(World.cell_at(enemy.position)):
			enemy.position = _world.free_position_near(_world.safe_position_near(enemy.position), enemy.radius)
		enemy.died.connect(_on_enemy_died)
		enemy.summon_requested.connect(_on_summon_requested)
		_entities.add_child(enemy)
		if enemy.is_boss():
			_setup_boss(enemy, _world.dungeon)


## Riprende una partita salvata (all'avvio della scena, vedi pending_save).
func _load(save: Dictionary) -> void:
	_world.set_seed(int(save["seed"]))
	_world.load_state(save["world"])
	_player.load_state(save["player"])
	_kills = int(save.get("kills", 0))
	_hud.set_kills(_kills)
	_day_night.time = float(save.get("time", 0.2))
	var position_saved := SaveGame.vector(save["position"])
	var dungeon_state: Dictionary = save.get("dungeon", {})
	# I salvataggi delle versioni precedenti non hanno i nemici: se ne fanno di nuovi.
	var enemies: Variant = save.get("enemies")
	if dungeon_state.is_empty():
		# Se una versione nuova ha cambiato il terreno, si cerca un posto
		# libero vicino a quello salvato.
		if _world.is_barrier(World.cell_at(position_saved)):
			position_saved = _world.safe_position_near(position_saved)
		_player.teleport(position_saved)
		await _prepare_region(tr("LOADING_GAME"))
		if enemies is Array:
			_restore_enemies(enemies)
		else:
			_populate(START_SPAWN_RANGE)
	else:
		_cave = SaveGame.vector(dungeon_state["cave"])
		_cave_levels = int(dungeon_state["levels"])
		_surface_return = SaveGame.vector(dungeon_state["return"])
		await _go_to_depth(int(dungeon_state["depth"]), position_saved, enemies)


# --- Sfide dei totem ---------------------------------------------------

func _start_challenge(arena: Vector2) -> void:
	var data: Dictionary = CHALLENGE.data
	_challenge_arena = arena
	_challenge_time = data["duration"]
	_challenge_waves = (data["wave_times"] as Array).duplicate()
	_challenge_enemies.clear()
	_world.set_totem_state(arena, "active")
	Sfx.play("summon", arena)


## Ondata di nemici dal bordo dell'arena: quanti e quanto forti dipende
## dal livello del giocatore (fino a "max_per_wave"). Compaiono in
## un'ellisse schiacciata come il terreno isometrico ("spawn_squash"), che a
## schermo sembra un cerchio a terra attorno al totem.
func _spawn_challenge_wave() -> void:
	var data: Dictionary = CHALLENGE.data
	var per_wave: Array = data["enemies_per_wave"]
	var count := mini(floori(float(per_wave[0]) + float(per_wave[1]) * (_player.level - 1)), int(data.get("max_per_wave", 99)))
	var distance := _world.arena_radius() * float(data["spawn_distance"])
	var squash := float(data.get("spawn_squash", GroundFx.GROUND_SQUASH))
	var start := randf() * TAU
	for i in count:
		var at := _challenge_arena + World.ground_ellipse(start + TAU * i / count, distance, squash)
		var enemy := _spawn_enemy(EnemyTypes.pick_random(_player.level + int(data["type_level_bonus"])), at)
		enemy.alert()
		_challenge_enemies.append(enemy)
	Sfx.play("summon_pop", _challenge_arena)


func _finish_challenge() -> void:
	var data: Dictionary = CHALLENGE.data
	var xp := int(data["xp_per_level"]) * _player.level
	_world.set_totem_state(_challenge_arena, "used")
	_challenge_arena = Vector2.INF
	_player.potions = maxi(_player.potions, mini(_player.potions + int(data["potion_reward"]), _player.potion_capacity()))
	_hud.flash_challenge(tr("CHALLENGE_WON") % xp)
	Sfx.play("level_up", _player.global_position)
	_player.add_experience(xp)


func _random_position(distance_range: Vector2) -> Vector2:
	var offset := Vector2.from_angle(randf() * TAU) * randf_range(distance_range.x, distance_range.y)
	return _player.position + offset


func _spawn_enemy(type_id: String, at: Vector2) -> Enemy:
	var enemy := Enemy.new()
	enemy.setup(type_id)
	enemy.player = _player
	enemy.position = _world.free_position_near(at, enemy.radius)
	enemy.died.connect(_on_enemy_died)
	enemy.summon_requested.connect(_on_summon_requested)
	_entities.add_child(enemy)
	return enemy


func _on_summon_requested(summoner: Enemy, type_id: String, positions: Array[Vector2]) -> void:
	var minion_xp: int = EnemyTypes.get_type(summoner.type_id)["summon"]["minion_xp"]
	for at in positions:
		var minion := _spawn_enemy(type_id, at)
		# I nemici evocati danno meno esperienza, altrimenti basterebbe
		# lasciare vivo l'evocatore per farne scorta.
		minion.xp_reward = minion_xp
		minion.drops_loot = false
		minion.is_minion = true
		summoner.add_minion(minion)


func _on_enemy_died(enemy: Enemy) -> void:
	_kills += 1
	_hud.set_kills(_kills)
	Sfx.play("xp", enemy.global_position)
	_player.add_experience(enemy.xp_reward)
	# Ogni tanto un nemico lascia monete o un oggetto (il boss ha il suo bottino).
	if enemy.drops_loot and not enemy.is_boss():
		var drops := Items.enemy_drops(_player.level)
		if not drops.is_empty():
			_drop_loot(enemy.global_position, drops)


func _on_player_leveled_up(_level: int) -> void:
	_pending_level_ups += 1
	if _pending_level_ups == 1:
		_show_level_up()


func _show_level_up() -> void:
	# Il livello mostrato è quello appena raggiunto da scegliere, anche
	# se nel frattempo se ne sono guadagnati altri.
	var reached := _player.level - _pending_level_ups + 1
	var damage_before := Player.BASE_DAMAGE + Player.DAMAGE_PER_LEVEL * (reached - 2)
	var damage_after := damage_before + Player.DAMAGE_PER_LEVEL
	get_tree().paused = true
	_hud.show_level_up(reached, damage_before, damage_after)


func _on_upgrade_chosen(upgrade: String) -> void:
	_player.apply_upgrade(upgrade)
	_pending_level_ups -= 1
	if _pending_level_ups > 0:
		_show_level_up()
	else:
		get_tree().paused = false


func _on_player_died() -> void:
	_hud.show_message(tr("HUD_DEFEAT"))
	# Collegato al segnale (e non con await) così, se nel frattempo si torna
	# al menù, il timer non richiama una scena già distrutta.
	get_tree().create_timer(GAME_OVER_DELAY).timeout.connect(_back_to_menu)


func _exit_tree() -> void:
	HitFeedback.reset()


func _back_to_menu() -> void:
	get_tree().paused = false
	HitFeedback.reset()
	get_tree().change_scene_to_file(MENU_SCENE)
