class_name LockMarker
extends Node2D
## Mirino sul nemico agganciato (vedi Player.lock_target): un anello che
## gira attorno ai suoi piedi e una freccia che ondeggia sopra la testa.

const COLOR := Color(1.0, 0.4, 0.3)

var target: Enemy


func _ready() -> void:
	top_level = true
	z_index = 15
	visible = false


## Segue il nemico nel passo fisico, come lui: l'interpolazione li muove insieme.
func _physics_process(_delta: float) -> void:
	var shown := target != null and is_instance_valid(target) and not target.is_dead()
	if shown and not visible:
		global_position = target.global_position
		reset_physics_interpolation()
	visible = shown
	if visible:
		global_position = target.global_position
		queue_redraw()


func _draw() -> void:
	if target == null or not is_instance_valid(target):
		return
	var time := Time.get_ticks_msec() / 1000.0
	var lift := Vector2(0, -target.ground_elevation)
	var radius := target.radius * 1.35
	draw_set_transform(lift, 0.0, Vector2(1.0, 0.5))
	for k in 4:
		var start := time * 2.0 + k * TAU / 4.0
		draw_arc(Vector2.ZERO, radius, start, start + 0.9, 10, COLOR, 4.0)
	draw_set_transform(lift)
	var top := Vector2(0, -target.radius * 2.4 - 8.0 - absf(sin(time * 4.0)) * 6.0)
	draw_colored_polygon(PackedVector2Array([top, top + Vector2(-9, -12), top + Vector2(9, -12)]), COLOR)
	draw_polyline(PackedVector2Array([top, top + Vector2(-9, -12), top + Vector2(9, -12), top]), Color(0.3, 0.05, 0.05), 2.0)
