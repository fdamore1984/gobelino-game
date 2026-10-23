class_name GoblinArt
## Il protagonista goblin disegnato in codice, nello stile del bozzetto a
## china: forme piene con il contorno ripassato a mano e ombre a tratteggio.
## Orecchie lunghe, ciuffo ritto, naso lungo e adunco, sguardo arrabbiato e
## arrogante. Il volto cambia con l'espressione:
##   "smug"   arrabbiato e arrogante (di solito): palpebre a metà, ghigno storto
##   "attack" urlo a bocca spalancata e occhi sgranati
##   "hurt"   occhi strizzati e denti stretti
##   "laugh"  risatina da goblin, occhi chiusi all'insù e bocca aperta
##   "dead"   occhi a croce
## Le posizioni sono rispetto al centro del corpo; facing è la direzione
## sul piano del terreno (come per Player).

const SKIN := Color(0.42, 0.72, 0.3)
const SKIN_DARK := Color(0.27, 0.5, 0.2)
const SKIN_LIGHT := Color(0.62, 0.85, 0.45)
const INK := Color(0.1, 0.08, 0.07)
const EYE := Color(1.0, 0.97, 0.85)
const MOUTH := Color(0.38, 0.08, 0.07)
const TONGUE := Color(0.75, 0.3, 0.3)
const TOOTH := Color(1.0, 0.96, 0.82)
const HAIR := Color(0.22, 0.12, 0.2)
const EAR_INSIDE := Color(0.72, 0.42, 0.38, 0.75)


## Busto un po' curvo con la pancia più chiara (radius: metà della larghezza).
static func draw_torso(canvas: CanvasItem, radius: float, facing: Vector2, skin: Color) -> void:
	var rng := _rng(3)
	var points := []
	for k in 14:
		var a := TAU * k / 14.0
		points.append(Vector2(cos(a) * radius * (0.8 if sin(a) > 0 else 0.95), sin(a) * radius * 0.72 + (radius * 0.12 if sin(a) > 0 else 0.0)))
	_blob(canvas, points, skin, rng)
	_hatch(canvas, Vector2(radius * 0.35, radius * 0.1), radius * 0.5)
	if facing.y > -0.3:
		canvas.draw_circle(Vector2(facing.x * radius * 0.3 - radius * 0.15, radius * 0.18), radius * 0.4, Color(SKIN_LIGHT, 0.5 * skin.a))


## Braccio magro dalla spalla alla mano (per la spada o la torcia).
static func draw_arm(canvas: CanvasItem, shoulder: Vector2, hand: Vector2, skin: Color) -> void:
	_line(canvas, shoulder, hand, skin, 5.0)
	canvas.draw_circle(hand, 4.0, SKIN_DARK)


## Testa con orecchie, ciuffo e, se guarda verso chi gioca, il volto.
static func draw_head(canvas: CanvasItem, head: Vector2, head_r: float, facing: Vector2, expression: String, skin: Color) -> void:
	var rng := _rng(11)
	var screen_f := Vector2(facing.x, facing.y * 0.5)
	_draw_ears(canvas, head, head_r, screen_f, skin, rng)
	var skull := []
	for k in 20:
		var a := TAU * k / 20.0
		var y := sin(a) * head_r * 0.9
		if y > 0.0:
			# Sotto, la mascella si stringe verso il mento a punta.
			y += head_r * 0.25 * pow(sin(a), 3.0)
		skull.append(head + Vector2(cos(a) * head_r * (1.0 - 0.18 * maxf(sin(a), 0.0)), y))
	_blob(canvas, skull, skin, rng)
	_hatch(canvas, head + Vector2(head_r * 0.45, head_r * 0.25), head_r * 0.45)
	for k in 7:
		var a := -PI / 2.0 + (k - 3) * 0.18
		var root := head + Vector2((k - 3) * head_r * 0.1, -head_r * 0.86) - screen_f * head_r * 0.18
		_line(canvas, root, root + Vector2.from_angle(a) * head_r * (0.45 + (k % 3) * 0.18), HAIR, 1.3)
	if facing.y > -0.3:
		_draw_face(canvas, head, head_r, facing, expression, skin)
	else:
		# Di spalle: una piega leggera della nuca.
		canvas.draw_arc(head + Vector2(0, head_r * 0.2), head_r * 0.45, 0.3, PI - 0.3, 10, Color(INK, 0.35), 1.0)


static func _draw_ears(canvas: CanvasItem, head: Vector2, head_r: float, screen_f: Vector2, skin: Color, rng: RandomNumberGenerator) -> void:
	for k: float in [-1.0, 1.0]:
		var base := head + Vector2(k * head_r * 0.78, -head_r * 0.12) - screen_f * head_r * 0.14
		var tip := head + Vector2(k * head_r * 2.0, -head_r * 0.8) - screen_f * head_r * 0.36
		_blob(canvas, [base + Vector2(0, -head_r * 0.36), tip, base + Vector2(0, head_r * 0.34)], skin, rng)
		canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(k * 3, -head_r * 0.14), tip - Vector2(k * head_r * 0.4, -2), base + Vector2(k * 3, head_r * 0.16)]), Color(EAR_INSIDE, EAR_INSIDE.a * skin.a))
		# Due ciuffetti di peli sulla punta.
		var out := (tip - base).normalized()
		for h in 2:
			var from := tip - out * head_r * (0.14 + h * 0.14)
			canvas.draw_line(from, from + out.rotated(-k * (0.35 + h * 0.3)) * head_r * 0.32, Color(INK, 0.8), 1.0)


static func _draw_face(canvas: CanvasItem, head: Vector2, head_r: float, facing: Vector2, expression: String, skin: Color) -> void:
	var frontal := clampf(facing.y, 0.0, 1.0)
	var turn := facing.x
	var face := head + Vector2(turn * head_r * 0.3, head_r * 0.05)
	var spread := head_r * 0.42 * clampf(frontal + 0.3, 0.35, 1.0)
	var profile := absf(turn) > 0.85
	# Rughe sulla fronte: più fitte quando è arrabbiato.
	var wrinkles := 1 if expression == "laugh" else 2
	for k in wrinkles:
		var y := -head_r * (0.5 + k * 0.12)
		_ink(canvas, face + Vector2(-head_r * 0.18, y), face + Vector2(head_r * 0.18, y - 1.0), 1.0)
	for k: float in [-1.0, 1.0]:
		if profile and signf(k) != signf(turn):
			continue
		_draw_eye(canvas, face + Vector2(k * spread, -head_r * 0.18), head_r, k, turn, profile, expression, skin)
	_draw_mouth(canvas, face + Vector2(turn * head_r * 0.12, head_r * 0.5), head_r, frontal, turn, expression)
	_draw_nose(canvas, face, head_r, turn, skin)


## Occhio e sopracciglio: k è -1 per quello a sinistra, +1 per quello a destra.
static func _draw_eye(canvas: CanvasItem, eye: Vector2, head_r: float, k: float, turn: float, profile: bool,
		expression: String, skin: Color) -> void:
	var w := head_r * 0.27 * (0.6 if profile else 1.0)
	var h := head_r * 0.2
	match expression:
		"hurt":
			# Occhi strizzati, a punta verso il naso: > <
			_ink(canvas, eye + Vector2(-k * w, -h * 0.7), eye + Vector2(k * w * 0.6, 0), 2.2)
			_ink(canvas, eye + Vector2(k * w * 0.6, 0), eye + Vector2(-k * w, h * 0.7), 2.2)
			_ink(canvas, eye + Vector2(-k * w * 1.1, -h * 2.2), eye + Vector2(k * w * 0.9, -h * 1.5), 2.6)
			return
		"laugh":
			# Occhi chiusi dalla contentezza, ad arco all'insù.
			canvas.draw_arc(eye + Vector2(0, h * 0.4), w * 0.9, PI + 0.4, TAU - 0.4, 10, INK, 2.4)
			_ink(canvas, eye + Vector2(-k * w * 1.1, -h * 1.9), eye + Vector2(k * w * 0.9, -h * 1.6), 2.6)
			return
		"dead":
			_ink(canvas, eye + Vector2(-w * 0.7, -h * 0.8), eye + Vector2(w * 0.7, h * 0.8), 2.2)
			_ink(canvas, eye + Vector2(w * 0.7, -h * 0.8), eye + Vector2(-w * 0.7, h * 0.8), 2.2)
			return
	var almond := PackedVector2Array()
	var open := 1.15 if expression == "attack" else 1.0
	for s in 13:
		var a := PI * s / 12.0
		almond.append(eye + Vector2(-cos(a) * w, -sin(a) * h * open))
	for s in range(11, 0, -1):
		var a := PI * s / 12.0
		almond.append(eye + Vector2(-cos(a) * w, sin(a) * h * 0.55 * open))
	canvas.draw_colored_polygon(almond, Color(EYE, skin.a))
	# Pupille piccole e fisse quando urla, sguardo di lato quando è arrogante.
	var pupil_size := h * (0.42 if expression == "attack" else 0.62)
	var look := turn * w * 0.35 + (w * 0.25 if expression == "smug" else 0.0)
	var pupil := eye + Vector2(look - k * w * 0.1, h * 0.1)
	canvas.draw_circle(pupil, pupil_size, INK)
	canvas.draw_circle(pupil + Vector2(-1.2, -1.2), h * 0.16, Color(1, 1, 1, 0.9 * skin.a))
	if expression == "smug":
		# Palpebra calata a metà sull'occhio, storta: aria di superiorità. È
		# la parte dell'occhio sopra una linea obliqua.
		var left := eye + Vector2(-w * 1.2, -h * 0.32 + k * h * 0.28)
		var right := eye + Vector2(w * 1.2, -h * 0.32 - k * h * 0.28)
		var above := PackedVector2Array([left, right, right + Vector2(0, -h * 3.0), left + Vector2(0, -h * 3.0)])
		var bigger := PackedVector2Array()
		for point in almond:
			bigger.append(eye + (point - eye) * 1.08)
		for lid in Geometry2D.intersect_polygons(bigger, above):
			canvas.draw_colored_polygon(lid, skin.darkened(0.08))
		_ink(canvas, eye + Vector2(-w * 1.05, -h * 0.32 + k * h * 0.26), eye + Vector2(w * 1.05, -h * 0.32 - k * h * 0.26), 2.4)
	else:
		# Palpebra superiore più bassa verso il naso: sguardo arrabbiato.
		_ink(canvas, eye + Vector2(-k * w * 1.0, -h * 0.6 * open), eye + Vector2(k * w * 1.05, -h * 1.05 * open), 2.2)
	var outline := almond.duplicate()
	outline.append(almond[0])
	canvas.draw_polyline(outline, Color(INK, 0.85), 1.1)
	# Sopracciglio aggrottato: basso verso il naso e alto all'esterno
	# (ancora di più quando attacca).
	var drop := 1.05 if expression == "attack" else 0.85
	_ink(canvas, eye + Vector2(-k * w * 0.8, -h * (2.3 - drop * 1.2)), eye + Vector2(k * w * 1.25, -h * 2.45), 3.6)


static func _draw_mouth(canvas: CanvasItem, mouth: Vector2, head_r: float, frontal: float, turn: float, expression: String) -> void:
	var width := head_r * 0.6 * clampf(frontal + 0.35, 0.45, 1.0)
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	# Quanto è aperta, quanto sale ogni angolo (ghigno storto da un lato).
	var depth := 0.1
	var left_up := 0.0
	var right_up := 0.0
	match expression:
		"smug":
			depth = 0.12
			left_up = -0.02
			right_up = 0.2
		"attack":
			depth = 0.42
			left_up = 0.05
			right_up = 0.05
			width *= 0.85
		"hurt":
			depth = 0.12
			left_up = -0.08
			right_up = -0.08
		"laugh":
			depth = 0.36
			left_up = 0.16
			right_up = 0.16
		"dead":
			depth = 0.06
	for s in 11:
		var t := s / 10.0
		var x := (t - 0.5) * 2.0 * width
		var corner := lerpf(left_up, right_up, t) * (1.0 - sin(t * PI))
		upper.append(mouth + Vector2(x, -sin(t * PI) * head_r * 0.03 - corner * head_r))
		lower.append(mouth + Vector2(x, sin(t * PI) * head_r * depth - corner * head_r))
	# Gli angoli sono in comune tra il labbro sopra e quello sotto.
	var inside := upper.duplicate()
	for s in range(lower.size() - 2, 0, -1):
		inside.append(lower[s])
	canvas.draw_colored_polygon(inside, MOUTH)
	if expression in ["attack", "laugh"]:
		canvas.draw_circle(mouth + Vector2(0, head_r * depth * 0.65), width * 0.3, TONGUE)
	# Denti aguzzi: tutti quando urla o ride, solo dal lato del ghigno quando
	# è arrogante, stretti quando è colpito.
	var first := 0
	if expression == "smug":
		first = 2
	for s in range(first, 5):
		var t := (s + 0.5) / 5.0
		var at := upper[int(t * 10.0)]
		var size := head_r * (0.09 if s % 2 == 0 else 0.07)
		var length := size * (1.0 if expression == "hurt" else 1.9)
		canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-size, 0), at + Vector2(size, 0), at + Vector2(0, length)]), TOOTH)
	if expression in ["attack", "laugh", "hurt"]:
		for t: float in [0.22, 0.78]:
			var at := lower[int(t * 10.0)]
			var size := head_r * 0.07
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-size, 0), at + Vector2(size, 0), at + Vector2(0, -size * 2.2)]), TOOTH)
	var outline := inside.duplicate()
	outline.append(inside[0])
	canvas.draw_polyline(outline, INK, 1.5)
	# Pieghe agli angoli della bocca.
	for k: float in [-1.0, 1.0]:
		var up := right_up if k > 0.0 else left_up
		var corner := mouth + Vector2(k * width, -up * head_r)
		_ink(canvas, corner, corner + Vector2(k * head_r * 0.1, -head_r * (0.06 + up * 0.5)), 1.3)


## Naso lungo e adunco, sopra la bocca senza coprirla. È costruito come se
## guardasse a destra e specchiato se guarda a sinistra, così i punti non
## si incrociano mai.
static func _draw_nose(canvas: CanvasItem, face: Vector2, head_r: float, turn: float, skin: Color) -> void:
	var side := 1.0 if turn >= 0.0 else -1.0
	var amount := absf(turn)
	var root := face + Vector2(turn * head_r * 0.12, -head_r * 0.08)
	var tip := root + Vector2(turn * head_r * 0.75, head_r * 0.42)
	var half := head_r * 0.15
	var middle := root.lerp(tip, 0.6) + Vector2((half * 0.9 + amount * 3.0) * side, 0)
	var nose := PackedVector2Array([
		root + Vector2(-half * side, 0), root + Vector2(half * side, 0), middle,
		tip + Vector2(amount * 2.0 * side, 0), tip + Vector2((-amount * 2.0 - 1.0) * side, 3.0),
		root.lerp(tip, 0.75) + Vector2(-half * 0.8 * side, half * 0.6),
	])
	canvas.draw_colored_polygon(nose, skin)
	canvas.draw_colored_polygon(PackedVector2Array([root + Vector2(half * 0.2 * side, 0), root + Vector2(half * side, 0), middle, tip]), Color(SKIN_DARK, skin.a))
	var line := nose.duplicate()
	line.append(nose[0])
	canvas.draw_polyline(line, INK, 1.4)
	canvas.draw_circle(tip + Vector2((-amount * 4.0 - 2.0) * side, 1.0), 1.6, INK)


## Forma piena col contorno a china ripassato più volte (sempre uguale da
## un frame all'altro, così non tremola).
static func _blob(canvas: CanvasItem, points: Array, color: Color, rng: RandomNumberGenerator) -> void:
	var packed := PackedVector2Array(points)
	canvas.draw_colored_polygon(packed, color)
	var closed := packed.duplicate()
	closed.append(packed[0])
	for pass_index in 3:
		var jitter := PackedVector2Array()
		for point in closed:
			jitter.append(point + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)))
		canvas.draw_polyline(jitter, Color(INK, 0.75 * color.a), 1.1)


static func _line(canvas: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	canvas.draw_line(a + Vector2(0.8, 0.6), b + Vector2(0.6, 0.8), Color(INK, 0.8 * color.a), width + 2.0)
	canvas.draw_line(a, b, color, width)


static func _ink(canvas: CanvasItem, a: Vector2, b: Vector2, width: float) -> void:
	canvas.draw_line(a, b, INK, width)
	canvas.draw_line(a + Vector2(0.5, 0.4), b + Vector2(-0.4, 0.5), Color(INK, 0.5), width * 0.6)


## Ombra a tratteggio.
static func _hatch(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	for k in 6:
		var x := -radius * 0.6 + k * radius * 0.22
		canvas.draw_line(center + Vector2(x, -radius * 0.45), center + Vector2(x + radius * 0.35, radius * 0.4), Color(INK, 0.3), 1.0)


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
