class_name Obstacle
extends Node2D
## Ostacolo naturale del mondo, disegnato con forme geometriche: albero,
## sasso, cespuglio, rovi, cassa o il totem al centro di un'arena. La posizione è la base a terra, così
## l'ordinamento per y lo mette davanti o dietro ai personaggi; viene
## disegnato più in alto quanto il blocco di terreno su cui si trova. Gli effetti (blocco,
## rallentamento, danni dei rovi) sono gestiti da World.

## La chioma degli alberi diventa trasparente quando il giocatore ci passa dietro.
const CANOPY_FADE_ALPHA := 0.4

var type_id := ""
var radius := 20.0
var _type: Dictionary
var _variant := 0
var _canopy_alpha := 1.0
var _opened := false
## Altezza del terreno sotto l'ostacolo.
var _lift := 0.0


func setup(data: Dictionary, type: Dictionary) -> void:
	type_id = data["type"]
	radius = data["radius"]
	position = data["position"]
	_variant = data["variant"]
	_lift = data["elevation"]
	_type = type
	# Disegnato una volta sola; solo gli alberi controllano il giocatore e
	# il totem si anima.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	set_process(type_id in ["tree", "totem", "chest"])


func _process(_delta: float) -> void:
	if type_id == "totem":
		queue_redraw()
		return
	if type_id == "chest":
		# Brilla finché è chiusa; poi si ridisegna aperta.
		_opened = World.current != null and World.current.is_chest_opened(position)
		queue_redraw()
		return
	var player: Node2D = World.current.player if World.current else null
	var target := 1.0
	if player:
		# Confronto sullo schermo: anche il giocatore è disegnato alla sua altezza.
		var player_lift: float = World.current.elevation_at(player.global_position)
		var offset := player.global_position - Vector2(0, player_lift) - (global_position - Vector2(0, _lift))
		# Dietro l'albero (più in alto sullo schermo) e sotto la chioma.
		if offset.y < 0.0 and offset.y > -radius * 3.2 and absf(offset.x) < radius * 1.1:
			target = CANOPY_FADE_ALPHA
	if not is_equal_approx(target, _canopy_alpha):
		_canopy_alpha = move_toward(_canopy_alpha, target, 0.1)
		queue_redraw()


func _color(index: int) -> Color:
	var colors: Array = _type["colors"]
	var color: Array = colors[index % colors.size()]
	return Color(color[0], color[1], color[2])


func _type_color(key: String) -> Color:
	var color: Array = _type[key]
	return Color(color[0], color[1], color[2])


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _variant
	draw_set_transform(Vector2(0, -_lift))
	match type_id:
		"tree":
			_draw_tree(rng)
		"rock":
			_draw_rock(rng)
		"bush":
			_draw_bush(rng)
		"bramble":
			_draw_bramble(rng)
		"totem":
			_draw_totem()
		"chest":
			_draw_chest()


func _draw_shadow(width: float) -> void:
	draw_set_transform(Vector2(0, -_lift), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, width, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2(0, -_lift))


## Tronco e chioma: tonda (latifoglia) o a strati di triangoli (abete).
func _draw_tree(rng: RandomNumberGenerator) -> void:
	_draw_shadow(radius * 0.9)
	var trunk := _type_color("trunk")
	var trunk_height := radius * 1.1
	draw_rect(Rect2(-radius * 0.18, -trunk_height, radius * 0.36, trunk_height), trunk)
	draw_rect(Rect2(-radius * 0.18, -trunk_height, radius * 0.12, trunk_height), trunk.lightened(0.15))
	var leaves := _color(rng.randi())
	leaves.a = _canopy_alpha
	var dark := leaves.darkened(0.25)
	if rng.randf() < 0.35:
		for k in 3:
			var width := radius * (1.1 - k * 0.25)
			var base_y := -trunk_height * 0.6 - k * radius * 0.7
			var tip_y := base_y - radius * 1.3
			draw_colored_polygon(PackedVector2Array([Vector2(-width, base_y), Vector2(width, base_y), Vector2(0, tip_y)]), dark if k == 0 else leaves)
			draw_colored_polygon(PackedVector2Array([Vector2(0, base_y), Vector2(width, base_y), Vector2(0, tip_y)]), leaves.darkened(0.12))
	else:
		var center := Vector2(0, -trunk_height - radius * 0.55)
		draw_circle(center + Vector2(0, radius * 0.2), radius, dark)
		draw_circle(center + Vector2(-radius * 0.45, 0), radius * 0.7, leaves)
		draw_circle(center + Vector2(radius * 0.4, -radius * 0.1), radius * 0.75, leaves)
		draw_circle(center + Vector2(0, -radius * 0.45), radius * 0.7, leaves.lightened(0.08))
		draw_circle(center + Vector2(-radius * 0.25, -radius * 0.55), radius * 0.3, Color(leaves.lightened(0.2), 0.6 * _canopy_alpha))


## Masso irregolare con la faccia superiore più chiara.
func _draw_rock(rng: RandomNumberGenerator) -> void:
	_draw_shadow(radius * 1.05)
	var color := _color(rng.randi())
	var points := PackedVector2Array()
	var sides := rng.randi_range(6, 8)
	for k in sides:
		var angle := TAU * k / sides + rng.randf_range(-0.2, 0.2)
		points.append(Vector2(cos(angle), sin(angle) * 0.75) * radius * rng.randf_range(0.8, 1.05) + Vector2(0, -radius * 0.45))
	draw_colored_polygon(points, color.darkened(0.15))
	var top := PackedVector2Array()
	for point in points:
		top.append(point * 0.65 + Vector2(0, -radius * 0.35))
	draw_colored_polygon(top, color.lightened(0.1))
	points.append(points[0])
	draw_polyline(points, color.darkened(0.4), 2.0)


## Cespuglio: gruppo di cerchi, a volte con le bacche.
func _draw_bush(rng: RandomNumberGenerator) -> void:
	_draw_shadow(radius * 0.95)
	var color := _color(rng.randi())
	var blobs := []
	for k in 5:
		blobs.append([Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.9, -0.3)) * radius, radius * rng.randf_range(0.4, 0.6)])
	for blob: Array in blobs:
		draw_circle(blob[0] + Vector2(0, 4), blob[1], color.darkened(0.3))
	for blob: Array in blobs:
		draw_circle(blob[0], blob[1], color)
		draw_circle(blob[0] + Vector2(-blob[1] * 0.3, -blob[1] * 0.3), blob[1] * 0.35, color.lightened(0.12))
	if rng.randf() < 0.5:
		var berries := _type_color("berries")
		for k in 4:
			draw_circle(Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-1.0, -0.3)) * radius, 2.5, berries)


## Rovi: un groviglio di rami spinosi con qualche bacca.
func _draw_bramble(rng: RandomNumberGenerator) -> void:
	draw_set_transform(Vector2(0, -_lift), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, radius, Color(0.12, 0.08, 0.06, 0.45))
	draw_set_transform(Vector2(0, -_lift))
	var colors := [_color(0), _color(1)]
	for k in 9:
		var color: Color = colors[k % 2]
		var start := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.4, 0.4)) * radius
		var end := start + Vector2.from_angle(rng.randf_range(-PI, 0.0)) * radius * rng.randf_range(0.5, 0.9)
		end.y = maxf(end.y, -radius * 0.8)
		var middle := (start + end) / 2.0 + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 4))
		draw_polyline(PackedVector2Array([start, middle, end]), color, 2.0)
		# Spine.
		for point: Vector2 in [middle, (middle + end) / 2.0]:
			var normal := (end - start).normalized().orthogonal() * 5.0
			draw_line(point, point + normal, color.lightened(0.2), 1.5)
			draw_line(point, point - normal * 0.8, color.lightened(0.2), 1.5)
	var berries := _type_color("berries")
	for k in 5:
		draw_circle(Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.6, 0.2)) * radius, 2.5, berries)


## Totem di pietra a tre blocchi con occhi luminosi: azzurri e con un
## anello pulsante a terra quando si può avviare la sfida, rossi durante la
## sfida, spenti dopo.
func _draw_totem() -> void:
	var state := World.current.totem_state(position) if World.current else "ready"
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
	var glow := _type_color("glow")
	if state == "active":
		glow = _type_color("active")
	elif state == "used":
		glow = _type_color("used")
	if state != "used":
		draw_set_transform(Vector2(0, -_lift), 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, radius * 2.2 + pulse * 10.0, 0.0, TAU, 40, Color(glow, 0.35 + 0.3 * pulse), 5.0)
		draw_set_transform(Vector2(0, -_lift))
	_draw_shadow(radius * 1.1)
	var stone := _type_color("stone")
	var y := 0.0
	for k in 3:
		var width := radius * (1.0 - k * 0.18)
		var height := radius * (0.9 - k * 0.1)
		y -= height
		# Faccia davanti e lato in ombra, come un blocco squadrato.
		draw_rect(Rect2(-width, y, width * 2.0, height), stone.darkened(0.05 * k))
		draw_rect(Rect2(width * 0.55, y, width * 0.45, height), stone.darkened(0.25))
		draw_line(Vector2(-width, y), Vector2(width, y), stone.lightened(0.2), 2.0)
		# Occhi e bocca incisi, con la luce dello stato.
		var eye := Color(glow, 0.6 + 0.4 * pulse) if state != "used" else glow
		draw_circle(Vector2(-width * 0.38, y + height * 0.38), width * 0.13, eye)
		draw_circle(Vector2(width * 0.18, y + height * 0.38), width * 0.13, eye)
		draw_line(Vector2(-width * 0.4, y + height * 0.75), Vector2(width * 0.2, y + height * 0.75), stone.darkened(0.45), 3.0)
	# In cima una punta.
	draw_colored_polygon(PackedVector2Array([Vector2(-radius * 0.5, y), Vector2(radius * 0.5, y), Vector2(0, y - radius * 0.7)]), stone.lightened(0.1))


## Cassa di legno con le fasce di metallo: chiusa brilla un poco, aperta
## mostra il coperchio alzato e l'interno vuoto.
func _draw_chest() -> void:
	_draw_shadow(radius * 1.2)
	var wood := _color(0)
	var metal := _type_color("metal")
	var width := radius * 1.3
	var height := radius * 0.9
	draw_rect(Rect2(-width, -height, width * 2.0, height), wood)
	draw_rect(Rect2(width * 0.55, -height, width * 0.45, height), wood.darkened(0.25))
	for x: float in [-width * 0.6, width * 0.4]:
		draw_rect(Rect2(x, -height, width * 0.18, height), metal.darkened(0.2))
	if _opened:
		draw_rect(Rect2(-width, -height - 4.0, width * 2.0, 6.0), wood.darkened(0.6))
		draw_colored_polygon(PackedVector2Array([Vector2(-width, -height - 2.0), Vector2(width, -height - 2.0), Vector2(width * 0.9, -height - radius * 1.1), Vector2(-width * 0.9, -height - radius * 1.1)]), wood.lightened(0.05))
		return
	var lid := PackedVector2Array([Vector2(-width, -height), Vector2(width, -height), Vector2(width * 0.85, -height - radius * 0.6), Vector2(-width * 0.85, -height - radius * 0.6)])
	draw_colored_polygon(lid, wood.lightened(0.12))
	draw_rect(Rect2(-4.0, -height - 3.0, 8.0, 9.0), metal)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 300.0)
	draw_circle(Vector2(width * 0.7, -height - radius * 0.7), 2.0 + pulse * 1.5, Color(1.0, 0.95, 0.6, 0.6 + 0.4 * pulse))
