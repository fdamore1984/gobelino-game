class_name HitSpark
extends Node2D
## Scintilla nel punto in cui un colpo raggiunge il nemico: un lampo e dei
## raggi che si allargano e svaniscono. Segue il tempo di gioco, quindi
## durante il fermo dell'impatto resta "congelata" sul colpo.

const LIFETIME := 0.22
const RAYS := 8

## Altezza sullo schermo del punto colpito (terreno + corpo del nemico).
var lift := 0.0
var size := 22.0
var color := Color(1.0, 0.95, 0.7)

var _age := 0.0


## Crea la scintilla in at (posizione a terra) alzata di lift.
static func spawn(parent: Node, at: Vector2, at_lift: float, spark_size: float, spark_color: Color) -> void:
	var spark := HitSpark.new()
	spark.position = at
	spark.lift = at_lift
	spark.size = spark_size
	spark.color = spark_color
	spark.z_index = 10
	spark.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(spark)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var center := Vector2(0, -lift)
	# Lampo al centro che si spegne subito, raggi che si allungano.
	draw_circle(center, size * 0.6 * (1.0 - t), Color(1, 1, 1, 0.9 * (1.0 - t)))
	for i in RAYS:
		var direction := Vector2.from_angle(TAU * i / RAYS + 0.3)
		var inner := size * (0.3 + 0.6 * t)
		var outer := size * ((1.0 if i % 2 == 0 else 0.7) + 0.6 * t)
		draw_line(center + direction * inner, center + direction * outer, Color(color, 1.0 - t), maxf(4.5 * (1.0 - t), 1.5))
