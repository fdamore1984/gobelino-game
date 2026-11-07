class_name HitSpark
extends Node2D
## Scintilla nel punto in cui un colpo raggiunge il nemico: un lampo e dei
## raggi che si allargano e svaniscono. Segue il tempo di gioco, quindi
## durante il fermo dell'impatto resta "congelata" sul colpo.
##
## Ai colpi a segno (vedi spawn con cut) c'è anche il lampo d'impatto: un
## bagliore bianco e un taglio di luce orientato come il fendente, che dura
## FLASH_TIME secondi, più grandi per i colpi potenti. Si somma alla luce
## della scena (fusione additiva) e non prende luci, così il buio della
## notte e dei sotterranei non lo spegne (vedi _flash_material).

const LIFETIME := 0.22
const RAYS := 8
## Lampo d'impatto: durata, grandezza del bagliore e del taglio rispetto a
## size, spessore del taglio e quanto in più per i colpi potenti.
const FLASH_TIME := 0.1
const FLASH_GLOW := 1.05
const FLASH_CUT_LENGTH := 2.6
const FLASH_CUT_WIDTH := 0.22
const FLASH_HEAVY_FACTOR := 1.35
const COLOR_FLASH := Color(1.0, 1.0, 1.0, 0.95)

## Altezza sullo schermo del punto colpito (terreno + corpo del nemico).
var lift := 0.0
var size := 22.0
var color := Color(1.0, 0.95, 0.7)
## Direzione del taglio di luce (radianti; NAN: niente lampo d'impatto).
var cut := NAN
var heavy := false

var _age := 0.0

static var _flash_material: CanvasItemMaterial


## Crea la scintilla in at (posizione a terra) alzata di lift. Con cut (la
## direzione del fendente sullo schermo, in radianti) anche il lampo
## d'impatto, più grande se heavy.
static func spawn(parent: Node, at: Vector2, at_lift: float, spark_size: float, spark_color: Color, cut_angle := NAN, is_heavy := false) -> void:
	var spark := HitSpark.new()
	spark.position = at
	spark.lift = at_lift
	spark.size = spark_size
	spark.color = spark_color
	spark.cut = cut_angle
	spark.heavy = is_heavy
	spark.z_index = 10
	spark.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	spark.material = flash_material()
	parent.add_child(spark)


## Materiale additivo e senza luci condiviso da scintille e lampi.
static func flash_material() -> CanvasItemMaterial:
	if _flash_material == null:
		_flash_material = CanvasItemMaterial.new()
		_flash_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_flash_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _flash_material


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var center := Vector2(0, -lift)
	if not is_nan(cut) and _age < FLASH_TIME:
		_draw_flash(center, _age / FLASH_TIME)
	# Lampo al centro che si spegne subito, raggi che si allungano.
	Shapes.disc(self, center, size * 0.6 * (1.0 - t), Color(1, 1, 1, 0.9 * (1.0 - t)))
	for i in RAYS:
		var direction := Vector2.from_angle(TAU * i / RAYS + 0.3)
		var inner := size * (0.3 + 0.6 * t)
		var outer := size * ((1.0 if i % 2 == 0 else 0.7) + 0.6 * t)
		draw_line(center + direction * inner, center + direction * outer, Color(color, 1.0 - t), maxf(4.5 * (1.0 - t), 1.5))


## Lampo d'impatto (t da 0 a 1): bagliore bianco che si allarga e si spegne
## e taglio di luce, una lama sottile appuntita alle estremità che si
## allunga di colpo nella direzione del fendente.
func _draw_flash(center: Vector2, t: float) -> void:
	var grow := FLASH_HEAVY_FACTOR if heavy else 1.0
	var fade := 1.0 - t
	Shapes.glow(self, center, size * FLASH_GLOW * grow * (0.8 + 0.4 * t), Color(COLOR_FLASH, 0.6 * fade))
	var along := Vector2.from_angle(cut)
	var across := along.orthogonal()
	var half_length := size * FLASH_CUT_LENGTH * grow * (0.55 + 0.45 * ease(t, 0.3)) / 2.0
	var half_width := size * FLASH_CUT_WIDTH * grow * fade
	var white := Color(COLOR_FLASH, fade)
	draw_primitive(PackedVector2Array([center - along * half_length, center - across * half_width,
			center + along * half_length, center + across * half_width]),
			PackedColorArray([Color(white, 0.0), white, Color(white, 0.0), white]), PackedVector2Array())
	# Il cuore del taglio, più stretto e pieno.
	draw_primitive(PackedVector2Array([center - along * half_length * 0.7, center - across * half_width * 0.4,
			center + along * half_length * 0.7, center + across * half_width * 0.4]),
			PackedColorArray([white]), PackedVector2Array())
