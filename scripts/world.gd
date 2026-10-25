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
## i salti in aria) e si scende cadendo; anche i nemici scendono dai gradini
## e saltano su quelli alti un livello (vedi Enemy), ma nei burroni non vanno. Sopra ci sono ostacoli naturali: alberi,
## sassi, cespugli, rovi e casse con il bottino. Qua e là ci sono arene: ampie zone piane e
## libere con al centro un totem che avvia una sfida (vedi Game).
## Lunghe catene di montagne e burroni non si attraversano (hanno qualche
## passaggio); nelle pareti delle montagne si aprono caverne che portano a
## un sotterraneo (vedi Dungeon), disegnato con gli stessi blocchi.
##
## Le posizioni di personaggi e oggetti sono a terra (il piano x, y);
## l'altezza del terreno sotto di loro (elevation_at) li disegna più in
## alto. Il terreno viene generato e disegnato a blocchi di rombi attorno
## alla telecamera; i blocchi più alti di quelli dietro vengono disegnati
## tra i personaggi (non col resto del terreno), così coprono chi ci passa
## dietro; quelli che coprono il giocatore, e tutti quelli attorno,
## diventano trasparenti finché resta lì dietro.
##
## Prestazioni: i dati del terreno (livelli, rampe, ostacoli) di una regione
## grande attorno al giocatore sono generati in anticipo (begin_region,
## generate_region); avvicinandosi al bordo Game mette in pausa e genera la
## regione nuova. I pezzi da disegnare vengono creati un po' prima che
## entrino nello schermo, uno per frame, così non ci sono scatti.

const DATA := preload("res://data/world.json")

## Mezza altezza di un rombo della griglia (i rombi sono 128 x 64).
const CELL := 64.0
## Un pezzo di mondo è un quadrato di CHUNK_CELLS x CHUNK_CELLS rombi.
const CHUNK_CELLS := 8
const MAINTAIN_INTERVAL := 0.15
## I pezzi vengono creati quando arrivano a questa distanza dallo schermo
## e tolti quando se ne allontanano di altri KEEP_MARGIN.
const PREFETCH_MARGIN := 380.0
const KEEP_MARGIN := 320.0
## I dati fuori dalla regione si dimenticano solo oltre questi rombi in memoria.
const FORGET_THRESHOLD := 110000
## Blocchi davanti al giocatore: del tutto trasparenti entro OCCLUSION_INNER
## pixel dal suo corpo sullo schermo, di nuovo pieni oltre OCCLUSION_OUTER.
const OCCLUSION_INNER := 150.0
const OCCLUSION_OUTER := 240.0
## Altezza del corpo del giocatore sopra i piedi, dove si misura la distanza.
const OCCLUSION_BODY := 30.0
const OCCLUSION_FADE_SPEED := 5.0
## I blocchi da rendere trasparenti si cercano solo ogni tanto (la
## dissolvenza continua a ogni frame): costa meno e non si nota.
const OCCLUSION_INTERVAL := 0.05
## Solo i blocchi più alti dei piedi di almeno tanto coprono davvero il corpo
## (i gradini bassi restano pieni).
const OCCLUSION_MIN_HEIGHT := 40.0
## Gli ostacoli vengono messi solo in questa parte del rombo, lontano dai bordi.
const PLACE_MIN := 14.0
const PLACE_MAX := 44.0
## Dislivello superato camminando (le rampe salgono un po' alla volta).
const STEP_TOLERANCE := 8.0
## Ostacoli vicinissimi (vedi obstacles_close): quadrati di questo lato,
## ognuno con gli ostacoli che arrivano entro CLOSE_REACH dal quadrato;
## CLOSE_COLLISION_MAX è la collisione più grande di un ostacolo.
const CLOSE_SQUARE := 64.0
const CLOSE_REACH := 48.0
const CLOSE_COLLISION_MAX := 48.0
## Linea di vista (vedi clear_line): passo dei controlli lungo la linea,
## raggio del colpo, quota sopra cui una parete ferma il colpo e differenza
## d'altezza entro cui un ostacolo lo ferma.
const LINE_STEP := 20.0
const LINE_RADIUS := 6.0
const LINE_CLEARANCE := 30.0
const PROJECTILE_HEIGHT_REACH := 70.0
## Coordinate (u, v) dei vertici dentro il rombo: alto, destra, basso, sinistra.
const CORNERS := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
## Direzioni in cui può salire una rampa (verso il rombo vicino più alto).
const RAMP_DIRECTIONS := [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1)]
## Distanza tra le linee degli strati di terra sulle pareti.
const STRATA_STEP := 14.0
const LIP_WIDTH := 5.0

## Tipi di blocco: terreno normale, montagna o burrone (invalicabili) e
## roccia del sotterraneo.
enum Kind { GROUND, MOUNTAIN, RAVINE, ROCK }

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
var _arena: Dictionary = DATA.data["arena"]
## Regione -> centro della sua arena (Vector2.INF se non ce l'ha).
var _arena_cache := {}
var _merchant: Dictionary = DATA.data["merchant"]
## Regione -> posizione del suo mercante (Vector2.INF se non ce l'ha).
var _merchant_cache := {}
## (regione, dimensione) -> arene o mercanti delle regioni attorno.
var _sites_cache := {}
## Mercante -> oggetti rari che ha ancora in vendita.
var _merchant_stocks := {}
## Totem (centro dell'arena) -> stato: "active" durante la sfida, "used" dopo.
var _totem_states := {}
## Casse già aperte (posizione -> true).
var _opened_chests := {}
## Caverne il cui sotterraneo è stato completato (posizione -> true).
var cleared_caves := {}
## Sotterraneo in cui si trova il giocatore (null in superficie).
var dungeon: Dungeon
## Regione pregenerata, in pezzi, e pezzi ancora da generare.
var region := Rect2i()
var _region_queue: Array[Vector2i] = []
var _region_total := 0
## Pezzi da mostrare, il più vicino in fondo: se ne crea uno per frame.
var _view_queue: Array[Vector2i] = []
var _dungeon_data: Dictionary = DATA.data["dungeon"]
var _levels: int
var _height_noise := FastNoiseLite.new()
var _path_noise := FastNoiseLite.new()
var _forest_noise := FastNoiseLite.new()
var _bramble_noise := FastNoiseLite.new()
var _ridge_noise := FastNoiseLite.new()
var _gap_noise := FastNoiseLite.new()
var _barrier_kind_noise := FastNoiseLite.new()
## Dati calcolati per rombo: livello, tipo (Kind), rampa, sentiero.
var _level_cache := {}
var _kind_cache := {}
var _ramp_cache := {}
var _path_cache := {}
## Colori già convertiti dai dati, per disegnare in fretta.
var _grass_colors: Array[Color] = []
var _face_colors: Array[Color] = []
var _mountain_colors: Array[Color] = []
var _mountain_face_colors: Array[Color] = []
var _dungeon_floor_colors: Array[Color] = []
var _dungeon_face_colors: Array[Color] = []
var _pebble_colors: Array[Color] = []
var _flower_colors: Array[Color] = []
var _mushroom_colors: Array[Color] = []
var _path_color: Color
var _lip_color: Color
var _ravine_color: Color
var _dungeon_wall_color: Color
var _tuft_range := Vector2i.ZERO
## Pezzo -> ostacoli (dizionari), generati quando servono.
var _chunk_obstacles := {}
## Rettangolo di pezzi (Vector4i) -> i loro ostacoli in una sola lista (vedi obstacles_near).
var _near_cache := {}
## Quadrato -> ostacoli vicinissimi (vedi obstacles_close).
var _close_cache := {}
## Pezzo -> {"view": nodo del terreno, "nodes": ostacoli e blocchi tra i personaggi}.
var _chunk_views := {}
var _maintain_timer := 0.0
## Ultimo rombo troppo alto che ha fermato un movimento (vedi move).
var _blocking_cell := Vector2i.ZERO
var _has_blocking_cell := false
var _contact_glow := ContactGlow.new()
## Blocchi resi trasparenti perché coprono il giocatore.
var _faded_blocks := {}
## Blocchi che adesso coprono il giocatore (blocco -> true) e attesa prima di
## ricontrollarli.
var _wanted_blocks := {}
var _occlusion_timer := 0.0


func _ready() -> void:
	current = self
	if seed_value == 0:
		seed_value = randi_range(1, 1 << 30)
	_levels = _terrain["levels"]
	level_height = _terrain["level_height"]
	_setup_noises()
	_grass_colors = _colors(_terrain["grass_colors"])
	_face_colors = _colors(_terrain["face_colors"])
	_mountain_colors = _colors(_terrain["mountain_colors"])
	_mountain_face_colors = _colors(_terrain["mountain_face_colors"])
	_dungeon_floor_colors = _colors(_dungeon_data["floor_colors"])
	_dungeon_face_colors = _colors(_dungeon_data["face_colors"])
	_pebble_colors = _colors(_decor["pebble_colors"])
	_flower_colors = _colors(_decor["flower_colors"])
	_mushroom_colors = _colors(_dungeon_data["mushroom_colors"])
	_path_color = _color(_terrain["path_color"])
	_lip_color = _color(_terrain["lip_color"])
	_ravine_color = _color(_terrain["ravine_color"])
	_dungeon_wall_color = _color(_dungeon_data["wall_color"])
	var tufts: Array = _decor["grass_tufts"]
	_tuft_range = Vector2i(tufts[0], tufts[1])
	# I pezzi di terreno si disegnano da dietro in avanti.
	y_sort_enabled = true
	# Dove il terreno non è ancora disegnato si vede il colore dell'erba più bassa.
	RenderingServer.set_default_clear_color(_grass_colors[0].darkened(0.3))


func _exit_tree() -> void:
	if current == self:
		current = null
	if not _contact_glow.is_inside_tree():
		_contact_glow.free()


## Cambia il seme (caricando una partita): rumori nuovi e dati da rifare.
func set_seed(value: int) -> void:
	seed_value = value
	_setup_noises()
	_arena_cache.clear()
	_merchant_cache.clear()
	_sites_cache.clear()
	set_dungeon(dungeon)


func _setup_noises() -> void:
	_setup_noise(_height_noise, 0, _terrain["height_frequency"], _terrain["height_octaves"])
	_setup_noise(_path_noise, 1, _terrain["path_frequency"], 1)
	_setup_noise(_forest_noise, 2, _terrain["forest_frequency"], 2)
	_setup_noise(_bramble_noise, 3, _terrain["bramble_frequency"], 1)
	_setup_noise(_ridge_noise, 4, _terrain["barrier_frequency"], 1)
	_setup_noise(_gap_noise, 5, _terrain["barrier_gap_frequency"], 1)
	_setup_noise(_barrier_kind_noise, 6, _terrain["barrier_kind_frequency"], 1)


## Stato del mondo da salvare: casse aperte, totem usati, scorte dei
## mercanti e caverne completate (le posizioni come coppie di numeri).
func save_state() -> Dictionary:
	var stocks := []
	for merchant: Vector2 in _merchant_stocks:
		stocks.append({"at": SaveGame.array(merchant), "stock": _merchant_stocks[merchant]})
	var totems := []
	for arena: Vector2 in _totem_states:
		# Una sfida interrotta dal salvataggio si potrà rifare.
		if _totem_states[arena] == "used":
			totems.append(SaveGame.array(arena))
	return {
		"chests": _opened_chests.keys().map(SaveGame.array), "totems": totems,
		"stocks": stocks, "caves": cleared_caves.keys().map(SaveGame.array),
	}


func load_state(data: Dictionary) -> void:
	for at: Array in data.get("chests", []):
		_opened_chests[SaveGame.vector(at)] = true
	for at: Array in data.get("totems", []):
		_totem_states[SaveGame.vector(at)] = "used"
	for entry: Dictionary in data.get("stocks", []):
		var stock: Array[String] = []
		stock.assign(entry["stock"])
		_merchant_stocks[SaveGame.vector(entry["at"])] = stock
	for at: Array in data.get("caves", []):
		cleared_caves[SaveGame.vector(at)] = true


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
	# Un pezzo nuovo per frame, il più vicino: niente scatti.
	if not _view_queue.is_empty():
		var chunk: Vector2i = _view_queue.pop_back()
		if not _chunk_views.has(chunk):
			_show_chunk(chunk)
	_update_occlusion(delta)


## I blocchi davanti al giocatore che lo coprirebbero diventano
## trasparenti in tutta la zona attorno a lui: si vede cosa succede dietro
## pareti, muri del sotterraneo e montagne.
func _update_occlusion(delta: float) -> void:
	var hero := player as Player
	if hero == null:
		return
	var feet := hero.position
	var altitude := hero.altitude()
	var body := feet - Vector2(0, altitude + OCCLUSION_BODY)
	_occlusion_timer -= delta
	if _occlusion_timer <= 0.0:
		_occlusion_timer = OCCLUSION_INTERVAL
		_wanted_blocks.clear()
		var center := _chunk_of(cell_at(feet))
		for i in range(-1, 3):
			for j in range(-1, 3):
				var entry: Variant = _chunk_views.get(center + Vector2i(i, j))
				if entry == null:
					continue
				for node: Node in entry["nodes"]:
					var block := node as TerrainBlock
					if block and _covers(block, feet, altitude, body):
						_wanted_blocks[block] = true
	var wanted := _wanted_blocks
	for block: Variant in wanted:
		if is_instance_valid(block):
			_faded_blocks[block] = true
	for key: Variant in _faded_blocks.keys():
		# I blocchi dei pezzi tolti nel frattempo non esistono più.
		if not is_instance_valid(key):
			_faded_blocks.erase(key)
			continue
		var block := key as TerrainBlock
		var target := 0.0
		if not wanted.has(block):
			target = 1.0
		elif OCCLUSION_OUTER > OCCLUSION_INNER:
			target = smoothstep(OCCLUSION_INNER, OCCLUSION_OUTER, _block_distance(block, body))
		block.modulate.a = move_toward(block.modulate.a, target, OCCLUSION_FADE_SPEED * delta)
		if target >= 1.0 and block.modulate.a >= 1.0:
			_faded_blocks.erase(block)


## Il blocco è disegnato dopo il giocatore (gli sta davanti), è più alto
## dei suoi piedi ed è vicino al suo corpo sullo schermo.
func _covers(block: TerrainBlock, feet: Vector2, altitude: float, body: Vector2) -> bool:
	if block.position.y <= feet.y or _top_height(block.cell) < altitude + OCCLUSION_MIN_HEIGHT:
		return false
	return _block_distance(block, body) < OCCLUSION_OUTER


## Distanza sullo schermo tra il punto e la parete del blocco (dalla cima
## alla base, al centro del rombo).
func _block_distance(block: TerrainBlock, point: Vector2) -> float:
	var ground := cell_center(block.cell)
	var top := ground - Vector2(0, _top_height(block.cell))
	var y := clampf(point.y, top.y, ground.y)
	return point.distance_to(Vector2(ground.x, y))


# --- Coordinate --------------------------------------------------------

## Rombo che contiene il punto: gli indici contano le rette y = ±x/2 della griglia.
static func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori((point.y + point.x / 2.0) / CELL), floori((point.y - point.x / 2.0) / CELL))


## Punto del mondo con coordinate u = y + x/2, v = y - x/2.
static func _from_uv(u: float, v: float) -> Vector2:
	return Vector2(u - v, (u + v) / 2.0)


## Coordinate del punto nella griglia dei rombi, con la parte frazionaria
## (il rombo è la parte intera, vedi cell_at).
static func to_grid(point: Vector2) -> Vector2:
	return Vector2((point.y + point.x / 2.0) / CELL, (point.y - point.x / 2.0) / CELL)


static func from_grid(grid: Vector2) -> Vector2:
	return _from_uv(grid.x * CELL, grid.y * CELL)


## Il punto più vicino a point dentro il cerchio di rombi attorno a center
## (raggio in rombi): sullo schermo è un'ellisse, come le caverne del
## sotterraneo (per esempio l'arena del boss).
static func clamp_to_grid_circle(point: Vector2, center: Vector2, radius: float) -> Vector2:
	var origin := to_grid(center)
	var offset := to_grid(point) - origin
	if offset.length() <= radius:
		return point
	return from_grid(origin + offset.limit_length(radius))


## Punto a terra a distanza radius in direzione angle: il terreno isometrico
## schiaccia i cerchi in ellissi (squash: rapporto tra altezza e larghezza,
## come le macchie di GroundFx).
static func ground_ellipse(angle: float, radius: float, squash := GroundFx.GROUND_SQUASH) -> Vector2:
	return Vector2(cos(angle), sin(angle) * squash) * radius


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


static func _colors(list: Array) -> Array[Color]:
	var result: Array[Color] = []
	for values: Array in list:
		result.append(_color(values))
	return result


# --- Terreno -----------------------------------------------------------

## Livello di altezza del blocco (0 = il più basso; le montagne sono più
## alte di tutti gli altri blocchi, i burroni sotto lo zero). Attorno al
## punto di partenza il terreno è piano. Nel sotterraneo il pavimento è al
## livello 0 e la roccia è un blocco alto.
func level_of(cell: Vector2i) -> int:
	var cached: Variant = _level_cache.get(cell)
	if cached != null:
		return cached
	var kind := Kind.GROUND
	var level := 0
	if dungeon:
		if not dungeon.is_floor(cell):
			kind = Kind.ROCK
			level = dungeon.wall_level
	else:
		var center := cell_center(cell)
		var ridge := _barrier_strength(center)
		if ridge > 0.0:
			if _barrier_kind_noise.get_noise_2dv(center) >= 0.0:
				# La montagna sale a gradini verso la cresta.
				kind = Kind.MOUNTAIN
				level = _levels + 1 + mini(floori(ridge * 4.0), 3)
			else:
				kind = Kind.RAVINE
				level = -int(_terrain["ravine_depth"])
		else:
			level = _ground_level(center)
	_kind_cache[cell] = kind
	_level_cache[cell] = level
	return level


func _ground_level(center: Vector2) -> int:
	if center.length() < float(_terrain["start_flat_radius"]):
		center = Vector2.ZERO
	else:
		# Le arene sono tutte allo stesso livello del loro centro.
		var arena := arena_near(center)
		var merchant := merchant_near(center)
		if arena != Vector2.INF and center.distance_to(arena) < float(_arena["radius"]):
			center = arena
		# Anche lo spiazzo del mercante è piano.
		elif merchant != Vector2.INF and center.distance_to(merchant) < float(_merchant["clear_radius"]):
			center = merchant
	var t := _height_noise.get_noise_2dv(center) * float(_terrain["height_contrast"]) * 0.5 + 0.5
	return clampi(floori(t * _levels), 0, _levels - 1)


## Montagne e burroni corrono lungo le linee in cui un rumore vale zero,
## con qualche passaggio; mai vicino alla partenza, alle arene o ai
## mercanti. Restituisce 0 fuori, fino a 1 sulla linea centrale.
func _barrier_strength(center: Vector2) -> float:
	if center.length() < float(_terrain["barrier_start_clear"]):
		return 0.0
	var width := float(_terrain["barrier_width"])
	var ridge := absf(_ridge_noise.get_noise_2dv(center))
	if ridge >= width or _gap_noise.get_noise_2dv(center) > float(_terrain["barrier_gap"]):
		return 0.0
	var arena := arena_near(center)
	if arena != Vector2.INF and center.distance_to(arena) < float(_arena["radius"]) + CELL * 3.0:
		return 0.0
	var merchant := merchant_near(center)
	if merchant != Vector2.INF and center.distance_to(merchant) < float(_merchant["clear_radius"]) + CELL * 3.0:
		return 0.0
	return 1.0 - ridge / width


## Tipo del blocco (vedi Kind).
func kind_of(cell: Vector2i) -> int:
	level_of(cell)
	return _kind_cache[cell]


## Montagne, burroni e roccia del sotterraneo non si attraversano mai.
func is_barrier(cell: Vector2i) -> bool:
	return kind_of(cell) != Kind.GROUND


## Direzione in cui sale la rampa del blocco, o zero se è piano. Una rampa
## collega un blocco piano al vicino più alto di un livello.
func ramp_of(cell: Vector2i) -> Vector2i:
	var cached: Variant = _ramp_cache.get(cell)
	if cached != null:
		return cached
	var result := Vector2i.ZERO
	if dungeon == null and kind_of(cell) == Kind.GROUND:
		var level := level_of(cell)
		var center := cell_center(cell)
		var far_from_start := center.length() > float(_terrain["start_flat_radius"]) + CELL * 2.0
		var arena := arena_near(center)
		var far_from_arena := arena == Vector2.INF or center.distance_to(arena) > float(_arena["radius"]) + CELL * 2.0
		var merchant := merchant_near(center)
		var far_from_merchant := merchant == Vector2.INF or center.distance_to(merchant) > float(_merchant["clear_radius"]) + CELL * 2.0
		if far_from_start and far_from_arena and far_from_merchant and _random_unit([seed_value, cell.x, cell.y, "ramp"]) < float(_terrain["ramp_chance"]):
			for direction: Vector2i in RAMP_DIRECTIONS:
				if level_of(cell + direction) == level + 1 and level_of(cell - direction) == level \
						and kind_of(cell + direction) == Kind.GROUND:
					result = direction
					break
	_ramp_cache[cell] = result
	return result


## Sentiero sterrato: una striscia lungo una curva del rumore, e lo
## spiazzo di terra attorno al totem delle arene e ai mercanti.
func is_path(cell: Vector2i) -> bool:
	var cached: Variant = _path_cache.get(cell)
	if cached != null:
		return cached
	var result := false
	if dungeon == null and kind_of(cell) == Kind.GROUND:
		var center := cell_center(cell)
		var arena := arena_near(center)
		var merchant := merchant_near(center)
		if arena != Vector2.INF and center.distance_to(arena) < float(_arena["plaza_radius"]):
			result = true
		elif merchant != Vector2.INF and center.distance_to(merchant) < float(_merchant["plaza_radius"]):
			result = true
		else:
			result = absf(_path_noise.get_noise_2dv(center)) < float(_terrain["path_width"])
	_path_cache[cell] = result
	return result


# --- Arene con il totem -------------------------------------------------

## Centro dell'arena della regione (le regioni sono quadrati del mondo),
## o Vector2.INF se la regione non ne ha. Lontano dalla partenza.
func _arena_of_region(region: Vector2i) -> Vector2:
	if _arena_cache.has(region):
		return _arena_cache[region]
	var center := Vector2.INF
	var size := float(_arena["region"])
	var margin := float(_arena["radius"]) + CELL * 2.0
	if _random_unit([seed_value, region.x, region.y, "arena"]) < float(_arena["chance"]):
		var offset := Vector2(_random_unit([seed_value, region.x, region.y, "arena_x"]), _random_unit([seed_value, region.x, region.y, "arena_y"]))
		var candidate := Vector2(region) * size + Vector2(margin, margin) + offset * (size - 2.0 * margin)
		if candidate.length() > float(_arena["min_start_distance"]):
			center = candidate
	_arena_cache[region] = center
	return center


## Centro dell'arena che contiene il punto (o la più vicina nelle regioni
## attorno), Vector2.INF se non ce ne sono.
func arena_near(point: Vector2) -> Vector2:
	if dungeon:
		return Vector2.INF
	return _nearest(point, _sites_near(point, float(_arena["region"]), _arena_of_region))


## Posizioni (arene o mercanti) delle regioni attorno al punto: site_of
## dà la posizione nella regione, o Vector2.INF.
func _sites_near(point: Vector2, size: float, site_of: Callable) -> Array[Vector2]:
	var region := Vector2i(floori(point.x / size), floori(point.y / size))
	# Le stesse regioni servono a tutti i rombi vicini: si ricordano.
	var key := Vector3i(region.x, region.y, int(size))
	var cached: Variant = _sites_cache.get(key)
	if cached != null:
		return cached
	var sites: Array[Vector2] = []
	for i in range(-1, 2):
		for j in range(-1, 2):
			var site: Vector2 = site_of.call(region + Vector2i(i, j))
			if site != Vector2.INF:
				sites.append(site)
	_sites_cache[key] = sites
	return sites


static func _nearest(point: Vector2, sites: Array[Vector2]) -> Vector2:
	var best := Vector2.INF
	for site in sites:
		if best == Vector2.INF or point.distance_to(site) < point.distance_to(best):
			best = site
	return best


func arena_radius() -> float:
	return _arena["radius"]


# --- Mercanti ------------------------------------------------------------

## Posizione del mercante della regione, o Vector2.INF se non ce l'ha.
## Lontano dalla partenza e dalle arene.
func _merchant_of_region(region: Vector2i) -> Vector2:
	if _merchant_cache.has(region):
		return _merchant_cache[region]
	var site := Vector2.INF
	var size := float(_merchant["region"])
	var margin := float(_merchant["clear_radius"]) + CELL * 2.0
	if _random_unit([seed_value, region.x, region.y, "merchant"]) < float(_merchant["chance"]):
		var offset := Vector2(_random_unit([seed_value, region.x, region.y, "merchant_x"]), _random_unit([seed_value, region.x, region.y, "merchant_y"]))
		var candidate := Vector2(region) * size + Vector2(margin, margin) + offset * (size - 2.0 * margin)
		var arena := arena_near(candidate)
		if candidate.length() > float(_merchant["min_start_distance"]) \
				and (arena == Vector2.INF or candidate.distance_to(arena) > float(_merchant["arena_distance"])):
			site = candidate
	_merchant_cache[region] = site
	return site


func merchant_near(point: Vector2) -> Vector2:
	if dungeon:
		return Vector2.INF
	return _nearest(point, _sites_near(point, float(_merchant["region"]), _merchant_of_region))


## Mercante toccato da chi sta in point (stesso livello e abbastanza
## vicino): la sua posizione, o Vector2.INF.
func merchant_touched(point: Vector2, reach: float) -> Vector2:
	var merchant := merchant_near(point)
	if merchant == Vector2.INF or point.distance_to(merchant) > reach + float(_merchant["collision"]) \
			or absf(elevation_at(point) - elevation_at(merchant)) > STEP_TOLERANCE:
		return Vector2.INF
	return merchant


## Oggetti rari in vendita dal mercante: scelti a caso la prima volta,
## spariscono quando li si compra (vedi ShopPanel).
func merchant_stock(merchant: Vector2) -> Array[String]:
	if not _merchant_stocks.has(merchant):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, merchant, "stock"])
		var choices := Items.shop_items()
		var count: Array = _merchant["stock"]
		var stock: Array[String] = []
		for i in mini(rng.randi_range(count[0], count[1]), choices.size()):
			stock.append(choices.pop_at(rng.randi_range(0, choices.size() - 1)))
		_merchant_stocks[merchant] = stock
	return _merchant_stocks[merchant]


## Totem toccato da chi sta in point (stesso livello e abbastanza vicino):
## restituisce il centro della sua arena, o Vector2.INF.
func totem_touched(point: Vector2, reach: float) -> Vector2:
	var arena := arena_near(point)
	if arena == Vector2.INF:
		return Vector2.INF
	var totem: Dictionary = _arena["totem"]
	if point.distance_to(arena) > reach + float(totem["collision"]) or absf(elevation_at(point) - elevation_at(arena)) > STEP_TOLERANCE:
		return Vector2.INF
	return arena


## Cassa toccata da chi sta in point: il suo dizionario, o vuoto. Le
## casse già aperte non contano.
func chest_touched(point: Vector2, reach: float) -> Dictionary:
	for obstacle: Dictionary in obstacles_near(point):
		if obstacle["type"] == "chest" and not is_chest_opened(obstacle["position"]) \
				and point.distance_to(obstacle["position"]) <= reach + obstacle["collision"] \
				and absf(elevation_at(point) - obstacle["elevation"]) <= STEP_TOLERANCE:
			return obstacle
	return {}


func is_chest_opened(at: Vector2) -> bool:
	return (dungeon.opened_chests if dungeon else _opened_chests).has(at)


func open_chest(at: Vector2) -> void:
	(dungeon.opened_chests if dungeon else _opened_chests)[at] = true


## Casse, totem, mercanti, caverne e scale nei pezzi di mondo attorno al punto (per la minimappa).
func points_of_interest(center: Vector2, radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var corners := [center + Vector2(-radius, -radius), center + Vector2(radius, radius), center + Vector2(-radius, radius), center + Vector2(radius, -radius)]
	var min_chunk := _chunk_of(cell_at(corners[0]))
	var max_chunk := min_chunk
	for corner: Vector2 in corners:
		var chunk := _chunk_of(cell_at(corner))
		min_chunk = min_chunk.min(chunk)
		max_chunk = max_chunk.max(chunk)
	for i in range(min_chunk.x, max_chunk.x + 1):
		for j in range(min_chunk.y, max_chunk.y + 1):
			for obstacle: Dictionary in _obstacles_of(Vector2i(i, j)):
				if obstacle["type"] in ["chest", "totem", "merchant", "cave", "stairs", "exit"]:
					result.append(obstacle)
	return result


## Colore del terreno nel punto, per la minimappa.
func map_color(point: Vector2) -> Color:
	var cell := cell_at(point)
	return _top_color(cell, kind_of(cell), is_path(cell))


## Stato del totem: "ready", "active" (sfida in corso) o "used".
func totem_state(arena: Vector2) -> String:
	return _totem_states.get(arena, "ready")


func set_totem_state(arena: Vector2, state: String) -> void:
	_totem_states[arena] = state


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
## si viene spinti fuori dagli ostacoli solidi. Con into_ravines = false
## (i nemici) nei burroni non si entra nemmeno potendo scendere.
func move(from: Vector2, motion: Vector2, radius: float, climb := 0.0, can_drop := false, into_ravines := true) -> Vector2:
	_has_blocking_cell = false
	var base := elevation_at(from)
	var to := from + motion
	var drop_ravine := can_drop and into_ravines
	if not _can_pass(from, base, to, radius, climb, can_drop, drop_ravine):
		var along_x := from + Vector2(motion.x, 0.0)
		var along_y := from + Vector2(0.0, motion.y)
		if _can_pass(from, base, along_x, radius, climb, can_drop, drop_ravine):
			to = along_x
		elif _can_pass(from, base, along_y, radius, climb, can_drop, drop_ravine):
			to = along_y
		else:
			to = from
	var pushed := _push_out(to, radius)
	if pushed != to and _can_pass(from, base, pushed, radius, climb, can_drop, drop_ravine):
		to = pushed
	return to


## Si controlla il punto d'arrivo e un punto poco più avanti, così ci si
## ferma un po' prima del bordo di un gradino (base: altezza di partenza).
func _can_pass(from: Vector2, base: float, to: Vector2, radius: float, climb: float, can_drop: bool, drop_ravine: bool) -> bool:
	if to == from:
		return true
	return _can_stand(to, base, climb, can_drop, drop_ravine) \
			and _can_stand(to + (to - from).normalized() * radius * 0.5, base, climb, can_drop, drop_ravine)


func _can_stand(probe: Vector2, base: float, climb: float, can_drop: bool, drop_ravine: bool) -> bool:
	var cell := cell_at(probe)
	# Nei burroni ci si può cadere (chi può scendere dai gradini, salvo i
	# nemici) o passarci sopra saltando; montagne e roccia fermano sempre.
	if is_barrier(cell) and not (drop_ravine and kind_of(cell) == Kind.RAVINE):
		# Montagne e roccia si illuminano; nei burroni non c'è niente da illuminare.
		_blocking_cell = cell
		_has_blocking_cell = kind_of(cell) != Kind.RAVINE
		return false
	var height := elevation_at(probe)
	if height > base + climb + STEP_TOLERANCE:
		_blocking_cell = cell
		_has_blocking_cell = true
		return false
	if not can_drop and height < base - STEP_TOLERANCE:
		return false
	return true


func _push_out(point: Vector2, radius: float) -> Vector2:
	for obstacle: Dictionary in obstacles_close(point):
		if not obstacle["solid"]:
			continue
		var offset: Vector2 = point - obstacle["position"]
		var minimum: float = radius + obstacle["collision"]
		if offset.length() < minimum:
			point = obstacle["position"] + (offset.normalized() if offset != Vector2.ZERO else Vector2.DOWN) * minimum
	return point


## Illumina per un attimo quello che chi si muove in point (all'altezza
## altitude) sta toccando: gli ostacoli solidi si schiariscono da soli (vedi
## Obstacle.flash), del blocco di terreno troppo alto (incontrato
## dall'ultima chiamata a move) si accende solo il tratto di superficie
## toccato. Niente contorni né riquadri attorno. Da chiamare subito dopo move.
func highlight_contacts(point: Vector2, radius: float, altitude: float) -> void:
	if entities == null:
		return
	for obstacle: Dictionary in obstacles_close(point):
		var center: Vector2 = obstacle["position"]
		if obstacle["solid"] and point.distance_to(center) <= radius + obstacle["collision"] + 1.5:
			var node: Variant = obstacle.get("node")
			if node != null and is_instance_valid(node):
				(node as Obstacle).flash()
	if _has_blocking_cell:
		var corners := cell_corners(_blocking_cell)
		var best := 0
		var best_distance := INF
		for k in 4:
			var distance := Geometry2D.get_closest_point_to_segment(point, corners[k], corners[(k + 1) % 4]).distance_to(point)
			if distance < best_distance:
				best = k
				best_distance = distance
		_show_contacts()
		_contact_glow.touch_wall(_blocking_cell, best, point, altitude)


func _show_contacts() -> void:
	if not _contact_glow.is_inside_tree():
		entities.add_child(_contact_glow)


## Ostacoli dei pezzi di mondo attorno al punto (entro 60 pixel), da non
## modificare. È chiamata di continuo da tutti i personaggi: lontano dai
## bordi dei pezzi restituisce la lista del pezzo stesso, vicino ai bordi
## quella dei pezzi attorno, unita una volta sola e poi ricordata.
func obstacles_near(point: Vector2) -> Array:
	var low := _chunk_of(cell_at(point))
	var high := low
	for offset: Vector2 in [Vector2(-60, 0), Vector2(60, 0), Vector2(0, -60), Vector2(0, 60)]:
		var chunk := _chunk_of(cell_at(point + offset))
		low = low.min(chunk)
		high = high.max(chunk)
	if low == high:
		return _obstacles_of(low)
	var key := Vector4i(low.x, low.y, high.x, high.y)
	if not _near_cache.has(key):
		var result := []
		for i in range(low.x, high.x + 1):
			for j in range(low.y, high.y + 1):
				result.append_array(_obstacles_of(Vector2i(i, j)))
		_near_cache[key] = result
	return _near_cache[key]


## Ostacoli che possono toccare chi sta in point con un raggio fino a
## CLOSE_REACH: una lista breve per i controlli fatti a ogni passo
## (spinta fuori dagli ostacoli, rallentamenti), da non modificare.
func obstacles_close(point: Vector2) -> Array:
	var key := Vector2i((point / CLOSE_SQUARE).floor())
	if _close_cache.has(key):
		return _close_cache[key]
	var square := Rect2(Vector2(key) * CLOSE_SQUARE, Vector2(CLOSE_SQUARE, CLOSE_SQUARE))
	var area := square.grow(CLOSE_REACH + CLOSE_COLLISION_MAX)
	var low := _chunk_of(cell_at(area.position))
	var high := low
	for corner: Vector2 in [area.position + Vector2(area.size.x, 0), area.position + Vector2(0, area.size.y), area.end]:
		var chunk := _chunk_of(cell_at(corner))
		low = low.min(chunk)
		high = high.max(chunk)
	var result := []
	for i in range(low.x, high.x + 1):
		for j in range(low.y, high.y + 1):
			for obstacle: Dictionary in _obstacles_of(Vector2i(i, j)):
				var at: Vector2 = obstacle["position"]
				var closest := at.clamp(square.position, square.end)
				if at.distance_to(closest) <= CLOSE_REACH + float(obstacle["collision"]):
					result.append(obstacle)
	_close_cache[key] = result
	return result


## Un colpo che vola a quota altitude (altezza del terreno da cui parte)
## si ferma in point: montagna o roccia, un terreno più alto di altitude +
## clearance (una parete), o un ostacolo solido a quella quota.
func blocks_projectile(point: Vector2, altitude: float, clearance: float, radius: float) -> bool:
	var kind := kind_of(cell_at(point))
	if kind == Kind.MOUNTAIN or kind == Kind.ROCK:
		return true
	if elevation_at(point) > altitude + clearance:
		return true
	for obstacle: Dictionary in obstacles_close(point):
		if obstacle["solid"] and point.distance_to(obstacle["position"]) < radius + float(obstacle["collision"]) \
				and absf(float(obstacle["elevation"]) - altitude) < PROJECTILE_HEIGHT_REACH:
			return true
	return false


## Da from si vede to (niente pareti, montagne, roccia o ostacoli solidi in
## mezzo) per un colpo a quota altitude: serve per mirare, agganciare e
## cercare bersagli solo dove un colpo potrebbe arrivare. I due estremi
## sono esclusi (chi tira e chi è bersaglio).
func clear_line(from: Vector2, to: Vector2, altitude: float, clearance := LINE_CLEARANCE) -> bool:
	var length := from.distance_to(to)
	var steps := int(length / LINE_STEP)
	for k in range(1, steps):
		var point := from.lerp(to, float(k) / steps)
		if blocks_projectile(point, altitude, clearance, LINE_RADIUS):
			return false
	return true


## Ostacolo non solido (cespuglio, rovi) su cui si trova il punto, quello
## che rallenta di più; vuoto se non ce ne sono.
func ground_obstacle_at(point: Vector2, radius: float) -> Dictionary:
	var found := {}
	for obstacle: Dictionary in obstacles_close(point):
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
		var free := not is_barrier(cell_at(candidate)) and absf(elevation_at(candidate + Vector2(radius, 0)) - height) < STEP_TOLERANCE \
				and absf(elevation_at(candidate - Vector2(radius, 0)) - height) < STEP_TOLERANCE
		for obstacle: Dictionary in obstacles_near(candidate):
			if candidate.distance_to(obstacle["position"]) < radius + obstacle["collision"] + 8.0:
				free = false
				break
		if free:
			return candidate
	return point


## Il punto più vicino (cercando a spirale) in cui si può stare: per
## esempio quando un salvataggio cade dentro una montagna.
func safe_position_near(point: Vector2) -> Vector2:
	for ring in range(1, 40):
		for k in ring * 6:
			var candidate := point + Vector2.from_angle(TAU * k / (ring * 6)) * ring * CELL * 0.5
			if not is_barrier(cell_at(candidate)) and ground_obstacle_at(candidate, 20.0).is_empty():
				return free_position_near(candidate, 22.0)
	return point


# --- Generazione degli ostacoli ---------------------------------------

func _obstacles_of(chunk: Vector2i) -> Array:
	if not _chunk_obstacles.has(chunk):
		_chunk_obstacles[chunk] = _generate_obstacles(chunk)
	return _chunk_obstacles[chunk]


func _generate_obstacles(chunk: Vector2i) -> Array:
	if dungeon:
		return _dungeon_obstacles(chunk)
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
	# Una cassa vicino alla partenza, per scoprirle subito.
	var start_chest_data: Array = _terrain["start_chest"]
	var start_chest := Vector2(start_chest_data[0], start_chest_data[1])
	if _chunk_of(cell_at(start_chest)) == chunk:
		var chest: Dictionary = _obstacle_types["chest"]
		result.append({
			"type": "chest", "position": start_chest, "elevation": elevation_at(start_chest), "radius": 18.0,
			"collision": 18.0 * float(chest["collision"]), "solid": true, "slow": 1.0, "damage": 0,
			"damage_interval": 0.0, "variant": 1,
		})
	# Il totem al centro dell'arena e il banco del mercante sono ostacoli
	# solidi del pezzo che li contiene.
	var chunk_center := _from_uv((chunk.x + 0.5) * CHUNK_CELLS * CELL, (chunk.y + 0.5) * CHUNK_CELLS * CELL)
	var totem: Dictionary = _arena["totem"]
	for arena in _sites_near(chunk_center, float(_arena["region"]), _arena_of_region):
		if _chunk_of(cell_at(arena)) == chunk:
			result.append(_site_obstacle("totem", arena, totem["radius"], totem["collision"]))
	for merchant in _sites_near(chunk_center, float(_merchant["region"]), _merchant_of_region):
		if _chunk_of(cell_at(merchant)) == chunk:
			result.append(_site_obstacle("merchant", merchant, _merchant["radius"], _merchant["collision"]))
	# Ingresso di una caverna: niente ostacoli davanti.
	var cave := _cave_in_chunk(chunk)
	if not cave.is_empty():
		result = result.filter(func(obstacle: Dictionary) -> bool:
			return obstacle["position"].distance_to(cave["position"]) > 90.0)
		result.append(cave)
	return result


func _site_obstacle(type_id: String, at: Vector2, radius: float, collision: float) -> Dictionary:
	return {
		"type": type_id, "position": at, "elevation": elevation_at(at), "radius": radius,
		"collision": collision, "solid": true, "slow": 1.0, "damage": 0,
		"damage_interval": 0.0, "variant": 0,
	}


## Sceglie quale ostacolo mettere sul blocco (o nessuno), con probabilità
## che dipendono dalla zona: boschi, macchie di rovi, alture, bordi dei gradini.
func _pick_obstacle(cell: Vector2i, rng: RandomNumberGenerator) -> String:
	var center := cell_center(cell)
	if center.length() < float(_terrain["start_clear_radius"]) or kind_of(cell) != Kind.GROUND \
			or is_path(cell) or ramp_of(cell) != Vector2i.ZERO:
		return ""
	var arena := arena_near(center)
	if arena != Vector2.INF and center.distance_to(arena) < float(_arena["radius"]) + CELL:
		return ""
	var merchant := merchant_near(center)
	if merchant != Vector2.INF and center.distance_to(merchant) < float(_merchant["clear_radius"]) + CELL:
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


# --- Regione pregenerata e pezzi di mondo attorno alla telecamera -------

## Prepara la regione pregenerata attorno al punto (nel sotterraneo, tutto
## il sotterraneo): dimentica i dati fuori e mette in coda i pezzi ancora
## da generare, dal più vicino. Poi si chiama generate_region finché
## is_region_ready.
func begin_region(point: Vector2) -> void:
	var center := _chunk_of(cell_at(point))
	if dungeon:
		region = dungeon.chunk_rect()
	else:
		var radius := int(_terrain["pregen_radius"])
		region = Rect2i(center - Vector2i(radius, radius), Vector2i(radius * 2 + 1, radius * 2 + 1))
	if _level_cache.size() > FORGET_THRESHOLD:
		_forget_outside(region.grow(2))
	_region_queue.clear()
	for i in range(region.position.x, region.end.x):
		for j in range(region.position.y, region.end.y):
			if not _chunk_obstacles.has(Vector2i(i, j)):
				_region_queue.append(Vector2i(i, j))
	# Si prendono dalla fine: i più vicini per ultimi nella lista.
	_region_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(center) > b.distance_squared_to(center))
	_region_total = _region_queue.size()


## Genera pezzi della regione per al più budget_usec microsecondi.
## Restituisce l'avanzamento, da 0 a 1.
func generate_region(budget_usec: int) -> float:
	var start := Time.get_ticks_usec()
	while not _region_queue.is_empty() and Time.get_ticks_usec() - start < budget_usec:
		_obstacles_of(_region_queue.pop_back())
	return 1.0 if _region_total == 0 else 1.0 - float(_region_queue.size()) / _region_total


func is_region_ready() -> bool:
	return _region_queue.is_empty()


## Vicino al bordo della regione pregenerata: è ora di generarne un'altra.
func near_region_edge(point: Vector2) -> bool:
	if dungeon:
		return false
	return not region.grow(-int(_terrain["pregen_edge"])).has_point(_chunk_of(cell_at(point)))


## Dimentica i dati del terreno fuori dal rettangolo di pezzi (ma non quelli
## dei pezzi mostrati).
func _forget_outside(keep: Rect2i) -> void:
	for chunk: Vector2i in _chunk_obstacles.keys():
		if not keep.has_point(chunk) and not _chunk_views.has(chunk):
			_chunk_obstacles.erase(chunk)
	_near_cache.clear()
	_close_cache.clear()
	for cache: Dictionary in [_level_cache, _ramp_cache, _path_cache, _kind_cache]:
		for cell: Vector2i in cache.keys():
			if not keep.has_point(_chunk_of(cell)):
				cache.erase(cell)


## Mostra subito tutti i pezzi attorno alla telecamera (all'avvio o dopo un
## salto lontano), senza aspettare un pezzo per frame.
func refresh_now() -> void:
	# La telecamera può non aver ancora raggiunto il giocatore appena spostato.
	var camera := get_viewport().get_camera_2d()
	if camera:
		camera.force_update_scroll()
	_update_chunks()
	while not _view_queue.is_empty():
		var chunk: Vector2i = _view_queue.pop_back()
		if not _chunk_views.has(chunk):
			_show_chunk(chunk)


## Pezzi da mostrare: quelli sullo schermo più un margine, così sono pronti
## prima di entrare nell'inquadratura; i pezzi ben fuori vengono tolti.
func _update_chunks() -> void:
	var camera := get_viewport().get_camera_2d()
	var center := camera.get_screen_center_position() if camera else Vector2.ZERO
	var view := _view_rect(PREFETCH_MARGIN)
	var keep := _view_rect(PREFETCH_MARGIN + KEEP_MARGIN)
	var corners := [view.position, view.end, Vector2(view.position.x, view.end.y), Vector2(view.end.x, view.position.y)]
	var min_chunk := _chunk_of(cell_at(corners[0]))
	var max_chunk := min_chunk
	for corner: Vector2 in corners:
		var chunk := _chunk_of(cell_at(corner))
		min_chunk = min_chunk.min(chunk)
		max_chunk = max_chunk.max(chunk)
	_view_queue.clear()
	for i in range(min_chunk.x, max_chunk.x + 1):
		for j in range(min_chunk.y, max_chunk.y + 1):
			var chunk := Vector2i(i, j)
			# I pezzi negli angoli del rettangolo (u, v) sono fuori dallo schermo.
			if not _chunk_views.has(chunk) and _chunk_bounds(chunk).intersects(view):
				_view_queue.append(chunk)
	# Si prendono dalla fine: i più vicini al centro dello schermo per primi.
	_view_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _chunk_bounds(a).get_center().distance_squared_to(center) > _chunk_bounds(b).get_center().distance_squared_to(center))
	for chunk: Vector2i in _chunk_views.keys():
		if not _chunk_bounds(chunk).intersects(keep):
			_hide_chunk(chunk)


## Rettangolo dello schermo allargato di margin; sotto serve più margine
## perché i blocchi alti salgono verso l'alto.
func _view_rect(margin: float) -> Rect2:
	var camera := get_viewport().get_camera_2d()
	var center := camera.get_screen_center_position() if camera else Vector2.ZERO
	var zoom := camera.zoom if camera else Vector2.ONE
	var half := get_viewport_rect().size / zoom / 2.0 + Vector2(margin, margin)
	return Rect2(center - half, half * 2.0).grow_side(SIDE_BOTTOM, _max_level() * level_height)


## Livello più alto possibile: le cime delle montagne o la roccia del sotterraneo.
func _max_level() -> int:
	return dungeon.wall_level if dungeon else _levels + 4


func _chunk_bounds(chunk: Vector2i) -> Rect2:
	var u := chunk.x * CHUNK_CELLS * CELL
	var v := chunk.y * CHUNK_CELLS * CELL
	var size := CHUNK_CELLS * CELL
	var bounds := Rect2(_from_uv(u, v), Vector2.ZERO)
	for corner: Vector2 in [_from_uv(u + size, v), _from_uv(u + size, v + size), _from_uv(u, v + size)]:
		bounds = bounds.expand(corner)
	return bounds.grow_side(SIDE_TOP, _max_level() * level_height)


func _show_chunk(chunk: Vector2i) -> void:
	var view := ChunkView.new()
	view.world = self
	view.chunk = chunk
	view.position = _from_uv(chunk.x * CHUNK_CELLS * CELL, chunk.y * CHUNK_CELLS * CELL)
	add_child(view)
	var nodes: Array[Node] = []
	if entities:
		for data: Dictionary in _obstacles_of(chunk):
			nodes.append(_make_obstacle_node(data))
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
	# Da dietro in avanti: prima i rombi con u + v più piccolo. I blocchi che
	# coprono chi sta dietro li disegna il loro TerrainBlock, tra i personaggi;
	# qui sotto resta il pavimento da cui salgono, che si vede quando il
	# blocco diventa trasparente (vedi _update_occlusion).
	for depth in 2 * CHUNK_CELLS - 1:
		for i in range(maxi(0, depth - CHUNK_CELLS + 1), mini(depth, CHUNK_CELLS - 1) + 1):
			var cell := chunk * CHUNK_CELLS + Vector2i(i, depth - i)
			if entities == null or not _covers_behind(cell):
				draw_cell(canvas, cell, offset)
			else:
				draw_floor(canvas, cell, offset)


## Pavimento sotto un blocco che copre chi sta dietro: il rombo piano
## all'altezza del vicino dietro più basso (dove sta chi viene coperto), con
## le sue pareti verso i vicini davanti. Di solito è nascosto dal blocco.
func draw_floor(canvas: CanvasItem, cell: Vector2i, offset: Vector2) -> void:
	var base := _top_height(cell)
	for step: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
		base = minf(base, _top_height(cell + step))
	var corners := cell_corners(cell)
	var heights: Array[float] = [base, base, base, base]
	var top := PackedVector2Array()
	for k in 4:
		corners[k] += offset
		top.append(corners[k] - Vector2(0, base))
	var kind := kind_of(cell)
	var faces := _face_colors_of(kind)
	_draw_face(canvas, corners, heights, cell + Vector2i(1, 0), 1, 2, 0, 3, faces[0], false)
	_draw_face(canvas, corners, heights, cell + Vector2i(0, 1), 2, 3, 1, 0, faces[1], false)
	canvas.draw_colored_polygon(top, _top_color(cell, kind, is_path(cell)).darkened(0.15))


## Un blocco: pareti davanti (dove il vicino è più basso) e faccia
## superiore, piana o inclinata, del colore del suo tipo.
func draw_cell(canvas: CanvasItem, cell: Vector2i, offset: Vector2) -> void:
	var corners := cell_corners(cell)
	var heights: Array[float] = []
	var top := PackedVector2Array()
	for k in 4:
		heights.append(corner_height(cell, k))
		corners[k] += offset
		top.append(corners[k] - Vector2(0, heights[k]))
	var kind := kind_of(cell)
	# Parete destra (lato destra-basso, vicino (u+1, v)) e sinistra (lato
	# basso-sinistra, vicino (u, v+1)): i vertici combaciano con quelli del vicino.
	var faces := _face_colors_of(kind)
	var lip := kind == Kind.GROUND and dungeon == null
	_draw_face(canvas, corners, heights, cell + Vector2i(1, 0), 1, 2, 0, 3, faces[0], lip)
	_draw_face(canvas, corners, heights, cell + Vector2i(0, 1), 2, 3, 1, 0, faces[1], lip)

	var path := is_path(cell)
	var color := _top_color(cell, kind, path)
	var ramp := ramp_of(cell)
	if ramp != Vector2i.ZERO:
		# Le rampe che salgono verso il fondo sono in ombra, le altre in luce.
		color = color.darkened(0.12) if ramp.x + ramp.y < 0 else color.lightened(0.08)
	canvas.draw_colored_polygon(top, color)
	if ramp != Vector2i.ZERO:
		_draw_ramp_lines(canvas, top, ramp, color)
	_draw_decor(canvas, cell, offset, kind, path)


func _top_color(cell: Vector2i, kind: int, path: bool) -> Color:
	match kind:
		Kind.MOUNTAIN:
			return _mountain_colors[clampi(level_of(cell) - _levels - 1, 0, _mountain_colors.size() - 1)]
		Kind.RAVINE:
			return _ravine_color
		Kind.ROCK:
			return _dungeon_wall_color
	if dungeon:
		return _dungeon_floor_colors[posmod(hash([cell.x, cell.y]), _dungeon_floor_colors.size())]
	return _path_color if path else _grass_colors[clampi(level_of(cell), 0, _levels - 1)]


func _face_colors_of(kind: int) -> Array[Color]:
	if kind == Kind.MOUNTAIN:
		return _mountain_face_colors
	if dungeon:
		return _dungeon_face_colors
	return _face_colors


func _draw_face(canvas: CanvasItem, corners: PackedVector2Array, heights: Array[float], other: Vector2i,
		first: int, second: int, other_first: int, other_second: int, color: Color, lip: bool) -> void:
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
	# Strati della roccia o della terra, tutti in una sola chiamata.
	var strata := PackedVector2Array()
	var depth := STRATA_STEP
	while depth < maxf(top_a - bottom_a, top_b - bottom_b) - 4.0:
		strata.append(a - Vector2(0, top_a - minf(depth, top_a - bottom_a)))
		strata.append(b - Vector2(0, top_b - minf(depth, top_b - bottom_b)))
		depth += STRATA_STEP
	if not strata.is_empty():
		canvas.draw_multiline(strata, color.darkened(0.18), 1.5)
	if lip:
		# Bordo d'erba che sporge in cima.
		var lip_a := minf(LIP_WIDTH, top_a - bottom_a)
		var lip_b := minf(LIP_WIDTH, top_b - bottom_b)
		var lip_points := PackedVector2Array([a - Vector2(0, top_a), b - Vector2(0, top_b)])
		if lip_b > 0.5:
			lip_points.append(b - Vector2(0, top_b - lip_b))
		if lip_a > 0.5:
			lip_points.append(a - Vector2(0, top_a - lip_a))
		if lip_points.size() >= 3:
			canvas.draw_colored_polygon(lip_points, _lip_color)
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
	var lines := PackedVector2Array()
	for k in range(1, 4):
		var t := k / 4.0
		lines.append((low[0] as Vector2).lerp(high[0], t))
		lines.append((low[1] as Vector2).lerp(high[1], t))
	canvas.draw_multiline(lines, color.darkened(0.15), 1.5)


## Ciuffi d'erba e fiori sui blocchi d'erba, sassolini sui sentieri e nel
## sotterraneo (dove crescono anche funghi luminosi): solo decorazione.
func _draw_decor(canvas: CanvasItem, cell: Vector2i, offset: Vector2, kind: int, path: bool) -> void:
	if kind != Kind.GROUND:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_decor_seed(), cell.x, cell.y, "decor"])
	if path or dungeon:
		for k in rng.randi_range(2, 4):
			var at := _decor_point(cell, rng, offset)
			canvas.draw_circle(at, rng.randf_range(1.5, 3.0), _pebble_colors[k % _pebble_colors.size()])
		if dungeon and rng.randf() < float(_dungeon_data["mushroom_chance"]):
			var at := _decor_point(cell, rng, offset)
			var glow := _mushroom_colors[rng.randi() % _mushroom_colors.size()]
			canvas.draw_circle(at, 7.0, Color(glow, 0.25))
			canvas.draw_line(at, at + Vector2(0, -5), Color(0.8, 0.8, 0.75), 2.0)
			canvas.draw_circle(at + Vector2(0, -6), 3.5, glow)
		return
	var grass := _grass_colors[clampi(level_of(cell), 0, _levels - 1)].darkened(0.3)
	var tufts := PackedVector2Array()
	for k in rng.randi_range(_tuft_range.x, _tuft_range.y):
		var at := _decor_point(cell, rng, offset)
		tufts.append_array([at, at + Vector2(-4, -7), at, at + Vector2(0, -9), at, at + Vector2(4, -7)])
	if not tufts.is_empty():
		canvas.draw_multiline(tufts, grass, 1.5)
	if rng.randf() < float(_decor["flower_chance"]):
		var color := _flower_colors[rng.randi() % _flower_colors.size()]
		var at := _decor_point(cell, rng, offset)
		for k in 3:
			canvas.draw_circle(at + Vector2.from_angle(k * TAU / 3.0) * 3.0, 2.5, color)
		canvas.draw_circle(at, 1.5, Color(0.95, 0.8, 0.3))


## Punto a caso sulla faccia superiore del blocco, lontano dai bordi.
func _decor_point(cell: Vector2i, rng: RandomNumberGenerator, offset: Vector2) -> Vector2:
	var ground := _from_uv(cell.x * CELL + rng.randf_range(10.0, 54.0), cell.y * CELL + rng.randf_range(10.0, 54.0))
	return ground + offset - Vector2(0, elevation_at(ground))


# --- Sotterraneo -------------------------------------------------------

## Entra nel sotterraneo (o torna in superficie con null): il terreno
## cambia del tutto, quindi si buttano pezzi mostrati e dati calcolati.
## Poi va chiamato begin_region.
func set_dungeon(value: Dungeon) -> void:
	dungeon = value
	for chunk: Vector2i in _chunk_views.keys():
		_hide_chunk(chunk)
	_view_queue.clear()
	_faded_blocks.clear()
	_chunk_obstacles.clear()
	_near_cache.clear()
	_close_cache.clear()
	for cache: Dictionary in [_level_cache, _ramp_cache, _path_cache, _kind_cache]:
		cache.clear()
	region = Rect2i()
	var ground := _dungeon_wall_color if dungeon else _grass_colors[0].darkened(0.3)
	RenderingServer.set_default_clear_color(ground)


## Seme della decorazione e degli ostacoli: in superficie quello del
## mondo, nel sotterraneo quello del piano.
func _decor_seed() -> int:
	return dungeon.seed_value if dungeon else seed_value


func _dungeon_obstacles(chunk: Vector2i) -> Array:
	var result: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	var chance := float(_dungeon_data["stalagmite_chance"])
	var rock: Dictionary = _obstacle_types["rock"]
	var radius_range: Array = rock["radius"]
	for i in CHUNK_CELLS:
		for j in CHUNK_CELLS:
			var cell := chunk * CHUNK_CELLS + Vector2i(i, j)
			if not dungeon.is_open(cell):
				continue
			rng.seed = hash([dungeon.seed_value, cell.x, cell.y, "rock"])
			if rng.randf() >= chance:
				continue
			var radius := rng.randf_range(radius_range[0], radius_range[1])
			var spot := _from_uv(cell.x * CELL + rng.randf_range(PLACE_MIN, PLACE_MAX), cell.y * CELL + rng.randf_range(PLACE_MIN, PLACE_MAX))
			result.append({
				"type": "rock", "position": spot, "elevation": 0.0, "radius": radius,
				"collision": radius * float(rock["collision"]), "solid": true, "slow": 1.0, "damage": 0,
				"damage_interval": 0.0, "variant": rng.randi(),
			})
	# Passaggi nelle pareti: verso la superficie (all'arrivo) e verso il
	# piano sotto; poi le casse.
	for special: Array in [["exit", dungeon.arrival, dungeon.arrival_side], ["stairs", dungeon.stairs, dungeon.stairs_side]]:
		var cell: Vector2i = special[1]
		if cell.x >= 0 and _chunk_of(cell) == chunk:
			result.append(make_wall_obstacle(special[0], cell, special[2]))
	for chest in dungeon.chests:
		if _chunk_of(chest) == chunk:
			result.append(make_obstacle("chest", cell_center(chest)))
	return result


## Passaggio in una parete (caverna, scale, uscita): sul lato side del
## rombo (verso la roccia), poco davanti alla parete, con la sua direzione.
func make_wall_obstacle(type_id: String, cell: Vector2i, side: Vector2i) -> Dictionary:
	var corners := cell_corners(cell)
	var a := corners[0]
	var b := corners[3] if side == Vector2i(-1, 0) else corners[1]
	var data := make_obstacle(type_id, _wall_mouth(cell, side))
	data["edge"] = (b - a).normalized()
	return data


func _wall_mouth(cell: Vector2i, side: Vector2i) -> Vector2:
	var corners := cell_corners(cell)
	var b := corners[3] if side == Vector2i(-1, 0) else corners[1]
	return ((corners[0] + b) / 2.0).lerp(cell_center(cell), 0.25)


## Punto davanti a un passaggio nella parete, a quella distanza dal centro
## del rombo: è lì che si arriva.
func in_front_of_wall(cell: Vector2i, side: Vector2i, distance: float) -> Vector2:
	var center := cell_center(cell)
	return center + (center - _wall_mouth(cell, side)).normalized() * distance


## Ostacolo speciale (cassa, caverna, scale, uscita) al punto dato, con le
## dimensioni del suo tipo in data/world.json.
func make_obstacle(type_id: String, at: Vector2) -> Dictionary:
	var type: Dictionary = _obstacle_types[type_id]
	var radius := float((type["radius"] as Array)[0])
	return {
		"type": type_id, "position": at, "elevation": elevation_at(at), "radius": radius,
		"collision": radius * float(type["collision"]), "solid": type["solid"], "slow": 1.0, "damage": 0,
		"damage_interval": 0.0, "variant": 1,
	}


## Aggiunge un ostacolo durante il gioco (per esempio l'uscita che compare
## dopo il boss), anche nel pezzo già mostrato.
func add_obstacle(data: Dictionary) -> void:
	var chunk := _chunk_of(cell_at(data["position"]))
	_obstacles_of(chunk).append(data)
	_near_cache.clear()
	_close_cache.clear()
	if _chunk_views.has(chunk) and entities:
		var node := _make_obstacle_node(data)
		_chunk_views[chunk]["nodes"].append(node)


func _make_obstacle_node(data: Dictionary) -> Obstacle:
	var obstacle := Obstacle.new()
	var type: Dictionary = _obstacle_types.get(data["type"], {})
	match data["type"]:
		"totem":
			type = _arena["totem"]
		"merchant":
			type = _merchant
	obstacle.setup(data, type)
	data["node"] = obstacle
	entities.add_child(obstacle)
	return obstacle


## Ostacolo di quel tipo toccato da chi sta in point (stesso livello e
## abbastanza vicino): il suo dizionario, o vuoto.
func touched(type_id: String, point: Vector2, reach: float) -> Dictionary:
	for obstacle: Dictionary in obstacles_near(point):
		if obstacle["type"] == type_id and point.distance_to(obstacle["position"]) <= reach + obstacle["collision"] \
				and absf(elevation_at(point) - obstacle["elevation"]) <= STEP_TOLERANCE:
			return obstacle
	return {}


## Caverne il cui sotterraneo è già stato completato: l'ingresso è chiuso.
func is_cave_cleared(at: Vector2) -> bool:
	return cleared_caves.has(at)


## Davanti al blocco non c'è niente di più alto che possa coprire
## l'ingresso di una caverna.
func _open_in_front(cell: Vector2i) -> bool:
	var level := level_of(cell)
	for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		if level_of(cell + step) > level:
			return false
	return true


## Ingresso di una caverna nella parete di una montagna, in un blocco
## d'erba (o di sentiero) davanti alla parete; al più uno per pezzo.
func _cave_in_chunk(chunk: Vector2i) -> Dictionary:
	var chance := float(_terrain["cave_chance"])
	for i in CHUNK_CELLS:
		for j in CHUNK_CELLS:
			var cell := chunk * CHUNK_CELLS + Vector2i(i, j)
			if kind_of(cell) != Kind.GROUND or ramp_of(cell) != Vector2i.ZERO or not _open_in_front(cell):
				continue
			for side: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1)]:
				# Un tratto dritto di parete: montagna dietro e ai due lati.
				var along := Vector2i(side.y, side.x)
				if kind_of(cell + side) != Kind.MOUNTAIN or kind_of(cell + side + along) != Kind.MOUNTAIN \
						or kind_of(cell + side - along) != Kind.MOUNTAIN \
						or _random_unit([seed_value, cell.x, cell.y, side.x, "cave"]) >= chance:
					continue
				# La parete della montagna è il lato del blocco che dà sulla montagna.
				return make_wall_obstacle("cave", cell, side)
	return {}


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


## Luce sul tratto di blocco di terreno contro cui il giocatore sbatte
## (vedi highlight_contacts): solo sulla superficie del blocco, più forte
## nel punto toccato e sfumata verso i lati; dura un attimo e svanisce. Se
## il lato toccato è una parete visibile (davanti) si accende la parete,
## altrimenti il bordo della faccia superiore lungo quel lato.
class ContactGlow:
	extends Node2D

	const HOLD := 0.3
	## Mezza lunghezza del tratto illuminato e profondità sulla faccia superiore.
	const EDGE_HALF := 34.0
	const TOP_DEPTH := 16.0
	## Altezza illuminata della parete sopra i piedi, al più.
	const WALL_HEIGHT := 40.0
	const COLOR_LIGHT := Color(1, 1, 1, 0.55)

	## Chiave (rombo e lato) -> {tempo rimasto e poligono con i colori}.
	var _marks := {}

	func _ready() -> void:
		z_index = 10
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		set_process(false)

	## Lato side (0 alto-destra, 1 destra-basso, 2 basso-sinistra, 3
	## sinistra-alto) del rombo cell toccato vicino a point da chi sta alla
	## quota altitude.
	func touch_wall(cell: Vector2i, side: int, point: Vector2, altitude: float) -> void:
		var world := World.current
		var corners := World.cell_corners(cell)
		var a := corners[side]
		var b := corners[(side + 1) % 4]
		var top_a := world.corner_height(cell, side)
		var top_b := world.corner_height(cell, (side + 1) % 4)
		var along := (b - a).normalized()
		var at := Geometry2D.get_closest_point_to_segment(point, a, b)
		var length := a.distance_to(b)
		var t := a.distance_to(at) / length
		var t0 := clampf(t - EDGE_HALF / length, 0.0, 1.0)
		var t1 := clampf(t + EDGE_HALF / length, 0.0, 1.0)
		# Tre punti lungo il lato: estremi trasparenti, centro acceso.
		var steps := [t0, t, t1]
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for k in 3:
			var u: float = steps[k]
			var ground := a.lerp(b, u)
			var top := lerpf(top_a, top_b, u)
			if side in [1, 2]:
				# Parete davanti: dalla cima fin quasi ai piedi.
				outer.append(ground - Vector2(0, top))
				inner.append(ground - Vector2(0, maxf(altitude, top - WALL_HEIGHT)))
			else:
				# Lato dietro: la parete non si vede, si accende il bordo in cima.
				var toward := (World.cell_center(cell) - ground).normalized()
				outer.append(ground - Vector2(0, top))
				inner.append(ground + toward * TOP_DEPTH - Vector2(0, top))
		var key := Vector3i(cell.x, cell.y, side)
		_marks[key] = {"time": HOLD, "outer": outer, "inner": inner}
		set_process(true)
		queue_redraw()

	func _process(delta: float) -> void:
		for key: Variant in _marks.keys():
			_marks[key]["time"] -= delta
			if _marks[key]["time"] <= 0.0:
				_marks.erase(key)
		queue_redraw()
		if _marks.is_empty():
			set_process(false)

	func _draw() -> void:
		for mark: Dictionary in _marks.values():
			var alpha := clampf(mark["time"] / HOLD, 0.0, 1.0) * COLOR_LIGHT.a
			var outer: PackedVector2Array = mark["outer"]
			var inner: PackedVector2Array = mark["inner"]
			var clear := Color(COLOR_LIGHT, 0.0)
			var lit := Color(COLOR_LIGHT, alpha)
			var edge_lit := Color(COLOR_LIGHT, alpha * 0.4)
			# Due quadrilateri: dal bordo sinistro al centro e dal centro al destro.
			for k in 2:
				# Vicino all'angolo del rombo un tratto può essere lungo zero.
				if outer[k].distance_to(outer[k + 1]) < 1.0:
					continue
				var points := PackedVector2Array([outer[k], outer[k + 1], inner[k + 1], inner[k]])
				var colors := PackedColorArray([clear if k == 0 else lit, lit if k == 0 else clear,
						edge_lit if k == 0 else clear, clear if k == 0 else edge_lit])
				draw_polygon(points, colors)
