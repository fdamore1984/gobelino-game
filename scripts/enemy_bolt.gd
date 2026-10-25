class_name EnemyBolt
extends Node2D
## Dardo magico scagliato dai nemici lanciatori (e dalle magie del boss,
## più grandi, vedi radius): vola dritto e colpisce il
## giocatore (si può schivare, saltare o parare come gli altri colpi).
## Non attraversa pareti, montagne, roccia e ostacoli solidi: lì si spegne.

const RADIUS := 9.0
const FLIGHT_HEIGHT := 26.0
const HIT_HEIGHT_REACH := 50.0

var direction := Vector2.RIGHT
var speed := 260.0
var damage := 1
var max_distance := 600.0
var altitude := 0.0
var color := Color(0.8, 0.5, 1.0)
## Grandezza del dardo (per collisioni e disegno).
var radius := RADIUS

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
			and position.distance_to(player.position) < radius + Player.RADIUS:
		# Il colpo arriva da dove si trova il dardo: la parata frontale funziona,
		# anche appena alzata (la parata è istantanea e gira subito il giocatore).
		var result := player.receive_hit(position - direction * 40.0, damage)
		if result != "ignored":
			if result in ["blocked", "parried", "broken"]:
				# Parato: il dardo si spezza sulla spada con un lampo.
				HitSpark.spawn(get_parent(), position, altitude + FLIGHT_HEIGHT, 30.0, Player.COLOR_GUARD_SPARK)
			queue_free()
			return
	if World.current and World.current.blocks_projectile(position, altitude, FLIGHT_HEIGHT, radius):
		queue_free()
		return
	if _travelled >= max_distance:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var lift := Vector2(0, -altitude - FLIGHT_HEIGHT)
	Shapes.disc(self, Vector2(0, -altitude + 4.0), radius * 0.7, Color(0, 0, 0, 0.2))
	for i in 4:
		Shapes.disc(self, lift - direction * (i + 1) * 9.0, radius * (0.8 - i * 0.15), Color(color, 0.35 - i * 0.07))
	var spin := _age * 12.0
	draw_primitive(PackedVector2Array([
		lift + Vector2.from_angle(spin) * radius * 1.3, lift + Vector2.from_angle(spin + PI / 2.0) * radius * 0.7,
		lift + Vector2.from_angle(spin + PI) * radius * 1.3, lift + Vector2.from_angle(spin + PI * 1.5) * radius * 0.7,
	]), PackedColorArray([color]), PackedVector2Array())
	Shapes.disc(self, lift, radius * 0.4, Color(1, 1, 1, 0.9))
