class_name Flashlight
extends Node2D
## Luce della torcia del giocatore: un solo fascio a cono, ampio e
## profondo, nella direzione dello sguardo (vedi LightTexture.get_cone_texture
## e la voce "flashlight" di data/world.json: "beam" è il fascio). Niente
## alone attorno al personaggio né fasci di contorno: la luce è solo quella
## del cono, che parte un poco dietro le spalle ("back_offset" pixel, in
## pianta, dalla parte opposta allo sguardo) così avvolge anche chi tiene
## la torcia. Il cono è pensato in pianta e questo nodo lo schiaccia a metà
## in verticale, come i cerchi a terra della prospettiva isometrica:
## puntato in orizzontale è lungo e stretto, verso l'alto o il basso dello
## schermo corto e largo, come un fascio steso sul terreno. Il nodo va
## messo a terra sotto il personaggio, all'altezza del terreno su cui si
## trova (Player lo sposta, vedi LightShaders).
##
## Serve solo al buio: con abbastanza luce (di giorno, all'alba, al
## tramonto) il fascio non illumina nulla; si accende a poco a poco mentre
## il buio passa da "dark_from" a "dark_full" (vedi DayNight.darkness), e al
## buio pieno illumina quanto la luce del giorno.
##
## La luce non passa attraverso i muri: il fascio ha le ombre degli
## ostacoli alla base dei blocchi (vedi World); pareti, personaggi e oggetti
## prendono la luce del punto del pavimento ai loro piedi (vedi LightShaders).

const DATA := preload("res://data/world.json")
## La prospettiva isometrica: il terreno è schiacciato a metà in verticale.
const GROUND_SQUASH := 0.5

## Accesa o spenta.
var enabled := false:
	set(value):
		enabled = value
		_light.enabled = value

var _settings: Dictionary = DATA.data["flashlight"]
## Luce del fascio e sua energia piena.
var _light := PointLight2D.new()
var _energy := 1.0
## Energia data adesso (per non riscriverla a ogni frame se non cambia).
var _power := -1.0


func _init() -> void:
	scale = Vector2(1.0, GROUND_SQUASH)
	var beam: Dictionary = _settings["beam"]
	_light.texture = LightTexture.get_cone_texture(float(beam["angle"]))
	_light.texture_scale = float(beam["range"]) / (LightTexture.CONE_SIZE / 2.0)
	_light.color = World._color(_settings["color"])
	_light.shadow_enabled = true
	_light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	_light.shadow_filter_smooth = 2.0
	_light.shadow_item_cull_mask = World.OCCLUDER_BASE
	_light.enabled = enabled
	_energy = float(beam["energy"])
	add_child(_light)


## Quanto illumina adesso il fascio acceso, da 0 (c'è luce: niente) a 1
## (buio pieno: come di giorno).
func strength() -> float:
	if not enabled:
		return 0.0
	var dark := DayNight.current.darkness() if DayNight.current else 1.0
	return smoothstep(float(_settings["dark_from"]), float(_settings["dark_full"]), dark)


func _process(_delta: float) -> void:
	if not enabled:
		return
	var power := strength()
	if not is_equal_approx(power, _power):
		_power = power
		_light.energy = _energy * power
		_light.visible = power > 0.001


## Distanza (in pianta) del vertice del cono dietro le spalle.
func back_offset() -> float:
	return float(_settings["back_offset"])


## Punta il fascio nella direzione dello sguardo (sullo schermo): in pianta
## la componente verticale è il doppio. back: quanto arretrare il vertice
## del cono dietro le spalle (in pianta; vedi Player.place_torch, che lo
## accorcia contro un muro).
func aim(direction: Vector2, back := -1.0) -> void:
	if direction == Vector2.ZERO:
		return
	var plan := Vector2(direction.x, direction.y / GROUND_SQUASH).normalized()
	_light.rotation = plan.angle()
	_light.position = -plan * (back_offset() if back < 0.0 else back)


## Vertice del cono sul terreno (coordinate del mondo) puntando verso
## direction con il vertice arretrato di back (in pianta), partendo dai
## piedi in feet.
static func origin_from(feet: Vector2, direction: Vector2, back: float) -> Vector2:
	var plan := Vector2(direction.x, direction.y / GROUND_SQUASH).normalized()
	return feet - Vector2(plan.x, plan.y * GROUND_SQUASH) * back
