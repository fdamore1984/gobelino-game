class_name BodyBlood
extends RefCounted
## Sangue sul corpo di un personaggio (giocatore e nemici): quanto è sporco
## (amount, da 0 a 1), la tinta rossa del corpo e gli schizzi sul corpo
## tondo (vedi BloodSplatter.body_texture), che compaiono via via più
## numerosi quanto più è sporco (gli ultimi comparsi sono i primi a sparire
## pulendosi). Si pulisce da solo, di clean_rate al secondo.
##
## Gli schizzi sono ritagliati sul cerchio del corpo, così non escono dalla
## sagoma: le loro forme, in un corpo di raggio 1, sono mesh preparate una
## volta sola e condivise da tutti i personaggi (LAYOUTS disposizioni).

const LAYOUTS := 4
const MAX_SPOTS := 10
## Il corpo, sporco del tutto, si tinge di rosso fino a questa parte.
const TINT := 0.4
const COLOR := Color(0.55, 0.02, 0.03)
const ALPHA := 0.9
## Raggio della macchia centrale degli schizzi, rispetto al corpo.
const SPOT_CORE := Vector2(0.12, 0.22)
const CIRCLE_SIDES := 24

## Disposizioni: ognuna è un elenco di schizzi {"mesh", "texture"}.
static var _layouts: Array[Array] = []

var amount := 0.0
var clean_rate := 0.0
var _spots: Array
var _count := 0


## layout: quale disposizione degli schizzi (qualsiasi intero); count:
## quanti schizzi al massimo, completamente sporco.
func _init(layout: int, count: int, clean := 0.0) -> void:
	_spots = _layout(layout)
	_count = mini(count, MAX_SPOTS)
	clean_rate = clean


func add(value: float) -> void:
	amount = clampf(amount + value, 0.0, 1.0)


## Si pulisce un po'. Restituisce true finché c'è sangue da disegnare.
func update(delta: float) -> bool:
	if amount <= 0.0:
		return false
	amount = move_toward(amount, 0.0, clean_rate * delta)
	return true


## Colore del corpo tinto dal sangue.
func tint(body: Color) -> Color:
	if amount <= 0.0:
		return body
	return Color(body.lerp(COLOR, amount * TINT), body.a)


## Schizzi su un corpo tondo di raggio radius centrato in center.
func draw(canvas: CanvasItem, radius: float, alpha: float, center := Vector2.ZERO) -> void:
	if amount <= 0.0:
		return
	var transform := Transform2D(0.0, Vector2(radius, radius), 0.0, center)
	for k in _count:
		var shown := clampf(amount * _count - k, 0.0, 1.0)
		if shown <= 0.0:
			break
		var spot: Dictionary = _spots[k]
		canvas.draw_mesh(spot["mesh"], spot["texture"], transform, Color(COLOR, ALPHA * shown * alpha))


static func _layout(index: int) -> Array:
	if _layouts.is_empty():
		var circle := PackedVector2Array()
		for k in CIRCLE_SIDES:
			circle.append(Vector2.from_angle(TAU * k / CIRCLE_SIDES) * 0.97)
		for l in LAYOUTS:
			var rng := RandomNumberGenerator.new()
			rng.seed = 7 + l
			var spots := []
			for k in MAX_SPOTS:
				var at := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.05, 0.72)
				var core := rng.randf_range(SPOT_CORE.x, SPOT_CORE.y)
				spots.append({"mesh": _clipped_mesh(at, core, rng.randf() * TAU, circle),
						"texture": BloodSplatter.body_texture(rng.randi())})
			_layouts.append(spots)
	return _layouts[posmod(index, LAYOUTS)]


## Mesh dello schizzo centrato in at (raggio della macchia centrale core,
## ruotato di angle) ritagliato sul cerchio, con le coordinate della texture.
static func _clipped_mesh(at: Vector2, core: float, angle: float, circle: PackedVector2Array) -> ArrayMesh:
	var half := core / BloodSplatter.BODY_CORE
	var along := Vector2.from_angle(angle) * half
	var across := along.orthogonal()
	var quad := PackedVector2Array([at - along + across, at + along + across, at + along - across, at - along - across])
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	for part in Geometry2D.intersect_polygons(quad, circle):
		var points := PackedVector2Array()
		for index in Geometry2D.triangulate_polygon(part):
			points.append(part[index])
		for point in points:
			var local := point - at
			vertices.append(point)
			uvs.append(Vector2(local.dot(along), -local.dot(across)) / (half * half) * 0.5 + Vector2(0.5, 0.5))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
