class_name Flashlight
extends Node2D
## Luce della torcia del giocatore: fasci a cono nella direzione
## dello sguardo (vedi LightTexture.get_cone_texture): uno ampio e
## profondo e, attorno, uno ancora più largo e lungo ma molto meno luminoso
## ("beams" della voce "flashlight" di data/world.json). In più un piccolo
## alone rotondo illumina il terreno attorno al personaggio ("halo"). I coni sono pensati in pianta e questo
## nodo li schiaccia a metà in verticale, come i cerchi a terra della
## prospettiva isometrica: puntati in orizzontale sono lunghi e stretti,
## verso l'alto o il basso dello schermo corti e larghi, come fasci stesi
## sul terreno. Il nodo va messo a terra sotto il personaggio, all'altezza
## del terreno su cui si trova (Player lo sposta, vedi LightShaders).
##
## Serve solo al buio: con abbastanza luce (di giorno, all'alba, al
## tramonto) i fasci non illuminano nulla; si accendono a poco a poco mentre
## il buio passa da "dark_from" a "dark_full" (vedi DayNight.darkness), e al
## buio pieno il fascio principale illumina quanto la luce del giorno.
##
## La luce non passa attraverso i muri: i fasci hanno le ombre degli
## ostacoli alla base dei blocchi (vedi World); pareti, personaggi e oggetti
## prendono la luce del punto del pavimento ai loro piedi (vedi LightShaders).

const DATA := preload("res://data/world.json")
## La prospettiva isometrica: il terreno è schiacciato a metà in verticale.
const GROUND_SQUASH := 0.5

## Accesa o spenta.
var enabled := false:
	set(value):
		enabled = value
		for light in _lights:
			light.enabled = value
		_halo.enabled = value

var _settings: Dictionary = DATA.data["flashlight"]
## Luci dei fasci e loro energia piena.
var _lights: Array[PointLight2D] = []
var _energies: Array[float] = []
## Alone attorno al personaggio (non segue lo sguardo) e sua energia piena.
var _halo := PointLight2D.new()
var _halo_energy := 0.0


func _init() -> void:
	scale = Vector2(1.0, GROUND_SQUASH)
	for beam: Dictionary in _settings["beams"]:
		var light := PointLight2D.new()
		light.texture = LightTexture.get_cone_texture(float(beam["angle"]))
		light.texture_scale = float(beam["range"]) / (LightTexture.CONE_SIZE / 2.0)
		light.color = World._color(_settings["color"])
		light.shadow_enabled = true
		light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		light.shadow_filter_smooth = 2.0
		light.shadow_item_cull_mask = World.OCCLUDER_BASE
		light.enabled = enabled
		add_child(light)
		_lights.append(light)
		_energies.append(float(beam["energy"]))
	# L'alone: la texture è già un'ellisse schiacciata, quindi qui si annulla
	# lo schiacciamento del nodo.
	var halo: Dictionary = _settings["halo"]
	_halo.texture = LightTexture.get_texture()
	_halo.texture_scale = float(halo["range"]) / (LightTexture.SIZE / 2.0)
	_halo.scale = Vector2(1.0, 1.0 / GROUND_SQUASH)
	_halo.color = World._color(_settings["color"])
	_halo.shadow_enabled = true
	_halo.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	_halo.shadow_filter_smooth = 2.0
	_halo.shadow_item_cull_mask = World.OCCLUDER_BASE
	_halo.enabled = enabled
	_halo_energy = float(halo["energy"])
	add_child(_halo)


## Quanto illuminano adesso i fasci accesi, da 0 (c'è luce: niente) a 1
## (buio pieno: come di giorno).
func strength() -> float:
	if not enabled:
		return 0.0
	var dark := DayNight.current.darkness() if DayNight.current else 1.0
	return smoothstep(float(_settings["dark_from"]), float(_settings["dark_full"]), dark)


func _process(_delta: float) -> void:
	if enabled:
		var power := strength()
		for k in _lights.size():
			_lights[k].energy = _energies[k] * power
			_lights[k].visible = power > 0.001
		_halo.energy = _halo_energy * power
		_halo.visible = power > 0.001


## Punta i fasci nella direzione dello sguardo (sullo schermo): in pianta
## la componente verticale è il doppio.
func aim(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		for light in _lights:
			light.rotation = Vector2(direction.x, direction.y / GROUND_SQUASH).angle()
