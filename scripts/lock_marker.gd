class_name LockMarker
extends Node2D
## Mirino sul nemico agganciato (vedi Player.lock_target): un anello rosso
## che gira attorno ai suoi piedi, steso a terra nella prospettiva
## isometrica. Agganciando un nuovo nemico l'anello si stringe su di lui.

const COLOR := Color(1.0, 0.25, 0.2)
## Durata e ampiezza dell'impulso dell'anello su un nuovo bersaglio.
const PULSE_TIME := 0.25
const PULSE_SCALE := 0.8

var target: Enemy
## Bersaglio del passo precedente e impulso rimasto (0-1).
var _shown_target: Enemy
var _pulse := 0.0


func _ready() -> void:
	top_level = true
	z_index = 15
	visible = false


## Segue il nemico nel passo fisico, come lui: l'interpolazione li muove insieme.
func _physics_process(delta: float) -> void:
	var shown := target != null and is_instance_valid(target) and not target.is_dead()
	_pulse = move_toward(_pulse, 0.0, delta / PULSE_TIME)
	# Nuovo bersaglio: il mirino salta su di lui senza scivolare dal vecchio.
	if shown and (not visible or target != _shown_target):
		global_position = target.global_position
		reset_physics_interpolation()
		_pulse = 1.0
	_shown_target = target if shown else null
	visible = shown
	if visible:
		global_position = target.global_position
		queue_redraw()


func _draw() -> void:
	if target == null or not is_instance_valid(target):
		return
	var time := Time.get_ticks_msec() / 1000.0
	var radius := target.radius * 1.35 * (1.0 + PULSE_SCALE * _pulse)
	draw_set_transform(Vector2(0, -target.ground_elevation + target.radius * 0.8), 0.0, Vector2(1.0, 0.5))
	for k in 4:
		var start := time * 2.0 + k * TAU / 4.0
		draw_arc(Vector2.ZERO, radius, start, start + 0.9, 10, COLOR, 4.0)
