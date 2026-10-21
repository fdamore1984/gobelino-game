extends Node2D
## Terreno del livello di test: un piano senza limiti con una griglia
## isometrica, disegnata solo nella parte inquadrata dalla telecamera.

const TILE_HEIGHT := 64.0
const COLOR_GROUND := Color(0.16, 0.2, 0.14)
const COLOR_LINE := Color(0.21, 0.26, 0.18)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	var center := camera.get_screen_center_position() if camera else Vector2.ZERO
	var zoom := camera.zoom if camera else Vector2.ONE
	var half := get_viewport_rect().size / zoom / 2.0 + Vector2(TILE_HEIGHT, TILE_HEIGHT)
	var view := Rect2(center - half, half * 2.0)
	draw_rect(view, COLOR_GROUND)

	# Rette y = ±x/2 + k * TILE_HEIGHT: formano i rombi della griglia isometrica.
	var left := view.position.x
	var right := view.end.x
	for slope: float in [0.5, -0.5]:
		var offsets := [
			view.position.y - slope * left, view.position.y - slope * right,
			view.end.y - slope * left, view.end.y - slope * right,
		]
		var first := floori(offsets.min() / TILE_HEIGHT)
		var last := ceili(offsets.max() / TILE_HEIGHT)
		for k in range(first, last + 1):
			var offset := k * TILE_HEIGHT
			draw_line(Vector2(left, slope * left + offset), Vector2(right, slope * right + offset), COLOR_LINE, 2.0)
