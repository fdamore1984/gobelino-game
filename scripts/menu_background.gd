extends Control
## Sfondo del menù iniziale nello stile del sito: sfumatura radiale verde,
## raggi chiari dietro il titolo, grana leggera e, in basso, Gobelino e un
## demone disegnati col contorno nero.

## Da dove partono i raggi (in frazioni dello schermo) e quanti sono.
const RAYS_CENTER := Vector2(0.5, 0.18)
const RAYS := 12
const COLOR_RAY := Color(1, 1, 1, 0.13)
const COLOR_DEMON := Color("ff4b4b")
const COLOR_EAR := Player.COLOR_BODY

var _gradient := GradientTexture2D.new()
var _grain := UiStyle.grain_texture()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([UiStyle.BACK_LIGHT, UiStyle.BACK, UiStyle.BACK_DARK])
	_gradient.gradient = gradient
	_gradient.fill = GradientTexture2D.FILL_RADIAL
	_gradient.fill_from = Vector2(0.85, 1.0)
	_gradient.fill_to = Vector2(-0.1, -0.1)
	resized.connect(queue_redraw)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_texture_rect(_gradient, rect, false)
	var origin := size * RAYS_CENTER
	var reach := size.length()
	for k in RAYS:
		var a := TAU * k / RAYS
		draw_colored_polygon(PackedVector2Array([origin, origin + Vector2.from_angle(a) * reach,
				origin + Vector2.from_angle(a + PI / RAYS) * reach]), COLOR_RAY)
	_draw_goblin(Vector2(size.x - 150.0, size.y - 120.0), 56.0, 0.17)
	_draw_demon(Vector2(150.0, size.y - 230.0), 40.0, -0.2)
	draw_texture_rect(_grain, rect, true)


## Gobelino: testa tonda con le orecchie a punta e gli occhi grandi.
func _draw_goblin(center: Vector2, radius: float, angle: float) -> void:
	draw_set_transform(center, angle)
	for side: float in [-1.0, 1.0]:
		_ink_polygon(PackedVector2Array([Vector2(side * radius * 0.85, -radius * 0.2),
				Vector2(side * radius * 1.55, -radius * 0.65), Vector2(side * radius * 1.1, radius * 0.25)]), COLOR_EAR)
	_ink_disc(Vector2.ZERO, radius, Player.COLOR_BODY)
	draw_arc(Vector2.ZERO, radius * 0.72, PI * 1.1, PI * 1.45, 12, Player.COLOR_BODY.lightened(0.45), 6.0, true)
	_draw_eyes(Vector2(0, -radius * 0.12), radius / 32.0, false)
	draw_arc(Vector2(0, radius * 0.3), radius * 0.28, PI * 0.2, PI * 0.8, 10, UiStyle.INK, 4.0, true)
	draw_set_transform(Vector2.ZERO)


## Demone rosso a rombo, arrabbiato.
func _draw_demon(center: Vector2, radius: float, angle: float) -> void:
	draw_set_transform(center, angle)
	_ink_polygon(PackedVector2Array([Vector2(0, -radius), Vector2(radius * 0.8, 0), Vector2(0, radius), Vector2(-radius * 0.8, 0)]), COLOR_DEMON)
	_draw_eyes(Vector2(0, -radius * 0.08), radius / 48.0, true)
	draw_set_transform(Vector2.ZERO)


## Occhi bianchi ovali con le pupille, come quelli di Ufotizio; arrabbiati
## con le sopracciglia storte.
func _draw_eyes(center: Vector2, scale_factor: float, angry: bool) -> void:
	for side: float in [-1.0, 1.0]:
		var eye := center + Vector2(side * 10.0, 0) * scale_factor
		_ink_polygon(_ellipse(eye, Vector2(7.5, 9.5) * scale_factor), Color.WHITE, 3.0)
		Shapes.disc(self, eye + Vector2(2.0, 2.0) * scale_factor, 3.6 * scale_factor, UiStyle.INK)
		if angry:
			draw_line(eye + Vector2(side * 9.0, -13.0) * scale_factor, eye + Vector2(-side * 5.0, -7.0) * scale_factor, UiStyle.INK, 4.0 * scale_factor, true)


func _ellipse(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in 24:
		points.append(center + Vector2.from_angle(TAU * k / 24.0) * radii)
	return points


func _ink_disc(center: Vector2, radius: float, color: Color, outline := 5.0) -> void:
	Shapes.disc(self, center, radius + outline, UiStyle.INK)
	Shapes.disc(self, center, radius, color)


## Poligono pieno col contorno nero (il poligono allargato, a spigoli tondi).
func _ink_polygon(points: PackedVector2Array, color: Color, outline := 5.0) -> void:
	for grown in Geometry2D.offset_polygon(points, outline, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(grown, UiStyle.INK)
	draw_colored_polygon(points, color)
