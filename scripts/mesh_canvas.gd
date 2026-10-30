class_name MeshCanvas
extends RefCounted
## Raccoglie in un'unica mesh i disegni del terreno (vedi World.ChunkView e
## World.TerrainBlock), che poi si disegna con una sola chiamata. Ogni
## poligono disegnato direttamente sarebbe una chiamata a sé: nel browser
## dei telefoni (WebGL) migliaia di chiamate per frame rallentano molto.
## Offre gli stessi metodi di CanvasItem usati da World, con lo stesso
## risultato: i triangoli si disegnano nell'ordine in cui arrivano e UV.y
## porta la luce come nei poligoni (vedi LightShaders.ground).

## Lati del cerchio (draw_circle): meno per i puntini piccoli.
const CIRCLE_SIDES := 16
const SMALL_CIRCLE_SIDES := 8
const SMALL_CIRCLE_RADIUS := 4.0

var _vertices := PackedVector2Array()
var _colors := PackedColorArray()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()


func draw_colored_polygon(points: PackedVector2Array, color: Color, uvs := PackedVector2Array()) -> void:
	var colors := PackedColorArray()
	colors.resize(points.size())
	colors.fill(color)
	draw_polygon(points, colors, uvs)


func draw_polygon(points: PackedVector2Array, colors: PackedColorArray, uvs := PackedVector2Array()) -> void:
	# Come CanvasItem: un poligono che non si scompone in triangoli non si disegna.
	var triangles := Geometry2D.triangulate_polygon(points)
	if triangles.is_empty():
		return
	_add(points, colors, uvs, triangles)


## Come draw_polygon, ma per al più quattro punti già in ordine (senza scomposizione).
func draw_primitive(points: PackedVector2Array, colors: PackedColorArray, uvs := PackedVector2Array()) -> void:
	var triangles := PackedInt32Array([0, 1, 2])
	if points.size() == 4:
		triangles.append_array([0, 2, 3])
	elif points.size() < 3:
		return
	if colors.size() == 1:
		var color := colors[0]
		colors = PackedColorArray()
		colors.resize(points.size())
		colors.fill(color)
	_add(points, colors, uvs, triangles)


## Segmenti a coppie di punti, come quadrilateri larghi width (almeno un pixel).
func draw_multiline(pairs: PackedVector2Array, color: Color, width := -1.0) -> void:
	var half := maxf(width, 1.0) / 2.0
	var colors := PackedColorArray([color, color, color, color])
	for k in range(0, pairs.size() - 1, 2):
		var across := (pairs[k + 1] - pairs[k]).orthogonal().normalized() * half
		draw_primitive(PackedVector2Array([pairs[k] + across, pairs[k + 1] + across, pairs[k + 1] - across, pairs[k] - across]), colors)


func draw_line(from: Vector2, to: Vector2, color: Color, width := -1.0) -> void:
	draw_multiline(PackedVector2Array([from, to]), color, width)


func draw_circle(center: Vector2, radius: float, color: Color) -> void:
	var sides := SMALL_CIRCLE_SIDES if radius < SMALL_CIRCLE_RADIUS else CIRCLE_SIDES
	var points := PackedVector2Array()
	for k in sides:
		points.append(center + Vector2.from_angle(k * TAU / sides) * radius)
	draw_colored_polygon(points, color)


func _add(points: PackedVector2Array, colors: PackedColorArray, uvs: PackedVector2Array, triangles: PackedInt32Array) -> void:
	var start := _vertices.size()
	_vertices.append_array(points)
	_colors.append_array(colors)
	if uvs.size() == points.size():
		_uvs.append_array(uvs)
	else:
		var zero := PackedVector2Array()
		zero.resize(points.size())
		_uvs.append_array(zero)
	for index in triangles:
		_indices.append(start + index)


## Disegna su canvas tutto ciò che si è raccolto e restituisce la mesh, che
## chi disegna deve tenere finché resta sullo schermo (null se non c'è nulla).
func commit(canvas: CanvasItem) -> ArrayMesh:
	if _indices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	canvas.draw_mesh(mesh, null)
	return mesh
