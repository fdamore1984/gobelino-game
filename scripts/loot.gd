class_name Loot
extends Node2D
## Oggetto a terra uscito da una cassa: salta fuori, poi galleggia finché
## il giocatore non ci passa sopra e lo raccoglie. Tenendo premuto
## "focus" (R2) gli oggetti a terra si vedono molto meglio: mentre il mondo
## si spegne (vedi LowHealthVignette) restano a colori, più grandi, sopra a
## tutto il resto e con un'aura bianca attorno.

const PICKUP_RANGE := 38.0
## Appena uscito dalla cassa non si raccoglie subito, così si vede volare.
const PICKUP_DELAY := 0.45
const SIZE := 26.0
const FLY_TIME := 0.4
const FOCUS_SCALE := 1.35
## Aura bianca in modalità focus: raggio rispetto all'oggetto e forza.
const FOCUS_AURA := 1.6
const COLOR_AURA := Color(1, 1, 1, 0.7)
## In modalità focus l'oggetto si disegna sopra alberi, sassi e personaggi.
const FOCUS_Z := 50

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
	add_to_group(LowHealthVignette.FOCUS_GROUP)
	if World.current:
		_lift = World.current.elevation_at(_to)


func _physics_process(delta: float) -> void:
	_age += delta
	var t := minf(_age / FLY_TIME, 1.0)
	position = _from.lerp(_to, t)
	z_index = FOCUS_Z if LowHealthVignette.focus_held() else 0
	if _age >= PICKUP_DELAY and player and not player.is_dead() \
			and player.position.distance_to(position) < PICKUP_RANGE \
			and absf(player.ground_elevation - _lift) < 40.0:
		# Con la cintura piena le pozioni restano a terra.
		if player.pickup(item_id, amount):
			queue_free()
	queue_redraw()


## Centro dell'oggetto disegnato (salto e galleggiamento compresi), rispetto alla base.
func _center() -> Vector2:
	var t := minf(_age / FLY_TIME, 1.0)
	# Salto ad arco all'uscita, poi galleggia su e giù.
	var hop := sin(PI * t) * 50.0
	var bob := 4.0 * sin(_age * 4.0) if t >= 1.0 else 0.0
	return Vector2(0, -_lift - 18.0 - hop - bob)


## Modalità focus: dove resta a colori e quanto è grande (vedi LowHealthVignette).
func focus_spot() -> Vector3:
	var at := global_position + _center()
	return Vector3(at.x, at.y, SIZE * FOCUS_SCALE * 1.4)


func _draw() -> void:
	var center := _center()
	Shapes.disc(self, Vector2(0, -_lift + 4.0), 9.0, Shapes.SHADOW)
	if LowHealthVignette.focus_held():
		var pulse := 0.5 + 0.5 * sin(_age * 5.0)
		Shapes.glow(self, center, SIZE * FOCUS_SCALE * FOCUS_AURA * (0.9 + 0.1 * pulse), COLOR_AURA)
		ItemIcon.draw_item(self, center, SIZE * FOCUS_SCALE, item_id)
		return
	Shapes.disc(self, center, SIZE * 0.6, Color(1, 1, 0.8, 0.18 + 0.1 * sin(_age * 6.0)))
	ItemIcon.draw_item(self, center, SIZE, item_id)
