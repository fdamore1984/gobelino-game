class_name Dungeon
extends RefCounted
## Sotterraneo sotto una caverna delle montagne: caverne collegate da
## gallerie, generate a caso ma sempre uguali per la stessa caverna e lo
## stesso piano, in una griglia piccola di rombi. Si arriva davanti a un
## passaggio nella parete che riporta in superficie e si cerca quello che
## scende al piano sotto (i passaggi sono sempre in una parete, mai a terra);
## all'ultimo piano, nella caverna più lontana, c'è l'arena del boss.
## Parametri in data/world.json ("dungeon").
##
## Il terreno lo disegna World come la superficie: il pavimento è al
## livello 0, la roccia è un blocco alto che non si scala.

const DATA := preload("res://data/world.json")
## Caverne non più vicine di così (in rombi), così restano separate.
const ROOM_SPACING := 9
## Ostacoli e nemici stanno ad almeno questa distanza (in rombi) da scale e arena.
const KEEP_CLEAR := 3
## Due passaggi nelle pareti non stanno mai più vicini di così (in rombi).
const PASSAGE_SPACING := 8

## Piano (1 = il primo sotto la superficie) e quanti piani ha il sotterraneo.
var depth := 1
var levels := 2
var width := 0
var height := 0
var seed_value := 0
var wall_level := 4
## Caverne: {"center": Vector2i, "radius": int}; la prima è quella d'arrivo.
var rooms: Array[Dictionary] = []
var arrival := Vector2i.ZERO
## Lato del rombo in cui si apre il passaggio nella parete (vedi _wall_spot).
var arrival_side := Vector2i(-1, 0)
## Scala per scendere (solo se non è l'ultimo piano) e arena del boss (solo all'ultimo).
var stairs := Vector2i(-1, -1)
var stairs_side := Vector2i(-1, 0)
var arena := Vector2i(-1, -1)
## Dove si apre l'uscita dopo il boss, nella parete dell'arena.
var arena_exit := Vector2i(-1, -1)
var arena_exit_side := Vector2i(-1, 0)
var arena_radius := 0
var chests: Array[Vector2i] = []
## Casse già aperte in questo piano (posizione -> true).
var opened_chests := {}

## 1 = pavimento, 0 = roccia; fuori dalla griglia è tutta roccia.
var _floor := PackedByteArray()


func _init(dungeon_seed: int, depth_value: int, levels_value: int) -> void:
	seed_value = dungeon_seed
	depth = depth_value
	levels = levels_value
	_generate()


## Quanti piani ha il sotterraneo di una caverna (sempre lo stesso per la stessa caverna).
static func levels_for(cave_seed: int) -> int:
	var range_values: Array = DATA.data["dungeon"]["levels"]
	var rng := RandomNumberGenerator.new()
	rng.seed = cave_seed
	return rng.randi_range(range_values[0], range_values[1])


func is_last() -> bool:
	return depth >= levels


## Centro dell'arena del boss nel mondo (solo all'ultimo piano).
func arena_center() -> Vector2:
	return World.cell_center(arena)


func is_floor(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return false
	return _floor[cell.y * width + cell.x] == 1


## Pavimento libero tutto attorno e lontano da scale, arena e casse: qui
## si possono mettere stalagmiti e nemici senza chiudere le gallerie.
func is_open(cell: Vector2i) -> bool:
	for i in range(-1, 2):
		for j in range(-1, 2):
			if not is_floor(cell + Vector2i(i, j)):
				return false
	for spot in [arrival, stairs]:
		if spot.x >= 0 and (spot as Vector2i).distance_to(cell) < KEEP_CLEAR:
			return false
	if arena.x >= 0 and arena.distance_to(cell) < arena_radius + 1:
		return false
	for chest in chests:
		if chest.distance_to(cell) < 2:
			return false
	return true


## Pezzi di mondo (vedi World) che coprono il sotterraneo, con un bordo di roccia.
func chunk_rect() -> Rect2i:
	var last := Vector2i(floori(float(width) / World.CHUNK_CELLS), floori(float(height) / World.CHUNK_CELLS))
	return Rect2i(Vector2i(-1, -1), last + Vector2i(3, 3))


## Rombi del pavimento di una caverna, per farci comparire i nemici.
func room_cells(room: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var center: Vector2i = room["center"]
	var radius: int = room["radius"]
	for i in range(-radius, radius + 1):
		for j in range(-radius, radius + 1):
			var cell := center + Vector2i(i, j)
			if is_open(cell):
				result.append(cell)
	return result


func _generate() -> void:
	var data: Dictionary = DATA.data["dungeon"]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var size: Array = data["size"]
	width = int(size[0]) + int(size[1]) * (depth - 1)
	height = width
	wall_level = data["wall_level"]
	_floor.resize(width * height)
	_floor.fill(0)
	var room_count: Array = data["rooms"]
	var count := int(room_count[0]) + int(room_count[1]) * (depth - 1)
	var radius_range: Array = data["room_radius"]
	arena_radius = data["arena_radius"]
	var margin: int = (arena_radius if is_last() else int(radius_range[1])) + 2
	# Caverne sparse, lontane tra loro.
	for attempt in 300:
		if rooms.size() >= count:
			break
		var center := Vector2i(rng.randi_range(margin, width - 1 - margin), rng.randi_range(margin, height - 1 - margin))
		var free := true
		for room in rooms:
			if (room["center"] as Vector2i).distance_to(center) < ROOM_SPACING:
				free = false
				break
		if free:
			rooms.append({"center": center, "radius": rng.randi_range(radius_range[0], radius_range[1])})
	if rooms.size() < 2:
		# Non dovrebbe succedere, ma due caverne agli angoli opposti bastano.
		rooms = [{"center": Vector2i(margin, margin), "radius": radius_range[0]},
				{"center": Vector2i(width - 1 - margin, height - 1 - margin), "radius": radius_range[0]}]
	for room in rooms:
		_carve_room(room["center"], room["radius"], rng)
	# Gallerie: ogni caverna si collega alla più vicina tra quelle già
	# collegate, più qualche giro in più.
	for i in range(1, rooms.size()):
		var best := 0
		for j in i:
			if _room_distance(j, i) < _room_distance(best, i):
				best = j
		_carve_tunnel(rooms[best]["center"], rooms[i]["center"], rng)
	for k in floori(rooms.size() / 3.0):
		_carve_tunnel(rooms[rng.randi() % rooms.size()]["center"], rooms[rng.randi() % rooms.size()]["center"], rng)
	var arrival_spot := _wall_spot(rooms[0]["center"], int(rooms[0]["radius"]) + 2)
	arrival = arrival_spot[0]
	arrival_side = arrival_spot[1]
	# La caverna più lontana a piedi dall'arrivo ha la scala, o l'arena del boss.
	var distances := _distances_from(arrival)
	var far_room := 1
	for i in range(1, rooms.size()):
		if distances.get(rooms[i]["center"], 0) > distances.get(rooms[far_room]["center"], 0):
			far_room = i
	if is_last():
		arena = rooms[far_room]["center"]
		rooms[far_room]["radius"] = arena_radius
		_carve_room(arena, arena_radius, rng, false)
		var exit_spot := _wall_spot(arena, arena_radius + 2, [arrival])
		arena_exit = exit_spot[0]
		arena_exit_side = exit_spot[1]
	else:
		var stairs_spot := _wall_spot(rooms[far_room]["center"], int(rooms[far_room]["radius"]) + 2, [arrival])
		stairs = stairs_spot[0]
		stairs_side = stairs_spot[1]
	# Casse nelle altre caverne.
	var chest_range: Array = data["chests"]
	var candidates: Array[int] = []
	for i in range(1, rooms.size()):
		if i != far_room:
			candidates.append(i)
	for k in mini(rng.randi_range(chest_range[0], chest_range[1]), candidates.size()):
		var room: Dictionary = rooms[candidates.pop_at(rng.randi() % candidates.size())]
		var spot: Vector2i = room["center"] + Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
		if is_floor(spot):
			chests.append(spot)


## Passaggio in una parete vicino al punto: un rombo di pavimento con
## dietro (lato in alto a sinistra o in alto a destra sullo schermo) un
## tratto dritto di roccia e attorno pavimento libero, così l'arco si vede
## bene, lontano dai passaggi in avoid. Restituisce [rombo, lato]; se non
## c'è si accontenta di un rombo con la roccia dietro, poi cerca ovunque.
func _wall_spot(near: Vector2i, max_distance: int, avoid: Array[Vector2i] = []) -> Array:
	for reach: int in [max_distance, maxi(width, height)]:
		for strict: bool in [true, false]:
			var spot := _find_wall_spot(near, reach, avoid, strict)
			if not spot.is_empty():
				return spot
	return [near, Vector2i(-1, 0)]


func _find_wall_spot(near: Vector2i, max_distance: int, avoid: Array[Vector2i], strict: bool) -> Array:
	var best: Array = []
	var best_distance := INF
	for i in range(-max_distance, max_distance + 1):
		for j in range(-max_distance, max_distance + 1):
			var cell := near + Vector2i(i, j)
			if not is_floor(cell) or (strict and not is_floor(cell + Vector2i(1, 1))):
				continue
			if avoid.any(func(other: Vector2i) -> bool: return other.distance_to(cell) < PASSAGE_SPACING):
				continue
			for side: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1)]:
				var along := Vector2i(side.y, side.x)
				if is_floor(cell + side) or not is_floor(cell - side):
					continue
				if strict and (is_floor(cell + side + along) or is_floor(cell + side - along) \
						or not is_floor(cell + along) or not is_floor(cell - along)):
					continue
				var distance := Vector2(i, j).length()
				if distance < best_distance:
					best = [cell, side]
					best_distance = distance
	return best


func _room_distance(a: int, b: int) -> float:
	return (rooms[a]["center"] as Vector2i).distance_to(rooms[b]["center"])


## Caverna tondeggiante dai bordi irregolari (rough = false: cerchio pieno).
func _carve_room(center: Vector2i, radius: int, rng: RandomNumberGenerator, rough := true) -> void:
	for i in range(-radius - 1, radius + 2):
		for j in range(-radius - 1, radius + 2):
			var limit := radius + (rng.randf_range(-0.7, 0.6) if rough else 0.3)
			if Vector2(i, j).length() <= limit:
				_set_floor(center + Vector2i(i, j))


## Galleria larga due rombi che va da a a b con qualche svolta.
func _carve_tunnel(from: Vector2i, to: Vector2i, rng: RandomNumberGenerator) -> void:
	var at := from
	var guard := 0
	while at != to and guard < 400:
		guard += 1
		var step := Vector2i.ZERO
		var horizontal := rng.randf() < 0.5
		if at.x == to.x:
			horizontal = false
		elif at.y == to.y:
			horizontal = true
		if rng.randf() < 0.15:
			# Una piccola deviazione, per gallerie meno dritte.
			step = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][rng.randi() % 4]
		elif horizontal:
			step = Vector2i(signi(to.x - at.x), 0)
		else:
			step = Vector2i(0, signi(to.y - at.y))
		at = (at + step).clamp(Vector2i(1, 1), Vector2i(width - 3, height - 3))
		_set_floor(at)
		_set_floor(at + Vector2i(1, 0))
		_set_floor(at + Vector2i(0, 1))


func _set_floor(cell: Vector2i) -> void:
	if cell.x >= 1 and cell.y >= 1 and cell.x < width - 1 and cell.y < height - 1:
		_floor[cell.y * width + cell.x] = 1


## Distanza a piedi (in rombi) di ogni rombo del pavimento dal punto.
func _distances_from(start: Vector2i) -> Dictionary:
	var distances := {start: 0}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := cell + step
			if is_floor(next) and not distances.has(next):
				distances[next] = distances[cell] + 1
				queue.append(next)
	return distances
