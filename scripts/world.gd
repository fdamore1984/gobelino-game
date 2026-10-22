class_name World
extends Node2D
## Mondo del livello di test: un terreno senza limiti generato a caso, con
## pianure, colline e altopiani separati da pendii (percorribili) o da
## dirupi (invalicabili, ma si può saltarne giù), e ostacoli naturali:
## alberi, sassi, cespugli e rovi. Parametri in data/world.json.
##
## Il terreno è fatto dai rombi della griglia isometrica, ognuno con un
## livello di altezza; viene generato e disegnato a blocchi solo attorno
## alla telecamera. Giocatore e nemici si muovono con move(), che li ferma
## contro dirupi e ostacoli solidi.

const DATA := preload("res://data/world.json")

## Mezza altezza di un rombo della griglia (i rombi sono 128 x 64).
const CELL := 64.0
## Un blocco è un quadrato di CHUNK_CELLS x CHUNK_CELLS rombi.
const CHUNK_CELLS := 8
## I blocchi lontani dalla telecamera vengono dimenticati.
const FORGET_DISTANCE := 3600.0
const MAINTAIN_INTERVAL := 0.25
## Gli ostacoli vengono messi solo in questa parte del rombo, così non
## finiscono sui bordi o sulle pareti dei dirupi.
const PLACE_MIN := 14.0
const PLACE_MAX := 44.0

## Mondo attivo: giocatore e nemici lo usano per muoversi.
static var current: World

## Seme della generazione: 0 = a caso a ogni partita.
var seed_value := 0
## Nodo con ordinamento per y in cui mettere gli ostacoli, e giocatore.
var entities: Node2D
var player: Node2D

var _terrain: Dictionary = DATA.data["terrain"]
var _obstacle_types: Dictionary = DATA.data["obstacles"]
var _decor: Dictionary = DATA.data["decor"]
var _levels: int
var _face_height: float
var _height_noise := FastNoiseLite.new()
var _cliff_noise := FastNoiseLite.new()
var _forest_noise := FastNoiseLite.new()
var _bramble_noise := FastNoiseLite.new()
## Blocco -> ostacoli (dizionari), generati quando servono.
var _chunk_obstacles := {}
## Blocco -> {"view": nodo del terreno, "nodes": nodi degli ostacoli}.
var _chunk_views := {}
var _maintain_timer := 0.0


func _ready() -> void:
	current = self
	if seed_value == 0:
		seed_value = randi_range(1, 1 << 30)
	_levels = _terrain["levels"]
	_face_height = _terrain["face_height"]
	_setup_noise(_height_noise, 0, _terrain["height_frequency"], _terrain["height_octaves"])
	_setup_noise(_cliff_noise, 1, _terrain["cliff_frequency"], 1)
	_setup_noise(_forest_noise, 2, _terrain["forest_frequency"], 2)
	_setup_noise(_bramble_noise, 3, _terrain["bramble_frequency"], 1)
	# Dove i blocchi del terreno non sono ancora disegnati si vede il colore più basso.
	RenderingServer.set_default_clear_color(_level_color(0))


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


## Vertici del rombo: alto, destra, basso, sinistra.
static func cell_corners(cell: Vector2i) -> PackedVector2Array:
	var u := cell.x * CELL
	var v := cell.y * CELL
	return PackedVector2Array([
		_from_uv(u, v), _from_uv(u + CELL, v), _from_uv(u + CELL, v + CELL), _from_uv(u, v + CELL),
	])


static func _chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / CHUNK_CELLS), floori(float(cell.y) / CHUNK_CELLS))


# --- Terreno -----------------------------------------------------------

## Livello di altezza del rombo (0 = il più basso). Attorno al punto di
## partenza il terreno è piano.
func level_of(cell: Vector2i) -> int:
	var center := cell_center(cell)
	if center.length() < float(_terrain["start_flat_radius"]):
		center = Vector2.ZERO
	var t := _height_noise.get_noise_2dv(center) * float(_terrain["height_contrast"]) * 0.5 + 0.5
	return clampi(floori(t * _levels), 0, _levels - 1)


func level_at(point: Vector2) -> int:
	return level_of(cell_at(point))


## Tra due rombi vicini di livello diverso c'è un dirupo o un pendio. Un
## salto di due livelli è sempre un dirupo; di un livello lo è nelle zone
## rocciose, tranne qualche rampa che permette di salire.
func is_cliff(a: Vector2i, b: Vector2i) -> bool:
	var difference := absi(level_of(a) - level_of(b))
	if difference == 0:
		return false
	if difference >= 2:
		return true
	var middle := (cell_center(a) + cell_center(b)) / 2.0
	if _cliff_noise.get_noise_2dv(middle) < float(_terrain["cliff_threshold"]):
		return false
	var low := a if a < b else b
	var high := b if a < b else a
	return _random_unit([seed_value, low.x, low.y, high.x, high.y]) >= float(_terrain["ramp_chance"])


## Livelli di cui si scende saltando giù da un dirupo andando da from a to
## (0 se non si attraversa un dirupo verso il basso).
func cliff_drop(from: Vector2, to: Vector2) -> int:
	var a := cell_at(from)
	var b := cell_at(to)
	if a == b or level_of(b) >= level_of(a) or not is_cliff(a, b):
		return 0
	return level_of(a) - level_of(b)


## Altezza della parete di un dirupo sullo schermo.
func face_height(levels: int) -> float:
	return minf(_face_height * levels, 44.0)


## Numero pseudo-casuale in [0, 1) che dipende solo dai valori dati.
static func _random_unit(values: Array) -> float:
	return float(posmod(hash(values), 100000)) / 100000.0


# --- Movimento ---------------------------------------------------------

## Sposta da from di motion e restituisce la nuova posizione: ci si ferma
## contro i dirupi (scivolando lungo il bordo) e si viene spinti fuori
## dagli ostacoli solidi. Chi è in aria (can_drop) può saltare giù da un dirupo.
func move(from: Vector2, motion: Vector2, radius: float, can_drop := false) -> Vector2:
	var to := from + motion
	if not _can_pass(from, to, can_drop):
		var along_x := from + Vector2(motion.x, 0.0)
		var along_y := from + Vector2(0.0, motion.y)
		if _can_pass(from, along_x, can_drop):
			to = along_x
		elif _can_pass(from, along_y, can_drop):
			to = along_y
		else:
			to = from
	var pushed := _push_out(to, radius)
	if pushed != to and _can_pass(from, pushed, can_drop):
		to = pushed
	return to


## Si controlla il punto a terra e un punto poco più in basso: così chi
## sta sopra un dirupo si ferma prima di finire sulla parete disegnata.
func _can_pass(from: Vector2, to: Vector2, can_drop: bool) -> bool:
	for offset: Vector2 in [Vector2.ZERO, Vector2(0.0, _face_height)]:
		if not _transition_ok(cell_at(from + offset), cell_at(to + offset), can_drop):
			return false
	return true


func _transition_ok(a: Vector2i, b: Vector2i, can_drop: bool) -> bool:
	if a == b:
		return true
	var step := b - a
	if absi(step.x) + absi(step.y) == 1:
		return _step_ok(a, b, can_drop)
	if absi(step.x) <= 1 and absi(step.y) <= 1:
		# In diagonale si passa per uno dei due rombi in mezzo.
		var via_u := a + Vector2i(step.x, 0)
		var via_v := a + Vector2i(0, step.y)
		return (_step_ok(a, via_u, can_drop) and _step_ok(via_u, b, can_drop)) \
				or (_step_ok(a, via_v, can_drop) and _step_ok(via_v, b, can_drop))
	return true


func _step_ok(a: Vector2i, b: Vector2i, can_drop: bool) -> bool:
	if not is_cliff(a, b):
		return true
	return can_drop and level_of(b) < level_of(a)


func _push_out(point: Vector2, radius: float) -> Vector2:
	for obstacle: Dictionary in obstacles_near(point):
		if not obstacle["solid"]:
			continue
		var offset: Vector2 = point - obstacle["position"]
		var minimum: float = radius + obstacle["collision"]
		if offset.length() < minimum:
			point = obstacle["position"] + (offset.normalized() if offset != Vector2.ZERO else Vector2.DOWN) * minimum
	return point


## Ostacoli dei blocchi attorno al punto.
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


## Ostacolo non solido (cespuglio, rovi) su cui si trova il punto, che
## rallenta di più; vuoto se non ce ne sono.
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
## dagli ostacoli.
func free_position_near(point: Vector2, radius: float) -> Vector2:
	for attempt in 12:
		var candidate := point + Vector2.from_angle(attempt * 2.4) * attempt * 30.0
		var free := true
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
				"type": type_id, "position": spot, "radius": radius,
				"collision": radius * float(type["collision"]), "solid": type["solid"],
				"slow": type.get("slow", 1.0), "damage": type.get("damage", 0),
				"damage_interval": type.get("damage_interval", 0.0), "variant": rng.randi(),
			})
	return result


## Sceglie quale ostacolo mettere nel rombo (o nessuno), con probabilità
## che dipendono dalla zona: boschi, macchie di rovi, alture, dirupi.
func _pick_obstacle(cell: Vector2i, rng: RandomNumberGenerator) -> String:
	var center := cell_center(cell)
	if center.length() < float(_terrain["start_clear_radius"]):
		return ""
	var forest := clampf(_forest_noise.get_noise_2dv(center) * 2.0, 0.0, 1.0)
	var brambles := clampf(_bramble_noise.get_noise_2dv(center) * 2.5 - 0.6, 0.0, 1.0)
	var level := level_of(cell)
	var near_cliff := false
	for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if is_cliff(cell, cell + step):
			near_cliff = true
			break
	var chances := {}
	for type_id: String in _obstacle_types:
		var type: Dictionary = _obstacle_types[type_id]
		var chance: float = type["chance"]
		chance += float(type.get("forest_bonus", 0.0)) * forest
		chance += float(type.get("patch_bonus", 0.0)) * brambles
		chance += float(type.get("level_bonus", 0.0)) * level
		if near_cliff:
			chance += float(type.get("cliff_bonus", 0.0))
		chances[type_id] = chance
	var roll := rng.randf()
	for type_id: String in chances:
		roll -= chances[type_id]
		if roll < 0.0:
			return type_id
	return ""


## Un ostacolo va messo tutto sullo stesso livello, lontano dai bordi dei dirupi.
func _placeable(spot: Vector2, radius: float) -> bool:
	var cell := cell_at(spot)
	var level := level_of(cell)
	for offset: Vector2 in [Vector2(-radius, 0), Vector2(radius, 0), Vector2(0, -radius * 0.5), Vector2(0, radius * 0.5 + _face_height)]:
		var other := cell_at(spot + offset)
		if other != cell and (level_of(other) != level or is_cliff(cell, other)):
			return false
	return true


# --- Blocchi attorno alla telecamera -----------------------------------

func _update_chunks() -> void:
	var camera := get_viewport().get_camera_2d()
	var center := camera.get_screen_center_position() if camera else Vector2.ZERO
	var zoom := camera.zoom if camera else Vector2.ONE
	var half := get_viewport_rect().size / zoom / 2.0 + Vector2(CELL * 3.0, CELL * 3.0)
	# Gli indici (u, v) del rettangolo inquadrato stanno tra quelli dei suoi angoli.
	var cells: Array[Vector2i] = []
	for corner: Vector2 in [center - half, center + half, Vector2(center.x - half.x, center.y + half.y), Vector2(center.x + half.x, center.y - half.y)]:
		cells.append(_chunk_of(cell_at(corner)))
	var min_chunk := cells[0]
	var max_chunk := cells[0]
	for chunk in cells:
		min_chunk = min_chunk.min(chunk)
		max_chunk = max_chunk.max(chunk)
	var wanted := {}
	for i in range(min_chunk.x, max_chunk.x + 1):
		for j in range(min_chunk.y, max_chunk.y + 1):
			var chunk := Vector2i(i, j)
			# I blocchi negli angoli del rettangolo (u, v) sono fuori dallo schermo.
			if _chunk_visible(chunk, center, half):
				wanted[chunk] = true
				if not _chunk_views.has(chunk):
					_show_chunk(chunk)
	for chunk: Vector2i in _chunk_views.keys():
		if not wanted.has(chunk):
			_hide_chunk(chunk)
	for chunk: Vector2i in _chunk_obstacles.keys():
		var chunk_center := _from_uv((chunk.x + 0.5) * CHUNK_CELLS * CELL, (chunk.y + 0.5) * CHUNK_CELLS * CELL)
		if not wanted.has(chunk) and chunk_center.distance_to(center) > FORGET_DISTANCE:
			_chunk_obstacles.erase(chunk)


func _chunk_visible(chunk: Vector2i, center: Vector2, half: Vector2) -> bool:
	var u := chunk.x * CHUNK_CELLS * CELL
	var v := chunk.y * CHUNK_CELLS * CELL
	var size := CHUNK_CELLS * CELL
	var corners := [_from_uv(u, v), _from_uv(u + size, v), _from_uv(u + size, v + size), _from_uv(u, v + size)]
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for corner: Vector2 in corners:
		bounds = bounds.expand(corner)
	return bounds.intersects(Rect2(center - half, half * 2.0))


func _show_chunk(chunk: Vector2i) -> void:
	var view := ChunkView.new()
	view.world = self
	view.chunk = chunk
	add_child(view)
	var nodes: Array[Node] = []
	if entities:
		for data: Dictionary in _obstacles_of(chunk):
			var obstacle := Obstacle.new()
			obstacle.setup(data, _obstacle_types[data["type"]])
			entities.add_child(obstacle)
			nodes.append(obstacle)
	_chunk_views[chunk] = {"view": view, "nodes": nodes}


func _hide_chunk(chunk: Vector2i) -> void:
	var entry: Dictionary = _chunk_views[chunk]
	entry["view"].queue_free()
	for node: Node in entry["nodes"]:
		node.queue_free()
	_chunk_views.erase(chunk)


## Genera subito i blocchi attorno alla telecamera (per esempio all'avvio).
func refresh() -> void:
	_update_chunks()


# --- Disegno del terreno ----------------------------------------------

func _level_color(level: int) -> Color:
	var color: Array = _terrain["level_colors"][level]
	return Color(color[0], color[1], color[2])


func _cliff_color(index: int) -> Color:
	var color: Array = _terrain["cliff_colors"][index]
	return Color(color[0], color[1], color[2])


func draw_chunk(canvas: CanvasItem, chunk: Vector2i) -> void:
	for i in CHUNK_CELLS:
		for j in CHUNK_CELLS:
			_draw_cell(canvas, chunk * CHUNK_CELLS + Vector2i(i, j))


func _draw_cell(canvas: CanvasItem, cell: Vector2i) -> void:
	var corners := cell_corners(cell)
	var top := corners[0]
	var right := corners[1]
	var bottom := corners[2]
	var left := corners[3]
	var center := cell_center(cell)
	var level := level_of(cell)
	var base := _level_color(level)
	# Piccole variazioni di colore tra un rombo e l'altro.
	var tint := (_random_unit([seed_value, cell.x, cell.y, "tint"]) - 0.5) * 0.03
	base = Color(base.r + tint, base.g + tint * 1.3, base.b + tint)
	canvas.draw_colored_polygon(corners, base)
	_draw_decor(canvas, cell, base)
	var line := base.lightened(0.07)
	canvas.draw_line(left, top, line, 2.0)
	canvas.draw_line(top, right, line, 2.0)

	# Bordi verso i rombi dietro (in alto sullo schermo).
	for edge: Array in [[Vector2i(-1, 0), left, top], [Vector2i(0, -1), top, right]]:
		var other: Vector2i = cell + edge[0]
		var other_level := level_of(other)
		if other_level == level:
			continue
		var cliff := is_cliff(cell, other)
		var inset := _inset_band(edge[1], edge[2], center, 0.22 if cliff else 0.3)
		if other_level > level:
			# Dietro c'è un'altura: ombra ai suoi piedi.
			canvas.draw_colored_polygon(inset, Color(0, 0, 0, 0.3 if cliff else 0.12))
			if cliff:
				canvas.draw_line(edge[1], edge[2], _cliff_color(1).darkened(0.3), 4.0)
		else:
			# Dietro il terreno scende: bordo chiaro.
			canvas.draw_colored_polygon(inset, Color(1, 1, 0.8, 0.08 if cliff else 0.05))
			canvas.draw_line(edge[1], edge[2], base.lightened(0.25 if cliff else 0.12), 3.0 if cliff else 2.0)

	# Bordi verso i rombi davanti: se si scende con un dirupo, la parete
	# di roccia è disegnata qui, nella parte bassa del rombo.
	for edge: Array in [[Vector2i(1, 0), right, bottom, 0], [Vector2i(0, 1), bottom, left, 1]]:
		var other: Vector2i = cell + edge[0]
		var other_level := level_of(other)
		if other_level >= level:
			continue
		var a: Vector2 = edge[1]
		var b: Vector2 = edge[2]
		if is_cliff(cell, other):
			var height := face_height(level - other_level)
			var lift := Vector2(0, -height)
			var face := _cliff_color(edge[3])
			canvas.draw_colored_polygon(PackedVector2Array([a + lift, b + lift, b, a]), face)
			# Strati della roccia e bordo d'erba in cima.
			for k in range(1, 3):
				var y := lift * (1.0 - k / 3.0)
				canvas.draw_line(a + y, b + y, face.darkened(0.2), 1.5)
			canvas.draw_line(a + lift, b + lift, base.lightened(0.3), 3.0)
			canvas.draw_line(a, b, Color(0, 0, 0, 0.35), 2.0)
		else:
			# Pendio: una fascia sfumata verso il colore più basso.
			var band := _inset_band(a, b, center, 0.3)
			var lower := _level_color(other_level)
			canvas.draw_colored_polygon(band, base.lerp(lower, 0.5))


## Fascia lungo il lato a-b, larga una frazione della distanza dal centro.
func _inset_band(a: Vector2, b: Vector2, center: Vector2, amount: float) -> PackedVector2Array:
	return PackedVector2Array([a, b, b.lerp(center, amount), a.lerp(center, amount)])


## Ciuffi d'erba e fiori: solo decorazione, senza effetti sul movimento.
func _draw_decor(canvas: CanvasItem, cell: Vector2i, base: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, cell.x, cell.y, "decor"])
	var tufts: Array = _decor["grass_tufts"]
	var grass := base.darkened(0.25)
	for k in rng.randi_range(tufts[0], tufts[1]):
		var at := _from_uv(cell.x * CELL + rng.randf_range(8.0, 40.0), cell.y * CELL + rng.randf_range(8.0, 40.0))
		canvas.draw_line(at, at + Vector2(-4, -7), grass, 1.5)
		canvas.draw_line(at, at + Vector2(0, -9), grass, 1.5)
		canvas.draw_line(at, at + Vector2(4, -7), grass, 1.5)
	if rng.randf() < float(_decor["flower_chance"]):
		var colors: Array = _decor["flower_colors"]
		var color: Array = colors[rng.randi() % colors.size()]
		var at := _from_uv(cell.x * CELL + rng.randf_range(8.0, 40.0), cell.y * CELL + rng.randf_range(8.0, 40.0))
		for k in 3:
			canvas.draw_circle(at + Vector2.from_angle(k * TAU / 3.0) * 3.0, 2.5, Color(color[0], color[1], color[2]))
		canvas.draw_circle(at, 1.5, Color(0.95, 0.8, 0.3))


## Disegno di un blocco di terreno: viene fatto una volta sola alla creazione.
class ChunkView:
	extends Node2D

	var world: World
	var chunk: Vector2i

	func _draw() -> void:
		world.draw_chunk(self, chunk)
