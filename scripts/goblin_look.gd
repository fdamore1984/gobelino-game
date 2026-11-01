class_name GoblinLook
## Aspetto dei goblin, uguale per il giocatore e per i nemici (che sono
## goblin anche loro, vedi Enemy): testa tonda con le orecchie a punta, gli
## occhioni che guardano dove si va (niente "naso" a indicare la
## direzione) e la bocca. Solo forme geometriche, come il resto del gioco.
##
## Regole perché la faccia resti sempre visibile (vedi Player._draw ed
## Enemy._draw): le orecchie vanno prima della testa, che le copre alla
## base; armi, fiaschette e torcia vanno prima della faccia, che è
## l'ultima cosa disegnata; guardando quasi a nord il goblin è di spalle e
## la faccia non si vede.
## Coordinate rispetto al centro della testa.

## Guardando a nord oltre questa soglia (facing.y) il goblin è di spalle.
const FACE_HIDDEN_BELOW := -0.85
## Centro degli occhi: spostato verso dove si guarda e un po' in alto.
const EYE_SHIFT := 0.3
const EYE_HEIGHT := -0.18
## La bocca sta sotto gli occhi.
const MOUTH_BELOW := 0.42
const COLOR_EAR_INSIDE := Color(0.95, 0.55, 0.55)
const COLOR_TEETH := Color(1.0, 0.98, 0.9)
const COLOR_MOUTH := Color(0.3, 0.05, 0.06)
## Bocche possibili dei nemici (il giocatore sorride).
const MOUTHS := ["grin", "frown", "teeth", "fang", "open"]


## Varianti casuali di un goblin nemico, dal seme del suo aspetto: orecchie
## più o meno lunghe e pendenti (a volte una strappata), occhi più grandi o
## più piccoli, bocca, cicatrice, benda su un occhio e porri.
static func variant(look_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed * 7919 + 13
	return {
		"ear_length": rng.randf_range(0.75, 1.4),
		"ear_droop": rng.randf_range(-0.25, 0.55),
		"torn": [-1.0, 1.0][rng.randi() % 2] if rng.randf() < 0.25 else 0.0,
		"eye_size": rng.randf_range(0.17, 0.26),
		"mouth": MOUTHS[rng.randi() % MOUTHS.size()],
		"scar": rng.randf() < 0.3,
		"patch": [-1.0, 1.0][rng.randi() % 2] if rng.randf() < 0.12 else 0.0,
		"warts": rng.randi() % 3 if rng.randf() < 0.4 else 0,
		"wart_seed": rng.randi(),
	}


## Orecchie a punta ai lati della testa (si disegnano prima della testa).
## length: lunghezza rispetto a quella del giocatore; droop: quanto
## pendono verso il basso; torn: lato dell'orecchio con la punta strappata
## (-1 sinistro, 1 destro, 0 nessuno).
static func ears(canvas: CanvasItem, radius: float, color: Color, length := 1.0, droop := 0.0, torn := 0.0) -> void:
	var ink := Color(Shapes.INK, color.a)
	var inside := Color(COLOR_EAR_INSIDE, color.a * 0.8)
	for side: float in [-1.0, 1.0]:
		var base_top := Vector2(side * radius * 0.8, -radius * 0.3)
		var base_bottom := Vector2(side * radius * 0.9, radius * 0.25)
		var tip := Vector2(side * radius * (0.85 + 0.65 * length), -radius * (0.6 - droop) * length)
		var points := PackedVector2Array([base_top, tip, base_bottom])
		if torn == side:
			# Punta strappata: un morso a V al posto della punta.
			var cut := tip.lerp(base_top, 0.35)
			var cut2 := tip.lerp(base_bottom, 0.35)
			points = PackedVector2Array([base_top, cut, cut.lerp(cut2, 0.5).lerp(Vector2(side * radius, 0.0), 0.3), cut2, base_bottom])
		# Solo primitive (triangoli): nel renderer Compatibility i poligoni
		# ridisegnati a ogni frame costano molto (vedi Shapes).
		var middle := (base_top + base_bottom + tip) / 3.0
		_fan(canvas, _grown(points, middle, Shapes.INK_WIDTH * 1.4), ink)
		_fan(canvas, points, color)
		_fan(canvas, _scaled(points, (base_top + base_bottom) / 2.0, 0.55), inside)


## Triangoli a ventaglio dal primo punto (il poligono dell'orecchio è convesso
## o quasi).
static func _fan(canvas: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	var colors := PackedColorArray([color])
	for k in range(1, points.size() - 1):
		canvas.draw_primitive(PackedVector2Array([points[0], points[k], points[k + 1]]), colors, PackedVector2Array())


static func _grown(points: PackedVector2Array, middle: Vector2, width: float) -> PackedVector2Array:
	var grown := PackedVector2Array()
	for point in points:
		grown.append(point + (point - middle).normalized() * width)
	return grown


static func _scaled(points: PackedVector2Array, middle: Vector2, factor: float) -> PackedVector2Array:
	var scaled := PackedVector2Array()
	for point in points:
		scaled.append(middle.lerp(point, factor))
	return scaled


## Testa tonda col contorno a inchiostro e il riflesso in alto a sinistra.
static func head(canvas: CanvasItem, radius: float, color: Color) -> void:
	Shapes.ink_disc(canvas, Vector2.ZERO, radius, color)
	canvas.draw_arc(Vector2.ZERO, radius * 0.7, PI * 1.1, PI * 1.45, 10, Color(color.lightened(0.4), color.a * 0.8), maxf(radius * 0.14, 2.0))


static func face_visible(facing: Vector2) -> bool:
	return facing.y >= FACE_HIDDEN_BELOW


static func eyes_center(radius: float, facing: Vector2) -> Vector2:
	return facing * radius * EYE_SHIFT + Vector2(0, radius * EYE_HEIGHT)


## Faccia: occhioni con le pupille che guardano dove si va, bocca e, per i
## nemici, i dettagli della variante (vedi variant). Va disegnata per ultima.
static func face(canvas: CanvasItem, radius: float, facing: Vector2, eye_size: float, angry: bool, mouth: String,
		alpha := 1.0, look := {}) -> void:
	if not face_visible(facing):
		return
	var eyes := eyes_center(radius, facing)
	var size := maxf(radius * eye_size, 3.5)
	var ink := Color(Shapes.INK, alpha)
	Shapes.eyes(canvas, eyes, size, facing, angry, alpha)
	var spacing := size * 1.25 * (1.0 - 0.3 * absf(facing.x))
	var patch: float = look.get("patch", 0.0)
	if patch != 0.0:
		# Benda nera su un occhio, col laccio che gira attorno alla testa.
		var eye := eyes + Vector2(patch * spacing, 0)
		Shapes.oval(canvas, eye, Vector2(size * 1.15, size * 1.35), ink)
		canvas.draw_line(eye + Vector2(-radius * 0.5, -size * 1.4), eye + Vector2(radius * 0.5, size * 0.2), ink, maxf(radius * 0.07, 1.5))
	if look.get("scar", false):
		# Cicatrice di traverso sull'altro occhio.
		var eye := eyes + Vector2(-(patch if patch != 0.0 else 1.0) * spacing, 0)
		var a := eye + Vector2(-size * 0.9, -size * 1.6)
		var b := eye + Vector2(size * 0.7, size * 1.5)
		canvas.draw_line(a, b, Color(0.55, 0.15, 0.15, alpha), maxf(radius * 0.08, 1.5))
		for k in 3:
			var at := a.lerp(b, 0.25 + 0.25 * k)
			canvas.draw_line(at + Vector2(-size * 0.3, size * 0.1), at + Vector2(size * 0.3, -size * 0.1), Color(0.55, 0.15, 0.15, alpha), maxf(radius * 0.05, 1.0))
	var warts: int = look.get("warts", 0)
	if warts > 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = look.get("wart_seed", 0)
		for k in warts:
			var at := eyes + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(0.25, 0.55)) * radius
			Shapes.disc(canvas, at, radius * 0.07, Color(0.2, 0.3, 0.12, alpha * 0.8))
	_mouth(canvas, eyes + Vector2(0, radius * MOUTH_BELOW), radius, mouth, alpha)


static func _mouth(canvas: CanvasItem, at: Vector2, radius: float, kind: String, alpha: float) -> void:
	var ink := Color(Shapes.INK, alpha)
	var width := maxf(radius * 0.09, 2.0)
	var half := radius * 0.28
	match kind:
		"smile":
			canvas.draw_arc(at + Vector2(0, -half * 0.6), half, PI * 0.2, PI * 0.8, 10, ink, width)
		"grin":
			# Ghigno storto con un dente.
			canvas.draw_arc(at + Vector2(0, -half * 0.7), half * 1.1, PI * 0.15, PI * 0.85, 10, ink, width)
			_fan(canvas, PackedVector2Array([at + Vector2(half * 0.2, half * 0.25), at + Vector2(half * 0.55, half * 0.2),
					at + Vector2(half * 0.38, half * 0.7)]), Color(COLOR_TEETH, alpha))
		"frown":
			canvas.draw_arc(at + Vector2(0, half * 0.8), half, PI * 1.2, PI * 1.8, 10, ink, width)
		"teeth":
			# Denti serrati: una fila bianca a zig-zag.
			var rect := Rect2(at + Vector2(-half, -half * 0.3), Vector2(half * 2.0, half * 0.75))
			canvas.draw_rect(rect.grow(width * 0.6), ink)
			canvas.draw_rect(rect, Color(COLOR_TEETH, alpha))
			for k in range(1, 4):
				var x := rect.position.x + rect.size.x * k / 4.0
				canvas.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), ink, maxf(width * 0.5, 1.0))
		"fang":
			# Bocca dritta con due zanne che escono verso l'alto.
			canvas.draw_line(at + Vector2(-half, 0), at + Vector2(half, 0), ink, width)
			for side: float in [-1.0, 1.0]:
				var root := at + Vector2(side * half * 0.6, 0)
				_fan(canvas, PackedVector2Array([root + Vector2(-half * 0.18, 0), root + Vector2(half * 0.18, 0),
						root + Vector2(0, -half * 0.55)]), Color(COLOR_TEETH, alpha))
		"open":
			Shapes.oval(canvas, at, Vector2(half * 0.75, half * 0.6), ink)
			Shapes.oval(canvas, at, Vector2(half * 0.55, half * 0.42), Color(COLOR_MOUTH, alpha))
