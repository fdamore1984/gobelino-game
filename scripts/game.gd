extends Node2D
## Livello di test del gameplay: un piano senza limiti con nemici sparsi
## a caso attorno al giocatore. I nemici troppo lontani vengono rimossi e
## ne compaiono di nuovi fuori dallo schermo, così ce ne sono sempre.

const MENU_SCENE := "res://scenes/menu.tscn"

const ENEMY_COUNT := 12
## All'avvio i nemici sono sparsi a questa distanza dal giocatore.
const START_SPAWN_RANGE := Vector2(450.0, 1300.0)
## Poi ricompaiono fuori dall'inquadratura.
const SPAWN_RANGE := Vector2(850.0, 1400.0)
const DESPAWN_DISTANCE := 2000.0
const MAINTAIN_INTERVAL := 1.0
const GAME_OVER_DELAY := 2.5

@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player
@onready var _hud: Hud = $HUD

var _kills := 0
var _maintain_timer := MAINTAIN_INTERVAL


func _ready() -> void:
	_player.health_changed.connect(_hud.set_health)
	_player.died.connect(_on_player_died)
	_hud.set_health(_player.health, Player.MAX_HEALTH)
	_hud.set_kills(_kills)
	for i in ENEMY_COUNT:
		_spawn_enemy(START_SPAWN_RANGE)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("menu"):
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
		_spawn_enemy(SPAWN_RANGE)


func _spawn_enemy(distance_range: Vector2) -> void:
	var enemy := Enemy.new()
	enemy.player = _player
	var offset := Vector2.from_angle(randf() * TAU) * randf_range(distance_range.x, distance_range.y)
	enemy.position = _player.position + offset
	enemy.died.connect(_on_enemy_died)
	_entities.add_child(enemy)


func _on_enemy_died(_enemy: Enemy) -> void:
	_kills += 1
	_hud.set_kills(_kills)


func _on_player_died() -> void:
	_hud.show_message("Sconfitto!")
	# Collegato al segnale (e non con await) così, se nel frattempo si torna
	# al menù, il timer non richiama una scena già distrutta.
	get_tree().create_timer(GAME_OVER_DELAY).timeout.connect(_back_to_menu)


func _back_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
