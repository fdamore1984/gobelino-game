class_name Loot
extends Node2D
## Oggetto a terra uscito da una cassa: salta fuori, poi galleggia finché
## il giocatore non ci passa sopra e lo raccoglie.

const PICKUP_RANGE := 38.0
## Appena uscito dalla cassa non si raccoglie subito, così si vede volare.
const PICKUP_DELAY := 0.45
const SIZE := 26.0
const FLY_TIME := 0.4

var item_id := "gold"
var amount := 1
var player: Player

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _age := 0.0
var _lift := 0.0


## Esce da from e atterra in to.
func launch(from: Vector2, to: Vector2) -> void:
	_from = from
	_to = to
	position = from


func _ready() -> void:
	add_to_group("loot")
	if World.current:
		_lift = World.current.elevation_at(_to)


func _physics_process(delta: float) -> void:
	_age += delta
	var t := minf(_age / FLY_TIME, 1.0)
	position = _from.lerp(_to, t)
	if _age >= PICKUP_DELAY and player and not player.is_dead() \
			and player.position.distance_to(position) < PICKUP_RANGE \
			and absf(player.ground_elevation - _lift) < 40.0:
		player.pickup(item_id, amount)
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := minf(_age / FLY_TIME, 1.0)
	# Salto ad arco all'uscita, poi galleggia su e giù.
	var hop := sin(PI * t) * 50.0
	var bob := 4.0 * sin(_age * 4.0) if t >= 1.0 else 0.0
	var center := Vector2(0, -_lift - 18.0 - hop - bob)
	Shapes.disc(self, Vector2(0, -_lift + 4.0), 9.0, Color(0, 0, 0, 0.25))
	Shapes.disc(self, center, SIZE * 0.6, Color(1, 1, 0.8, 0.18 + 0.1 * sin(_age * 6.0)))
	ItemIcon.draw_item(self, center, SIZE, item_id)
