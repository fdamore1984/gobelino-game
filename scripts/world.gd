class_name World
extends Node2D
## Mondo del livello di test: un terreno isometrico a blocchi, senza limiti
## e generato a caso. Parametri in data/world.json.
##
## Ogni rombo della griglia è un blocco quadrato con l'erba (o un sentiero
## sterrato) sopra e le pareti di terra ai lati, a un livello di altezza
## preso dal rumore: si formano piattaforme a gradini, colline e altopiani.
## Alcuni blocchi sono rampe inclinate che salgono di un livello. Si sale
## sui blocchi più alti saltando (un livello col salto normale, di più con
## i salti in aria) e si scende cadendo; i nemici non saltano e restano sul
## loro livello, salvo le rampe. Sopra ci sono ostacoli naturali: alberi,
## sassi, cespugli e rovi.
##
## Le posizioni di personaggi e oggetti sono a terra (il piano x, y);
## l'altezza del terreno sotto di loro (elevation_at) li disegna più in
## alto. Il terreno viene generato e disegnato a blocchi di rombi attorno
## alla telecamera; i blocchi più alti di quelli dietro vengono ridisegnati
## tra i personaggi, così coprono chi ci passa dietro.

const DATA := preload("res://data/world.json")

## Mezza altezza di un rombo della griglia (i rombi sono 128 x 64).
const CELL := 64.0
## Un pezzo di mondo è un quadrato di CHUNK_CELLS x CHUNK_CELLS rombi.
const CHUNK_CELLS := 8
## I pezzi lontani dalla telecamera vengono dimenticati.
const FORGET_DISTANCE := 3600.0
const MAINTAIN_INTERVAL := 0.25
## Gli ostacoli vengono messi solo in questa parte del rombo, lontano dai bordi.
const PLACE_MIN := 14.0
const PLACE_MAX := 44.0
## Dislivello superato camminando (le rampe salgono un po' alla volta).
const STEP_TOLERANCE := 8.0
## Coordinate (u, v) dei vertici dentro il rombo: alto, destra, basso, sinistra.
const CORNERS := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
## Direzioni in cui può salire una rampa (verso il rombo vicino più alto).
const RAMP_DIRECTIONS := [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1)]
const CACHE_LIMIT := 60000
## Distanza tra le linee degli strati di terra sulle pareti.
const STRATA_STEP := 14.0
const LIP_WIDTH := 5.0

## Mondo attivo: giocatore e nemici lo usano per muoversi.
static var current: World

## Seme della generazione: 0 = a caso a ogni partita.
var seed_value := 0
## Nodo con ordinamento per y in cui mettere ostacoli e blocchi che
## coprono i personaggi, e giocatore.
var entities: Node2D
var player: Node2D
## Altezza di un livello del terreno sullo schermo.
var level_height := 32.0

var _terrain: Dictionary = DATA.data["terrain"]
var _obstacle_types: Dictionary = DATA.data["obstacles"]
var _decor: Dictionary = DATA.data["decor"]
var _levels: int
var _height_noise := FastNoiseLite.new()
var _path_noise := FastNoiseLite.new()
var _forest_noise := FastNoiseLite.new()
var _bramble_noise := FastNoiseLite.new()
var _level_cache := {}
var _ramp_cache := {}
## Pezzo -> ostacoli (dizionari), generati quando servono.
var _chunk_obstacles := {}
## Pezzo -> {"view": nodo del terreno, "nodes": ostacoli e blocchi tra i personaggi}.
var _chunk_views := {}
var _maintain_timer := 0.0


func _ready() -> void:
	current = self
	if seed_value == 0:
		seed_value = randi_range(1, 1 << 30)
	_levels = _terrain["levels"]
	level_height = _terrain["level_height"]
	_setup_noise(_height_noise, 0, _terrain["height_frequency"], _terrain["height_octaves"])
	_setup_noise(_path_noise, 1, _terrain["path_frequency"], 1)
	_setup_noise(_forest_noise, 2, _terrain["forest_frequency"], 2)
	_setup_noise(_bramble_noise, 3, _terrain["bramble_frequency"], 1)
	# I pezzi di terreno si disegnano da dietro in avanti.
	y_sort_enabled = true
	# Dove il terreno non è ancora disegnato si vede il colore dell'erba più bassa.
	RenderingServer.set_default_clear_color(_color(_terrain["grass_colors"][0]).darkened(0.3))


func _exit_tree() -> void:
	if current == self:
		current = null


func _setup_noise(noise: FastNoiseLite, offset: int, frequency: float, octaves: int) -> void:
	noise.seed = seed_value + offset * 7919
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = octaves


func _process(delta: float) -> void:
	_maintain_timer -= delta
	if _maintain_timer <= 0.0:
		_maintain_timer = MAINTAIN_INTERVAL
		_update_chunks()


# --- Coordinate --------------------------------------------------------

## Rombo che contiene il punto: gli indici contano le rette y = ±x/2 della griglia.
static func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori((point.y + point.x / 2.0) / CELL), floori((point.y - point.x / 2.0) / CELL))


## Punto del mondo con coordinate u = y + x/2, v = y - x/2.
static func _from_uv(u: float, v: float) -> Vector2:
	return Vector2(u - v, (u + v) / 2.0)


static func cell_center(cell: Vector2i) -> Vector2:
	return _from_uv((cell.x + 0.5) * CELL, (cell.y + 0.5) * CELL)


## Vertici del rombo a terra: alto, destra, basso, sinistra.
static func cell_corners(cell: Vector2i) -> PackedVector2Array:
	var points := PackedVector2Array()
	for corner: Vector2 in CORNERS:
		points.append(_from_uv((cell.x + corner.x) * CELL, (cell.y + corner.y) * CELL))
	return points


static func _chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / CHUNK_CELLS), floori(float(cell.y) / CHUNK_CELLS))


## Numero pseudo-casuale in [0, 1) che dipende solo dai valori dati.
static func _random_unit(values: Array) -> float:
	return float(posmod(hash(values), 100000)) / 100000.0


static func _color(values: Array) -> Color:
	return Color(values[0], values[1], values[2])


# --- Terreno -----------------------------------------------------------

## Livello di altezza del blocco (0 = il più basso). Attorno al punto di
## partenza il terreno è piano.
func level_of(cell: Vector2i) -> int:
	if _level_cache.has(cell):
		return _level_cache[cell]
	var center := cell_center(cell)
	if center.length() < float(_terrain["start_flat_radius"]):
		center = Vector2.ZERO
	var t := _height_noise.get_noise_2dv(center) * float(_terrain["height_contrast"]) * 0.5 + 0.5
	var level := clampi(floori(t * _levels), 0, _levels - 1)
	if _level_cache.size() > CACHE_LIMIT:
		_level_cache.clear()
		_ramp_cache.clear()
	_level_cache[cell] = level
	return level


## Direzione in cui sale la rampa del blocco, o zero se è piano. Una rampa
## collega un blocco piano al vicino più alto di un livello.
func ramp_of(cell: Vector2i) -> Vector2i:
	if _ramp_cache.has(cell):
		return _ramp_cache[cell]
	var result := Vector2i.ZERO
	var level := level_of(cell)
	var far_from_start := cell_center(cell).length() > float(_terrain["start_flat_radius"]) + CELL * 2.0
	if far_from_start and _random_unit([seed_value, cell.x, cell.y, "ramp"]) < float(_terrain["ramp_chance"]):
		for direction: Vector2i in RAMP_DIRECTIONS:
			if level_of(cell + direction) == level + 1 and level_of(cell - direction) == level:
				result = direction
				break
	_ramp_cache[cell] = result
	return result


## Sentiero sterrato: una striscia lungo una curva del rumore.
func is_path(cell: Vector2i) -> bool:
	return absf(_path_noise.get_noise_2dv(cell_center(cell))) < float(_terrain["path_width"])


## Altezza del terreno in un punto (u, v) del rombo, tra 0 e 1.
func _height_in(cell: Vector2i, local: Vector2) -> float:
	var rise := 0.0
	var ramp := ramp_of(cell)
	if ramp == Vector2i(1, 0):
		rise = local.x
	elif ramp == Vector2i(-1, 0):
		rise = 1.0 - local.x
	elif ramp == Vector2i(0, 1):
		rise = local.y
	elif ramp == Vector2i(0, -1):
		rise = 1.0 - local.y
	return (level_of(cell) + rise) * level_height


func corner_height(cell: Vector2i, corner: int) -> float:
	return _height_in(cell, CORNERS[corner])


## Altezza del terreno sotto il punto, sullo schermo.
func elevation_at(point: Vector2) -> float:
	var cell := cell_at(point)
	var local := Vector2((point.y + point.x / 2.0) / CELL - cell.x, (point.y - point.x / 2.0) / CELL - cell.y)
	return _height_in(cell, local)


func _top_height(cell: Vector2i) -> float:
	return (level_of(cell) + (1 if ramp_of(cell) != Vector2i.ZERO else 0)) * level_height


# --- Movimento ---------------------------------------------------------

## Sposta da from di motion e restituisce la nuova posizione. Si sale su
## un blocco più alto solo se si è abbastanza in alto (climb: quanto si è
## sopra il terreno, per esempio saltando); si scende da un gradino solo
## con can_drop. Ci si ferma contro i gradini scivolando lungo il bordo e
## si viene spinti fuori dagli ostacoli solidi.
func move(from: Vector2, motion: Vector2, radius: float, climb := 0.0, can_drop := false) -> Vector2:
	var to := from + motion
	if not _can_pass(from, to, radius, climb, can_drop):
		var along_x := from + Vector2(motion.x, 0.0)
		var along_y := from + Vector2(0.0, motion.y)
		if _can_pass(from, along_x, radius, climb, can_drop):
			to = along_x
		elif _can_pass(from, along_y, radius, climb, can_drop):
			to = along_y
		else:
			to = from
	var pushed := _push_out(to, radius)
	if pushed != to and _can_pass(from, pushed, radius, climb, can_drop):
		to = pushed
	return to


## Si controlla il punto d'arrivo e un punto poco più avanti, così ci si
## ferma un po' prima del bordo di un gradino.
func _can_pass(from: Vector2, to: Vector2, radius: float, climb: float, can_drop: bool) -> bool:
	if to == from:
		return true
	var base := elevation_at(from)
	var ahead := (to - from).normalized() * radius * 0.5
	for probe: Vector2 in [to, to + ahead]:
		var height := elevation_at(probe)
		if height > base + climb + STEP_TOLERANCE:
			return false
		if not can_drop and height < base - STEP_TOLERANCE:
			return false
	return true


func _push_out(point: Vector2, radius: float) -> Vector2:
	for obstacle: Dictionary in obstacles_near(point):
		if not obstacle["solid"]:
			continue
		var offset: Vector2 = point - obstacle["position"]
		var minimum: float = radius + obstacle["collision"]
		if offset.length() < minimum:
			point = obstacle["position"] + (offset.normalized() if offset != Vector2.ZERO else Vector2.DOWN) * minimum
	return point


## Ostacoli dei pezzi di mondo attorno al punto.
func obstacles_near(point: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	for offset: Vector2 in [Vector2(-60, 0), Vector2(60, 0), Vector2(0, -60), Vector2(0, 60)]:
		var chunk := _chunk_of(cell_at(point + offset))
		if seen.has(chunk):
			continue
		seen[chunk] = true
		result.append_array(_obstacles_of(chunk))
	return result


## Ostacolo non solido (cespuglio, rovi) su cui si trova il punto, quello
## che rallenta di più; vuoto se non ce ne sono.
func ground_obstacle_at(point: Vector2, radius: float) -> Dictionary:
	var found := {}
	for obstacle: Dictionary in obstacles_near(point):
		if obstacle["solid"]:
			continue
		if point.distance_to(obstacle["position"]) < radius * 0.5 + obstacle["collision"]:
			if found.is_empty() or obstacle["slow"] < found["slow"]:
				found = obstacle
	return found


## Moltiplicatore della velocità a terra (cespugli e rovi rallentano).
func slow_at(point: Vector2, radius: float) -> float:
	var obstacle := ground_obstacle_at(point, radius)
	return 1.0 if obstacle.is_empty() else float(obstacle["slow"])


## Posizione libera vicino al punto, per far comparire i nemici fuori
## dagli ostacoli e non a cavallo di un gradino.
func free_position_near(point: Vector2, radius: float) -> Vector2:
	for attempt in 12:
		var candidate := point + Vector2.from_angle(attempt * 2.4) * attempt * 30.0
		var height := elevation_at(candidate)
		var free := absf(elevation_at(candidate + Vector2(radius, 0)) - height) < STEP_TOLERANCE \
				and absf(elevation_at(candidate - Vector2(radius, 0)) - height) < STEP_TOLERANCE
		for obstacle: Dictionary in obstacles_near(candidate):
			if candidate.distance_to(obstacle["position"]) < radius + obstacle["collision"] + 8.0:
				free = false
				break
		if free:
			return candidate
	return point


# --- Generazione degli ostacoli ---------------------------------------

func _obstacles_of(chunk: Vector2i) -> Array:
	if not _chunk_obstacles.has(chunk):
		_chunk_obstacles[chunk] = _generate_obstacles(chunk)
	return _chunk_obstacles[chunk]


func _generate_obstacles(chunk: Vector2i) -> Array:
	var result: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	for i in CHUNK_CELLS:
		for j in CHUNK_CELLS:
			var cell := chunk * CHUNK_CELLS + Vector2i(i, j)
			rng.seed = hash([seed_value, cell.x, cell.y, "obstacle"])
			var type_id := _pick_obstacle(cell, rng)
			if type_id == "":
				continue
			var type: Dictionary = _obstacle_types[type_id]
			var radius_range: Array = type["radius"]
			var radius := rng.randf_range(radius_range[0], radius_range[1])
			var spot := _from_uv(cell.x * CELL + rng.randf_range(PLACE_MIN, PLACE_MAX), cell.y * CELL + rng.randf_range(PLACE_MIN, PLACE_MAX))
			if not _placeable(spot, radius):
				continue
			result.append({
				"type": type_id, "position": spot, "elevation": elevation_at(spot), "radius": radius,
				"collision": radius * float(type["collision"]), "solid": type["solid"],
				"slow": type.get("slow", 1.0), "damage": type.get("damage", 0),
				"damage_interval": type.get("damage_interval", 0.0), "variant": rng.randi(),
			})
	return result


## Sceglie quale ostacolo mettere sul blocco (o nessuno), con probabilità
## che dipendono dalla zona: boschi, macchie di rovi, alture, bordi dei gradini.
func _pick_obstacle(cell: Vector2i, rng: RandomNumberGenerator) -> String:
	var center := cell_center(cell)
	if center.length() < float(_terrain["start_clear_radius"]) or is_path(cell) or ramp_of(cell) != Vector2i.ZERO:
		return ""
	var forest := clampf(_forest_noise.get_noise_2dv(center) * 2.0, 0.0, 1.0)
	var brambles := clampf(_bramble_noise.get_noise_2dv(center) * 2.5 - 0.6, 0.0, 1.0)
	var level := level_of(cell)
	var near_edge := false
	for step: Vector2i in RAMP_DIRECTIONS:
		if level_of(cell + step) != level:
			near_edge = true
			break
	var roll := rng.randf()
	for type_id: String in _obstacle_types:
		var type: Dictionary = _obstacle_types[type_id]
		var chance: float = type["chance"]
		chance += float(type.get("forest_bonus", 0.0)) * forest
		chance += float(type.get("patch_bonus", 0.0)) * brambles
		chance += float(type.get("level_bonus", 0.0)) * level
		if near_edge:
			chance += float(type.get("edge_bonus", 0.0))
		roll -= chance
		if roll < 0.0:
			return type_id
	return ""


## Un ostacolo va messo tutto sullo stesso blocco piano, fuori dai sentieri.
func _placeable(spot: Vector2, radius: float) -> bool:
	var height := elevation_at(spot)
	for offset: Vector2 in [Vector2(-radius, 0), Vector2(radius, 0), Vector2(0, -radius * 0.5), Vector2(0, radius * 0.5)]:
		var point := spot + offset
		if absf(elevation_at(point) - height) > 0.1 or is_path(cell_at(point)):
			return false
	return true


# --- Pezzi di mondo attorno alla telecamera ----------------------------

func _update_chunks() -> void:
	var camera := get_viewport().get_camera_2d()
	var center := camera.get_screen_center_position() if camera else Vector2.ZERO
	var zoom := camera.zoom if camera else Vector2.ONE
	# Sotto lo schermo serve più margine: i blocchi alti salgono verso l'alto.
	var half := get_viewport_rect().size / zoom / 2.0 + Vector2(CELL * 3.0, CELL * 3.0)
	var view := Rect2(center - half, half * 2.0).grow_side(SIDE_BOTTOM, _levels * level_height)
	var corners := [view.position, view.end, Vector2(view.position.x, view.end.y), Vector2(view.end.x, view.position.y)]
	var min_chunk := _chunk_of(cell_at(corners[0]))
	var max_chunk := min_chunk
	for corner: Vector2 in corners:
		var chunk := _chunk_of(cell_at(corner))
		min_chunk = min_chunk.min(chunk)
		max_chunk = max_chunk.max(chunk)
	var wanted := {}
	for i in range(min_chunk.x, max_chunk.x + 1):
		for j in range(min_chunk.y, max_chunk.y + 1):
			var chunk := Vector2i(i, j)
			# I pezzi negli angoli del rettangolo (u, v) sono fuori dallo schermo.
			if _chunk_bounds(chunk).intersects(view):
				wanted[chunk] = true
				if not _chunk_views.has(chunk):
					_show_chunk(chunk)
	for chunk: Vector2i in _chunk_views.keys():
		if not wanted.has(chunk):
			_hide_chunk(chunk)
	for chunk: Vector2i in _chunk_obstacles.keys():
		if not wanted.has(chunk) and _chunk_bounds(chunk).get_center().distance_to(center) > FORGET_DISTANCE:
			_chunk_obstacles.erase(chunk)


func _chunk_bounds(chunk: Vector2i) -> Rect2:
	var u := chunk.x * CHUNK_CELLS * CELL
	var v := chunk.y * CHUNK_CELLS * CELL
	var size := CHUNK_CELLS * CELL
	var bounds := Rect2(_from_uv(u, v), Vector2.ZERO)
	for corner: Vector2 in [_from_uv(u + size, v), _from_uv(u + size, v + size), _from_uv(u, v + size)]:
		bounds = bounds.expand(corner)
	return bounds.grow_side(SIDE_TOP, _levels * level_height)


func _show_chunk(chunk: Vector2i) -> void:
	var view := ChunkView.new()
	view.world = self
	view.chunk = chunk
	view.position = _from_uv(chunk.x * CHUNK_CELLS * CELL, chunk.y * CHUNK_CELLS * CELL)
	add_child(view)
	var nodes: Array[Node] = []
	if entities:
		for data: Dictionary in _obstacles_of(chunk):
			var obstacle := Obstacle.new()
			obstacle.setup(data, _obstacle_types[data["type"]])
			entities.add_child(obstacle)
			nodes.append(obstacle)
		for i in CHUNK_CELLS:
			for j in CHUNK_CELLS:
				var cell := chunk * CHUNK_CELLS + Vector2i(i, j)
				if _covers_behind(cell):
					var block := TerrainBlock.new()
					block.world = self
					block.cell = cell
					block.position = cell_corners(cell)[0]
					entities.add_child(block)
					nodes.append(block)
	_chunk_views[chunk] = {"view": view, "nodes": nodes}


func _hide_chunk(chunk: Vector2i) -> void:
	var entry: Dictionary = _chunk_views[chunk]
	entry["view"].queue_free()
	for node: Node in entry["nodes"]:
		node.queue_free()
	_chunk_views.erase(chunk)


## Un blocco più alto di quelli dietro può coprire chi ci passa dietro:
## va disegnato anche tra i personaggi, ordinato con loro.
func _covers_behind(cell: Vector2i) -> bool:
	var top := _top_height(cell)
	for step: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
		if _top_height(cell + step) < top:
			return true
	return false


# --- Disegno dei blocchi ----------------------------------------------

func draw_chunk(canvas: CanvasItem, chunk: Vector2i, offset: Vector2) -> void:
	# Da dietro in avanti: prima i rombi con u + v più piccolo.
	for depth in 2 * CHUNK_CELLS - 1:
		for i in range(maxi(0, depth - CHUNK_CELLS + 1), mini(depth, CHUNK_CELLS - 1) + 1):
			draw_cell(canvas, chunk * CHUNK_CELLS + Vector2i(i, depth - i), offset)


## Un blocco: pareti di terra davanti (dove il vicino è più basso) e
## faccia superiore d'erba o di sentiero, piana o inclinata.
func draw_cell(canvas: CanvasItem, cell: Vector2i, offset: Vector2) -> void:
	var corners := cell_corners(cell)
	var heights: Array[float] = []
	var top := PackedVector2Array()
	for k in 4:
		heights.append(corner_height(cell, k))
		corners[k] += offset
		top.append(corners[k] - Vector2(0, heights[k]))
	var faces: Array = _terrain["face_colors"]
	# Parete destra (lato destra-basso, vicino (u+1, v)) e sinistra (lato
	# basso-sinistra, vicino (u, v+1)): i vertici combaciano con quelli del vicino.
	_draw_face(canvas, cell, corners, heights, 1, 2, Vector2i(1, 0), 0, 3, _color(faces[0]))
	_draw_face(canvas, cell, corners, heights, 2, 3, Vector2i(0, 1), 1, 0, _color(faces[1]))

	var path := is_path(cell)
	var level := level_of(cell)
	var color := _color(_terrain["path_color"]) if path else _color(_terrain["grass_colors"][level])
	var tint := (_random_unit([seed_value, cell.x, cell.y, "tint"]) - 0.5) * 0.03
	color = Color(color.r + tint, color.g + tint * 1.3, color.b + tint)
	var ramp := ramp_of(cell)
	if ramp != Vector2i.ZERO:
		# Le rampe che salgono verso il fondo sono in ombra, le altre in luce.
		color = color.darkened(0.12) if ramp.x + ramp.y < 0 else color.lightened(0.08)
	canvas.draw_colored_polygon(top, color)
	if ramp != Vector2i.ZERO:
		_draw_ramp_lines(canvas, top, ramp, color)
	_draw_decor(canvas, cell, offset, path)
	# Bordi: chiari dietro, scuri davanti.
	canvas.draw_polyline(PackedVector2Array([top[3], top[0], top[1]]), color.lightened(0.15), 2.0)
	canvas.draw_polyline(PackedVector2Array([top[1], top[2], top[3]]), color.darkened(0.2), 1.5)


func _draw_face(canvas: CanvasItem, cell: Vector2i, corners: PackedVector2Array, heights: Array[float],
		first: int, second: int, direction: Vector2i, other_first: int, other_second: int, color: Color) -> void:
	var other := cell + direction
	var top_a := heights[first]
	var top_b := heights[second]
	var bottom_a := minf(corner_height(other, other_first), top_a)
	var bottom_b := minf(corner_height(other, other_second), top_b)
	if top_a - bottom_a < 0.5 and top_b - bottom_b < 0.5:
		return
	var a := corners[first]
	var b := corners[second]
	var points := PackedVector2Array([a - Vector2(0, top_a), b - Vector2(0, top_b)])
	if top_b - bottom_b >= 0.5:
		points.append(b - Vector2(0, bottom_b))
	if top_a - bottom_a >= 0.5:
		points.append(a - Vector2(0, bottom_a))
	canvas.draw_colored_polygon(points, color)
	# Strati della terra e bordo d'erba che sporge in cima.
	var depth := STRATA_STEP
	while depth < maxf(top_a - bottom_a, top_b - bottom_b) - 4.0:
		var start := a - Vector2(0, top_a - minf(depth, top_a - bottom_a))
		var end := b - Vector2(0, top_b - minf(depth, top_b - bottom_b))
		canvas.draw_line(start, end, color.darkened(0.18), 1.5)
		depth += STRATA_STEP
	var lip := _color(_terrain["lip_color"])
	var lip_a := minf(LIP_WIDTH, top_a - bottom_a)
	var lip_b := minf(LIP_WIDTH, top_b - bottom_b)
	var lip_points := PackedVector2Array([a - Vector2(0, top_a), b - Vector2(0, top_b)])
	if lip_b > 0.5:
		lip_points.append(b - Vector2(0, top_b - lip_b))
	if lip_a > 0.5:
		lip_points.append(a - Vector2(0, top_a - lip_a))
	if lip_points.size() >= 3:
		canvas.draw_colored_polygon(lip_points, lip)
	canvas.draw_line(a - Vector2(0, bottom_a), b - Vector2(0, bottom_b), Color(0, 0, 0, 0.3), 2.0)


## Linee lungo la pendenza di una rampa, parallele al lato più alto.
func _draw_ramp_lines(canvas: CanvasItem, top: PackedVector2Array, ramp: Vector2i, color: Color) -> void:
	# Lati bassi e alti della rampa, come coppie di vertici (alto, destra, basso, sinistra).
	var low: Array
	var high: Array
	if ramp == Vector2i(1, 0):
		low = [top[0], top[3]]
		high = [top[1], top[2]]
	elif ramp == Vector2i(-1, 0):
		low = [top[1], top[2]]
		high = [top[0], top[3]]
	elif ramp == Vector2i(0, 1):
		low = [top[0], top[1]]
		high = [top[3], top[2]]
	else:
		low = [top[3], top[2]]
		high = [top[0], top[1]]
	for k in range(1, 4):
		var t := k / 4.0
		canvas.draw_line((low[0] as Vector2).lerp(high[0], t), (low[1] as Vector2).lerp(high[1], t), color.darkened(0.15), 1.5)


## Ciuffi d'erba e fiori sui blocchi d'erba, sassolini sui sentieri: solo decorazione.
func _draw_decor(canvas: CanvasItem, cell: Vector2i, offset: Vector2, path: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, cell.x, cell.y, "decor"])
	if path:
		var pebbles: Array = _decor["pebble_colors"]
		for k in rng.randi_range(2, 4):
			var at := _decor_point(cell, rng, offset)
			canvas.draw_circle(at, rng.randf_range(1.5, 3.0), _color(pebbles[k % pebbles.size()]))
		return
	var tufts: Array = _decor["grass_tufts"]
	var grass := _color(_terrain["grass_colors"][level_of(cell)]).darkened(0.3)
	for k in rng.randi_range(tufts[0], tufts[1]):
		var at := _decor_point(cell, rng, offset)
		canvas.draw_line(at, at + Vector2(-4, -7), grass, 1.5)
		canvas.draw_line(at, at + Vector2(0, -9), grass, 1.5)
		canvas.draw_line(at, at + Vector2(4, -7), grass, 1.5)
	if rng.randf() < float(_decor["flower_chance"]):
		var colors: Array = _decor["flower_colors"]
		var color := _color(colors[rng.randi() % colors.size()])
		var at := _decor_point(cell, rng, offset)
		for k in 3:
			canvas.draw_circle(at + Vector2.from_angle(k * TAU / 3.0) * 3.0, 2.5, color)
		canvas.draw_circle(at, 1.5, Color(0.95, 0.8, 0.3))


## Punto a caso sulla faccia superiore del blocco, lontano dai bordi.
func _decor_point(cell: Vector2i, rng: RandomNumberGenerator, offset: Vector2) -> Vector2:
	var ground := _from_uv(cell.x * CELL + rng.randf_range(10.0, 54.0), cell.y * CELL + rng.randf_range(10.0, 54.0))
	return ground + offset - Vector2(0, elevation_at(ground))


## Un pezzo di terreno sotto i personaggi: disegnato una volta sola alla creazione.
class ChunkView:
	extends Node2D

	var world: World
	var chunk: Vector2i

	func _draw() -> void:
		world.draw_chunk(self, chunk, -position)


## Blocco ridisegnato tra i personaggi: la posizione è il suo vertice più
## arretrato, così chi sta dietro viene disegnato prima e resta coperto.
class TerrainBlock:
	extends Node2D

	var world: World
	var cell: Vector2i

	func _ready() -> void:
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	func _draw() -> void:
		world.draw_cell(self, cell, -position)
