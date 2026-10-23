class_name Shapes
## Forme che si ridisegnano a ogni frame, in modo economico. Nel renderer
## Compatibility draw_circle, draw_colored_polygon e draw_polyline creano
## ogni volta un nuovo poligono da mandare alla scheda video, e con tanti
## nemici sullo schermo il gioco rallenta: qui i cerchi sono rettangoli con
## la texture di un disco (si disegnano insieme in un colpo solo) e i
## poligoni fissi sono mesh preparate una volta sola.

const DISC_SIZE := 64

static var _disc: ImageTexture
## Forma (chiave) -> mesh già pronta, per draw_mesh.
static var _meshes := {}


## Disco pieno, come draw_circle.
static func disc(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	if radius <= 0.0:
		return
	canvas.draw_texture_rect(disc_texture(), Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


static func disc_texture() -> Texture2D:
	if _disc == null:
		var image := Image.create(DISC_SIZE, DISC_SIZE, false, Image.FORMAT_RGBA8)
		var middle := Vector2(DISC_SIZE, DISC_SIZE) / 2.0
		for x in DISC_SIZE:
			for y in DISC_SIZE:
				var distance := Vector2(x + 0.5, y + 0.5).distance_to(middle)
				image.set_pixel(x, y, Color(1, 1, 1, clampf(middle.x - distance, 0.0, 1.0)))
		_disc = ImageTexture.create_from_image(image)
	return _disc


## Mesh bianca del poligono (da colorare con il modulate di draw_mesh),
## ricordata con la chiave data.
static func polygon_mesh(key: Variant, points: PackedVector2Array) -> ArrayMesh:
	if not _meshes.has(key):
		var indices := Geometry2D.triangulate_polygon(points)
		var vertices := PackedVector2Array()
		for index in indices:
			vertices.append(points[index])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var mesh := ArrayMesh.new()
		if not vertices.is_empty():
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_meshes[key] = mesh
	return _meshes[key]


## Contorno chiuso del poligono, largo width, come mesh (vedi polygon_mesh).
static func outline_mesh(key: Variant, points: PackedVector2Array, width: float) -> ArrayMesh:
	if not _meshes.has(key):
		var vertices := PackedVector2Array()
		var half := width / 2.0
		for i in points.size():
			var a := points[i]
			var b := points[(i + 1) % points.size()]
			var side := (b - a).normalized().orthogonal() * half
			# Ogni lato è un rettangolo, allungato un poco per chiudere gli angoli.
			var along := (b - a).normalized() * half
			var quad := [a - along + side, b + along + side, b + along - side, a - along - side]
			vertices.append_array(PackedVector2Array([quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_meshes[key] = mesh
	return _meshes[key]
