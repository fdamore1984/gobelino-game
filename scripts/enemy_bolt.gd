class_name EnemyBolt
extends Node2D
## Dardo magico scagliato dai nemici lanciatori (e dalle magie del boss,
## più grandi, vedi radius), o freccia degli arcieri (arrow): vola dritto e
## colpisce il giocatore (si può schivare, saltare o parare come gli altri
## colpi). Se il giocatore fluttua a mezz'aria caricando lo slam aereo il
## colpo sale verso di lui e lo raggiunge (vedi Player.receive_hit).
## Non attraversa pareti, montagne, roccia e ostacoli solidi: lì si spegne. Colpisce anche gli altri nemici che incontra (fuoco amico,
## vedi Enemy.hurt_enemy), mai chi l'ha sparato.

const RADIUS := 9.0
const FLIGHT_HEIGHT := 26.0
const HIT_HEIGHT_REACH := 50.0

var direction := Vector2.RIGHT
var speed := 260.0
## Punti di danno per il fuoco amico (vedi Enemy.hurt_enemy) e punti vita
## tolti al giocatore (vedi EnemyTypes.player_damage).
var damage := 1
var player_damage := 1
var max_distance := 600.0
var altitude := 0.0
var color := Color(0.8, 0.5, 1.0)
## Grandezza del dardo (per collisioni e disegno).
var radius := RADIUS
## Freccia invece di dardo magico (solo l'aspetto cambia).
var arrow := false
## Il nemico che l'ha sparato (non viene colpito dal suo proiettile) e il
## suo livello di minaccia (per i danni del fuoco amico, anche se intanto muore).
var shooter: Enemy
var threat_level := 1

var _travelled := 0.0
var _age := 0.0
## Quanto si è alzato in volo verso il giocatore sospeso a mezz'aria.
var _rise := 0.0


func _ready() -> void:
	z_index = 5


func _physics_process(delta: float) -> void:
	# Durante l'attacco speciale della Frenesia anche i proiettili restano sospesi.
	if Enemy.frozen:
		return
	_age += delta
	var step := direction * speed * delta
	position += step
	_travelled += step.length()
	var player := World.current.player as Player if World.current else null
	if player:
		# Verso il giocatore sospeso a mezz'aria il colpo sale (il corpo sta
		# sopra le gambe), altrimenti torna all'altezza di volo.
		var wanted := 0.0
		if player.is_air_charging():
			wanted = maxf(player.altitude() - altitude + Player.LEG_LENGTH - FLIGHT_HEIGHT, 0.0)
		_rise = move_toward(_rise, wanted, speed * delta)
	if player and not player.is_dead() and absf(player.ground_elevation - altitude) <= HIT_HEIGHT_REACH \
			and position.distance_to(player.position) < radius + Player.RADIUS:
		# Il colpo arriva da dove si trova il dardo: la parata frontale funziona,
		# anche appena alzata (la parata è istantanea e gira subito il giocatore).
		var result := player.receive_hit(position - direction * 40.0, player_damage, true)
		if result != "ignored":
			if result in ["blocked", "parried", "broken"]:
				# Parato: il dardo si spezza sulla spada con un lampo.
				HitSpark.spawn(get_parent(), position, altitude + FLIGHT_HEIGHT + _rise, 30.0, Player.COLOR_GUARD_SPARK)
			queue_free()
			return
	if _hit_enemy():
		queue_free()
		return
	if World.current and World.current.blocks_projectile(position, altitude, FLIGHT_HEIGHT, radius):
		queue_free()
		return
	if _travelled >= max_distance:
		queue_free()
	queue_redraw()


## Fuoco amico: il primo altro nemico toccato, alla stessa altezza, viene
## ferito come da un colpo di chi ha sparato. Restituisce true se ha colpito.
func _hit_enemy() -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or (is_instance_valid(shooter) and enemy == shooter) or enemy.is_dead() \
				or absf(enemy.ground_elevation - altitude) > HIT_HEIGHT_REACH:
			continue
		if position.distance_to(enemy.position) < radius + enemy.radius:
			Enemy.hurt_enemy(enemy, damage, threat_level, direction, false)
			HitSpark.spawn(get_parent(), position, altitude + FLIGHT_HEIGHT, 12.0, color)
			return true
	return false


func _draw() -> void:
	var lift := Vector2(0, -altitude - FLIGHT_HEIGHT - _rise)
	Shapes.disc(self, Vector2(0, -altitude + 4.0), radius * 0.7, Color(0, 0, 0, 0.2))
	if arrow:
		_draw_arrow(lift)
		return
	for i in 4:
		Shapes.disc(self, lift - direction * (i + 1) * 9.0, radius * (0.8 - i * 0.15), Color(color, 0.35 - i * 0.07))
	var spin := _age * 12.0
	draw_primitive(PackedVector2Array([
		lift + Vector2.from_angle(spin) * radius * 1.3, lift + Vector2.from_angle(spin + PI / 2.0) * radius * 0.7,
		lift + Vector2.from_angle(spin + PI) * radius * 1.3, lift + Vector2.from_angle(spin + PI * 1.5) * radius * 0.7,
	]), PackedColorArray([color]), PackedVector2Array())
	Shapes.disc(self, lift, radius * 0.4, Color(1, 1, 1, 0.9))


## Freccia: asta di legno, punta di metallo e piume, con una scia leggera.
func _draw_arrow(at: Vector2) -> void:
	var across := direction.orthogonal()
	var tip := at + direction * 14.0
	var tail := at - direction * 14.0
	draw_line(tail - direction * 10.0, tail, Color(1, 1, 1, 0.25), 2.0)
	draw_line(tail, tip, Color(0.55, 0.38, 0.2), 2.5)
	draw_colored_polygon(PackedVector2Array([tip + direction * 8.0, tip + across * 4.0, tip - across * 4.0]), Color(0.82, 0.84, 0.88))
	for side: float in [1.0, -1.0]:
		draw_line(tail, tail - direction * 6.0 + across * side * 5.0, color, 2.0)
