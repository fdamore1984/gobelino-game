class_name GoblinLook
## Aspetto dei goblin, uguale per il giocatore e per i nemici (che sono
## goblin anche loro, vedi Enemy): testa tonda con le orecchie a punta e
## una faccia fatta solo di due occhi piccoli e neri, spostati verso dove si
## guarda (niente bocca, niente "naso" a indicare la direzione). Solo forme
## geometriche, come il resto del gioco.
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
## Occhi: due puntini neri, raggio e distanza dal centro rispetto al
## raggio della testa (più vicini guardando di lato).
const DOT_SIZE := 0.11
const DOT_SPACING := 0.3
const COLOR_EAR_INSIDE := Color(0.95, 0.55, 0.55)
## Orecchie a punta ai lati della testa (si disegnano prima della testa).
## length: lunghezza rispetto a quella del giocatore; droop: quanto
## pendono verso il basso; torn: lato dell'orecchio con la punta strappata
## (-1 sinistro, 1 destro, 0 nessuno); ink: spessore del contorno nero
## (i nemici lo hanno uguale a quello del corpo).
static func ears(canvas: CanvasItem, radius: float, color: Color, length := 1.0, droop := 0.0, torn := 0.0, ink_width := -1.0) -> void:
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
		_fan(canvas, _grown(points, middle, ink_width if ink_width > 0.0 else Shapes.INK_WIDTH * 1.4), ink)
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


## Faccia: solo due occhi piccoli e neri che guardano dove si va; con
## look {"squint": true} (smorfia di dolore) diventano due trattini. Va
## disegnata per ultima.
static func face(canvas: CanvasItem, radius: float, facing: Vector2, alpha := 1.0, look := {}) -> void:
	if not face_visible(facing):
		return
	dots(canvas, eyes_center(radius, facing), radius, facing, alpha, look.get("squint", false))


## I due occhi a puntino attorno a center (anche per non morti e ghoul, che
## li hanno più avanti, vedi Enemy._draw_undead ed Enemy._draw_ghoul).
static func dots(canvas: CanvasItem, center: Vector2, radius: float, facing: Vector2, alpha := 1.0, squint := false) -> void:
	var size := maxf(radius * DOT_SIZE, 1.8)
	var spacing := radius * DOT_SPACING * (1.0 - 0.3 * absf(facing.x))
	var ink := Color(Shapes.INK, alpha)
	for side: float in [-1.0, 1.0]:
		var eye := center + Vector2(side * spacing, 0)
		if squint:
			canvas.draw_line(eye - Vector2(size * 1.4, 0), eye + Vector2(size * 1.4, 0), ink, maxf(size * 0.8, 1.5))
		else:
			Shapes.disc(canvas, eye, size, ink)
