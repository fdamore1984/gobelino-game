class_name GroundFx
extends Node2D
## Effetti a terra, disegnati sopra il terreno e sotto personaggi e
## ostacoli: macchie di sangue dei nemici colpiti, corpi dei nemici
## abbattuti (restano un po' e poi svaniscono) e onde d'urto degli
## attacchi a terra. Le gocce in volo sono disegnate sopra a tutto (vedi
## AirLayer). Un solo nodo per tutti gli effetti, così restano leggeri
## anche quando sono tanti.

const BLOOD_COLOR := Color(0.6, 0.03, 0.04)
const DROP_GRAVITY := 950.0
## Le macchie restano per questo tempo; gli ultimi FADE_TIME secondi svaniscono.
const SPLAT_TIME := 30.0
const CORPSE_TIME := 20.0
const FADE_TIME := 4.0
const MAX_SPLATS := 260
const MAX_CORPSES := 40
## Onda d'urto: l'anello dura WAVE_TIME, le crepe nel terreno CRACK_TIME.
const WAVE_TIME := 0.45
const CRACK_TIME := 2.5
const CRACK_COUNT := 7
const DUST_COUNT := 12
const COLOR_WAVE := Color(1.0, 0.85, 0.55)
const COLOR_DUST := Color(0.55, 0.45, 0.32)
## Gli effetti fermi (macchie che svaniscono) si ridisegnano più di rado.
const IDLE_REDRAW := 0.2
## Le gocce stanno in un quadrato del mondo: la terra sotto è ellittica.
const GROUND_SQUASH := 0.5

static var current: GroundFx

var _drops: Array[Dictionary] = []
var _splats: Array[Dictionary] = []
var _corpses: Array[Dictionary] = []
var _waves: Array[Dictionary] = []
var _air := AirLayer.new()
var _redraw_timer := 0.0


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	_air.fx = self
	_air.z_index = 20
	add_child(_air)


## Sangue di un colpo: gocce che schizzano nella direzione del colpo e
## restano a terra come macchie, più una macchia subito sotto il nemico.
static func bleed(at: Vector2, altitude: float, direction: Vector2, amount: int) -> void:
	if current == null:
		return
	for i in amount:
		var spread := direction.rotated(randf_range(-0.8, 0.8)) * randf_range(50.0, 240.0)
		current._drops.append({
			"position": at, "altitude": altitude, "velocity": Vector2(spread.x, spread.y * 0.6),
			"rise": randf_range(60.0, 300.0), "size": randf_range(2.0, 4.0), "age": 0.0,
		})
	current._add_splat(at + direction * 8.0, _ground(at), randf_range(6.0, 10.0), direction, 0.0)


## Pozza sotto un nemico abbattuto: si allarga in un attimo.
static func pool(at: Vector2, size: float) -> void:
	if current:
		current._add_splat(at, _ground(at), size, Vector2.RIGHT, 1.2)


## Corpo di un nemico abbattuto, steso a terra: points è la sua forma
## rispetto al punto at (alla base), già nella posa distesa.
static func corpse(at: Vector2, elevation: float, points: PackedVector2Array, color: Color) -> void:
	if current == null:
		return
	current._corpses.append({"position": at, "elevation": elevation, "points": points, "color": color, "age": 0.0})
	if current._corpses.size() > MAX_CORPSES:
		current._corpses.pop_front()


## Onda d'urto di un attacco a terra, larga radius, con crepe e polvere.
static func shockwave(at: Vector2, elevation: float, radius: float) -> void:
	if current:
		current._waves.append({"position": at, "elevation": elevation, "radius": radius, "age": 0.0, "seed": randi()})


static func _ground(at: Vector2) -> float:
	return World.current.elevation_at(at) if World.current else 0.0


## Macchia irregolare: qualche cerchio allungato nella direzione del colpo.
## grow: secondi in cui si allarga (0 = subito piena).
func _add_splat(at: Vector2, elevation: float, size: float, direction: Vector2, grow: float) -> void:
	var blobs: Array[Vector3] = [Vector3(0, 0, size)]
	for k in randi_range(2, 4):
		var offset := direction.rotated(randf_range(-0.6, 0.6)) * size * randf_range(0.4, 1.4)
		blobs.append(Vector3(offset.x, offset.y, size * randf_range(0.3, 0.6)))
	_splats.append({
		"position": at, "elevation": elevation, "blobs": blobs, "age": 0.0, "grow": grow,
		"color": BLOOD_COLOR.darkened(randf_range(0.0, 0.25)),
	})
	if _splats.size() > MAX_SPLATS:
		_splats.pop_front()


func _process(delta: float) -> void:
	var moving := not _drops.is_empty() or not _waves.is_empty()
	for i in range(_drops.size() - 1, -1, -1):
		var drop := _drops[i]
		drop["age"] += delta
		drop["position"] += drop["velocity"] * delta
		drop["rise"] -= DROP_GRAVITY * delta
		drop["altitude"] += drop["rise"] * delta
		var ground := _ground(drop["position"])
		if drop["altitude"] <= ground or drop["age"] > 2.0:
			_add_splat(drop["position"], ground, drop["size"] * randf_range(0.8, 1.6), (drop["velocity"] as Vector2).normalized(), 0.0)
			_drops.remove_at(i)
	for list: Array[Dictionary] in [_splats, _corpses, _waves]:
		for item in list:
			item["age"] += delta
			if item.get("grow", 0.0) > 0.0 and item["age"] < item["grow"]:
				moving = true
	while not _splats.is_empty() and _splats[0]["age"] >= SPLAT_TIME:
		_splats.pop_front()
	while not _corpses.is_empty() and _corpses[0]["age"] >= CORPSE_TIME:
		_corpses.pop_front()
	while not _waves.is_empty() and _waves[0]["age"] >= CRACK_TIME:
		_waves.pop_front()
	_redraw_timer -= delta
	if moving or _redraw_timer <= 0.0:
		_redraw_timer = IDLE_REDRAW
		queue_redraw()
		_air.queue_redraw()


## Rettangolo visibile, per non disegnare quello che è fuori dallo schermo.
func _view() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return Rect2(-1e6, -1e6, 2e6, 2e6)
	var half := get_viewport_rect().size / camera.zoom / 2.0 + Vector2(200, 300)
	return Rect2(camera.get_screen_center_position() - half, half * 2.0)


static func _fade(age: float, lifetime: float) -> float:
	return clampf((lifetime - age) / FADE_TIME, 0.0, 1.0)


func _draw() -> void:
	var view := _view()
	for splat in _splats:
		var at: Vector2 = splat["position"] - Vector2(0, splat["elevation"])
		if not view.has_point(at):
			continue
		var grow: float = splat["grow"]
		var scale_factor := 1.0 if grow <= 0.0 else ease(minf(splat["age"] / grow, 1.0), 0.4)
		var color := Color(splat["color"], 0.85 * _fade(splat["age"], SPLAT_TIME))
		draw_set_transform(at, 0.0, Vector2(1.0, GROUND_SQUASH) * scale_factor)
		for blob: Vector3 in splat["blobs"]:
			draw_circle(Vector2(blob.x, blob.y), blob.z, color)
	for body in _corpses:
		var at: Vector2 = body["position"] - Vector2(0, body["elevation"])
		if not view.has_point(at):
			continue
		var alpha := _fade(body["age"], CORPSE_TIME)
		var color: Color = body["color"]
		draw_set_transform(at)
		draw_colored_polygon(body["points"], Color(color, alpha))
		var outline: PackedVector2Array = body["points"].duplicate()
		outline.append(outline[0])
		draw_polyline(outline, Color(color.darkened(0.4), alpha), 2.0)
	for wave in _waves:
		_draw_wave(wave)
	draw_set_transform(Vector2.ZERO)


## Anello che si allarga, polvere che vola via e crepe che restano un po'.
func _draw_wave(wave: Dictionary) -> void:
	var age: float = wave["age"]
	var radius: float = wave["radius"]
	draw_set_transform(wave["position"] - Vector2(0, wave["elevation"]), 0.0, Vector2(1.0, GROUND_SQUASH))
	var rng := RandomNumberGenerator.new()
	rng.seed = wave["seed"]
	var crack_alpha := clampf((CRACK_TIME - age) / 1.0, 0.0, 1.0) * 0.6
	for k in CRACK_COUNT:
		var direction := Vector2.from_angle(TAU * k / CRACK_COUNT + rng.randf_range(-0.3, 0.3))
		var length := radius * rng.randf_range(0.35, 0.65) * minf(age / 0.08, 1.0)
		var bend := direction.rotated(rng.randf_range(-0.5, 0.5))
		var middle := direction * length * 0.5
		draw_polyline(PackedVector2Array([Vector2.ZERO, middle, middle + bend * length * 0.5]), Color(0.15, 0.1, 0.05, crack_alpha), 3.0)
	if age < WAVE_TIME:
		var t := age / WAVE_TIME
		var ring := radius * (0.25 + 0.75 * ease(t, 0.4))
		draw_circle(Vector2.ZERO, ring, Color(COLOR_WAVE, 0.18 * (1.0 - t)))
		draw_arc(Vector2.ZERO, ring, 0.0, TAU, 48, Color(COLOR_WAVE, 0.9 * (1.0 - t)), 6.0 * (1.0 - t) + 1.0)
		for k in DUST_COUNT:
			var direction := Vector2.from_angle(TAU * k / DUST_COUNT + rng.randf_range(-0.2, 0.2))
			var at := direction * ring * rng.randf_range(0.7, 1.05) + Vector2(0, -40.0 * t * (1.0 - t) / GROUND_SQUASH)
			draw_circle(at, rng.randf_range(4.0, 9.0) * (1.0 - t * 0.6), Color(COLOR_DUST, 0.7 * (1.0 - t)))


## Gocce in volo, sopra personaggi e ostacoli.
class AirLayer:
	extends Node2D

	var fx: GroundFx

	func _draw() -> void:
		for drop in fx._drops:
			draw_circle(drop["position"] - Vector2(0, drop["altitude"]), drop["size"], GroundFx.BLOOD_COLOR.lightened(0.1))
