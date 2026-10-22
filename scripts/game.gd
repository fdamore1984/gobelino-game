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

@onready var _world: World = $World
@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player
@onready var _hud: Hud = $HUD

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


func _ready() -> void:
	_world.entities = _entities
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
	for i in ENEMY_COUNT:
		_spawn_enemy(EnemyTypes.pick_random(_player.level), _random_position(START_SPAWN_RANGE))


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("menu") and not get_tree().paused:
		_back_to_menu()
		return
	_update_challenge(delta)
	_check_chests()
	_maintain_timer -= delta
	if _maintain_timer <= 0.0:
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
	var away := (_player.position - at).normalized()
	for i in drops.size():
		var loot := Loot.new()
		loot.item_id = drops[i][0]
		loot.amount = drops[i][1]
		loot.player = _player
		var angle := away.angle() + (i - (drops.size() - 1) / 2.0) * 0.7
		loot.launch(at, _world.free_position_near(at + Vector2.from_angle(angle) * 60.0, 10.0))
		_entities.add_child(loot)


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


func _back_to_menu() -> void:
	get_tree().paused = false
	HitFeedback.reset()
	get_tree().change_scene_to_file(MENU_SCENE)
