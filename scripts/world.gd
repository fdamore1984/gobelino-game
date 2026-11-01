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
## sassi, cespugli e casse con il bottino. Qua e là ci sono arene: ampie zone piane e
## libere con al centro un totem che avvia una sfida (vedi Game).
## Lunghe catene di montagne e burroni non si attraversano (hanno qualche
## passaggio); nelle pareti delle montagne si aprono caverne che portano a
## un sotterraneo (vedi Dungeon), disegnato con gli stessi blocchi. Dai
## mausolei in rovina ("metro", "crypt_chance" in "terrain") si scende nelle
## catacombe (Dungeon con kind "metro"): navate di lastre di pietra, fosse
## ossarie incassate piene di ossa, file di grandi tombe, pareti di pietra
## con nicchie di teschi, stendardi strappati e sangue, candele di fiamma
## verde (parametri in "metro").
##
## Le posizioni di personaggi e oggetti sono a terra (il piano x, y);
## l'altezza del terreno sotto di loro (elevation_at) li disegna più in
## alto. Il terreno viene generato e disegnato a blocchi di rombi attorno
## alla telecamera; i blocchi più alti di quelli dietro vengono disegnati
## tra i personaggi (non col resto del terreno), così coprono chi ci passa
## dietro. Non diventano trasparenti: di chi sta dietro si vede solo la
## sagoma (vedi is_covered e Silhouette).
##
## Mappa e minimappa mostrano solo le zone scoperte: i rombi entro un raggio
## dal giocatore ("map" in data/world.json) si segnano a mano a mano che si
## esplora e restano scoperti (vedi reveal_around, is_explored), una mappa
## per la superficie e una per ogni piano dei sotterranei (map_key).
##
## Luce della torcia (vedi Flashlight): il fascio parte dai piedi del
## giocatore, all'altezza del terreno su cui si trova, e si stende sullo
## schermo; le ombre si calcolano in pianta, nel punto del terreno sotto
## quello che si disegna, alzato quanto il terreno sotto il giocatore (vedi
## LightShaders e set_light_lift). Non passa attraverso montagne e pareti
## del sotterraneo: ogni blocco invalicabile (non i burroni) che confina
## con un posto in cui si cammina ha un ostacolo per la luce
## (LightOccluder2D) sulla sua base in pianta. Gli altopiani su cui si sale
## la lasciano passare. Pareti, cime e decorazioni dicono nella coordinata
## UV.y di ogni vertice di quanti pixel scendere per arrivare in pianta
## (vedi _light_uvs); una parete si accende solo se il fascio arriva
## davanti a lei.
##
## Prestazioni: i dati del terreno (livelli, rampe, ostacoli) di una regione
## grande attorno al giocatore sono generati in anticipo (begin_region,
## generate_region); avvicinandosi al bordo Game mette in pausa e genera la
## regione nuova. I pezzi da disegnare vengono creati un po' prima che
## entrino nello schermo, uno per frame, così non ci sono scatti.

## Contorno a inchiostro delle pareti dei blocchi (stile fumetto).
const CLIFF_INK_WIDTH := 3.0
const CLIFF_INK_ALPHA := 0.85

const DATA := preload("res://data/world.json")

## Mezza altezza di un rombo della griglia (i rombi sono 128 x 64).
const CELL := 64.0
## Un pezzo di mondo è un quadrato di CHUNK_CELLS x CHUNK_CELLS rombi.
const CHUNK_CELLS := 8
const MAINTAIN_INTERVAL := 0.15
## Blocchi tra i personaggi e ostacoli dei pezzi appena mostrati: si
## aggiungono al più tanti per frame, così il loro primo disegno (che
## prepara le mesh) non si accumula tutto nello stesso frame insieme al
## pavimento del pezzo. Nel browser dei telefoni un pezzo intero in un
## frame solo faceva scattare il gioco.
const NODES_PER_FRAME := 5
const PENDING_CATCH_UP := 40
## La regione successiva si genera in sottofondo mentre si gioca, a poco a
## poco (al più REGION_BACKGROUND_USEC per frame), quando ci si avvicina al
## bordo di REGION_PREFETCH pezzi più del necessario: così la schermata di
## caricamento ai bordi (vedi near_region_edge) non compare quasi mai.
const REGION_PREFETCH := 4
const REGION_BACKGROUND_USEC := 1500
## I pezzi vengono creati quando arrivano a questa distanza dallo schermo
## e tolti quando se ne allontanano di altri KEEP_MARGIN.
const PREFETCH_MARGIN := 380.0
const KEEP_MARGIN := 320.0
## I dati fuori dalla regione si dimenticano solo oltre questi rombi in memoria.
const FORGET_THRESHOLD := 110000
## Solo i blocchi più alti dei piedi di almeno tanto coprono davvero il
## corpo di un personaggio (i gradini bassi no, vedi is_covered).
const OCCLUSION_MIN_HEIGHT := 40.0
## I blocchi tra i personaggi si ordinano qualche pixel dopo il loro
## vertice più arretrato (vedi _show_chunk).
const BLOCK_SORT_BIAS := 8.0
## Lato dei quadrati della griglia dei blocchi che coprono (vedi is_covered).
const COVER_GRID := 128.0
## Muro trasparente attorno al giocatore coperto (vedi update_cutout):
## raggio del cerchio e tempo per aprirlo o chiuderlo.
const CUTOUT_RADIUS := 90.0
const CUTOUT_FADE_TIME := 0.25
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

## Maschera degli ostacoli per la luce (vedi in cima e Flashlight) e di
## quanto, davanti alla base di una parete, si guarda se arriva la luce
## (così il punto è davanti al suo stesso ostacolo).
const OCCLUDER_BASE := 1
const LIGHT_BASE_NUDGE := 4.0

## Come si calcola la luce dei punti che si disegnano (vedi _light_uvs):
## NONE dove sono, FACE alla base in pianta della parete (_light_base_a,
## _light_base_b), TOP scendendo di _light_top (cime e decorazioni).
enum LightMode { NONE, FACE, TOP }

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
## Colori delle catacombe (voce "metro" di data/world.json).
var _metro_data: Dictionary = DATA.data["metro"]
var _metro_floor_colors: Array[Color] = []
var _metro_face_colors: Array[Color] = []
var _train_faces: Array[Color] = []
var _candle_colors: Array[Color] = []
var _metro_colors := {}
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
## Blocchi tra i personaggi per quadrato dello schermo (vedi is_covered).
var _cover_grid := {}
## Altezza del terreno sotto la torcia (vedi set_light_lift).
var _light_lift := 0.0
## Blocchi resi trasparenti attorno al giocatore (vedi update_cutout) e
## quanto è aperto il cerchio, da 0 a 1.
var _cutout_blocks := {}
var _cutout_strength := 0.0
## Zone scoperte delle mappe (vedi reveal_around): chiave della mappa
## (map_key) -> pezzo di mondo -> 64 bit, uno per rombo del pezzo.
var explored := {}
## Mappa in cui si è adesso: "surface" o il piano di un sotterraneo (la
## imposta Game).
var map_key := "surface"
var _map_data: Dictionary = DATA.data["map"]
## Ultimo punto attorno a cui si è scoperta la mappa e attesa per il prossimo.
var _revealed_at := Vector2.INF
var _reveal_timer := 0.0
## Punto in pianta in cui si calcola la luce di quello che si disegna (vedi LightMode).
var _light_mode := LightMode.NONE
var _light_base_a := Vector2.ZERO
var _light_base_b := Vector2.ZERO
var _light_top := 0.0


func _ready() -> void:
	current = self
	LightShaders.set_lift(0.0)
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
	_metro_floor_colors = _colors(_metro_data["floor_colors"])
	_metro_face_colors = _colors(_metro_data["face_colors"])
	_train_faces = _colors(_metro_data["train_faces"])
	_candle_colors = _colors(_metro_data["glowstick_colors"])
	for key: String in ["track_color", "rail_color", "sleeper_color", "edge_color", "wall_color", "tile_band", "train_top", "train_window", "blood_color"]:
		_metro_colors[key] = _color(_metro_data[key])
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
		"explored": _explored_state(),
	}


## Zone scoperte da salvare: per ogni mappa, terne [x, y, bit] dei pezzi
## (i bit come testo: i numeri del JSON non tengono 64 bit).
func _explored_state() -> Dictionary:
	var result := {}
	for key: String in explored:
		var list := []
		for chunk: Vector2i in explored[key]:
			list.append([chunk.x, chunk.y, str(explored[key][chunk])])
		result[key] = list
	return result


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
	# I salvataggi di prima non hanno le zone scoperte: la mappa riparte vuota.
	var saved_maps: Dictionary = data.get("explored", {})
	for key: String in saved_maps:
		var seen := {}
		for entry: Array in saved_maps[key]:
			seen[Vector2i(int(entry[0]), int(entry[1]))] = str(entry[2]).to_int()
		explored[key] = seen


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
	# Un pezzo nuovo per frame, il più vicino, e pochi dei suoi blocchi e
	# ostacoli: niente scatti.
	if not _view_queue.is_empty():
		var chunk: Vector2i = _view_queue.pop_back()
		if not _chunk_views.has(chunk):
			_show_chunk(chunk)
	# Se se ne accumulano tanti (correndo veloci) se ne aggiungono di più.
	_add_pending_nodes(NODES_PER_FRAME + _pending_nodes.size() / PENDING_CATCH_UP)
	_update_background_region()
	_update_reveal(delta)


## Blocchi e ostacoli dei pezzi mostrati ancora da aggiungere (vedi
## NODES_PER_FRAME): [voce del pezzo in _chunk_views, dati].
var _pending_nodes: Array = []


func _add_pending_nodes(count: int) -> void:
	while count > 0 and not _pending_nodes.is_empty():
		var item: Array = _pending_nodes.pop_front()
		var entry: Dictionary = item[0]
		var chunk: Vector2i = entry["chunk"]
		# Il pezzo nel frattempo è stato tolto (o tolto e rimesso): niente.
		if not is_same(_chunk_views.get(chunk), entry):
			continue
		count -= 1
		var data: Variant = item[1]
		if data is Vector2i:
			var block := TerrainBlock.new()
			block.world = self
			block.cell = data
			# Ordinato poco dopo il suo vertice più arretrato: a pari
			# altezza sullo schermo il blocco copre chi gli sta dietro.
			block.position = cell_corners(data)[0] + Vector2(0, BLOCK_SORT_BIAS)
			block.material = LightShaders.ground()
			entities.add_child(block)
			entry["nodes"].append(block)
			_index_cover(block, true)
		else:
			entry["nodes"].append(_make_obstacle_node(data))


## Regione successiva in sottofondo (vedi REGION_PREFETCH): i dati del
## terreno si generano comunque quando servono, qui si prepara in anticipo.
func _update_background_region() -> void:
	# Prima della prima regione (vedi Game._prepare_region) non c'è niente da fare.
	if dungeon or entities == null or region.size.x <= 2 * (int(_terrain["pregen_edge"]) + REGION_PREFETCH):
		return
	if not is_region_ready():
		generate_region(REGION_BACKGROUND_USEC)
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var at := camera.get_screen_center_position()
	if not region.grow(-int(_terrain["pregen_edge"]) - REGION_PREFETCH).has_point(_chunk_of(cell_at(at))):
		begin_region(at)


## Il punto (sullo schermo, già alzato dell'altezza a cui è disegnato) è
## coperto da un blocco del terreno disegnato davanti a chi ha i piedi in
## feet: i muri non diventano trasparenti, dietro si vede la sagoma (vedi
## Silhouette). Si guardano i blocchi tra i personaggi dei pezzi vicini.
func is_covered(feet: Vector2, altitude: float, points: PackedVector2Array) -> bool:
	for point in points:
		var blocks: Variant = _cover_grid.get(Vector2i((point / COVER_GRID).floor()))
		if blocks == null:
			continue
		for block: TerrainBlock in blocks:
			if block.position.y > feet.y and block.top > altitude + OCCLUSION_MIN_HEIGHT \
					and Geometry2D.is_point_in_polygon(point, block.outline()):
				return true
	return false


## Aggiunge (o toglie) il blocco nei quadrati della griglia toccati dalla
## sua sagoma sullo schermo, così is_covered guarda solo quelli lì.
func _index_cover(block: TerrainBlock, add: bool) -> void:
	var bounds := Rect2(block.outline()[0], Vector2.ZERO)
	for point in block.outline():
		bounds = bounds.expand(point)
	var first := Vector2i((bounds.position / COVER_GRID).floor())
	var last := Vector2i((bounds.end / COVER_GRID).floor())
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			var key := Vector2i(x, y)
			if add:
				if not _cover_grid.has(key):
					_cover_grid[key] = []
				_cover_grid[key].append(block)
			elif _cover_grid.has(key):
				_cover_grid[key].erase(block)
				if _cover_grid[key].is_empty():
					_cover_grid.erase(key)


## La torcia è all'altezza lift (il terreno sotto il giocatore): le ombre
## si calcolano in pianta alzata di tanto, con gli ostacoli alzati insieme
## (vedi LightShaders).
func set_light_lift(lift: float) -> void:
	if is_equal_approx(lift, _light_lift):
		return
	_light_lift = lift
	LightShaders.set_lift(lift)
	for chunk: Vector2i in _chunk_views:
		var holder: Node2D = _chunk_views[chunk]["occluders"]
		holder.position = Vector2(0, -lift)


## Muro trasparente: mentre il giocatore (piedi in feet, alla quota
## altitude, corpo in center) è coperto, i blocchi davanti a lui diventano
## trasparenti in un cerchio attorno al corpo (vedi LightShaders.cutout).
## Il cerchio si apre e si chiude in CUTOUT_FADE_TIME secondi.
func update_cutout(feet: Vector2, altitude: float, center: Vector2, covered: bool, delta: float) -> void:
	_cutout_strength = move_toward(_cutout_strength, 1.0 if covered else 0.0, delta / CUTOUT_FADE_TIME)
	var material := LightShaders.cutout()
	material.set_shader_parameter("hole_center", center)
	material.set_shader_parameter("hole_radius", CUTOUT_RADIUS)
	material.set_shader_parameter("hole_strength", _cutout_strength)
	if not covered and _cutout_strength > 0.0:
		return
	var wanted := {}
	if covered:
		var area := Rect2(center - Vector2(CUTOUT_RADIUS, CUTOUT_RADIUS), Vector2(CUTOUT_RADIUS, CUTOUT_RADIUS) * 2.0)
		var first := Vector2i((area.position / COVER_GRID).floor())
		var last := Vector2i((area.end / COVER_GRID).floor())
		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				var blocks: Variant = _cover_grid.get(Vector2i(x, y))
				if blocks == null:
					continue
				for block: TerrainBlock in blocks:
					if wanted.has(block) or block.position.y <= feet.y:
						continue
					var outline := block.outline()
					if block.top <= altitude + OCCLUSION_MIN_HEIGHT:
						continue
					var bounds := Rect2(outline[0], Vector2.ZERO)
					for point in outline:
						bounds = bounds.expand(point)
					if bounds.intersects(area):
						wanted[block] = true
	for block: Variant in _cutout_blocks:
		if not wanted.has(block) and is_instance_valid(block):
			(block as TerrainBlock).material = LightShaders.ground()
	for block: TerrainBlock in wanted:
		block.material = material
	_cutout_blocks = wanted


## Sagoma sullo schermo del blocco disegnato (base e cima), per is_covered.
func block_outline(cell: Vector2i) -> PackedVector2Array:
	var points := PackedVector2Array()
	var corners := cell_corners(cell)
	for k in 4:
		points.append(corners[k])
		points.append(corners[k] - Vector2(0, corner_height(cell, k)))
	return Geometry2D.convex_hull(points)


# --- Mappa scoperta ----------------------------------------------------

## Raggio attorno al giocatore entro cui si scopre la mappa (e si vedono
## i nemici sulla minimappa), in pixel sullo schermo.
func reveal_radius() -> float:
	return float(_map_data["reveal_radius"])


## Scopre la mappa attorno al giocatore ogni tanto, quando si è spostato.
func _update_reveal(delta: float) -> void:
	_reveal_timer -= delta
	if player == null or _reveal_timer > 0.0:
		return
	_reveal_timer = float(_map_data["reveal_interval"])
	if _revealed_at.distance_to(player.position) >= float(_map_data["reveal_step"]):
		reveal_around(player.position)


## Segna come scoperti i rombi entro reveal_radius dal punto, nella mappa
## attuale: restano scoperti per sempre (si salvano, vedi save_state).
func reveal_around(point: Vector2) -> void:
	_revealed_at = point
	var radius := reveal_radius()
	if not explored.has(map_key):
		explored[map_key] = {}
	var seen: Dictionary = explored[map_key]
	var low := to_grid(point + Vector2(-radius, 0)).min(to_grid(point + Vector2(0, -radius)))
	var high := to_grid(point + Vector2(radius, 0)).max(to_grid(point + Vector2(0, radius)))
	for u in range(floori(low.x), ceili(high.x) + 1):
		for v in range(floori(low.y), ceili(high.y) + 1):
			var cell := Vector2i(u, v)
			if cell_center(cell).distance_to(point) > radius:
				continue
			var chunk := _chunk_of(cell)
			var bit := 1 << ((cell.x - chunk.x * CHUNK_CELLS) + (cell.y - chunk.y * CHUNK_CELLS) * CHUNK_CELLS)
			seen[chunk] = int(seen.get(chunk, 0)) | bit


## Il punto è in una zona già scoperta della mappa attuale.
func is_explored(point: Vector2) -> bool:
	var seen: Dictionary = explored.get(map_key, {})
	var cell := cell_at(point)
	var chunk := _chunk_of(cell)
	var mask := int(seen.get(chunk, 0))
	return mask & (1 << ((cell.x - chunk.x * CHUNK_CELLS) + (cell.y - chunk.y * CHUNK_CELLS) * CHUNK_CELLS)) != 0


## Cambia mappa (superficie o piano di un sotterraneo) e scopre subito
## attorno al giocatore.
func set_map_key(key: String) -> void:
	map_key = key
	_revealed_at = Vector2.INF
	_reveal_timer = 0.0


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
		# Roccia e tombe non si attraversano; le fosse ossarie sono più in basso.
		level = dungeon.level_at(cell)
		if not dungeon.is_floor(cell):
			kind = Kind.ROCK
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
				if obstacle["type"] in ["chest", "totem", "merchant", "cave", "metro", "stairs", "exit"]:
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


## Ostacolo non solido (cespuglio) su cui si trova il punto, quello
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


## Moltiplicatore della velocità a terra (i cespugli rallentano).
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
	else:
		# Mausoleo delle catacombe: niente ostacoli attorno.
		var crypt := _crypt_in_chunk(chunk)
		if not crypt.is_empty():
			result = result.filter(func(obstacle: Dictionary) -> bool:
				return obstacle["position"].distance_to(crypt["position"]) > 130.0)
			result.append(crypt)
	return result


func _site_obstacle(type_id: String, at: Vector2, radius: float, collision: float) -> Dictionary:
	return {
		"type": type_id, "position": at, "elevation": elevation_at(at), "radius": radius,
		"collision": collision, "solid": true, "slow": 1.0, "damage": 0,
		"damage_interval": 0.0, "variant": 0,
	}


## Sceglie quale ostacolo mettere sul blocco (o nessuno), con probabilità
## che dipendono dalla zona: boschi, alture, bordi dei gradini.
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
	_add_pending_nodes(_pending_nodes.size())


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
	view.material = LightShaders.ground()
	var occluders := _add_occluders(view, chunk)
	add_child(view)
	var nodes: Array[Node] = []
	var entry := {"view": view, "nodes": nodes, "occluders": occluders, "chunk": chunk}
	_chunk_views[chunk] = entry
	if entities:
		# Prima i blocchi (coprono chi passa dietro), poi gli ostacoli: si
		# aggiungono a poco a poco (vedi _add_pending_nodes).
		for i in CHUNK_CELLS:
			for j in CHUNK_CELLS:
				var cell := chunk * CHUNK_CELLS + Vector2i(i, j)
				if _covers_behind(cell):
					_pending_nodes.append([entry, cell])
		for data: Dictionary in _obstacles_of(chunk):
			_pending_nodes.append([entry, data])


func _hide_chunk(chunk: Vector2i) -> void:
	var entry: Dictionary = _chunk_views[chunk]
	entry["view"].queue_free()
	for node: Node in entry["nodes"]:
		if node is TerrainBlock:
			_index_cover(node, false)
		node.queue_free()
	_chunk_views.erase(chunk)


## Un blocco più alto di quelli dietro può coprire chi ci passa dietro:
## va disegnato anche tra i personaggi, ordinato con loro. Anche i blocchi
## in mezzo a un edificio o a un muro, se dietro di loro, abbastanza vicino
## da finire sotto il loro tetto sullo schermo, c'è un posto in cui si
## cammina: altrimenti chi passa dietro un edificio alto verrebbe disegnato
## sopra il tetto.
func _covers_behind(cell: Vector2i) -> bool:
	var top := _top_height(cell)
	for step: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
		if _top_height(cell + step) < top:
			return true
	if top <= 0.0 or not is_barrier(cell):
		return false
	# Ogni rombo più indietro è mezzo rombo più in alto sullo schermo.
	var reach := ceili((top + CELL) / (CELL * 0.5))
	for a in reach + 1:
		for b in reach + 1 - a:
			if (a > 0 or b > 0) and not is_barrier(cell - Vector2i(a, b)):
				return true
	return false


# --- Disegno dei blocchi ----------------------------------------------

func draw_chunk(canvas: Object, chunk: Vector2i, offset: Vector2) -> void:
	# Da dietro in avanti: prima i rombi con u + v più piccolo. I blocchi che
	# coprono chi sta dietro li disegna il loro TerrainBlock, tra i personaggi;
	# qui sotto resta il pavimento da cui salgono, che si vede quando il
	# blocco non c'è (vedi refresh_now).
	for depth in 2 * CHUNK_CELLS - 1:
		for i in range(maxi(0, depth - CHUNK_CELLS + 1), mini(depth, CHUNK_CELLS - 1) + 1):
			var cell := chunk * CHUNK_CELLS + Vector2i(i, depth - i)
			if entities == null or not _covers_behind(cell):
				draw_cell(canvas, cell, offset)
			else:
				draw_floor(canvas, cell, offset)


## Ostacoli per la luce dei blocchi invalicabili del pezzo che confinano
## con un posto in cui si cammina (vedi in cima), in un nodo figlio di view
## che li alza quanto il terreno sotto il giocatore (vedi set_light_lift).
func _add_occluders(view: Node2D, chunk: Vector2i) -> Node2D:
	var holder := Node2D.new()
	holder.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	holder.position = Vector2(0, -_light_lift)
	view.add_child(holder)
	for i in CHUNK_CELLS:
		for j in CHUNK_CELLS:
			var cell := chunk * CHUNK_CELLS + Vector2i(i, j)
			if not is_barrier(cell) or kind_of(cell) == Kind.RAVINE:
				continue
			var open := false
			for step: Vector2i in RAMP_DIRECTIONS:
				var other := cell + step
				if not is_barrier(other) or kind_of(other) == Kind.RAVINE:
					open = true
					break
			if not open:
				continue
			var polygon := PackedVector2Array()
			for corner in cell_corners(cell):
				polygon.append(corner - view.position)
			var shape := OccluderPolygon2D.new()
			shape.polygon = polygon
			var occluder := LightOccluder2D.new()
			occluder.occluder = shape
			occluder.occluder_light_mask = OCCLUDER_BASE
			holder.add_child(occluder)
	return holder


## Pavimento sotto un blocco che copre chi sta dietro: il rombo piano
## all'altezza del vicino dietro più basso (dove sta chi viene coperto), con
## le sue pareti verso i vicini davanti. Di solito è nascosto dal blocco.
func draw_floor(canvas: Object, cell: Vector2i, offset: Vector2) -> void:
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
	var faces := _face_colors_of(kind, cell)
	_draw_face(canvas, corners, heights, cell + Vector2i(1, 0), 1, 2, 0, 3, faces[0], false)
	_draw_face(canvas, corners, heights, cell + Vector2i(0, 1), 2, 3, 1, 0, faces[1], false)
	_light_mode = LightMode.TOP
	_light_top = base
	_fill(canvas, top, _top_color(cell, kind, is_path(cell)).darkened(0.15))
	_light_mode = LightMode.NONE


## Un blocco: pareti davanti (dove il vicino è più basso) e faccia
## superiore, piana o inclinata, del colore del suo tipo.
func draw_cell(canvas: Object, cell: Vector2i, offset: Vector2) -> void:
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
	var faces := _face_colors_of(kind, cell)
	var lip := kind == Kind.GROUND and dungeon == null
	# Nelle catacombe le pareti sono di pietra con le nicchie, le tombe scolpite.
	var pattern := ""
	if dungeon and dungeon.is_metro() and kind == Kind.ROCK:
		pattern = "train" if dungeon.tile_at(cell) == Dungeon.Tile.TRAIN else "tiles"
	_draw_face(canvas, corners, heights, cell + Vector2i(1, 0), 1, 2, 0, 3, faces[0], lip, cell, pattern)
	_draw_face(canvas, corners, heights, cell + Vector2i(0, 1), 2, 3, 1, 0, faces[1], lip, cell, pattern)

	var path := is_path(cell)
	var color := _top_color(cell, kind, path)
	var ramp := ramp_of(cell)
	if ramp != Vector2i.ZERO:
		# Le rampe che salgono verso il fondo sono in ombra, le altre in luce.
		color = color.darkened(0.12) if ramp.x + ramp.y < 0 else color.lightened(0.08)
	# La cima prende la luce del terreno in pianta sotto ogni suo vertice.
	_light_mode = LightMode.NONE
	var uvs := PackedVector2Array()
	for k in 4:
		uvs.append(Vector2(0.0, heights[k]))
	canvas.draw_colored_polygon(top, color, uvs)
	if ramp != Vector2i.ZERO:
		_light_mode = LightMode.TOP
		_light_top = (heights[0] + heights[1] + heights[2] + heights[3]) / 4.0
		_draw_ramp_lines(canvas, top, ramp, color)
	_draw_decor(canvas, cell, offset, kind, path)
	_light_mode = LightMode.NONE


func _top_color(cell: Vector2i, kind: int, path: bool) -> Color:
	match kind:
		Kind.MOUNTAIN:
			return _mountain_colors[clampi(level_of(cell) - _levels - 1, 0, _mountain_colors.size() - 1)]
		Kind.RAVINE:
			return _ravine_color
		Kind.ROCK:
			if dungeon and dungeon.is_metro():
				return _metro_colors["train_top"] if dungeon.tile_at(cell) == Dungeon.Tile.TRAIN else _metro_colors["wall_color"]
			return _dungeon_wall_color
	if dungeon and dungeon.is_metro():
		if dungeon.tile_at(cell) == Dungeon.Tile.TRACK:
			return _metro_colors["track_color"]
		return _metro_floor_colors[posmod(hash([cell.x, cell.y]), _metro_floor_colors.size())]
	if dungeon:
		return _dungeon_floor_colors[posmod(hash([cell.x, cell.y]), _dungeon_floor_colors.size())]
	return _path_color if path else _grass_colors[clampi(level_of(cell), 0, _levels - 1)]


func _face_colors_of(kind: int, cell: Vector2i) -> Array[Color]:
	if kind == Kind.MOUNTAIN:
		return _mountain_face_colors
	if dungeon and dungeon.is_metro():
		match dungeon.tile_at(cell):
			Dungeon.Tile.TRAIN:
				return _train_faces
			Dungeon.Tile.WALL:
				return _metro_face_colors
		# Bordo della navata sopra la fossa: pietra più scura.
		var stone: Array[Color] = [_metro_floor_colors[0].darkened(0.3), _metro_floor_colors[0].darkened(0.45)]
		return stone
	if dungeon:
		return _dungeon_face_colors
	return _face_colors


func _draw_face(canvas: Object, corners: PackedVector2Array, heights: Array[float], other: Vector2i,
		first: int, second: int, other_first: int, other_second: int, color: Color, lip: bool,
		cell := Vector2i.ZERO, pattern := "") -> void:
	var top_a := heights[first]
	var top_b := heights[second]
	var bottom_a := minf(corner_height(other, other_first), top_a)
	var bottom_b := minf(corner_height(other, other_second), top_b)
	if top_a - bottom_a < 0.5 and top_b - bottom_b < 0.5:
		return
	var a := corners[first]
	var b := corners[second]
	# Ogni punto della parete prende la luce che arriva in pianta alla sua base.
	_light_mode = LightMode.FACE
	_light_base_a = a
	_light_base_b = b
	var points := PackedVector2Array([a - Vector2(0, top_a), b - Vector2(0, top_b)])
	if top_b - bottom_b >= 0.5:
		points.append(b - Vector2(0, bottom_b))
	if top_a - bottom_a >= 0.5:
		points.append(a - Vector2(0, bottom_a))
	_fill(canvas, points, color)
	if pattern != "":
		if pattern == "train":
			_draw_tomb_side(canvas, a, b, top_a, top_b, bottom_a, bottom_b, cell, first, color)
		else:
			_draw_crypt_wall(canvas, a, b, top_a, top_b, bottom_a, bottom_b, cell, first, color)
		_line(canvas, a - Vector2(0, bottom_a), b - Vector2(0, bottom_b), Color(0, 0, 0, 0.4), 2.0)
		_light_mode = LightMode.NONE
		return
	# Strati della roccia o della terra, tutti in una sola chiamata.
	var strata := PackedVector2Array()
	var depth := STRATA_STEP
	while depth < maxf(top_a - bottom_a, top_b - bottom_b) - 4.0:
		strata.append(a - Vector2(0, top_a - minf(depth, top_a - bottom_a)))
		strata.append(b - Vector2(0, top_b - minf(depth, top_b - bottom_b)))
		depth += STRATA_STEP
	if not strata.is_empty():
		_lines(canvas, strata, color.darkened(0.18), 1.5)
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
			_fill(canvas, lip_points, _lip_color)
	_ink_face(canvas, a, b, top_a, top_b, bottom_a, bottom_b)
	_light_mode = LightMode.NONE


## Contorno a inchiostro della parete tra a e b (stile fumetto): bordo in
## cima, base e spigoli ai lati.
func _ink_face(canvas: Object, a: Vector2, b: Vector2, top_a: float, top_b: float, bottom_a: float, bottom_b: float) -> void:
	var ink := Color(Shapes.INK, CLIFF_INK_ALPHA)
	_line(canvas, a - Vector2(0, top_a), b - Vector2(0, top_b), ink, CLIFF_INK_WIDTH)
	_line(canvas, a - Vector2(0, bottom_a), b - Vector2(0, bottom_b), ink, CLIFF_INK_WIDTH)
	if top_a - bottom_a >= 0.5:
		_line(canvas, a - Vector2(0, top_a), a - Vector2(0, bottom_a), ink, CLIFF_INK_WIDTH * 0.8)
	if top_b - bottom_b >= 0.5:
		_line(canvas, b - Vector2(0, top_b), b - Vector2(0, bottom_b), ink, CLIFF_INK_WIDTH * 0.8)


## Parete di pietra delle catacombe tra a e b (dall'alto top alla base
## bottom): corsi di blocchi sfalsati, un fregio rosso scuro, il muschio che
## sale da terra e, qua e là, una nicchia con un teschio e le ossa, uno
## stendardo strappato o una strisciata di sangue che cola.
func _draw_crypt_wall(canvas: Object, a: Vector2, b: Vector2, top_a: float, top_b: float,
		bottom_a: float, bottom_b: float, cell: Vector2i, side: int, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_decor_seed(), cell.x, cell.y, side, "crypt"])
	var height := minf(top_a - bottom_a, top_b - bottom_b)
	var joints := PackedVector2Array()
	var depth := 12.0
	var row := 0
	while depth < height - 2.0:
		joints.append(a - Vector2(0, bottom_a + depth))
		joints.append(b - Vector2(0, bottom_b + depth))
		# Giunti verticali sfalsati tra un corso e l'altro.
		for t: float in ([0.25, 0.75] if row % 2 == 0 else [0.5]):
			var at := a.lerp(b, t)
			var base := lerpf(bottom_a, bottom_b, t)
			joints.append(at - Vector2(0, base + depth - 12.0))
			joints.append(at - Vector2(0, base + minf(depth, height)))
		depth += 12.0
		row += 1
	_lines(canvas, joints, color.darkened(0.25), 1.0)
	var band: Color = _metro_colors["tile_band"]
	_fill(canvas, PackedVector2Array([a - Vector2(0, bottom_a + 52.0), b - Vector2(0, bottom_b + 52.0),
			b - Vector2(0, bottom_b + 58.0), a - Vector2(0, bottom_a + 58.0)]), band)
	# Muschio e sporco alla base.
	var moss := Color(0.12, 0.16, 0.08, 0.55)
	_fill_colors(canvas, PackedVector2Array([a - Vector2(0, bottom_a), b - Vector2(0, bottom_b), b - Vector2(0, bottom_b + 24.0), a - Vector2(0, bottom_a + 24.0)]),
			PackedColorArray([moss, moss, Color(moss, 0.0), Color(moss, 0.0)]))
	var roll := rng.randf()
	if roll < 0.28 and height > 60.0:
		# Nicchia sepolcrale con un teschio e qualche osso.
		var t := rng.randf_range(0.25, 0.45)
		var p0 := a.lerp(b, t)
		var p1 := a.lerp(b, t + 0.32)
		var h0 := lerpf(bottom_a, bottom_b, t) + 14.0
		var h1 := lerpf(bottom_a, bottom_b, t + 0.32) + 14.0
		_fill(canvas, PackedVector2Array([p0 - Vector2(0, h0), p1 - Vector2(0, h1), p1 - Vector2(0, h1 + 26.0), p0 - Vector2(0, h0 + 26.0)]), Color(0.04, 0.03, 0.04))
		var bone: Color = _metro_colors["rail_color"]
		var skull := p0.lerp(p1, 0.5) - Vector2(0, lerpf(h0, h1, 0.5) + 9.0)
		_circle(canvas, skull, 5.5, bone)
		_fill(canvas, PackedVector2Array([skull + Vector2(-3, 3), skull + Vector2(3, 3), skull + Vector2(2.5, 7), skull + Vector2(-2.5, 7)]), bone)
		for eye: float in [-2.0, 2.0]:
			_circle(canvas, skull + Vector2(eye, 0), 1.4, Color(0.05, 0.04, 0.04))
		_line(canvas, p0.lerp(p1, 0.12) - Vector2(0, h0 + 4.0), p0.lerp(p1, 0.88) - Vector2(0, h1 + 3.0), bone.darkened(0.15), 2.5)
	elif roll < 0.42 and height > 70.0:
		# Stendardo strappato che pende dall'alto.
		var t := rng.randf_range(0.2, 0.6)
		var p0 := a.lerp(b, t)
		var p1 := a.lerp(b, t + 0.25)
		var high0 := lerpf(top_a, top_b, t) - 10.0
		var high1 := lerpf(top_a, top_b, t + 0.25) - 10.0
		var cloth := Color.from_hsv([0.0, 0.33, 0.75][rng.randi() % 3], 0.55, 0.35)
		var drop := minf(56.0, height - 30.0)
		var middle := p0.lerp(p1, 0.5) - Vector2(0, lerpf(high0, high1, 0.5) - drop - 8.0)
		_fill(canvas, PackedVector2Array([p0 - Vector2(0, high0), p1 - Vector2(0, high1), p1 - Vector2(0, high1 - drop),
				middle, p0 - Vector2(0, high0 - drop + rng.randf_range(0.0, 10.0))]), cloth)
		_line(canvas, p0 - Vector2(0, high0), p1 - Vector2(0, high1), Color(0.35, 0.25, 0.12), 2.5)
	if rng.randf() < float(_metro_data["blood_chance"]) * 1.5:
		# Strisciata di sangue che cola giù dalla parete.
		var blood: Color = _metro_colors["blood_color"]
		var t := rng.randf_range(0.15, 0.7)
		var high := rng.randf_range(24.0, maxf(height - 10.0, 26.0))
		var hand := a.lerp(b, t) - Vector2(0, lerpf(bottom_a, bottom_b, t) + high)
		var drag := (b - a) * rng.randf_range(0.15, 0.3)
		_fill(canvas, PackedVector2Array([hand, hand + drag, hand + drag + Vector2(0, 7), hand + Vector2(0, 9)]), blood)
		var drips := PackedVector2Array()
		for k in 4:
			var at := hand + drag * rng.randf() + Vector2(0, 6)
			drips.append_array([at, at + Vector2(0, rng.randf_range(8.0, high * 0.8))])
		_lines(canvas, drips, blood, 2.0)


## Fianco di una grande tomba: cornice del coperchio in cima, riquadri
## scolpiti, a volte un teschio inciso o una croce, e il muschio in basso.
func _draw_tomb_side(canvas: Object, a: Vector2, b: Vector2, top_a: float, top_b: float,
		bottom_a: float, bottom_b: float, cell: Vector2i, side: int, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_decor_seed(), cell.x, cell.y, side, "tomb"])
	var carving: Color = _metro_colors["train_window"]
	# Cornice sporgente del coperchio.
	_fill(canvas, PackedVector2Array([a - Vector2(0, top_a), b - Vector2(0, top_b), b - Vector2(0, top_b - 8.0), a - Vector2(0, top_a - 8.0)]), color.lightened(0.15))
	var p0 := a.lerp(b, 0.14)
	var p1 := a.lerp(b, 0.86)
	var h0 := lerpf(bottom_a, bottom_b, 0.14)
	var h1 := lerpf(bottom_a, bottom_b, 0.86)
	var top := minf(top_a - bottom_a, top_b - bottom_b) - 16.0
	var panel := PackedVector2Array([p0 - Vector2(0, h0 + 12.0), p1 - Vector2(0, h1 + 12.0), p1 - Vector2(0, h1 + top), p0 - Vector2(0, h0 + top)])
	_fill(canvas, panel, color.darkened(0.12))
	var frame := PackedVector2Array()
	for k in 4:
		frame.append_array([panel[k], panel[(k + 1) % 4]])
	_lines(canvas, frame, carving, 1.5)
	var middle := p0.lerp(p1, 0.5) - Vector2(0, lerpf(h0, h1, 0.5) + (12.0 + top) / 2.0)
	if rng.randf() < 0.4:
		# Teschio inciso.
		_circle(canvas, middle, 6.0, carving)
		for eye: float in [-2.2, 2.2]:
			_circle(canvas, middle + Vector2(eye, 0), 1.5, color)
	elif rng.randf() < 0.5:
		# Croce incisa.
		_lines(canvas, PackedVector2Array([middle - Vector2(0, 10), middle + Vector2(0, 10), middle - (b - a).normalized() * 6.0 - Vector2(0, 3),
				middle + (b - a).normalized() * 6.0 - Vector2(0, 3)]), carving, 2.0)
	var moss := Color(0.12, 0.16, 0.08, 0.6)
	_fill_colors(canvas, PackedVector2Array([a - Vector2(0, bottom_a), b - Vector2(0, bottom_b), b - Vector2(0, bottom_b + 16.0), a - Vector2(0, bottom_a + 16.0)]),
			PackedColorArray([moss, moss, Color(moss, 0.0), Color(moss, 0.0)]))


## Per ogni punto, di quanti pixel scendere per arrivare al punto in pianta
## da cui prende la luce (in UV.y, vedi LightShaders.ground): fin sotto la
## base in pianta della parete (un poco davanti, LIGHT_BASE_NUDGE) o di
## _light_top. Vuoto se la luce si calcola dove si disegna.
func _light_uvs(points: PackedVector2Array) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	if _light_mode == LightMode.NONE:
		return uvs
	uvs.resize(points.size())
	var a := _light_base_a
	var b := _light_base_b
	for k in points.size():
		var drop := _light_top
		if _light_mode == LightMode.FACE:
			var t := clampf((points[k].x - a.x) / (b.x - a.x), 0.0, 1.0) if absf(b.x - a.x) > 0.01 else 0.0
			drop = maxf(lerpf(a.y, b.y, t) - points[k].y, 0.0) + LIGHT_BASE_NUDGE
		uvs[k] = Vector2(0.0, drop)
	return uvs


func _fill(canvas: Object, points: PackedVector2Array, color: Color) -> void:
	canvas.draw_colored_polygon(points, color, _light_uvs(points))


func _fill_colors(canvas: Object, points: PackedVector2Array, colors: PackedColorArray) -> void:
	canvas.draw_polygon(points, colors, _light_uvs(points))


func _line(canvas: Object, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	_lines(canvas, PackedVector2Array([from, to]), color, width)


## Segmenti (a coppie di punti) come quadrilateri, così ogni vertice ha la sua luce.
func _lines(canvas: Object, pairs: PackedVector2Array, color: Color, width: float) -> void:
	if _light_mode == LightMode.NONE:
		canvas.draw_multiline(pairs, color, width)
		return
	var colors := PackedColorArray([color, color, color, color])
	for k in range(0, pairs.size() - 1, 2):
		var across := (pairs[k + 1] - pairs[k]).orthogonal().normalized() * width / 2.0
		var quad := PackedVector2Array([pairs[k] + across, pairs[k + 1] + across, pairs[k + 1] - across, pairs[k] - across])
		canvas.draw_primitive(quad, colors, _light_uvs(quad))


## Cerchio pieno che prende la luce come gli altri punti (un poligono, se serve).
func _circle(canvas: Object, center: Vector2, radius: float, color: Color) -> void:
	if _light_mode == LightMode.NONE:
		canvas.draw_circle(center, radius, color)
		return
	var points := PackedVector2Array()
	for k in 10:
		points.append(center + Vector2.from_angle(k * TAU / 10.0) * radius)
	_fill(canvas, points, color)


## Linee lungo la pendenza di una rampa, parallele al lato più alto.
func _draw_ramp_lines(canvas: Object, top: PackedVector2Array, ramp: Vector2i, color: Color) -> void:
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
	_lines(canvas, lines, color.darkened(0.15), 1.5)


## Ciuffi d'erba e fiori sui blocchi d'erba, sassolini sui sentieri e nel
## sotterraneo (dove crescono anche funghi luminosi): solo decorazione.
func _draw_decor(canvas: Object, cell: Vector2i, offset: Vector2, kind: int, path: bool) -> void:
	if kind != Kind.GROUND:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_decor_seed(), cell.x, cell.y, "decor"])
	# Le decorazioni prendono la luce in pianta come la cima su cui stanno.
	_light_mode = LightMode.TOP
	_light_top = _top_height(cell) if ramp_of(cell) == Vector2i.ZERO else level_of(cell) * level_height + level_height / 2.0
	if dungeon and dungeon.is_metro():
		_draw_crypt_floor(canvas, cell, offset, rng)
		return
	if path or dungeon:
		for k in rng.randi_range(2, 4):
			var at := _decor_point(cell, rng, offset)
			_circle(canvas, at, rng.randf_range(1.5, 3.0), _pebble_colors[k % _pebble_colors.size()])
		if dungeon and rng.randf() < float(_dungeon_data["mushroom_chance"]):
			var at := _decor_point(cell, rng, offset)
			var glow := _mushroom_colors[rng.randi() % _mushroom_colors.size()]
			_circle(canvas, at, 7.0, Color(glow, 0.25))
			_line(canvas, at, at + Vector2(0, -5), Color(0.8, 0.8, 0.75), 2.0)
			_circle(canvas, at + Vector2(0, -6), 3.5, glow)
		return
	var grass := _grass_colors[clampi(level_of(cell), 0, _levels - 1)].darkened(0.3)
	var tufts := PackedVector2Array()
	for k in rng.randi_range(_tuft_range.x, _tuft_range.y):
		var at := _decor_point(cell, rng, offset)
		tufts.append_array([at, at + Vector2(-4, -7), at, at + Vector2(0, -9), at, at + Vector2(4, -7)])
	if not tufts.is_empty():
		_lines(canvas, tufts, grass, 1.5)
	if rng.randf() < float(_decor["flower_chance"]):
		var color := _flower_colors[rng.randi() % _flower_colors.size()]
		var at := _decor_point(cell, rng, offset)
		for k in 3:
			_circle(canvas, at + Vector2.from_angle(k * TAU / 3.0) * 3.0, 2.5, color)
		_circle(canvas, at, 1.5, Color(0.95, 0.8, 0.3))


## Pavimento delle catacombe: nelle fosse ossa sparse e teschi, sulle
## navate le lastre di pietra e una cornice lungo il bordo sopra le fosse;
## dappertutto sassolini, pozze di sangue e, qua e là, una candela di
## fiamma verde.
func _draw_crypt_floor(canvas: Object, cell: Vector2i, offset: Vector2, rng: RandomNumberGenerator) -> void:
	var lift := Vector2(0, _light_top)
	var point := func(u: float, v: float) -> Vector2:
		return _from_uv((cell.x + u) * CELL, (cell.y + v) * CELL) + offset - lift
	var bone: Color = _metro_colors["rail_color"]
	if dungeon.tile_at(cell) == Dungeon.Tile.TRACK:
		var bones := PackedVector2Array()
		for k in rng.randi_range(3, 6):
			var at: Vector2 = point.call(rng.randf_range(0.1, 0.9), rng.randf_range(0.1, 0.9))
			var along := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(5.0, 10.0) * Vector2(1.0, 0.5)
			bones.append_array([at - along, at + along])
		_lines(canvas, bones, bone.darkened(0.1), 2.5)
		for k in range(0, bones.size(), 2):
			_circle(canvas, bones[k], 1.8, bone)
			_circle(canvas, bones[k + 1], 1.8, bone)
		if rng.randf() < 0.35:
			var skull: Vector2 = point.call(rng.randf_range(0.25, 0.75), rng.randf_range(0.25, 0.75))
			_circle(canvas, skull, 5.0, bone)
			for eye: float in [-1.8, 1.8]:
				_circle(canvas, skull + Vector2(eye, 0.5), 1.3, Color(0.05, 0.04, 0.04))
		if rng.randf() < 0.25:
			# Acqua nera che ristagna sul fondo.
			var center: Vector2 = point.call(rng.randf_range(0.3, 0.7), rng.randf_range(0.3, 0.7))
			var pool := PackedVector2Array()
			for k in 8:
				pool.append(center + Vector2.from_angle(TAU * k / 8.0) * Vector2(14.0, 7.0) * rng.randf_range(0.7, 1.15))
			_fill(canvas, pool, Color(_metro_colors["sleeper_color"], 0.8))
	else:
		var joints := PackedVector2Array([point.call(0.5, 0.0), point.call(0.5, 1.0), point.call(0.0, 0.5), point.call(1.0, 0.5)])
		_lines(canvas, joints, Color(0, 0, 0, 0.15), 1.0)
		# Cornice di pietra lungo il bordo della navata sopra la fossa.
		for side: int in [-1, 1]:
			if dungeon.tile_at(cell + Vector2i(0, side)) == Dungeon.Tile.TRACK:
				var v := 0.1 if side < 0 else 0.9
				_line(canvas, point.call(0.0, v), point.call(1.0, v), _metro_colors["edge_color"], 4.0)
	for k in rng.randi_range(1, 3):
		_circle(canvas, point.call(rng.randf_range(0.15, 0.85), rng.randf_range(0.15, 0.85)), rng.randf_range(1.5, 3.0), _pebble_colors[k % _pebble_colors.size()])
	if rng.randf() < float(_metro_data["blood_chance"]):
		# Pozza di sangue rappreso, con gli schizzi attorno.
		var blood: Color = _metro_colors["blood_color"]
		var center: Vector2 = point.call(rng.randf_range(0.3, 0.7), rng.randf_range(0.3, 0.7))
		var pool := PackedVector2Array()
		var size := rng.randf_range(10.0, 22.0)
		for k in 9:
			pool.append(center + Vector2.from_angle(TAU * k / 9.0) * Vector2(size, size * 0.5) * rng.randf_range(0.6, 1.2))
		_fill(canvas, pool, blood)
		for k in 4:
			_circle(canvas, center + Vector2.from_angle(rng.randf() * TAU) * size * rng.randf_range(1.2, 1.8) * Vector2(1, 0.5), rng.randf_range(1.5, 3.0), blood)
	if rng.randf() < float(_metro_data["glowstick_chance"]):
		# Candela consumata con la fiamma verde.
		var at: Vector2 = point.call(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8))
		var glow := _candle_colors[rng.randi() % _candle_colors.size()]
		_circle(canvas, at - Vector2(0, 8), 10.0, Color(glow, 0.2))
		_fill(canvas, PackedVector2Array([at + Vector2(-2.5, 0), at + Vector2(2.5, 0), at + Vector2(2.5, -8), at + Vector2(-2.5, -8)]), Color(0.85, 0.82, 0.7))
		_fill(canvas, PackedVector2Array([at + Vector2(-2.5, -9), at + Vector2(0, -16), at + Vector2(2.5, -9)]), glow)


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
	_chunk_obstacles.clear()
	_near_cache.clear()
	_close_cache.clear()
	for cache: Dictionary in [_level_cache, _ramp_cache, _path_cache, _kind_cache]:
		cache.clear()
	region = Rect2i()
	var ground := _grass_colors[0].darkened(0.3)
	if dungeon:
		ground = _metro_colors["wall_color"] if dungeon.is_metro() else _dungeon_wall_color
	RenderingServer.set_default_clear_color(ground)


## Seme della decorazione e degli ostacoli: in superficie quello del
## mondo, nel sotterraneo quello del piano.
func _decor_seed() -> int:
	return dungeon.seed_value if dungeon else seed_value


## Ostacoli di un piano: stalagmiti (nelle catacombe anche sarcofagi bassi
## sulle navate e scheletri a terra), i passaggi nelle pareti e le casse.
func _dungeon_obstacles(chunk: Vector2i) -> Array:
	var result: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	var settings := dungeon.settings()
	var table := {"rock": float(settings["stalagmite_chance"])}
	if dungeon.is_metro():
		table["bench"] = float(settings["bench_chance"])
		table["corpse"] = float(settings["corpse_chance"])
	for i in CHUNK_CELLS:
		for j in CHUNK_CELLS:
			var cell := chunk * CHUNK_CELLS + Vector2i(i, j)
			if not dungeon.is_open(cell):
				continue
			rng.seed = hash([dungeon.seed_value, cell.x, cell.y, "rock"])
			var roll := rng.randf()
			var type_id := ""
			for id: String in table:
				roll -= table[id]
				if roll < 0.0:
					type_id = id
					break
			# I sarcofagi stanno sulle navate, non nelle fosse.
			if type_id == "" or (type_id == "bench" and dungeon.tile_at(cell) != Dungeon.Tile.FLOOR):
				continue
			var type: Dictionary = _obstacle_types[type_id]
			var radius_range: Array = type["radius"]
			var radius := rng.randf_range(radius_range[0], radius_range[1])
			var spot := _from_uv(cell.x * CELL + rng.randf_range(PLACE_MIN, PLACE_MAX), cell.y * CELL + rng.randf_range(PLACE_MIN, PLACE_MAX))
			if type_id == "bench":
				spot = cell_center(cell)
			result.append({
				"type": type_id, "position": spot, "elevation": elevation_at(spot), "radius": radius,
				"collision": radius * float(type["collision"]), "solid": type["solid"], "slow": type.get("slow", 1.0), "damage": 0,
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


## Mausoleo in rovina che porta alle catacombe ("metro"): al più uno per
## pezzo, raro ("crypt_chance"), su un tratto piano d'erba lontano dalla
## partenza, dalle arene e dai mercanti.
func _crypt_in_chunk(chunk: Vector2i) -> Dictionary:
	if _random_unit([seed_value, chunk.x, chunk.y, "crypt"]) >= float(_terrain["crypt_chance"]):
		return {}
	# Si provano i rombi interni del pezzo partendo da uno a caso.
	var side := CHUNK_CELLS - 2
	var first := posmod(hash([seed_value, chunk.x, chunk.y, "crypt_cell"]), side * side)
	for k in side * side:
		var index := (first + k) % (side * side)
		var cell := chunk * CHUNK_CELLS + Vector2i(1 + index % side, 1 + index / side)
		var center := cell_center(cell)
		if center.length() < float(_terrain["start_clear_radius"]) * 2.0:
			continue
		var arena := arena_near(center)
		if arena != Vector2.INF and center.distance_to(arena) < float(_arena["radius"]) + CELL * 3.0:
			continue
		var merchant := merchant_near(center)
		if merchant != Vector2.INF and center.distance_to(merchant) < float(_merchant["clear_radius"]) + CELL * 3.0:
			continue
		var flat := true
		var level := level_of(cell)
		for i in range(-1, 2):
			for j in range(-1, 2):
				var other := cell + Vector2i(i, j)
				if kind_of(other) != Kind.GROUND or level_of(other) != level or ramp_of(other) != Vector2i.ZERO:
					flat = false
		if flat:
			return make_obstacle("metro", center)
	return {}


## Un pezzo di terreno sotto i personaggi: disegnato una volta sola alla creazione.
class ChunkView:
	extends Node2D

	var world: World
	var chunk: Vector2i
	## Tutto il pezzo in una mesh sola (vedi MeshCanvas), da tenere finché si vede.
	var _mesh: ArrayMesh

	func _draw() -> void:
		var recorder := MeshCanvas.new()
		world.draw_chunk(recorder, chunk, -position)
		_mesh = recorder.commit(self)


## Blocco ridisegnato tra i personaggi: la posizione è il suo vertice più
## arretrato, così chi sta dietro viene disegnato prima e resta coperto.
class TerrainBlock:
	extends Node2D

	var world: World
	var cell: Vector2i
	## Altezza della cima.
	var top := 0.0
	var _outline := PackedVector2Array()
	## Il blocco in una mesh sola (vedi MeshCanvas).
	var _mesh: ArrayMesh

	func _ready() -> void:
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	## Sagoma sullo schermo (vedi World.is_covered), calcolata la prima volta.
	func outline() -> PackedVector2Array:
		if _outline.is_empty():
			_outline = world.block_outline(cell)
			top = world._top_height(cell)
		return _outline

	func _draw() -> void:
		var recorder := MeshCanvas.new()
		world.draw_cell(recorder, cell, -position)
		_mesh = recorder.commit(self)


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
