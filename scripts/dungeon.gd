class_name Dungeon
extends RefCounted
## Sotterraneo sotto una caverna delle montagne: caverne collegate da
## gallerie, generate a caso ma sempre uguali per la stessa caverna e lo
## stesso piano, in una griglia piccola di rombi. Le caverne non sono
## cerchi: più lobi sovrapposti dal bordo frastagliato; le gallerie
## serpeggiano, cambiano larghezza e hanno qualche nicchia; alla fine le
## pareti si levigano (vedi _carve_room, _carve_tunnel, _smooth_caves). Si arriva davanti a un
## passaggio nella parete che riporta in superficie e si cerca quello che
## scende al piano sotto (i passaggi sono sempre in una parete, mai a terra);
## all'ultimo piano, nella caverna più lontana, c'è l'arena del boss.
## Parametri in data/world.json ("dungeon").
##
## Il terreno lo disegna World come la superficie: il pavimento è al
## livello 0, la roccia è un blocco alto che non si scala.
##
## Le catacombe (kind "metro", parametri in "metro" di data/world.json)
## sono un sotterraneo come gli altri, sotto un mausoleo in rovina: al
## centro le navate di pietra (due laterali e una centrale con una fila di
## colonne) tra due fosse ossarie incassate un livello più in basso
## (TRACK), che oltre le navate continuano nelle gallerie scavate: curvano
## un rombo alla volta, hanno un camminamento lungo la parete, nicchie
## sepolcrali, cunicoli trasversali tra una galleria e l'altra e finiscono
## in un crollo. Nelle fosse, lungo le navate e nelle gallerie, le grandi
## tombe di pietra (TRAIN), a volte franate sul bordo della navata: sono
## ostacoli, ma il coperchio è un livello sopra la navata e ci si sale con
## un salto. Sopra e sotto le navate cappelle e camere sepolcrali, divise a
## caso in stanze, con brecce nei muri, angoli franati e cumuli di pietre
## (vedi _roughen), con le porte sulle navate. Il codice usa
## gli stessi nomi interni della metropolitana di Ciccio Massacro.

const DATA := preload("res://data/world.json")
## Caverne non più vicine di così (in rombi), così restano separate.
const ROOM_SPACING := 9
## Ostacoli e nemici stanno ad almeno questa distanza (in rombi) da scale e arena.
const KEEP_CLEAR := 3
## Due passaggi nelle pareti non stanno mai più vicini di così (in rombi).
const PASSAGE_SPACING := 8

## Tipo di ogni rombo delle catacombe (solo grafica e altezze; vedi tile_at).
enum Tile { FLOOR, WALL, TRACK, TRAIN }

## Piano (1 = il primo sotto la superficie) e quanti piani ha il sotterraneo.
var depth := 1
var levels := 2
## "cave" (caverna delle montagne) o "metro" (catacombe sotto un mausoleo).
var kind := "cave"
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

## Livello delle fosse ossarie e della cima delle tombe (solo nelle catacombe).
var track_level := -1
var train_level := 2
## Righe (v) delle navate (solo nelle catacombe).
var station_rows := Vector2i(-1, -1)

## 1 = pavimento, 0 = roccia; fuori dalla griglia è tutta roccia.
var _floor := PackedByteArray()
## Tipo di rombo (Tile), solo nelle catacombe.
var _tiles := PackedByteArray()


func _init(dungeon_seed: int, depth_value: int, levels_value: int, kind_value := "cave") -> void:
	seed_value = dungeon_seed
	depth = depth_value
	levels = levels_value
	kind = kind_value
	_generate()


## Parametri del tipo di sotterraneo ("dungeon" o "metro" di data/world.json).
static func data_for(kind_value: String) -> Dictionary:
	return DATA.data["metro" if kind_value == "metro" else "dungeon"]


func settings() -> Dictionary:
	return data_for(kind)


## Catacombe (vedi in cima).
func is_metro() -> bool:
	return kind == "metro"


## Quanti piani ha il sotterraneo di una caverna o di un mausoleo (sempre
## lo stesso per lo stesso ingresso).
static func levels_for(cave_seed: int, kind_value := "cave") -> int:
	var range_values: Array = data_for(kind_value)["levels"]
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


## Tipo del rombo (vedi Tile): nelle caverne solo pavimento e roccia.
func tile_at(cell: Vector2i) -> int:
	if not is_floor(cell):
		if is_metro() and cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height \
				and _tiles[cell.y * width + cell.x] == Tile.TRAIN:
			return Tile.TRAIN
		return Tile.WALL
	if is_metro():
		return _tiles[cell.y * width + cell.x]
	return Tile.FLOOR


## Livello del rombo: pavimento 0, roccia wall_level, fosse e tombe i loro.
func level_at(cell: Vector2i) -> int:
	match tile_at(cell):
		Tile.TRACK:
			return track_level
		Tile.TRAIN:
			return train_level
		Tile.WALL:
			return wall_level
	return 0


## Pavimento libero tutto attorno e lontano da scale, arena e casse: qui
## si possono mettere stalagmiti e nemici senza chiudere le gallerie. Con
## loose basta il rombo stesso (le fosse nelle gallerie sono strette).
func is_open(cell: Vector2i, loose := false) -> bool:
	for i in range(-1, 2):
		for j in range(-1, 2):
			if not is_floor(cell + Vector2i(i, j)) and not (loose and (i != 0 or j != 0)):
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


## Rombi del pavimento di una caverna (o di una stanza delle catacombe,
## col suo rettangolo), per farci comparire i nemici.
func room_cells(room: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var center: Vector2i = room["center"]
	var radius: int = room["radius"]
	var rect: Rect2i = room.get("rect", Rect2i(center - Vector2i(radius, radius), Vector2i(radius, radius) * 2 + Vector2i.ONE))
	var loose := is_metro()
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, y)
			if is_open(cell, loose):
				result.append(cell)
	return result


func _generate() -> void:
	var data := settings()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var size: Array = data["size"]
	width = int(size[0]) + int(size[1]) * (depth - 1)
	height = width
	wall_level = data["wall_level"]
	_floor.resize(width * height)
	_floor.fill(0)
	if is_metro():
		arena_radius = data["arena_radius"]
		var leaves: Array[Rect2i] = []
		_place_passages(_generate_station(rng, data, leaves), leaves, rng, data)
		return
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
	_smooth_caves(rooms[0]["center"])
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


## Caverna dalla forma irregolare (rough = false: cerchio pieno, per
## l'arena del boss): più lobi tondi sovrapposti attorno al centro, con il
## bordo frastagliato, così nessuna caverna è un cerchio.
func _carve_room(center: Vector2i, radius: int, rng: RandomNumberGenerator, rough := true) -> void:
	var lobes: Array[Vector3] = [Vector3(0, 0, radius)]
	if rough:
		var lobe_range: Array = settings().get("cave_lobes", [2, 4])
		for k in rng.randi_range(lobe_range[0], lobe_range[1]):
			var direction := Vector2.from_angle(rng.randf() * TAU)
			var offset := direction * radius * rng.randf_range(0.45, 0.8)
			lobes.append(Vector3(offset.x, offset.y, radius * rng.randf_range(0.35, 0.6)))
	var reach := ceili(radius * 1.5) + 1
	for i in range(-reach, reach + 1):
		for j in range(-reach, reach + 1):
			for lobe in lobes:
				var limit := lobe.z + (rng.randf_range(-0.7, 0.6) if rough else 0.3)
				if Vector2(i - lobe.x, j - lobe.y).length() <= limit:
					_set_floor(center + Vector2i(i, j))
					break


## Galleria da a verso b che serpeggia: la direzione oscilla attorno a
## quella verso la meta, la larghezza cambia da 1 a 3 rombi ("tunnel_width")
## e ogni tanto si apre una nicchia di lato ("alcove_chance").
func _carve_tunnel(from: Vector2i, to: Vector2i, rng: RandomNumberGenerator) -> void:
	var data := settings()
	var widths: Array = data.get("tunnel_width", [1, 3])
	var at := Vector2(from)
	var breadth := 2
	var wander := 0.0
	var guard := 0
	while Vector2i(at.round()) != to and guard < 600:
		guard += 1
		var toward := (Vector2(to) - at)
		if toward.length() < 1.5:
			at = Vector2(to)
		else:
			wander = clampf(wander + rng.randf_range(-0.5, 0.5), -1.1, 1.1)
			at += toward.normalized().rotated(wander)
		at = at.clamp(Vector2(1, 1), Vector2(width - 3, height - 3))
		if rng.randf() < 0.15:
			breadth = clampi(breadth + (1 if rng.randf() < 0.5 else -1), int(widths[0]), int(widths[1]))
		var cell := Vector2i(at.round())
		for i in breadth:
			for j in breadth:
				_set_floor(cell + Vector2i(i, j))
		if rng.randf() < float(data.get("alcove_chance", 0.0)):
			var side := Vector2(toward.y, -toward.x).normalized() * (1.0 if rng.randf() < 0.5 else -1.0)
			_set_floor(cell + Vector2i((side * float(breadth + 1)).round()))
			_set_floor(cell + Vector2i((side * float(breadth)).round()))


## Leviga le pareti: i rombi di roccia quasi circondati dal pavimento
## crollano, le punte di pavimento isolate si richiudono (una passata di
## automa cellulare); poi resta solo ciò che si raggiunge da start.
func _smooth_caves(start: Vector2i) -> void:
	var changes: Array[Vector2i] = []
	var fills: Array[Vector2i] = []
	for v in range(1, height - 1):
		for x in range(1, width - 1):
			var cell := Vector2i(x, v)
			var around := 0
			for i in range(-1, 2):
				for j in range(-1, 2):
					if (i != 0 or j != 0) and is_floor(cell + Vector2i(i, j)):
						around += 1
			if not is_floor(cell) and around >= 6:
				changes.append(cell)
			elif is_floor(cell) and around <= 1:
				fills.append(cell)
	for cell in changes:
		_set_floor(cell)
	for cell in fills:
		_floor[cell.y * width + cell.x] = 0
	_keep_reachable(start)


## Pianta delle catacombe (vedi in cima): navate, fosse ossarie,
## gallerie, tombe, cappelle e camere sepolcrali. Le stanze per i nemici
## (leaves) sono le camere, pezzi di navata e tratti di galleria; restituisce
## il pezzo di navata d'arrivo, in fondo a sinistra della prima navata.
func _generate_station(rng: RandomNumberGenerator, data: Dictionary, leaves: Array[Rect2i]) -> Rect2i:
	_tiles.resize(width * height)
	_tiles.fill(Tile.WALL)
	track_level = data["track_level"]
	train_level = data["train_level"]
	var side := int(data["side_platform"])
	var track := int(data["track_width"])
	var island_range: Array = data["island_platform"]
	var island := rng.randi_range(island_range[0], island_range[1])
	var total := side * 2 + track * 2 + island
	var top := (height - total) / 2 + rng.randi_range(-2, 2)
	station_rows = Vector2i(top, top + total - 1)
	var ends: Array = data["platform_end"]
	var x0 := 1 + rng.randi_range(ends[0], ends[1])
	var x1 := width - 2 - rng.randi_range(ends[0], ends[1])
	# Righe dall'alto: navata, fossa, navata centrale, fossa, navata.
	var rows: Array[Array] = []
	var y := top
	for part: Array in [["side", side], ["track", track], ["island", island], ["track", track], ["side", side]]:
		rows.append([part[0], y, y + int(part[1]) - 1])
		y += int(part[1])
	var segment := int(data["platform_segment"])
	var max_shift := int(data["tunnel_shift"])
	var shift := _tunnel_shifts(x0, x1, rng, data, rows)
	# Fosse ossarie: lungo le navate dritte, oltre nelle gallerie scavate
	# che curvano un rombo alla volta, con un camminamento lungo la parete
	# esterna e qualche nicchia sepolcrale; ogni galleria finisce in un
	# crollo prima del bordo.
	var tunnel_end: Array = data["tunnel_end"]
	var spans: Array[Vector2i] = []
	for t in 2:
		var row: Array = rows[1 + 2 * t]
		var outward := -1 if t == 0 else 1
		var left_end := 1 + rng.randi_range(tunnel_end[0], tunnel_end[1])
		var right_end := width - 2 - rng.randi_range(tunnel_end[0], tunnel_end[1])
		for x in range(left_end, right_end + 1):
			for v in range(int(row[1]), int(row[2]) + 1):
				_set_tile(Vector2i(x, v + shift[x]), Tile.TRACK)
			if x >= x0 and x <= x1:
				continue
			var walk := (int(row[1]) - 1 if t == 0 else int(row[2]) + 1) + shift[x]
			_set_tile(Vector2i(x, walk), Tile.FLOOR)
			if rng.randf() < float(data["niche_chance"]):
				_set_tile(Vector2i(x, walk + outward), Tile.FLOOR)
		for span: Vector2i in [Vector2i(left_end, x0 - 1), Vector2i(x1 + 1, right_end)]:
			if span.y - span.x >= 3:
				leaves.append(Rect2i(span.x, int(row[1]) - max_shift - 1, span.y - span.x + 1, int(row[2]) - int(row[1]) + 3 + 2 * max_shift))
				spans.append(span)
	# Cunicoli trasversali tra le due gallerie, ogni tanto (larghi due rombi).
	var cross: Array = data["cross_passage"]
	for mouth: Vector2i in [Vector2i(x0 - 1, -1), Vector2i(x1 + 1, 1)]:
		var x := mouth.x + mouth.y * rng.randi_range(int(cross[0]) / 2, int(cross[1]))
		while x > 2 and x < width - 3:
			for k in 2:
				for v in range(int(rows[1][2]) + 1, int(rows[3][1])):
					_set_tile(Vector2i(x + k * mouth.y, v + shift[x + k * mouth.y]), Tile.FLOOR)
			x += mouth.y * rng.randi_range(cross[0], cross[1])
	# Navate, con le testate irregolari (mai oltre l'inizio delle gallerie).
	var ragged := int(data["platform_ragged"])
	var first_platform := Rect2i()
	for row: Array in rows:
		if row[0] == "track":
			continue
		var first: int = row[1]
		var last: int = row[2]
		var a := x0 + rng.randi_range(0, ragged)
		var b := x1 - rng.randi_range(0, ragged)
		_fill(Vector2i(a, first), Vector2i(b, last))
		var x := a
		while x <= b:
			var length := mini(segment, b - x + 1)
			leaves.append(Rect2i(x, first, length, last - first + 1))
			if first_platform.size == Vector2i.ZERO:
				first_platform = Rect2i(x, first, length, last - first + 1)
			x += length
	# Colonne in mezzo alla navata centrale, una ogni "pillar_step" rombi.
	var island_row: Array = rows[2]
	var middle := (int(island_row[1]) + int(island_row[2])) / 2
	for x in range(x0 + 2, x1 - 1, int(data["pillar_step"])):
		_floor[middle * width + x] = 0
		_set_tile(Vector2i(x, middle), Tile.WALL, false)
	# Grandi tombe di pietra: lungo le navate (a volte franate, di traverso
	# sul bordo della navata) e nelle gallerie (si passa sul camminamento).
	# Il coperchio è un livello sopra la navata: ci si sale con un salto.
	var cars: Array = data["train_cars"]
	var car_length: Array = data["car_length"]
	for t in 2:
		var row: Array = rows[1 + 2 * t]
		if rng.randf() < float(data["train_chance"]):
			var count := rng.randi_range(cars[0], cars[1])
			var x := rng.randi_range(x0 + 1, maxi(x0 + 1, x1 - 1 - count * (int(car_length[1]) + 1)))
			for k in count:
				var length := rng.randi_range(car_length[0], car_length[1])
				var derail := (-1 if t == 0 else 1) if rng.randf() < float(data["derail_chance"]) else 0
				_place_car(x, mini(length, x1 - x), int(row[1]) + derail, int(row[2]) + derail, shift)
				x += length + 1
		var tunnel_cars: Array = data["tunnel_cars"]
		for span in spans:
			for k in rng.randi_range(tunnel_cars[0], tunnel_cars[1]):
				var length := rng.randi_range(car_length[0], car_length[1])
				if span.y - span.x - 2 < length:
					break
				_place_car(rng.randi_range(span.x + 1, span.y - length), length, int(row[1]), int(row[2]), shift)
	# Cappelle e camere sepolcrali sopra e sotto le navate, con le porte sulle navate.
	var areas := [Rect2i(x0, 1, x1 - x0 + 1, top - 2), Rect2i(x0, station_rows.y + 2, x1 - x0 + 1, height - station_rows.y - 3)]
	for k in areas.size():
		var area: Rect2i = areas[k]
		if area.size.y < int(data["room_size"][0]):
			continue
		_generate_rooms(area, rng, data, leaves)
		var wall_y := top - 1 if k == 0 else station_rows.y + 1
		var cells: Array[Vector2i] = []
		for x in range(x0, x1 + 1):
			cells.append(Vector2i(x, wall_y))
		var wall := {"cells": cells, "across": Vector2i(0, 1)}
		for _door in int(data["service_doors"]):
			_open_door(wall, rng)
	# Ciò che non si raggiunge dalla navata d'arrivo diventa muro.
	_keep_reachable(_center(first_platform))
	return first_platform


## Spostamento (in righe) delle fosse in ogni colonna: zero lungo le
## navate, nelle gallerie cambia di un rombo ogni "tunnel_bend" rombi,
## fino a "tunnel_shift", restando lontano dal bordo della pianta.
func _tunnel_shifts(x0: int, x1: int, rng: RandomNumberGenerator, data: Dictionary, rows: Array[Array]) -> PackedInt32Array:
	var shift := PackedInt32Array()
	shift.resize(width)
	shift.fill(0)
	var bend: Array = data["tunnel_bend"]
	var limit := int(data["tunnel_shift"])
	var low := maxi(-limit, 4 - int(rows[1][1]))
	var high := mini(limit, height - 5 - int(rows[3][2]))
	for direction: int in [-1, 1]:
		var x := x0 - 1 if direction < 0 else x1 + 1
		var current := 0
		var next_bend := rng.randi_range(bend[0], bend[1])
		while x >= 0 and x < width:
			next_bend -= 1
			if next_bend <= 0:
				current = clampi(current + (1 if rng.randf() < 0.5 else -1), low, high)
				next_bend = rng.randi_range(bend[0], bend[1])
			shift[x] = current
			x += direction
	return shift


## Grande tomba nella fossa: dalla colonna x per length rombi, sulle righe
## da first a last (spostate come la fossa della colonna).
func _place_car(x: int, length: int, first: int, last: int, shift: PackedInt32Array) -> void:
	for i in length:
		for v in range(first, last + 1):
			_set_tile(Vector2i(x + i, v + shift[x + i]), Tile.TRAIN)


## Ciò che non si raggiunge a piedi da start diventa muro.
func _keep_reachable(start: Vector2i) -> void:
	var reached := _distances_from(start)
	for v in height:
		for x in width:
			var cell := Vector2i(x, v)
			if is_floor(cell) and not reached.has(cell):
				_floor[v * width + x] = 0
				if is_metro():
					_tiles[v * width + x] = Tile.WALL


## Divide il rettangolo in stanze (aggiunte a leaves) con muri dritti e porte.
func _generate_rooms(area: Rect2i, rng: RandomNumberGenerator, data: Dictionary, leaves: Array[Rect2i]) -> void:
	# Lo spazio si taglia più volte con muri dritti: le stanze sono i pezzi
	# rimasti, i muri si incontrano a T e a croce.
	var first := leaves.size()
	var walls: Array[Dictionary] = []
	_split(area, rng, leaves, walls, data)
	for k in range(first, leaves.size()):
		_fill(leaves[k].position, leaves[k].end - Vector2i.ONE)
	# Ogni muro ha una porta (così tutte le stanze sono collegate), a volte
	# due, a volte sparisce del tutto (un salone); nei saloni grandi i pilastri.
	for wall in walls:
		if rng.randf() < float(data["merge_chance"]) and wall["cells"].size() <= int(data["merge_max"]):
			for cell: Vector2i in wall["cells"]:
				_set_floor(cell)
			continue
		_open_door(wall, rng)
		if rng.randf() < float(data["extra_doors"]):
			_open_door(wall, rng)
	for k in range(first, leaves.size()):
		_add_pillars(leaves[k], rng, data)
	_roughen(leaves, first, walls, rng, data)


## Camere meno regolari: tratti di muro crollati (brecce, oltre alle
## porte), angoli franati (camere a L) e cumuli di pietre contro i muri,
## senza mai chiudere porte e passaggi.
func _roughen(leaves: Array[Rect2i], first: int, walls: Array[Dictionary], rng: RandomNumberGenerator, data: Dictionary) -> void:
	for wall in walls:
		var cells: Array = wall["cells"]
		var across: Vector2i = wall["across"]
		if cells.size() < 5 or rng.randf() >= float(data.get("breach_chance", 0.0)):
			continue
		var length := rng.randi_range(1, 3)
		var at := rng.randi_range(1, cells.size() - 1 - length)
		for k in length:
			var cell: Vector2i = cells[at + k]
			if is_floor(cell + across) and is_floor(cell - across):
				_set_floor(cell)
	for k in range(first, leaves.size()):
		var leaf := leaves[k]
		if mini(leaf.size.x, leaf.size.y) >= 6 and rng.randf() < float(data.get("collapse_chance", 0.0)):
			var size := Vector2i(rng.randi_range(2, leaf.size.x / 3), rng.randi_range(2, leaf.size.y / 3))
			var corner := Vector2i(leaf.position.x if rng.randf() < 0.5 else leaf.end.x - size.x,
					leaf.position.y if rng.randf() < 0.5 else leaf.end.y - size.y)
			for x in range(corner.x, corner.x + size.x):
				for y in range(corner.y, corner.y + size.y):
					_fill_wall_inside(Vector2i(x, y), leaf)
		var debris := float(data.get("debris_chance", 0.0))
		if debris > 0.0:
			for x in range(leaf.position.x, leaf.end.x):
				for y in range(leaf.position.y, leaf.end.y):
					var cell := Vector2i(x, y)
					var on_edge := x == leaf.position.x or y == leaf.position.y or x == leaf.end.x - 1 or y == leaf.end.y - 1
					if on_edge and rng.randf() < debris and (cell - _center(leaf)).length() > 2.0:
						_fill_wall_inside(cell, leaf)


## Fa diventare muro un rombo della stanza leaf, ma non se è davanti a una
## porta o a un passaggio (un vicino fuori dalla stanza è pavimento).
func _fill_wall_inside(cell: Vector2i, leaf: Rect2i) -> void:
	if not is_floor(cell):
		return
	for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not leaf.has_point(cell + step) and is_floor(cell + step):
			return
	_floor[cell.y * width + cell.x] = 0
	if is_metro():
		_tiles[cell.y * width + cell.x] = Tile.WALL


## Arrivo, scala (o arena del boss all'ultimo piano), stanze e casse.
func _place_passages(start_leaf: Rect2i, leaves: Array[Rect2i], rng: RandomNumberGenerator, data: Dictionary) -> void:
	# La stanza più lontana a piedi ha la scala, o l'arena del boss.
	var arrival_room := _center(start_leaf)
	var arrival_spot := _wall_spot(arrival_room, maxi(start_leaf.size.x, start_leaf.size.y) / 2 + 2)
	arrival = arrival_spot[0]
	arrival_side = arrival_spot[1]
	var distances := _distances_from(arrival)
	var far := start_leaf
	for leaf in leaves:
		if distances.get(_center(leaf), 0) > distances.get(_center(far), 0) and is_floor(_center(leaf)):
			far = leaf
	if is_last():
		# Arena: un salone quadrato attorno alla stanza più lontana, dentro la pianta.
		var low := arena_radius + 2
		var high := width - arena_radius - 3
		arena = _center(far).clamp(Vector2i(low, low), Vector2i(high, high))
		if arena.distance_to(arrival) < arena_radius + 4:
			arena = Vector2i(width - 1, height - 1) - arena
			arena = arena.clamp(Vector2i(low, low), Vector2i(high, high))
		_fill(arena - Vector2i(arena_radius, arena_radius), arena + Vector2i(arena_radius, arena_radius))
	var arena_rect := Rect2i(arena - Vector2i(arena_radius + 1, arena_radius + 1), Vector2i(arena_radius, arena_radius) * 2 + Vector2i(3, 3))
	rooms = [_room(start_leaf, false)]
	var others: Array[Dictionary] = []
	for leaf in leaves:
		if leaf == start_leaf or (is_last() and arena_rect.intersects(leaf)):
			continue
		var room := _room(leaf, leaf == far)
		others.append(room)
	rooms.append_array(others)
	if is_last():
		rooms.append({"center": arena, "radius": arena_radius})
		var exit_spot := _wall_spot(arena, arena_radius + 2, [arrival])
		arena_exit = exit_spot[0]
		arena_exit_side = exit_spot[1]
	else:
		var stairs_spot := _wall_spot(_center(far), maxi(far.size.x, far.size.y) / 2 + 2, [arrival])
		stairs = stairs_spot[0]
		stairs_side = stairs_spot[1]
	# Casse nelle altre stanze.
	var chest_range: Array = data["chests"]
	var candidates: Array[Dictionary] = []
	for room in others:
		if not room["far"]:
			candidates.append(room)
	for k in mini(rng.randi_range(chest_range[0], chest_range[1]), candidates.size()):
		var room: Dictionary = candidates.pop_at(rng.randi() % candidates.size())
		var spot: Vector2i = room["center"] + Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
		if is_floor(spot):
			chests.append(spot)


## Taglia il rettangolo con un muro dritto (lungo il lato più lungo, in un
## punto a caso) e poi i due pezzi, finché sono abbastanza piccoli: i pezzi
## finali sono le stanze (leaves), i muri si ricordano in walls con i loro
## rombi. Più o meno a caso restano anche stanze grandi (saloni) e strette
## (corridoi).
func _split(rect: Rect2i, rng: RandomNumberGenerator, leaves: Array[Rect2i], walls: Array[Dictionary], data: Dictionary) -> void:
	var room: Array = data["room_size"]
	var smallest := int(room[0])
	var largest := int(room[1])
	var can_x := rect.size.x >= 2 * smallest + 1
	var can_y := rect.size.y >= 2 * smallest + 1
	var fits := rect.size.x <= largest and rect.size.y <= largest
	if not (can_x or can_y) or (fits and rng.randf() < float(data["stop_chance"])):
		leaves.append(rect)
		return
	var along_x := can_x and (not can_y or rect.size.x > rect.size.y or (rect.size.x == rect.size.y and rng.randf() < 0.5))
	var length := rect.size.x if along_x else rect.size.y
	# A volte un corridoio stretto lungo il muro.
	var cut := rng.randi_range(smallest, length - smallest - 1)
	if rng.randf() < float(data["corridor_chance"]) and length >= 2 * smallest + 4:
		cut = 2 if rng.randf() < 0.5 else length - 3
	var cells: Array[Vector2i] = []
	if along_x:
		for y in range(rect.position.y, rect.end.y):
			cells.append(Vector2i(rect.position.x + cut, y))
		_split(Rect2i(rect.position, Vector2i(cut, rect.size.y)), rng, leaves, walls, data)
		_split(Rect2i(rect.position + Vector2i(cut + 1, 0), Vector2i(rect.size.x - cut - 1, rect.size.y)), rng, leaves, walls, data)
	else:
		for x in range(rect.position.x, rect.end.x):
			cells.append(Vector2i(x, rect.position.y + cut))
		_split(Rect2i(rect.position, Vector2i(rect.size.x, cut)), rng, leaves, walls, data)
		_split(Rect2i(rect.position + Vector2i(0, cut + 1), Vector2i(rect.size.x, rect.size.y - cut - 1)), rng, leaves, walls, data)
	walls.append({"cells": cells, "across": Vector2i(1, 0) if along_x else Vector2i(0, 1)})


## Porta larga due rombi nel muro, dove da tutte e due le parti c'è
## pavimento (non contro un altro muro che arriva a T).
func _open_door(wall: Dictionary, rng: RandomNumberGenerator) -> void:
	var cells: Array = wall["cells"]
	var across: Vector2i = wall["across"]
	var options: Array[int] = []
	for k in cells.size() - 1:
		var ok := true
		for cell: Vector2i in [cells[k], cells[k + 1]]:
			if not is_floor(cell + across) or not is_floor(cell - across):
				ok = false
		if ok:
			options.append(k)
	if options.is_empty():
		# Muro corto o tutto contro altri muri: basta un rombo dove si passa.
		for k in cells.size():
			if is_floor(cells[k] + across) and is_floor(cells[k] - across):
				options.append(k)
		if options.is_empty():
			return
		_set_floor(cells[options[rng.randi() % options.size()]])
		return
	var at := options[rng.randi() % options.size()]
	_set_floor(cells[at])
	_set_floor(cells[at + 1])


## Colonne nelle sale più grandi: un rombo di muro ogni tre, lontano dai muri.
func _add_pillars(leaf: Rect2i, rng: RandomNumberGenerator, data: Dictionary) -> void:
	if leaf.size.x < int(data["pillar_room"]) or leaf.size.y < int(data["pillar_room"]) or rng.randf() >= float(data["pillar_chance"]):
		return
	for x in range(leaf.position.x + 2, leaf.end.x - 2, 3):
		for y in range(leaf.position.y + 2, leaf.end.y - 2, 3):
			# Qualcuna è crollata del tutto: le file non sono più regolari.
			if rng.randf() >= float(data.get("pillar_skip", 0.0)):
				_floor[y * width + x] = 0


static func _center(rect: Rect2i) -> Vector2i:
	return rect.position + rect.size / 2


func _room(rect: Rect2i, far: bool) -> Dictionary:
	return {"center": _center(rect), "radius": maxi(mini(rect.size.x, rect.size.y) / 2 - 1, 0), "rect": rect, "far": far}


## Pavimento in tutto il rettangolo da first a last (compresi).
func _fill(first: Vector2i, last: Vector2i) -> void:
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			_set_floor(Vector2i(x, y))


## Tipo di un rombo delle catacombe; floor: è anche pavimento (le fosse sì, muri e tombe no).
func _set_tile(cell: Vector2i, tile: int, floor := true) -> void:
	if cell.x >= 1 and cell.y >= 1 and cell.x < width - 1 and cell.y < height - 1:
		if floor:
			_floor[cell.y * width + cell.x] = 1
		_tiles[cell.y * width + cell.x] = tile


func _set_floor(cell: Vector2i) -> void:
	if cell.x >= 1 and cell.y >= 1 and cell.x < width - 1 and cell.y < height - 1:
		_floor[cell.y * width + cell.x] = 1
		if is_metro():
			_tiles[cell.y * width + cell.x] = Tile.FLOOR


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
