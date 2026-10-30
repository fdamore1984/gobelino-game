class_name Minimap
extends Control
## Minimappa in alto a destra: il terreno attorno al giocatore (livelli
## d'altezza e sentieri), i nemici come puntini rossi, casse, totem,
## mercanti, ingressi delle caverne, scale, uscite e oggetti a terra; il
## giocatore è la freccia bianca al centro. Si vedono solo le zone già
## scoperte (vedi World.is_explored; il resto è COLOR_UNKNOWN) e i nemici e
## gli oggetti a terra entro il raggio di scoperta attorno al giocatore.
##
## Prestazioni: il terreno è un'immagine preparata a poco a poco; i punti
## d'interesse si cercano solo ogni POI_REFRESH secondi e i puntini (nemici,
## oggetti) sono dischi di Shapes, che il renderer disegna tutti insieme.

## Metà del lato dell'area mostrata, in pixel del mondo.
const RANGE := 1100.0
## Punti campionati per lato per disegnare il terreno.
const SAMPLES := 60
const REFRESH_TIME := 0.4
const REFRESH_DISTANCE := 40.0
const COLOR_FRAME := Color(0, 0, 0, 0.55)
const COLOR_BORDER := Color(1, 1, 1, 0.5)
## Bordo scuro attorno ai segni, perché si leggano su ogni terreno.
const COLOR_OUTLINE := Color(0, 0, 0, 0.75)
const COLOR_ENEMY := Color(1.0, 0.2, 0.15)
const COLOR_CHEST := Color(1.0, 0.82, 0.25)
const COLOR_OPENED := Color(0.55, 0.5, 0.4)
const COLOR_TOTEM := Color(0.4, 1.0, 0.9)
const COLOR_TOTEM_ACTIVE := Color(1.0, 0.4, 0.2)
const COLOR_USED := Color(0.5, 0.5, 0.5)
const COLOR_LOOT := Color(1, 1, 1)
const COLOR_MERCHANT := Color(1.0, 0.6, 0.85)
## Ingressi delle caverne e scale (in giù), uscite verso la superficie.
const COLOR_CAVE := Color(0.95, 0.55, 0.2)
## Mausolei che portano alle catacombe.
const COLOR_METRO := Color(0.5, 0.3, 0.65)
const COLOR_EXIT := Color(1.0, 0.85, 0.45)
## Zone non ancora scoperte.
const COLOR_UNKNOWN := Color(0.06, 0.07, 0.06)

## Righe campionate a ogni frame: l'immagine nuova si prepara in più
## frame e sostituisce la vecchia quando è pronta, così non ci sono scatti.
const ROWS_PER_FRAME := 8
const POI_REFRESH := 0.25

var _image := Image.create(SAMPLES, SAMPLES, false, Image.FORMAT_RGB8)
var _next_image := Image.create(SAMPLES, SAMPLES, false, Image.FORMAT_RGB8)
var _next_center := Vector2.INF
var _next_row := 0
var _texture: ImageTexture
var _center := Vector2.INF
var _refresh := 0.0
var _player: Player
## Punti d'interesse attorno al giocatore (vedi World.points_of_interest),
## ricercati ogni POI_REFRESH secondi.
var _points: Array[Dictionary] = []
var _points_timer := 0.0


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
	if _next_center == Vector2.INF and _refresh <= 0.0 and _center.distance_to(_player.position) > REFRESH_DISTANCE:
		_refresh = REFRESH_TIME
		_next_center = _player.position
		_next_row = 0
	_points_timer -= delta
	if _points_timer <= 0.0 and World.current:
		_points_timer = POI_REFRESH
		_points = World.current.points_of_interest(_player.position, RANGE)
	if _next_center != Vector2.INF:
		# La prima volta (e dopo un salto lontano) non c'è niente da mostrare
		# nel frattempo: si campiona tutto subito.
		while _next_center != Vector2.INF and _center == Vector2.INF:
			_sample_rows()
		if _next_center != Vector2.INF:
			_sample_rows()
	queue_redraw()


## Dopo un salto lontano (entrando o uscendo da una caverna) il terreno
## vecchio non vale più: non si disegna finché non è pronto quello nuovo.
func reset() -> void:
	_center = Vector2.INF
	_next_center = Vector2.INF
	_refresh = 0.0
	_points.clear()
	_points_timer = 0.0


## Campiona qualche riga del terreno attorno al punto scelto (colore del
## blocco); finito, l'immagine nuova prende il posto della vecchia.
func _sample_rows() -> void:
	var world := World.current
	if world == null:
		return
	var step := 2.0 * RANGE / SAMPLES
	for j in range(_next_row, mini(_next_row + ROWS_PER_FRAME, SAMPLES)):
		for i in SAMPLES:
			var point := _next_center + Vector2(-RANGE + (i + 0.5) * step, -RANGE + (j + 0.5) * step)
			_next_image.set_pixel(i, j, world.map_color(point) if world.is_explored(point) else COLOR_UNKNOWN)
	_next_row += ROWS_PER_FRAME
	if _next_row >= SAMPLES:
		var ready := _next_image
		_next_image = _image
		_image = ready
		_texture.update(_image)
		_center = _next_center
		_next_center = Vector2.INF


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size).grow(3.0), COLOR_FRAME)
	if _player == null or _center == Vector2.INF:
		return
	draw_texture_rect(_texture, Rect2(_to_map(_center - Vector2(RANGE, RANGE)), size), false)
	var world := World.current
	if world:
		for point: Dictionary in _points:
			var at := _to_map(point["position"])
			if not _inside(at) or not world.is_explored(point["position"]):
				continue
			draw_point(self, world, point, at)
	var near := world.reveal_radius() if world else RANGE
	for node in get_tree().get_nodes_in_group("loot"):
		var at := _to_map((node as Node2D).global_position)
		if _inside(at) and (node as Node2D).global_position.distance_to(_player.position) <= near:
			Shapes.disc(self, at, 3.5, COLOR_OUTLINE)
			Shapes.disc(self, at, 2.5, COLOR_LOOT)
	for node in get_tree().get_nodes_in_group("enemies"):
		var at := _to_map((node as Node2D).global_position)
		if _inside(at) and (node as Node2D).global_position.distance_to(_player.position) <= near:
			Shapes.disc(self, at, 5.0, COLOR_OUTLINE)
			Shapes.disc(self, at, 3.8, COLOR_ENEMY)
	# Giocatore: freccia nella direzione in cui guarda.
	var center := _to_map(_player.position)
	var facing := _player.facing
	draw_colored_polygon(PackedVector2Array([
		center + facing * 11.0, center - facing * 6.5 + facing.orthogonal() * 7.5, center - facing * 6.5 - facing.orthogonal() * 7.5,
	]), COLOR_OUTLINE)
	draw_colored_polygon(PackedVector2Array([
		center + facing * 9.0, center - facing * 5.0 + facing.orthogonal() * 5.5, center - facing * 5.0 - facing.orthogonal() * 5.5,
	]), Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BORDER, false, 2.0)


func _to_map(point: Vector2) -> Vector2:
	return size / 2.0 + (point - _player.position) * size.x / (2.0 * RANGE)


func _inside(at: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(at)


## Segno di un punto d'interesse (cassa, totem, mercante, caverna,
## mausoleo delle catacombe, scala, uscita) in at, con un bordo scuro; usato anche dalla mappa completa.
static func draw_point(canvas: CanvasItem, world: World, point: Dictionary, at: Vector2) -> void:
	match point["type"]:
		"chest":
			var opened: bool = world.is_chest_opened(point["position"])
			canvas.draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), COLOR_OUTLINE)
			canvas.draw_rect(Rect2(at - Vector2(4, 4), Vector2(8, 8)), COLOR_OPENED if opened else COLOR_CHEST)
		"totem":
			var state := world.totem_state(point["position"])
			var color := COLOR_TOTEM
			if state == "active":
				color = COLOR_TOTEM_ACTIVE
			elif state == "used":
				color = COLOR_USED
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -9), at + Vector2(7, 0), at + Vector2(0, 9), at + Vector2(-7, 0)]), COLOR_OUTLINE)
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -7), at + Vector2(5.5, 0), at + Vector2(0, 7), at + Vector2(-5.5, 0)]), color)
		"merchant":
			# Una tenda: tetto a triangolo sopra il banco.
			canvas.draw_rect(Rect2(at + Vector2(-8, -10), Vector2(16, 17)), COLOR_OUTLINE)
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-7, -1), at + Vector2(7, -1), at + Vector2(0, -9)]), COLOR_MERCHANT)
			canvas.draw_rect(Rect2(at + Vector2(-5, -1), Vector2(10, 6)), COLOR_MERCHANT.darkened(0.3))
		"cave":
			# Un arco buio nella roccia (grigio se la caverna è già stata completata).
			var cleared := world.is_cave_cleared(point["position"])
			canvas.draw_circle(at, 8.0, COLOR_OUTLINE)
			canvas.draw_circle(at, 6.5, COLOR_USED if cleared else COLOR_CAVE)
			canvas.draw_circle(at + Vector2(0, 1.5), 3.5, Color(0.05, 0.04, 0.04))
		"metro":
			# Mausoleo: un teschio bianco su un quadrato viola (grigio se ripulito).
			var cleared := world.is_cave_cleared(point["position"])
			canvas.draw_rect(Rect2(at - Vector2(8, 8), Vector2(16, 16)), COLOR_OUTLINE)
			canvas.draw_rect(Rect2(at - Vector2(6.5, 6.5), Vector2(13, 13)), COLOR_USED if cleared else COLOR_METRO)
			var bone := Color(0.95, 0.93, 0.85)
			canvas.draw_circle(at + Vector2(0, -1), 3.8, bone)
			canvas.draw_rect(Rect2(at + Vector2(-2.2, 1.5), Vector2(4.4, 3.0)), bone)
			for side: float in [-1.0, 1.0]:
				canvas.draw_circle(at + Vector2(1.5 * side, -1.2), 1.1, COLOR_OUTLINE)
		"stairs":
			# Una freccia in giù: si scende.
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-8, -6), at + Vector2(8, -6), at + Vector2(0, 8)]), COLOR_OUTLINE)
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-6, -4.5), at + Vector2(6, -4.5), at + Vector2(0, 5.5)]), COLOR_CAVE)
		"exit":
			# Una freccia in su, luce calda: si torna in superficie.
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-8, 6), at + Vector2(8, 6), at + Vector2(0, -8)]), COLOR_OUTLINE)
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-6, 4.5), at + Vector2(6, 4.5), at + Vector2(0, -5.5)]), COLOR_EXIT)
