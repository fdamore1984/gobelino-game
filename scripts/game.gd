class_name Game
extends Node2D
## Livello di test del gameplay: un mondo senza limiti generato a caso
## (blocchi a gradini su più altezze e ostacoli naturali, vedi World) con nemici di vari
## tipi sparsi a caso attorno al giocatore. I nemici troppo lontani vengono
## rimossi e ne compaiono di nuovi fuori dallo schermo, così ce ne sono
## sempre. Gestisce anche esperienza, livelli e scelta dei potenziamenti.
##
## Toccando il totem al centro di un'arena parte una sfida di
## sopravvivenza (parametri in data/challenge.json): per 30 secondi
## arrivano ondate di nemici, più numerose e forti salendo di livello.
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
## La partita si salva da sola ogni 5 minuti ed entrando in una caverna;
## dal menù di pausa si salva a mano, ma solo senza nemici vicini e stando
## fermi. Vicino al bordo del territorio già generato il gioco si ferma un
## attimo per generarne altro (vedi World).

const MENU_SCENE := "res://scenes/menu.tscn"

const ENEMY_COUNT := 12
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
## Se adesso non si può salvare (sfida in corso), si riprova dopo un po'.
const AUTOSAVE_RETRY := 15.0
const SAVE_VERSION := 1
## Tempo per frame dedicato a generare il territorio, in microsecondi.
const REGION_STEP_USEC := 12000
## Dopo un passaggio (caverna, scale) gli ingressi contano solo dopo
## essersi allontanati di tanto dal punto d'arrivo.
const TRIGGER_REARM_DISTANCE := 110.0
## Distanza dagli ingressi entro cui l'HUD suggerisce cosa fare.
const PASSAGE_HINT_DISTANCE := 200.0
## Nemici più vicini di così impediscono di salvare.
const SAVE_SAFE_DISTANCE := 700.0
## Arrivando su un piano si compare un po' lontano dalla scala d'uscita.
const ARRIVAL_OFFSET := Vector2(0, 90)

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
## Mercante di cui è appena stato aperto il negozio (Vector2.INF se nessuno).
var _last_merchant := Vector2.INF
var _dungeon_data: Dictionary = World.DATA.data["dungeon"]
var _autosave_timer := AUTOSAVE_INTERVAL
## Caverna da cui si è scesi (Vector2.INF in superficie), quanti piani ha
## il suo sotterraneo e dove si torna in superficie.
var _cave := Vector2.INF
var _cave_levels := 0
var _surface_return := Vector2.ZERO
## Punto d'arrivo dell'ultimo passaggio (Vector2.INF = nessuno).
var _rest_point := Vector2.INF
var _boss: Enemy
## La generazione del territorio è partita (dopo che si vede la schermata d'attesa).
var _region_started := false


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
	_hud.player = _player
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
	_prepare_region()
	for i in ENEMY_COUNT:
		_spawn_enemy(EnemyTypes.pick_random(_player.level), _random_position(START_SPAWN_RANGE))


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("menu") and not get_tree().paused:
		_hud.pause_menu.open(_save_block_reason())
		return
	if not get_tree().paused and _world.near_region_edge(_player.position):
		_regenerate_region()
		return
	_update_challenge(delta)
	_check_chests()
	_check_merchant()
	_check_passages()
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
	for i in ENEMY_COUNT - alive:
		_spawn_enemy(EnemyTypes.pick_random(_player.level), _random_position(SPAWN_RANGE))


func _update_challenge(delta: float) -> void:
	var data: Dictionary = CHALLENGE.data
	if _challenge_arena == Vector2.INF:
		if _player.is_dead() or get_tree().paused:
			return
		var arena := _world.arena_near(_player.position)
		var touched := _world.totem_touched(_player.position, Player.RADIUS + 12.0)
		if touched != Vector2.INF and _world.totem_state(touched) == "ready":
			_start_challenge(touched)
		elif arena != Vector2.INF and _world.totem_state(arena) == "ready" \
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


func _check_chests() -> void:
	if _player.is_dead():
		return
	var chest := _world.chest_touched(_player.position, Player.RADIUS + 10.0)
	if chest.is_empty():
		return
	var at: Vector2 = chest["position"]
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


## Toccando il banco del mercante si apre il negozio; si riapre solo dopo
## essersi allontanati, così non ricompare appena chiuso.
func _check_merchant() -> void:
	if _player.is_dead():
		return
	if _last_merchant != Vector2.INF:
		if _player.position.distance_to(_last_merchant) > float(World.DATA.data["merchant"]["reopen_distance"]):
			_last_merchant = Vector2.INF
		return
	var merchant := _world.merchant_touched(_player.position, Player.RADIUS + 10.0)
	if merchant != Vector2.INF:
		_last_merchant = merchant
		_hud.open_shop(merchant)


# --- Territorio, caverne e sotterraneo ----------------------------------

## Genera subito la regione attorno al giocatore e mostra i pezzi visibili
## (all'avvio e dopo un passaggio tra superficie e sotterraneo).
func _prepare_region() -> void:
	_world.begin_region(_player.position)
	_world.generate_region(1 << 30)
	_world.refresh_now()


## Vicino al bordo della zona già generata: si mette in pausa e si genera
## il territorio attorno, mostrando l'avanzamento.
func _regenerate_region() -> void:
	get_tree().paused = true
	_hud.show_loading(tr("LOADING_LANDS"), 0.0)
	_region_started = false
	get_tree().process_frame.connect(_on_region_step)


func _on_region_step() -> void:
	# Al primo passo si vede appena la schermata d'attesa: si prepara la regione.
	if not _region_started:
		_region_started = true
		_world.begin_region(_player.position)
		return
	var progress := _world.generate_region(REGION_STEP_USEC)
	_hud.show_loading(tr("LOADING_LANDS"), progress)
	if _world.is_region_ready():
		get_tree().process_frame.disconnect(_on_region_step)
		_hud.hide_loading()
		get_tree().paused = false


## Ingressi delle caverne, scale per scendere e uscite del sotterraneo.
## Dopo un passaggio gli ingressi contano solo dopo essersi allontanati.
func _check_passages() -> void:
	if _player.is_dead() or _challenge_arena != Vector2.INF:
		return
	if _rest_point != Vector2.INF:
		if _player.position.distance_to(_rest_point) < TRIGGER_REARM_DISTANCE:
			return
		_rest_point = Vector2.INF
	var reach := Player.RADIUS + 6.0
	if _cave == Vector2.INF:
		var cave := _world.touched("cave", _player.position, reach)
		if not cave.is_empty() and not _world.is_cave_cleared(cave["position"]):
			_enter_cave(cave["position"])
	elif not _world.touched("stairs", _player.position, reach).is_empty():
		Sfx.play("summon", _player.global_position, 0.8)
		_go_to_depth(_world.dungeon.depth + 1, Vector2.INF)
	elif not _world.touched("exit", _player.position, reach).is_empty():
		Sfx.play("level_up", _player.global_position, 0.8)
		_leave_dungeon()


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
	_go_to_depth(1, Vector2.INF)
	# Autosalvataggio entrando nella caverna.
	_save(tr("SAVE_AUTO"))


## Seme del sotterraneo della caverna: sempre lo stesso per la stessa caverna.
func _cave_seed() -> int:
	return hash([_world.seed_value, roundi(_cave.x), roundi(_cave.y)])


## Porta il giocatore a un piano del sotterraneo (vicino alla scala
## d'arrivo, o in at se viene da un salvataggio), con i suoi nemici e,
## all'ultimo piano, il boss.
func _go_to_depth(depth: int, at: Vector2) -> void:
	_clear_level()
	var dungeon := Dungeon.new(hash([_cave_seed(), depth]), depth, _cave_levels)
	_world.set_dungeon(dungeon)
	_player.teleport(World.cell_center(dungeon.arrival) + ARRIVAL_OFFSET if at == Vector2.INF else at)
	_prepare_region()
	_rest_point = _player.position
	_day_night.set_override(World._color(_dungeon_data["darkness"]))
	_minimap.call("reset")
	_spawn_dungeon_enemies(dungeon)
	if dungeon.is_last() and not _world.is_cave_cleared(_cave):
		_spawn_boss(dungeon)
	_hud.flash_challenge(tr("DUNGEON_LEVEL") % [depth, dungeon.levels])


func _leave_dungeon() -> void:
	_clear_level()
	_world.set_dungeon(null)
	_day_night.clear_override()
	_player.teleport(_surface_return)
	_cave = Vector2.INF
	_prepare_region()
	_rest_point = _player.position
	_minimap.call("reset")
	for i in ENEMY_COUNT:
		_spawn_enemy(EnemyTypes.pick_random(_player.level), _random_position(SPAWN_RANGE))


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
	var boss := _spawn_enemy(_dungeon_data["boss"], World.cell_center(dungeon.arena))
	var factor := 1.0 + float(_dungeon_data["boss_health_per_level"]) * (_player.level - 1)
	boss.max_health = roundi(boss.max_health * factor)
	boss.health = boss.max_health
	boss.xp_reward = roundi(boss.xp_reward * factor)
	boss.damage += floori((_player.level - 1) / float(_dungeon_data["boss_damage_per_levels"]))
	boss.died.connect(_on_boss_died)
	_boss = boss
	_hud.show_boss(boss)


## Boss sconfitto: monete e oggetti rari, la caverna è completata e al
## centro dell'arena compare l'uscita verso la superficie.
func _on_boss_died(boss: Enemy) -> void:
	_world.cleared_caves[_cave] = true
	var gold: Array = _dungeon_data["boss_reward_gold"]
	var drops: Array[Array] = [["gold", int(gold[0]) + int(gold[1]) * _player.level]]
	var rare := Items.shop_items()
	rare.shuffle()
	for k in mini(int(_dungeon_data["boss_reward_items"]), rare.size()):
		drops.append([rare[k], 1])
	_drop_loot(boss.global_position, drops)
	_world.add_obstacle(_world.make_obstacle("exit", World.cell_center(_world.dungeon.arena)))
	_rest_point = _player.position
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

func _update_autosave(delta: float) -> void:
	_autosave_timer -= delta
	if _autosave_timer > 0.0:
		return
	if _player.is_dead() or _challenge_arena != Vector2.INF:
		_autosave_timer = AUTOSAVE_RETRY
		return
	_save(tr("SAVE_AUTO"))


func _save(message: String) -> void:
	_autosave_timer = AUTOSAVE_INTERVAL
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
	}
	if _cave != Vector2.INF:
		data["dungeon"] = {
			"cave": SaveGame.array(_cave), "levels": _cave_levels, "depth": _world.dungeon.depth,
			"return": SaveGame.array(_surface_return),
		}
	return data


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
	if dungeon_state.is_empty():
		_player.teleport(position_saved)
		# Salvando davanti a una caverna non ci si rientra appena caricato.
		_rest_point = position_saved
		_prepare_region()
		for i in ENEMY_COUNT:
			_spawn_enemy(EnemyTypes.pick_random(_player.level), _random_position(START_SPAWN_RANGE))
	else:
		_cave = SaveGame.vector(dungeon_state["cave"])
		_cave_levels = int(dungeon_state["levels"])
		_surface_return = SaveGame.vector(dungeon_state["return"])
		_go_to_depth(int(dungeon_state["depth"]), position_saved)


# --- Sfide dei totem ---------------------------------------------------

func _start_challenge(arena: Vector2) -> void:
	var data: Dictionary = CHALLENGE.data
	_challenge_arena = arena
	_challenge_time = data["duration"]
	_challenge_waves = (data["wave_times"] as Array).duplicate()
	_challenge_enemies.clear()
	_world.set_totem_state(arena, "active")
	Sfx.play("summon", arena)
	FloatingText.spawn(_entities, _player.global_position, tr("FX_CHALLENGE"), Player.COLOR_EMPOWERED, 40.0)


## Ondata di nemici dal bordo dell'arena: quanti e quanto forti dipende
## dal livello del giocatore.
func _spawn_challenge_wave() -> void:
	var data: Dictionary = CHALLENGE.data
	var per_wave: Array = data["enemies_per_wave"]
	var count := floori(float(per_wave[0]) + float(per_wave[1]) * (_player.level - 1))
	var distance := _world.arena_radius() * float(data["spawn_distance"])
	var start := randf() * TAU
	for i in count:
		var at := _challenge_arena + Vector2.from_angle(start + TAU * i / count) * distance
		var enemy := _spawn_enemy(EnemyTypes.pick_random(_player.level + int(data["type_level_bonus"])), at)
		enemy.alert()
		_challenge_enemies.append(enemy)
	Sfx.play("summon_pop", _challenge_arena)


func _finish_challenge() -> void:
	var data: Dictionary = CHALLENGE.data
	var xp := int(data["xp_per_level"]) * _player.level
	_world.set_totem_state(_challenge_arena, "used")
	_challenge_arena = Vector2.INF
	_player.potions = mini(_player.potions + int(data["potion_reward"]), _player.max_potions)
	_hud.flash_challenge(tr("CHALLENGE_WON") % xp)
	FloatingText.spawn(_entities, _player.global_position, tr("FX_XP") % xp, COLOR_XP, 24.0)
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
		summoner.add_minion(minion)


func _on_enemy_died(enemy: Enemy) -> void:
	_kills += 1
	_hud.set_kills(_kills)
	FloatingText.spawn(_entities, enemy.global_position, tr("FX_XP") % enemy.xp_reward, COLOR_XP, 24.0)
	Sfx.play("xp", enemy.global_position)
	_player.add_experience(enemy.xp_reward)


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
	FloatingText.spawn(_entities, _player.global_position, tr("FX_LEVEL_UP"), Player.COLOR_EMPOWERED, 56.0)
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
	if get_tree().process_frame.is_connected(_on_region_step):
		get_tree().process_frame.disconnect(_on_region_step)


func _back_to_menu() -> void:
	get_tree().paused = false
	HitFeedback.reset()
	get_tree().change_scene_to_file(MENU_SCENE)
