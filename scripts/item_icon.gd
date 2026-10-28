class_name ItemIcon
extends Control
## Icona geometrica di un oggetto (data/items.json), disegnata in codice in
## attesa delle icone definitive. Usata nell'inventario; draw_item disegna
## la stessa icona anche nel mondo (oggetti a terra).

@export var item_id := "":
	set(value):
		item_id = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if item_id == "":
		return
	var side := minf(size.x, size.y)
	draw_item(self, size / 2.0, side, item_id)


## Disegna l'oggetto centrato in center, grande circa side pixel.
static func draw_item(canvas: CanvasItem, center: Vector2, side: float, id: String) -> void:
	var color := Items.color(id)
	var s := side / 2.0
	match Items.category(id):
		"gold":
			canvas.draw_circle(center, s * 0.7, color.darkened(0.25))
			canvas.draw_circle(center, s * 0.55, color)
			canvas.draw_arc(center, s * 0.35, 0.0, TAU, 16, color.darkened(0.3), maxf(s * 0.08, 1.0))
		"weapon":
			BodyParts.draw_sword(canvas, center + Vector2(-s * 0.6, s * 0.6), -PI / 4.0, s * 1.7, maxf(s * 0.16, 2.0), color.lightened(0.3))
		"armor":
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-s * 0.7, -s * 0.6), center + Vector2(-s * 0.25, -s * 0.7), center + Vector2(0, -s * 0.5),
				center + Vector2(s * 0.25, -s * 0.7), center + Vector2(s * 0.7, -s * 0.6), center + Vector2(s * 0.55, s * 0.7),
				center + Vector2(-s * 0.55, s * 0.7),
			]), color)
			canvas.draw_line(center + Vector2(0, -s * 0.45), center + Vector2(0, s * 0.65), color.darkened(0.3), maxf(s * 0.08, 1.0))
		"boots":
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-s * 0.3, -s * 0.7), center + Vector2(s * 0.15, -s * 0.7), center + Vector2(s * 0.15, s * 0.2),
				center + Vector2(s * 0.7, s * 0.35), center + Vector2(s * 0.7, s * 0.65), center + Vector2(-s * 0.3, s * 0.65),
			]), color)
			canvas.draw_line(center + Vector2(-s * 0.3, s * 0.45), center + Vector2(s * 0.7, s * 0.45), color.darkened(0.35), maxf(s * 0.1, 1.0))
		"amulet":
			canvas.draw_arc(center + Vector2(0, -s * 0.2), s * 0.5, PI * 0.1, PI * 0.9, 12, Color(0.85, 0.8, 0.5), maxf(s * 0.07, 1.0))
			canvas.draw_arc(center + Vector2(0, -s * 0.2), s * 0.5, PI * 1.1, PI * 1.9, 12, Color(0.85, 0.8, 0.5), maxf(s * 0.07, 1.0))
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, s * 0.1), center + Vector2(s * 0.3, s * 0.4), center + Vector2(0, s * 0.75), center + Vector2(-s * 0.3, s * 0.4)]), color)
		"ring":
			canvas.draw_arc(center + Vector2(0, s * 0.15), s * 0.45, 0.0, TAU, 24, Color(0.9, 0.8, 0.4), maxf(s * 0.16, 1.5))
			canvas.draw_circle(center + Vector2(0, -s * 0.35), s * 0.22, color)
		"book":
			canvas.draw_rect(Rect2(center - Vector2(s * 0.6, s * 0.7), Vector2(s * 1.2, s * 1.4)), color)
			canvas.draw_rect(Rect2(center + Vector2(s * 0.45, -s * 0.62), Vector2(s * 0.12, s * 1.24)), Color(0.95, 0.92, 0.8))
			canvas.draw_circle(center, s * 0.25, color.lightened(0.4))
		"potion":
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.15, -s * 0.8), Vector2(s * 0.3, s * 0.4)), Color(0.85, 0.85, 0.85))
			canvas.draw_circle(center + Vector2(0, s * 0.15), s * 0.55, Color(0.85, 0.85, 0.85))
			canvas.draw_circle(center + Vector2(0, s * 0.2), s * 0.44, color)
		"bomb":
			HBombBlast.draw_bomb(canvas, center, side * 0.95, 0.0)
