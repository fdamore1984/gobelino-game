extends Node2D
## Livello di test del gameplay: un piano senza limiti con nemici di vari
## tipi sparsi a caso attorno al giocatore. I nemici troppo lontani vengono
## rimossi e ne compaiono di nuovi fuori dallo schermo, così ce ne sono
## sempre. Gestisce anche esperienza, livelli e scelta dei potenziamenti.

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

@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player
@onready var _hud: Hud = $HUD

var _kills := 0
var _maintain_timer := MAINTAIN_INTERVAL
## Livelli guadagnati per cui va ancora scelto il potenziamento.
var _pending_level_ups := 0


func _ready() -> void:
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


func _random_position(distance_range: Vector2) -> Vector2:
	var offset := Vector2.from_angle(randf() * TAU) * randf_range(distance_range.x, distance_range.y)
	return _player.position + offset


func _spawn_enemy(type_id: String, at: Vector2) -> Enemy:
	var enemy := Enemy.new()
	enemy.setup(type_id)
	enemy.player = _player
	enemy.position = at
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


func _back_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
