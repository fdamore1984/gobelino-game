class_name GroundFx
extends Node2D
## Effetti a terra, disegnati sopra il terreno e sotto personaggi e
## ostacoli: schizzi di sangue di chi viene colpito (vedi BloodSplatter),
## pozze di sangue di chi muore (restano), corpi dei nemici abbattuti
## (restano un po' e poi svaniscono) e onde d'urto degli attacchi a terra. Le gocce in volo sono disegnate sopra a tutto (vedi
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
## Pozze di sangue di chi muore: si allargano in POOL_GROW secondi e poi
## restano (finché si resta in quella zona: si tolgono passando tra
## l'aperto e gli edifici), al più MAX_POOLS (le più vecchie spariscono).
const POOL_GROW := 2.5
const MAX_POOLS := 80
const POOL_ALPHA := 0.95
## Le gocce che cadono lasciano schizzi più piccoli della goccia stessa
## (lo schizzo con i rivoli è più largo della macchia centrale).
const DROP_SPLAT := 0.75
## Onda d'urto: l'anello dura WAVE_TIME, le crepe nel terreno CRACK_TIME.
const WAVE_TIME := 0.45
const CRACK_TIME := 2.5
const CRACK_COUNT := 7
const DUST_COUNT := 12
const COLOR_WAVE := Color(1.0, 0.85, 0.55)
const COLOR_DUST := Color(0.55, 0.45, 0.32)
## Macchie e corpi si ridisegnano solo quando cambiano: al più ogni
## SPLAT_REDRAW secondi quando ne arrivano di nuovi, ogni IDLE_REDRAW
## mentre svaniscono. Onde d'urto e gocce in volo hanno un loro strato,
## ridisegnato a ogni frame solo finché ce ne sono.
const SPLAT_REDRAW := 0.05
const IDLE_REDRAW := 0.2
## Le gocce stanno in un quadrato del mondo: la terra sotto è ellittica.
const GROUND_SQUASH := 0.5
## Bagliore rosso del punto d'impatto di un attacco a terra (vedi danger_glow).
const COLOR_DANGER_GLOW := Color(1.0, 0.18, 0.08)
const COLOR_DANGER_CORE := Color(1.0, 0.55, 0.25)
## X al centro della zona d'impatto: rosso acceso, metà lato in parti del
## raggio e lampeggi al secondo (dall'inizio alla fine della carica).
const COLOR_DANGER_CROSS := Color(1.0, 0.1, 0.05)
const DANGER_CROSS := 0.28
const DANGER_BLINK := Vector2(3.0, 9.0)

static var current: GroundFx

var _drops: Array[Dictionary] = []
var _splats: Array[Dictionary] = []
var _corpses: Array[Dictionary] = []
var _pools: Array[Dictionary] = []
var _waves: Array[Dictionary] = []
var _air := AirLayer.new()
var _wave_layer := WaveLayer.new()
var _redraw_timer := 0.0
## Ci sono macchie o corpi nuovi da disegnare.
var _dirty := false


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	_air.fx = self
	_air.z_index = 20
	add_child(_air)
	_wave_layer.fx = self
	add_child(_wave_layer)


## Sangue di un colpo (giocatore e nemici): gocce che schizzano a fiotti
## nella direzione del colpo (alcune grosse, altre come nebbia) e restano a
## terra come schizzi, più uno schizzo largo subito sotto chi è colpito.
static func bleed(at: Vector2, altitude: float, direction: Vector2, amount: int) -> void:
	if current == null:
		return
	for i in amount:
		var spread := direction.rotated(randf_range(-0.8, 0.8)) * randf_range(50.0, 240.0)
		current._drops.append({
			"position": at, "altitude": altitude, "velocity": Vector2(spread.x, spread.y * 0.6),
			"rise": randf_range(60.0, 300.0), "size": randf_range(2.0, 4.0), "age": 0.0,
		})
	current._add_splat(at + direction * 8.0, _ground(at), randf_range(8.0, 12.0), direction, 0.0)


## Pozza di sangue sotto chi muore (giocatore e nemici), larga size: si
## allarga piano e poi resta (vedi POOL_GROW).
static func pool(at: Vector2, size: float) -> void:
	if current == null:
		return
	current._pools.append({"position": at, "elevation": _ground(at), "size": size, "age": 0.0,
			"angle": randf() * TAU, "variant": randi(), "color": BLOOD_COLOR.darkened(randf_range(0.1, 0.25))})
	if current._pools.size() > MAX_POOLS:
		current._pools.pop_front()
	current._dirty = true


## Corpo di un nemico abbattuto, steso a terra: points è la sua forma
## rispetto al punto at (alla base), già nella posa distesa.
static func corpse(at: Vector2, elevation: float, points: PackedVector2Array, color: Color) -> void:
	if current == null:
		return
	current._corpses.append({"position": at, "elevation": elevation, "points": points, "color": color, "age": 0.0})
	if current._corpses.size() > MAX_CORPSES:
		current._corpses.pop_front()
	current._dirty = true


## Onda d'urto di un attacco a terra, larga radius, con crepe e polvere.
static func shockwave(at: Vector2, elevation: float, radius: float) -> void:
	if current:
		current._waves.append({"position": at, "elevation": elevation, "radius": radius, "age": 0.0, "seed": randi()})


## Zona d'impatto di un attacco a terra che sta per arrivare (salto dei
## nemici): un bagliore rosso ovale, steso a terra nella prospettiva
## isometrica (largo il doppio che alto), largo quanto la zona colpita
## (radius), che si accende man mano che il colpo si avvicina (progress da
## 0 a 1), con un cuore più caldo e al centro una X rossa intermittente,
## anche lei stesa a terra, che lampeggia sempre più veloce.
static func danger_glow(canvas: CanvasItem, at: Vector2, radius: float, progress: float) -> void:
	var t := clampf(progress, 0.0, 1.0)
	# Il bordo del bagliore sfuma oltre la zona colpita: lo si allarga un po'
	# perché al limite della zona si veda ancora il rosso.
	Shapes.glow(canvas, at, radius * 1.3, Color(COLOR_DANGER_GLOW, 0.3 + 0.45 * t), GROUND_SQUASH)
	Shapes.glow(canvas, at, radius * (0.35 + 0.35 * t), Color(COLOR_DANGER_CORE, 0.15 + 0.45 * t), GROUND_SQUASH)
	var blink := sin(Time.get_ticks_msec() / 1000.0 * lerpf(DANGER_BLINK.x, DANGER_BLINK.y, t) * TAU)
	if blink > 0.0:
		var arm := radius * DANGER_CROSS
		var lines := PackedVector2Array([at + Vector2(-arm, -arm * GROUND_SQUASH), at + Vector2(arm, arm * GROUND_SQUASH),
				at + Vector2(-arm, arm * GROUND_SQUASH), at + Vector2(arm, -arm * GROUND_SQUASH)])
		canvas.draw_multiline(lines, Color(0.25, 0.0, 0.0, 0.6), 9.0)
		canvas.draw_multiline(lines, COLOR_DANGER_CROSS, 5.0)


## Toglie tutto (passando tra superficie e sotterraneo).
func clear() -> void:
	_drops.clear()
	_splats.clear()
	_corpses.clear()
	_pools.clear()
	_waves.clear()
	queue_redraw()
	_air.queue_redraw()
	_wave_layer.queue_redraw()


static func _ground(at: Vector2) -> float:
	return World.current.elevation_at(at) if World.current else 0.0


## Schizzo di sangue (vedi BloodSplatter.splat_texture) con la macchia
## centrale larga size e i rivoli nella direzione del colpo, steso a terra.
## grow: secondi in cui si allarga (0 = subito pieno).
func _add_splat(at: Vector2, elevation: float, size: float, direction: Vector2, grow: float) -> void:
	# La direzione è sullo schermo: in pianta la componente verticale è doppia.
	var angle := Vector2(direction.x, direction.y / GROUND_SQUASH).angle() + randf_range(-0.35, 0.35)
	_splats.append({
		"position": at, "elevation": elevation, "size": size, "angle": angle, "variant": randi(),
		"age": 0.0, "grow": grow, "color": BLOOD_COLOR.darkened(randf_range(0.0, 0.25)),
	})
	if _splats.size() > MAX_SPLATS:
		_splats.pop_front()
	_dirty = true


func _process(delta: float) -> void:
	var had_drops := not _drops.is_empty()
	var had_waves := not _waves.is_empty()
	var growing := false
	for i in range(_drops.size() - 1, -1, -1):
		var drop := _drops[i]
		drop["age"] += delta
		drop["position"] += drop["velocity"] * delta
		drop["rise"] -= DROP_GRAVITY * delta
		drop["altitude"] += drop["rise"] * delta
		var ground := _ground(drop["position"])
		if drop["altitude"] <= ground or drop["age"] > 2.0:
			_add_splat(drop["position"], ground, drop["size"] * randf_range(0.8, 1.6) * DROP_SPLAT, (drop["velocity"] as Vector2).normalized(), 0.0)
			_drops.remove_at(i)
	for list: Array[Dictionary] in [_splats, _corpses, _waves, _pools]:
		for item in list:
			item["age"] += delta
			if item.get("grow", 0.0) > 0.0 and item["age"] < item["grow"]:
				growing = true
	if not _pools.is_empty() and _pools[-1]["age"] < POOL_GROW:
		growing = true
	while not _splats.is_empty() and _splats[0]["age"] >= SPLAT_TIME:
		_splats.pop_front()
	while not _corpses.is_empty() and _corpses[0]["age"] >= CORPSE_TIME:
		_corpses.pop_front()
	while not _waves.is_empty() and _waves[0]["age"] >= CRACK_TIME:
		_waves.pop_front()
	# Gocce e onde si muovono: si ridisegnano finché ci sono (e un'ultima volta per toglierle).
	if had_drops or not _drops.is_empty():
		_air.queue_redraw()
	if had_waves or not _waves.is_empty():
		_wave_layer.queue_redraw()
	_redraw_timer -= delta
	if growing or (_dirty and _redraw_timer <= IDLE_REDRAW - SPLAT_REDRAW) or _redraw_timer <= 0.0:
		_redraw_timer = IDLE_REDRAW
		_dirty = false
		queue_redraw()


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
	for pool_item in _pools:
		var at: Vector2 = pool_item["position"] - Vector2(0, pool_item["elevation"])
		if not view.has_point(at):
			continue
		var size: float = pool_item["size"] * ease(minf(pool_item["age"] / POOL_GROW, 1.0), 0.35)
		BloodSplatter.draw(self, BloodSplatter.pool_texture(pool_item["variant"]), at, size, BloodSplatter.POOL_CORE,
				pool_item["angle"], Color(pool_item["color"], POOL_ALPHA), GROUND_SQUASH)
	for splat in _splats:
		var at: Vector2 = splat["position"] - Vector2(0, splat["elevation"])
		if not view.has_point(at):
			continue
		var grow: float = splat["grow"]
		var scale_factor := 1.0 if grow <= 0.0 else ease(minf(splat["age"] / grow, 1.0), 0.4)
		var color := Color(splat["color"], 0.85 * _fade(splat["age"], SPLAT_TIME))
		BloodSplatter.draw(self, BloodSplatter.splat_texture(splat["variant"]), at, splat["size"] * scale_factor,
				BloodSplatter.SPLAT_CORE, splat["angle"], color, GROUND_SQUASH)
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
	draw_set_transform(Vector2.ZERO)


## Anello che si allarga, polvere che vola via e crepe che restano un po',
## disegnati sullo strato delle onde (canvas).
func _draw_wave(canvas: CanvasItem, wave: Dictionary) -> void:
	var age: float = wave["age"]
	var radius: float = wave["radius"]
	canvas.draw_set_transform(wave["position"] - Vector2(0, wave["elevation"]), 0.0, Vector2(1.0, GROUND_SQUASH))
	var rng := RandomNumberGenerator.new()
	rng.seed = wave["seed"]
	var crack_alpha := clampf((CRACK_TIME - age) / 1.0, 0.0, 1.0) * 0.6
	for k in CRACK_COUNT:
		var direction := Vector2.from_angle(TAU * k / CRACK_COUNT + rng.randf_range(-0.3, 0.3))
		var length := radius * rng.randf_range(0.35, 0.65) * minf(age / 0.08, 1.0)
		var bend := direction.rotated(rng.randf_range(-0.5, 0.5))
		var middle := direction * length * 0.5
		canvas.draw_polyline(PackedVector2Array([Vector2.ZERO, middle, middle + bend * length * 0.5]), Color(0.15, 0.1, 0.05, crack_alpha), 3.0)
	if age < WAVE_TIME:
		var t := age / WAVE_TIME
		var ring := radius * (0.25 + 0.75 * ease(t, 0.4))
		Shapes.disc(canvas, Vector2.ZERO, ring, Color(COLOR_WAVE, 0.18 * (1.0 - t)))
		canvas.draw_arc(Vector2.ZERO, ring, 0.0, TAU, 48, Color(COLOR_WAVE, 0.9 * (1.0 - t)), 6.0 * (1.0 - t) + 1.0)
		for k in DUST_COUNT:
			var direction := Vector2.from_angle(TAU * k / DUST_COUNT + rng.randf_range(-0.2, 0.2))
			var at := direction * ring * rng.randf_range(0.7, 1.05) + Vector2(0, -40.0 * t * (1.0 - t) / GROUND_SQUASH)
			Shapes.disc(canvas, at, rng.randf_range(4.0, 9.0) * (1.0 - t * 0.6), Color(COLOR_DUST, 0.7 * (1.0 - t)))


## Gocce in volo, sopra personaggi e ostacoli.
class AirLayer:
	extends Node2D

	var fx: GroundFx

	func _draw() -> void:
		for drop in fx._drops:
			Shapes.disc(self, drop["position"] - Vector2(0, drop["altitude"]), drop["size"], GroundFx.BLOOD_COLOR.lightened(0.1))


## Onde d'urto, sopra le macchie.
class WaveLayer:
	extends Node2D

	var fx: GroundFx

	func _draw() -> void:
		for wave in fx._waves:
			fx._draw_wave(self, wave)
		draw_set_transform(Vector2.ZERO)
