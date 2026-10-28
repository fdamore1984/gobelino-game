class_name HBombBlast
extends Node2D
## Esplosione della runa del cataclisma che il goblin spacca sul terreno
## (vedi Player._h_bomb_impact; id interni "h_bomb" come in Ciccio Massacro):
## lampo bianco, schegge della pietra che volano via, vampata arcana larga
## quanto la zona colpita (radius), anello d'urto a terra, colonna di nebbia
## magica che sale e si allarga, e una luce forte che illumina attorno
## (anche di notte). Solo grafica: i danni li fa il giocatore. draw_bomb
## disegna la runa (anche in mano e nelle icone).

const LIFETIME := 1.8
## Parte della durata in cui la palla di fuoco cresce e brucia.
const FIRE_TIME := 0.45
## Il nodo è ordinato con i personaggi come se stesse questa parte del
## raggio più indietro: chi è al centro (il goblin) resta davanti al fuoco.
const SORT_BACK := 0.5
const SHARDS := 14
const SMOKE_PUFFS := 9
const COLOR_CORE := Color(0.95, 0.9, 1.0)
const COLOR_FLAME := Color(0.62, 0.3, 1.0)
const COLOR_SMOKE := Color(0.3, 0.2, 0.42)
## Runa: pietra grigia, bordo scuro e segno inciso che brilla.
const COLOR_HULL := Color(0.5, 0.5, 0.55)
const COLOR_BAND := Color(0.75, 0.5, 1.0)
const COLOR_TREFOIL := Color(0.2, 0.19, 0.24)

## Raggio della zona colpita e altezza del terreno dove esplode (da
## impostare prima di aggiungere il nodo alla scena, con la posizione).
var radius := 200.0
var altitude := 0.0

var _age := 0.0
var _seed := randi()
var _light := PointLight2D.new()


func _ready() -> void:
	position.y -= radius * SORT_BACK
	_light.texture = LightTexture.get_texture()
	_light.color = Color(0.75, 0.55, 1.0)
	_light.texture_scale = radius * 3.0 / LightTexture.SIZE
	_light.position = Vector2(0, -altitude + radius * SORT_BACK)
	add_child(_light)


func _process(delta: float) -> void:
	_age += delta
	_light.energy = 3.0 * pow(maxf(1.0 - _age / LIFETIME, 0.0), 2.0)
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var ground := Vector2(0, -altitude + radius * SORT_BACK)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	# Nebbia magica: la colonna e la nube in cima salgono e si allargano.
	var rise := ease(t, 0.4)
	for k in SMOKE_PUFFS:
		var up := float(k) / (SMOKE_PUFFS - 1)
		var at := ground + Vector2(rng.randf_range(-0.12, 0.12) * radius, -radius * (0.2 + 1.1 * up) * rise)
		var size := radius * (0.16 + 0.12 * up) * (0.5 + 0.5 * rise)
		Shapes.disc(self, at, size, Color(COLOR_SMOKE.lerp(COLOR_FLAME, 0.4 * (1.0 - t)), 0.7 * (1.0 - t)))
	var cap := ground + Vector2(0, -radius * 1.35 * rise)
	for k in 5:
		var offset := Vector2((k - 2) * radius * 0.17, rng.randf_range(-0.08, 0.08) * radius)
		Shapes.disc(self, cap + offset * (0.6 + 0.6 * rise), radius * 0.26 * (0.5 + 0.5 * rise), Color(COLOR_SMOKE, 0.75 * (1.0 - t)))
	# Vampata arcana schiacciata a terra, che si gonfia e poi si spegne.
	var fire_t := clampf(_age / FIRE_TIME, 0.0, 1.0)
	var fade := 1.0 - clampf((_age - FIRE_TIME) / (LIFETIME - FIRE_TIME), 0.0, 1.0)
	var fire := radius * (0.3 + 0.5 * ease(fire_t, 0.3))
	Shapes.glow(self, ground, fire * 1.6, Color(COLOR_FLAME, 0.5 * fade), 0.5)
	draw_set_transform(ground, 0.0, Vector2(1.0, 0.5))
	Shapes.disc(self, Vector2.ZERO, fire, Color(COLOR_FLAME.lerp(COLOR_SMOKE, 1.0 - fade), 0.7 * fade))
	Shapes.disc(self, Vector2.ZERO, fire * 0.5, Color(COLOR_CORE, 0.8 * fade * fade))
	# Anello d'urto a terra che corre fino al bordo della zona colpita.
	draw_arc(Vector2.ZERO, radius * ease(minf(t * 2.5, 1.0), 0.4), 0.0, TAU, 48, Color(1.0, 0.9, 0.7, 0.8 * (1.0 - minf(t * 2.5, 1.0))), 6.0)
	draw_set_transform(Vector2.ZERO)
	# Schegge della runa che schizzano via.
	for k in SHARDS:
		var angle := rng.randf() * TAU
		var speed := rng.randf_range(0.5, 1.2)
		var fly := Vector2.from_angle(angle) * Vector2(1.0, 0.5) * radius * speed * ease(minf(t * 2.0, 1.0), 0.5) \
				+ Vector2(0, -60.0 * sin(PI * minf(t * 2.0, 1.0)))
		var color := COLOR_HULL if k % 3 != 0 else COLOR_BAND
		var size := rng.randf_range(3.0, 7.0)
		draw_rect(Rect2(ground + fly - Vector2(size, size) / 2.0, Vector2(size, size * 0.6)), Color(color, 1.0 - t))
	# Lampo bianco iniziale.
	if _age < 0.2:
		Shapes.disc(self, ground, radius * 1.6, Color(1, 1, 1, 0.6 * (1.0 - _age / 0.2)))


## Runa del cataclisma, grande length e centrata in center: una pietra
## ovale con il bordo scuro e un segno inciso (una saetta tra due tacche)
## che brilla di viola; mirror la gira. glow (0-1) la fa brillare di più,
## per la carica.
static func draw_bomb(canvas: CanvasItem, center: Vector2, length: float, glow: float, mirror := false) -> void:
	var side := -1.0 if mirror else 1.0
	var half := length * 0.32
	var tall := length * 0.4
	if glow > 0.0:
		Shapes.glow(canvas, center, length * (0.7 + 0.2 * glow), Color(COLOR_BAND, 0.55 * glow))
	# Pietra: un ovale un po' irregolare, con il bordo scuro e un riflesso.
	var stone := PackedVector2Array()
	for k in 14:
		var a := TAU * k / 14.0
		var bump := 1.0 + 0.06 * sin(a * 3.0 + 1.0)
		stone.append(center + Vector2(cos(a) * half * side, sin(a) * tall) * bump)
	canvas.draw_colored_polygon(stone, COLOR_HULL)
	canvas.draw_polyline(stone + PackedVector2Array([stone[0]]), COLOR_TREFOIL, maxf(length * 0.035, 1.0))
	canvas.draw_line(center + Vector2(-side * half * 0.5, -tall * 0.7), center + Vector2(side * half * 0.1, -tall * 0.82), COLOR_HULL.lightened(0.35), maxf(length * 0.03, 1.0))
	# Segno inciso: una saetta tra due tacche, più luminosa con la carica.
	var rune := COLOR_BAND.lerp(Color.WHITE, 0.4 * glow)
	var w := maxf(length * 0.05, 1.5)
	var bolt := PackedVector2Array([center + Vector2(side * half * 0.15, -tall * 0.6), center + Vector2(-side * half * 0.2, -tall * 0.02),
			center + Vector2(side * half * 0.2, tall * 0.02), center + Vector2(-side * half * 0.15, tall * 0.6)])
	canvas.draw_polyline(bolt, rune, w)
	for dir: float in [-1.0, 1.0]:
		canvas.draw_line(center + Vector2(dir * half * 0.55, -tall * 0.25), center + Vector2(dir * half * 0.55, tall * 0.25), rune, w)
