class_name EnemyBolt
extends Node2D
## Dardo magico scagliato dai nemici lanciatori: vola dritto e colpisce il
## giocatore (si può schivare, saltare o parare come gli altri colpi).

const RADIUS := 9.0
const FLIGHT_HEIGHT := 26.0
const HIT_HEIGHT_REACH := 50.0

var direction := Vector2.RIGHT
var speed := 260.0
var damage := 1
var max_distance := 600.0
var altitude := 0.0
var color := Color(0.8, 0.5, 1.0)

var _travelled := 0.0
var _age := 0.0


func _ready() -> void:
	z_index = 5


func _physics_process(delta: float) -> void:
	_age += delta
	var step := direction * speed * delta
	position += step
	_travelled += step.length()
	var player := World.current.player as Player if World.current else null
	if player and not player.is_dead() and absf(player.ground_elevation - altitude) <= HIT_HEIGHT_REACH \
			and position.distance_to(player.position) < RADIUS + Player.RADIUS:
		# Il colpo arriva da dove si trova il dardo: la parata frontale funziona.
		if player.receive_hit(position - direction * 40.0, damage) != "ignored":
			queue_free()
			return
	if _travelled >= max_distance:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var lift := Vector2(0, -altitude - FLIGHT_HEIGHT)
	Shapes.disc(self, Vector2(0, -altitude + 4.0), RADIUS * 0.7, Color(0, 0, 0, 0.2))
	for i in 4:
		Shapes.disc(self, lift - direction * (i + 1) * 9.0, RADIUS * (0.8 - i * 0.15), Color(color, 0.35 - i * 0.07))
	var spin := _age * 12.0
	draw_primitive(PackedVector2Array([
		lift + Vector2.from_angle(spin) * RADIUS * 1.3, lift + Vector2.from_angle(spin + PI / 2.0) * RADIUS * 0.7,
		lift + Vector2.from_angle(spin + PI) * RADIUS * 1.3, lift + Vector2.from_angle(spin + PI * 1.5) * RADIUS * 0.7,
	]), PackedColorArray([color]), PackedVector2Array())
	Shapes.disc(self, lift, RADIUS * 0.4, Color(1, 1, 1, 0.9))
