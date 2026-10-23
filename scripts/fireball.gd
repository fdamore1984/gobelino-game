class_name Fireball
extends Node2D
## Palla di fuoco lanciata dal giocatore: cerca il nemico più vicino, lo
## insegue curvando e lo colpisce. Senza nemici vola dritta e si spegne.
## Illumina attorno a sé (utile di notte).

const SPEED := 470.0
## Velocità con cui curva verso il bersaglio (radianti al secondo).
const TURN_RATE := 7.0
const LIFETIME := 2.6
## Cerca bersagli entro questa distanza.
const SEEK_RANGE := 650.0
const RADIUS := 10.0
## Volando, resta sopra il terreno a questa altezza.
const FLIGHT_HEIGHT := 30.0
## Colpisce solo nemici più o meno alla sua altezza.
const HIT_HEIGHT_REACH := 70.0
const EXPLOSION_TIME := 0.3
const COLOR_CORE := Color(1.0, 0.95, 0.6)
const COLOR_FLAME := Color(1.0, 0.45, 0.1)

var damage := 20
var direction := Vector2.RIGHT
## Altezza del terreno da cui è partita: la palla resta a quella quota.
var altitude := 0.0

var _target: Enemy
var _age := 0.0
var _exploding := 0.0
var _trail: Array[Vector2] = []
var _light := PointLight2D.new()


func _ready() -> void:
	z_index = 5
	_light.texture = LightTexture.get_texture()
	_light.color = Color(1.0, 0.6, 0.3)
	_light.energy = 0.9
	_light.texture_scale = 0.7
	add_child(_light)
	_target = _find_target()


func _physics_process(delta: float) -> void:
	_age += delta
	if _exploding > 0.0:
		_exploding += delta
		_light.energy = 1.5 * (1.0 - _exploding / EXPLOSION_TIME)
		queue_redraw()
		if _exploding >= EXPLOSION_TIME:
			queue_free()
		return
	if _target == null or not is_instance_valid(_target) or _target.is_dead():
		_target = _find_target()
	if _target:
		var wanted := (_target.global_position - global_position).normalized()
		direction = Vector2.from_angle(rotate_toward(direction.angle(), wanted.angle(), TURN_RATE * delta))
	_trail.push_front(position)
	if _trail.size() > 8:
		_trail.pop_back()
	position += direction * SPEED * delta
	# La luce cade a terra sotto la palla, come un'ellisse isometrica.
	_light.position.y = -altitude
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead() or absf(enemy.ground_elevation - altitude) > HIT_HEIGHT_REACH:
			continue
		if global_position.distance_to(enemy.global_position) < RADIUS + enemy.radius:
			_explode(enemy)
			return
	if _age >= LIFETIME:
		_explode(null)
	queue_redraw()


func _find_target() -> Enemy:
	var best: Enemy = null
	var best_distance := SEEK_RANGE
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead() or absf(enemy.ground_elevation - altitude) > HIT_HEIGHT_REACH:
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best


func _explode(enemy: Enemy) -> void:
	_exploding = 0.001
	if enemy:
		enemy.take_damage(damage, direction, true)
		HitFeedback.hit(get_tree(), 0.05)
	Sfx.play("fireball_hit", global_position, 1.0, -2.0 if enemy else -8.0)


func _draw() -> void:
	var lift := Vector2(0, -altitude - FLIGHT_HEIGHT)
	if _exploding > 0.0:
		var t := _exploding / EXPLOSION_TIME
		draw_circle(lift, RADIUS + 40.0 * t, Color(COLOR_FLAME, 0.6 * (1.0 - t)))
		draw_arc(lift, RADIUS + 55.0 * t, 0.0, TAU, 24, Color(COLOR_CORE, 1.0 - t), 3.0)
		return
	# Ombra a terra, scia di fiamme e nucleo luminoso che pulsa.
	draw_circle(Vector2(0, -altitude + 6.0), RADIUS * 0.8, Color(0, 0, 0, 0.2))
	for i in _trail.size():
		var fade := 1.0 - float(i) / _trail.size()
		draw_circle(_trail[i] - position + lift, RADIUS * fade, Color(COLOR_FLAME, 0.5 * fade))
	var pulse := 1.0 + 0.15 * sin(_age * 40.0)
	draw_circle(lift, RADIUS * 1.4 * pulse, Color(COLOR_FLAME, 0.8))
	draw_circle(lift, RADIUS * 0.7, COLOR_CORE)
