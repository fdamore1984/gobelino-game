class_name Loot
extends Node2D
## Oggetto a terra uscito da una cassa o da un nemico: salta fuori, poi
## galleggia finché il giocatore non lo raccoglie. Quando il giocatore
## passa entro magnet_range() pixel l'oggetto gli vola incontro come
## attirato da una calamita, sempre più veloce (MAGNET_ACCEL, fino a
## MAGNET_MAX_SPEED), e si raccoglie toccandolo; non si attira quello che
## non si può prendere (vedi Player.can_pick_up: per esempio un kit medico
## con la vita piena), che resta a terra. Le scorte (kit medici, taniche,
## batterie di ricambio) si usano appena raccolte e, se nessuno le prende,
## dopo lifetime secondi spariscono, lampeggiando negli ultimi blink
## (vedi Items.supply_lifetime): bisogna menare e raccoglierle in fretta.
## Tenendo premuto
## "focus" (R2) gli oggetti a terra si vedono molto meglio: mentre il mondo
## si spegne (vedi LowHealthVignette) restano a colori, più grandi, sopra a
## tutto il resto e con un'aura bianca attorno.
##
## La sacca (bag) è il denaro perso morendo (vedi Game._drop_bag): una sacca
## legata con una luce dorata che pulsa, che non prende luci (si vede anche
## al buio) e che, raccolta, lo dice a Game (picked_up).

## Raccolto dal giocatore (per la sacca: vedi Game._on_bag_picked).
signal picked_up(item_id: String, amount: int)

const PICKUP_RANGE := 38.0
## Calamita (vedi in cima): distanza da cui si attira, accelerazione e
## velocità massima verso il giocatore.
const MAGNET_RANGE := 150.0
const MAGNET_ACCEL := 1500.0
const MAGNET_MAX_SPEED := 950.0
## Si attira solo con un dislivello col giocatore di al più questi pixel.
const MAGNET_HEIGHT := 120.0
## Lampeggiando prima di sparire: secondi accesi e spenti.
const BLINK_PERIOD := 0.24
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
## È la sacca del denaro perso morendo.
var bag := false
## Secondi dopo cui sparisce se nessuno lo raccoglie (INF: mai) e da
## quanti prima di sparire lampeggia (vedi Game._drop_loot).
var lifetime := INF
var blink := 0.0

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _age := 0.0
var _lift := 0.0
## Attirato dal giocatore (vedi in cima) e velocità attuale.
var _attracted := false
var _speed := 0.0


## Esce da from e atterra in to.
func launch(from: Vector2, to: Vector2) -> void:
	_from = from
	_to = to
	position = from


func _ready() -> void:
	add_to_group("loot")
	add_to_group(LowHealthVignette.FOCUS_GROUP)
	if bag:
		material = Enemy._unshaded_material()
	if World.current:
		_lift = World.current.elevation_at(_to)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	if _age < FLY_TIME:
		position = _from.lerp(_to, _age / FLY_TIME)
	z_index = FOCUS_Z if LowHealthVignette.focus_held() else 0
	if _age >= PICKUP_DELAY and is_instance_valid(player) and not player.is_dead() and player.can_pick_up(item_id):
		var distance := player.position.distance_to(position)
		if not _attracted and distance < magnet_range() and absf(player.ground_elevation - _lift) < MAGNET_HEIGHT:
			_attracted = true
		if _attracted:
			_speed = minf(_speed + MAGNET_ACCEL * delta, MAGNET_MAX_SPEED)
			position = position.move_toward(player.position, _speed * delta)
			_lift = lerpf(_lift, player.ground_elevation, minf(delta * 10.0, 1.0))
			distance = player.position.distance_to(position)
		if distance < PICKUP_RANGE and (_attracted or absf(player.ground_elevation - _lift) < 40.0):
			if player.pickup(item_id, amount):
				picked_up.emit(item_id, amount)
				queue_free()
				return
	else:
		# Non serve più (per esempio la vita si è riempita): resta dov'è.
		_attracted = false
		_speed = 0.0
	if lifetime != INF and lifetime - _age < blink:
		modulate.a = 1.0 if fmod(lifetime - _age, BLINK_PERIOD * 2.0) > BLINK_PERIOD else 0.25
	queue_redraw()


## Distanza da cui il giocatore attira l'oggetto (vedi in cima).
func magnet_range() -> float:
	return MAGNET_RANGE


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
	if bag:
		_draw_bag(center)
		return
	if LowHealthVignette.focus_held():
		var pulse := 0.5 + 0.5 * sin(_age * 5.0)
		Shapes.glow(self, center, SIZE * FOCUS_SCALE * FOCUS_AURA * (0.9 + 0.1 * pulse), COLOR_AURA)
		ItemIcon.draw_item(self, center, SIZE * FOCUS_SCALE, item_id)
		return
	Shapes.disc(self, center, SIZE * 0.6, Color(1, 1, 0.8, 0.18 + 0.1 * sin(_age * 6.0)))
	ItemIcon.draw_item(self, center, SIZE, item_id)


## Sacca del denaro perso: un fascio di luce dorata che pulsa (si vede da
## lontano), la sacca di tela legata in cima e una moneta che spunta.
func _draw_bag(center: Vector2) -> void:
	var pulse := 0.5 + 0.5 * sin(_age * 4.0)
	var base := Vector2(0, -_lift)
	draw_primitive(PackedVector2Array([base + Vector2(-10, 0), base + Vector2(10, 0), base + Vector2(5, -120), base + Vector2(-5, -120)]),
			PackedColorArray([Color(1.0, 0.85, 0.35, 0.35 + 0.15 * pulse), Color(1.0, 0.85, 0.35, 0.35 + 0.15 * pulse),
			Color(1.0, 0.85, 0.35, 0.0), Color(1.0, 0.85, 0.35, 0.0)]), PackedVector2Array())
	Shapes.glow(self, center, SIZE * (1.2 + 0.2 * pulse), Color(1.0, 0.8, 0.3, 0.45))
	Shapes.ink_disc(self, center + Vector2(0, 3), 11.0, Minimap.COLOR_BAG)
	draw_rect(Rect2(center + Vector2(-5, -12), Vector2(10, 6)), Shapes.INK)
	draw_rect(Rect2(center + Vector2(-4, -11), Vector2(8, 4)), Minimap.COLOR_BAG.darkened(0.2))
	draw_line(center + Vector2(-6, -6), center + Vector2(6, -6), Shapes.INK, 2.5)
	Shapes.ink_disc(self, center + Vector2(4, 5), 4.0, Minimap.COLOR_CHEST, 1.5)
