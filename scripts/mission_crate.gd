class_name MissionCrate
extends Node2D
## Forziere della missione "recupera il forziere" (vedi Missions e Game):
## un forziere di legno con le bande dorate e un fascio di luce magica verde
## che sale e si vede da lontano. Non prende luci, così si trova anche di
## notte. Si apre interagendo (vedi Game._find_interactable).

const SIZE := Vector2(44, 30)
const COLOR_WOOD := Color(0.55, 0.34, 0.18)
const COLOR_BAND := Color(0.95, 0.78, 0.25)
const COLOR_MAGIC := Color(0.45, 1.0, 0.6)

var _age := 0.0
var _lift := 0.0


func _ready() -> void:
	material = Enemy._unshaded_material()
	if World.current:
		_lift = World.current.elevation_at(position)


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	var base := Vector2(0, -_lift)
	Shapes.disc(self, base + Vector2(0, 4), 26.0, Shapes.SHADOW)
	# Fascio di luce magica e scintille che salgono.
	var pulse := 0.5 + 0.5 * sin(_age * 3.0)
	draw_primitive(PackedVector2Array([base + Vector2(-14, -10), base + Vector2(14, -10), base + Vector2(6, -170), base + Vector2(-6, -170)]),
			PackedColorArray([Color(COLOR_MAGIC, 0.35 + 0.15 * pulse), Color(COLOR_MAGIC, 0.35 + 0.15 * pulse), Color(COLOR_MAGIC, 0.0), Color(COLOR_MAGIC, 0.0)]),
			PackedVector2Array())
	for k in 6:
		var t := fposmod(_age * 0.5 + k / 6.0, 1.0)
		Shapes.disc(self, base + Vector2(sin(k * 2.1 + _age * 2.0) * 12.0, -20.0 - 140.0 * t), 3.0 * (1.0 - t) + 1.0, Color(COLOR_MAGIC.lightened(0.4), 1.0 - t))
	# Il forziere: corpo, coperchio bombato e bande dorate.
	var rect := Rect2(base + Vector2(-SIZE.x / 2.0, -SIZE.y), SIZE)
	draw_rect(rect.grow(3.0), Shapes.INK)
	draw_rect(rect, COLOR_WOOD)
	draw_rect(Rect2(rect.position, Vector2(SIZE.x, 9)), COLOR_WOOD.lightened(0.15))
	for x in [-15.0, 10.0]:
		draw_rect(Rect2(base + Vector2(x, -SIZE.y), Vector2(5, SIZE.y)), COLOR_BAND)
	Shapes.ink_disc(self, base + Vector2(0, -SIZE.y + 12), 4.0, COLOR_BAND, 1.5)
