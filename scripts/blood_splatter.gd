class_name BloodSplatter
## Texture del sangue disegnate in codice, in attesa degli sprite
## definitivi, al posto dei dischi tondi:
## - schizzi: una macchia centrale frastagliata con rivoli che partono verso
##   l'esterno (più numerosi verso destra, +X, la direzione del colpo) e
##   goccioline sparse (macchie a terra, vedi GroundFx);
## - schizzi raccolti: come sopra ma più compatti, per il sangue sul corpo
##   di giocatore e nemici (vedi BodyBlood);
## - pozza: una macchia larga a lobi, più scura al centro, per chi muore;
## - ferita: uno squarcio rosso con il bordo acceso e il fondo scuro (vedi
##   Wounds).
## Create una volta sola e condivise. A differenza del resto del gioco
## (filtro "nearest") sono filtrate in modo lineare con le mipmap, così
## restano morbide anche disegnate piccole.

const SPLAT_SIZE := 64
const POOL_SIZE := 128
const WOUND_SIZE := 64
## Varianti di ogni forma (scelte a caso, sempre le stesse a ogni avvio).
const VARIANTS := 6
## Raggio della macchia centrale rispetto a metà texture: chi disegna dà il
## raggio della macchia e la texture si allarga di conseguenza.
const SPLAT_CORE := 0.36
const BODY_CORE := 0.5
const POOL_CORE := 0.58
const WOUND_CORE := 0.9

static var _splats: Array[Texture2D] = []
static var _body_splats: Array[Texture2D] = []
static var _pools: Array[Texture2D] = []
static var _wound: Texture2D


## Schizzo a terra (variant: qualsiasi intero, si prende il resto).
static func splat_texture(variant: int) -> Texture2D:
	if _splats.is_empty():
		for v in VARIANTS:
			_splats.append(_make_splat(SPLAT_SIZE, 100 + v, SPLAT_CORE, 1.0))
	return _splats[posmod(variant, VARIANTS)]


## Schizzo raccolto, per il sangue sul corpo.
static func body_texture(variant: int) -> Texture2D:
	if _body_splats.is_empty():
		for v in VARIANTS:
			_body_splats.append(_make_splat(SPLAT_SIZE, 200 + v, BODY_CORE, 0.45))
	return _body_splats[posmod(variant, VARIANTS)]


## Pozza di sangue di chi è morto.
static func pool_texture(variant: int) -> Texture2D:
	if _pools.is_empty():
		for v in VARIANTS:
			_pools.append(_make_pool(300 + v))
	return _pools[posmod(variant, VARIANTS)]


static func wound_texture() -> Texture2D:
	if _wound == null:
		_wound = _make_wound()
	return _wound


## Disegna una texture del sangue centrata in at: core è il raggio della
## macchia centrale (core_ratio: la sua parte di metà texture), angle la
## rotazione in pianta e squash lo schiacciamento verticale dopo la
## rotazione (0.5 per le macchie a terra). Rispetta la trasformazione
## corrente del canvas.
static func draw(canvas: CanvasItem, texture: Texture2D, at: Vector2, core: float, core_ratio: float,
		angle: float, color: Color, squash := 1.0) -> void:
	var half := core / core_ratio
	var along := Vector2.from_angle(angle) * half
	var across := along.orthogonal()
	var points := PackedVector2Array()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var offset := along * corner.x - across * corner.y
		points.append(at + Vector2(offset.x, offset.y * squash))
	canvas.draw_primitive(points, PackedColorArray([color, color, color, color]),
			PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), texture)


## Texture filtrata in modo lineare con le mipmap (vedi sopra).
static func _smooth(image: Image) -> Texture2D:
	image.generate_mipmaps()
	var texture := CanvasTexture.new()
	texture.diffuse_texture = ImageTexture.create_from_image(image)
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return texture


## Schizzo: macchia centrale con il bordo a onde, rivoli che si assottigliano
## verso l'esterno con una goccia in fondo, e goccioline sparse. reach
## (0-1) è quanto si allungano rivoli e goccioline nello spazio rimasto.
static func _make_splat(size: int, seed_value: int, core_ratio: float, reach: float) -> Texture2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var half := size / 2.0
	var core := half * core_ratio
	var waves := _waves(rng, 6, Vector2(0.05, 0.16))
	var room := (half - 2.0 - core) * reach
	var streaks: Array[Dictionary] = []
	for k in rng.randi_range(4, 7):
		# Quasi tutti verso +X (la direzione del colpo), qualcuno di lato.
		var angle := rng.randf_range(-0.9, 0.9) if k < 3 else rng.randf_range(-PI, PI)
		var drop := rng.randf_range(1.0, 2.2) * size / 64.0
		var length := core + room * rng.randf_range(0.45, 1.0) - drop * 2.4
		streaks.append({"direction": Vector2.from_angle(angle), "length": length,
				"width": core * rng.randf_range(0.18, 0.32), "drop": drop})
	var drops: Array[Vector3] = []
	for k in rng.randi_range(5, 10):
		var radius := rng.randf_range(0.7, 2.0) * size / 64.0
		var at := Vector2.from_angle(rng.randf_range(-1.2, 1.2) if k % 3 != 0 else rng.randf() * TAU) \
				* (core + room * rng.randf_range(0.3, 1.0) - radius)
		drops.append(Vector3(at.x, at.y, radius))
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for x in size:
		for y in size:
			var p := Vector2(x + 0.5, y + 0.5) - Vector2(half, half)
			var distance := p.length()
			# Quanto si è dentro la forma, in pixel (positivo = dentro).
			var inside := core * _wave(waves, p.angle()) - distance
			for streak in streaks:
				var direction: Vector2 = streak["direction"]
				var t := clampf(p.dot(direction) / (streak["length"] as float), 0.0, 1.0)
				var on_line := direction * t * (streak["length"] as float)
				var width: float = streak["width"] * (1.0 - 0.75 * t)
				inside = maxf(inside, width - p.distance_to(on_line))
				inside = maxf(inside, streak["drop"] - p.distance_to(direction * ((streak["length"] as float) + streak["drop"] * 1.3)))
			for drop in drops:
				inside = maxf(inside, drop.z - p.distance_to(Vector2(drop.x, drop.y)))
			var alpha := clampf(inside + 0.5, 0.0, 1.0)
			# Più scuro verso il bordo, dove il sangue si rapprende.
			var shade := lerpf(0.72, 1.0, clampf(inside / (core * 0.5), 0.0, 1.0))
			image.set_pixel(x, y, Color(shade, shade, shade, alpha))
	return _smooth(image)


## Pozza: una macchia larga a lobi, con qualche lobo staccato attaccato al
## bordo, più scura al centro (il sangue è più spesso) e con un riflesso.
static func _make_pool(seed_value: int) -> Texture2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var half := POOL_SIZE / 2.0
	var core := half * POOL_CORE
	var waves := _waves(rng, 4, Vector2(0.06, 0.13))
	var lobes: Array[Vector3] = []
	for k in rng.randi_range(3, 5):
		var radius := core * rng.randf_range(0.18, 0.3)
		var at := Vector2.from_angle(rng.randf() * TAU) * (core * rng.randf_range(0.85, 1.05))
		lobes.append(Vector3(at.x, at.y, minf(radius, half - 2.0 - at.length())))
	var shine := Vector2.from_angle(rng.randf_range(-2.5, -0.6)) * core * 0.4
	var image := Image.create(POOL_SIZE, POOL_SIZE, false, Image.FORMAT_RGBA8)
	for x in POOL_SIZE:
		for y in POOL_SIZE:
			var p := Vector2(x + 0.5, y + 0.5) - Vector2(half, half)
			var inside := core * _wave(waves, p.angle()) - p.length()
			for lobe in lobes:
				inside = maxf(inside, lobe.z - p.distance_to(Vector2(lobe.x, lobe.y)))
			var alpha := clampf(inside + 0.5, 0.0, 1.0)
			var shade := lerpf(1.0, 0.68, clampf(inside / (core * 0.6), 0.0, 1.0))
			shade += 0.35 * (1.0 - smoothstep(0.0, core * 0.22, p.distance_to(shine)))
			image.set_pixel(x, y, Color(shade, shade, shade, alpha))
	return _smooth(image)


## Ferita: uno squarcio orizzontale a fuso (più largo al centro, a punta
## alle estremità, con il bordo un po' frastagliato), fondo rosso scuro,
## bordo rosso acceso e un livido attorno. Già colorata: va disegnata con
## il bianco (e l'alfa per farla svanire).
static func _make_wound() -> Texture2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 400
	var half := WOUND_SIZE / 2.0
	var length := half * WOUND_CORE
	var image := Image.create(WOUND_SIZE, WOUND_SIZE, false, Image.FORMAT_RGBA8)
	var phase := rng.randf() * TAU
	for x in WOUND_SIZE:
		for y in WOUND_SIZE:
			var p := Vector2(x + 0.5, y + 0.5) - Vector2(half, half)
			var u := clampf(absf(p.x) / length, 0.0, 1.0)
			var width := half * 0.26 * (1.0 - u * u) * (1.0 + 0.25 * sin(p.x * 0.9 + phase))
			var depth := width - absf(p.y)
			var color := Color(0, 0, 0, 0)
			if depth > -4.0 and u < 1.0:
				# Livido attorno, bordo acceso, fondo scuro.
				color = Color(0.45, 0.05, 0.06, 0.45 * clampf((depth + 4.0) / 4.0, 0.0, 1.0))
				if depth > -0.5:
					color = Color(0.95, 0.16, 0.12).lerp(Color(0.38, 0.0, 0.03), ease(clampf(depth / maxf(width, 0.5), 0.0, 1.0), 2.0))
					color.a = clampf(depth + 1.0, 0.0, 1.0)
			image.set_pixel(x, y, color)
	return _smooth(image)


## Onde del bordo: ampiezza e fase di qualche armonica, a caso.
static func _waves(rng: RandomNumberGenerator, count: int, amplitude: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for k in count:
		result.append(Vector2(rng.randf_range(amplitude.x, amplitude.y) / (1.0 + k * 0.3), rng.randf() * TAU))
	return result


static func _wave(waves: Array[Vector2], angle: float) -> float:
	var value := 1.0
	for k in waves.size():
		value += waves[k].x * sin(angle * (k + 2) + waves[k].y)
	return value
