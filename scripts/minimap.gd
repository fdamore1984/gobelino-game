extends Control
## Minimappa in alto a destra: il terreno attorno al giocatore (livelli
## d'altezza e sentieri), i nemici come puntini rossi, casse, totem,
## mercanti e oggetti a terra; il giocatore è la freccia bianca al centro.

## Metà del lato dell'area mostrata, in pixel del mondo.
const RANGE := 1100.0
## Punti campionati per lato per disegnare il terreno.
const SAMPLES := 60
const REFRESH_TIME := 0.4
const REFRESH_DISTANCE := 40.0
const COLOR_FRAME := Color(0, 0, 0, 0.55)
const COLOR_BORDER := Color(1, 1, 1, 0.5)
const COLOR_ENEMY := Color(1.0, 0.2, 0.15)
const COLOR_CHEST := Color(1.0, 0.82, 0.25)
const COLOR_OPENED := Color(0.55, 0.5, 0.4)
const COLOR_TOTEM := Color(0.4, 1.0, 0.9)
const COLOR_TOTEM_ACTIVE := Color(1.0, 0.4, 0.2)
const COLOR_USED := Color(0.5, 0.5, 0.5)
const COLOR_LOOT := Color(1, 1, 1)
const COLOR_MERCHANT := Color(1.0, 0.6, 0.85)

var _image := Image.create(SAMPLES, SAMPLES, false, Image.FORMAT_RGB8)
var _texture: ImageTexture
var _center := Vector2.INF
var _refresh := 0.0
var _player: Player


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture = ImageTexture.create_from_image(_image)


func _process(delta: float) -> void:
	if _player == null:
		var hud := get_parent() as Hud
		_player = hud.player if hud else null
		if _player == null:
			return
	_refresh -= delta
	if _refresh <= 0.0 and _center.distance_to(_player.position) > REFRESH_DISTANCE:
		_refresh = REFRESH_TIME
		_center = _player.position
		_update_terrain()
	queue_redraw()


## Campiona il terreno attorno al giocatore: colore del livello o del sentiero.
func _update_terrain() -> void:
	var world := World.current
	if world == null:
		return
	var step := 2.0 * RANGE / SAMPLES
	for i in SAMPLES:
		for j in SAMPLES:
			var point := _center + Vector2(-RANGE + (i + 0.5) * step, -RANGE + (j + 0.5) * step)
			_image.set_pixel(i, j, world.map_color(point))
	_texture.update(_image)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size).grow(3.0), COLOR_FRAME)
	if _player == null or _center == Vector2.INF:
		return
	draw_texture_rect(_texture, Rect2(_to_map(_center - Vector2(RANGE, RANGE)), size), false, Color(1, 1, 1, 0.85))
	var world := World.current
	if world:
		for point: Dictionary in world.points_of_interest(_player.position, RANGE):
			var at := _to_map(point["position"])
			if not _inside(at):
				continue
			match point["type"]:
				"chest":
					var opened: bool = world.is_chest_opened(point["position"])
					draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), COLOR_OPENED if opened else COLOR_CHEST)
				"totem":
					var state := world.totem_state(point["position"])
					var color := COLOR_TOTEM
					if state == "active":
						color = COLOR_TOTEM_ACTIVE
					elif state == "used":
						color = COLOR_USED
					draw_colored_polygon(PackedVector2Array([at + Vector2(0, -6), at + Vector2(5, 0), at + Vector2(0, 6), at + Vector2(-5, 0)]), color)
				"merchant":
					# Una tenda: tetto a triangolo sopra il banco.
					draw_colored_polygon(PackedVector2Array([at + Vector2(-6, -1), at + Vector2(6, -1), at + Vector2(0, -7)]), COLOR_MERCHANT)
					draw_rect(Rect2(at + Vector2(-4, -1), Vector2(8, 5)), COLOR_MERCHANT.darkened(0.3))
	for node in get_tree().get_nodes_in_group("loot"):
		var at := _to_map((node as Node2D).global_position)
		if _inside(at):
			draw_circle(at, 2.0, COLOR_LOOT)
	for node in get_tree().get_nodes_in_group("enemies"):
		var at := _to_map((node as Node2D).global_position)
		if _inside(at):
			draw_circle(at, 3.0, COLOR_ENEMY)
	# Giocatore: freccia nella direzione in cui guarda.
	var center := _to_map(_player.position)
	var facing := _player.facing
	draw_colored_polygon(PackedVector2Array([
		center + facing * 7.0, center - facing * 4.0 + facing.orthogonal() * 4.5, center - facing * 4.0 - facing.orthogonal() * 4.5,
	]), Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BORDER, false, 2.0)


func _to_map(point: Vector2) -> Vector2:
	return size / 2.0 + (point - _player.position) * size.x / (2.0 * RANGE)


func _inside(at: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(at)
