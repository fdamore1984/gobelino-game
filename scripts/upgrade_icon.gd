class_name UpgradeIcon
extends Control
## Icona geometrica di un potenziamento o di un effetto attivo, disegnata in
## codice in attesa delle icone definitive. Si adatta alla dimensione del
## controllo.

## Colore di ogni icona: aiuta a distinguerle a colpo d'occhio.
const COLORS := {
	"combo": Color(1.0, 0.95, 0.75),
	"heavy": Color(1.0, 0.55, 0.2),
	"dodge": Color(0.45, 0.85, 1.0),
	"jump": Color(0.5, 0.95, 0.55),
	"health": Color(0.95, 0.35, 0.35),
	"potion": Color(0.5, 1.0, 0.5),
	"shield": Color(0.45, 0.7, 1.0),
	"run": Color(1.0, 0.85, 0.3),
	"empowered": Color(1.0, 0.8, 0.25),
	"bubble": Color(0.55, 0.85, 1.0),
	"mana": Color(0.45, 0.65, 1.0),
	"spell": Color(1.0, 0.5, 0.15),
	"torch": Color(1.0, 0.75, 0.35),
	"bag": Color(0.8, 0.6, 0.35),
}

@export var kind := "":
	set(value):
		kind = value
		queue_redraw()


static func color_of(icon_kind: String) -> Color:
	return COLORS.get(icon_kind, Color.WHITE)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_icon(self, size / 2.0, minf(size.x, size.y), kind)


## Disegna l'icona centrata in center, larga side pixel; frame = false
## per non disegnare il cerchio di sfondo.
static func draw_icon(canvas: CanvasItem, center: Vector2, side: float, icon_kind: String, frame := true) -> void:
	# Le forme sono pensate in un quadrato da -1 a 1.
	canvas.draw_set_transform(center, 0.0, Vector2.ONE * side / 2.0)
	var color := color_of(icon_kind)
	if frame:
		canvas.draw_circle(Vector2.ZERO, 0.98, Color(0, 0, 0, 0.35))
		canvas.draw_arc(Vector2.ZERO, 0.98, 0.0, TAU, 32, Color(color, 0.6), 0.06)
	match icon_kind:
		"combo":
			# Tre fendenti obliqui, sempre più lunghi.
			for k in 3:
				var x := -0.4 + k * 0.35
				var length := 0.3 + k * 0.12
				canvas.draw_line(Vector2(x - length * 0.5, length), Vector2(x + length * 0.5, -length), color, 0.12)
		"heavy":
			# Stella a otto punte: il colpo potente.
			var points := PackedVector2Array()
			for k in 16:
				points.append(Vector2.from_angle(TAU * k / 16.0 - PI / 2.0) * (0.7 if k % 2 == 0 else 0.3))
			canvas.draw_colored_polygon(points, color)
		"dodge":
			# Due frecce verso destra, come una scia.
			for k in 2:
				var x := -0.45 + k * 0.45
				canvas.draw_polyline(PackedVector2Array([Vector2(x, -0.4), Vector2(x + 0.35, 0.0), Vector2(x, 0.4)]), Color(color, 0.55 + 0.45 * k), 0.14)
		"jump":
			# Freccia verso l'alto sopra il terreno.
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, -0.65), Vector2(0.4, -0.15), Vector2(-0.4, -0.15)]), color)
			canvas.draw_rect(Rect2(-0.14, -0.2, 0.28, 0.5), color)
			canvas.draw_line(Vector2(-0.55, 0.5), Vector2(0.55, 0.5), color, 0.1)
		"health":
			# Cuore: due cerchi e un triangolo.
			canvas.draw_circle(Vector2(-0.24, -0.15), 0.28, color)
			canvas.draw_circle(Vector2(0.24, -0.15), 0.28, color)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-0.5, -0.05), Vector2(0.5, -0.05), Vector2(0, 0.6)]), color)
		"potion":
			# Boccetta con il liquido.
			canvas.draw_rect(Rect2(-0.12, -0.65, 0.24, 0.3), Color(0.85, 0.85, 0.85))
			canvas.draw_circle(Vector2(0, 0.15), 0.45, Color(0.85, 0.85, 0.85))
			canvas.draw_circle(Vector2(0, 0.2), 0.36, color)
		"shield":
			# Scudo con una freccia che gira: ricarica più rapida.
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-0.5, -0.55), Vector2(0.5, -0.55), Vector2(0.5, 0.0), Vector2(0, 0.65), Vector2(-0.5, 0.0)]), color)
			canvas.draw_arc(Vector2(0, -0.05), 0.25, -PI * 0.8, PI * 0.6, 12, Color(0.1, 0.15, 0.3), 0.08)
		"run":
			# Freccia con le linee della velocità.
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(0.6, 0), Vector2(0.1, -0.4), Vector2(0.1, 0.4)]), color)
			for k in 3:
				var y := -0.25 + k * 0.25
				canvas.draw_line(Vector2(-0.6 + k * 0.1, y), Vector2(0.05, y), color, 0.09)
		"empowered":
			# Aura dorata: cerchio pieno con raggi.
			for k in 8:
				var direction := Vector2.from_angle(TAU * k / 8.0)
				canvas.draw_line(direction * 0.45, direction * 0.75, color, 0.1)
			canvas.draw_circle(Vector2.ZERO, 0.35, color)
		"mana":
			# Goccia di mana.
			canvas.draw_circle(Vector2(0, 0.18), 0.38, color)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-0.33, 0.0), Vector2(0.33, 0.0), Vector2(0, -0.62)]), color)
			canvas.draw_circle(Vector2(-0.12, 0.1), 0.1, Color(1, 1, 1, 0.6))
		"spell":
			# Palla di fuoco con la scia.
			for k in 3:
				canvas.draw_circle(Vector2(-0.45 + k * 0.15, 0.3 - k * 0.1), 0.1 + k * 0.04, Color(color, 0.4 + 0.2 * k))
			canvas.draw_circle(Vector2(0.15, -0.1), 0.38, color)
			canvas.draw_circle(Vector2(0.15, -0.1), 0.18, Color(1.0, 0.95, 0.6))
		"torch":
			# Torcia accesa.
			canvas.draw_line(Vector2(0, 0.65), Vector2(0, -0.1), Color(0.55, 0.36, 0.2), 0.16)
			canvas.draw_circle(Vector2(0, -0.3), 0.28, color)
			canvas.draw_circle(Vector2(0, -0.36), 0.14, Color(1.0, 0.95, 0.6))
		"bag":
			# Zaino: sacca con la patta e la fibbia.
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-0.5, -0.25), Vector2(0.5, -0.25), Vector2(0.6, 0.6), Vector2(-0.6, 0.6)]), color)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-0.5, -0.25), Vector2(0.5, -0.25), Vector2(0.35, 0.15), Vector2(-0.35, 0.15)]), color.darkened(0.25))
			canvas.draw_arc(Vector2(0, -0.3), 0.25, PI, TAU, 10, color.darkened(0.3), 0.1)
			canvas.draw_rect(Rect2(-0.08, 0.05, 0.16, 0.16), Color(0.9, 0.8, 0.4))
		"bubble":
			# Bolla dello scudo attivo.
			canvas.draw_circle(Vector2.ZERO, 0.6, Color(color, 0.3))
			canvas.draw_arc(Vector2.ZERO, 0.6, 0.0, TAU, 32, color, 0.1)
			canvas.draw_circle(Vector2(-0.22, -0.22), 0.12, Color(1, 1, 1, 0.7))
	canvas.draw_set_transform(Vector2.ZERO)
