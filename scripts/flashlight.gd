class_name Flashlight
extends Node2D
## Luce della torcia del giocatore: un fascio a cono nella
## direzione dello sguardo, ampio e profondo, senza alone attorno al
## personaggio (vedi LightTexture.get_cone_texture). Il cono è pensato in pianta e questo nodo
## lo schiaccia a metà in verticale, come i cerchi a terra della
## prospettiva isometrica: puntato in orizzontale è lungo e stretto, verso
## l'alto o il basso dello schermo è corto e largo, come un fascio steso sul
## terreno. Il nodo va messo a terra sotto il personaggio (Player lo sposta).

const COLOR := Color(1.0, 0.78, 0.45)
const ENERGY := 1.25
## Portata del fascio in pixel di terreno, in pianta.
const RANGE := 960.0
## La prospettiva isometrica: il terreno è schiacciato a metà in verticale.
const GROUND_SQUASH := 0.5

## Accesa o spenta.
var enabled := false:
	set(value):
		enabled = value
		_light.enabled = value

var _light := PointLight2D.new()


func _init() -> void:
	scale = Vector2(1.0, GROUND_SQUASH)
	_light.texture = LightTexture.get_cone_texture()
	_light.texture_scale = RANGE / (LightTexture.CONE_SIZE / 2.0)
	_light.color = COLOR
	_light.energy = ENERGY
	_light.enabled = enabled
	add_child(_light)


## Punta il fascio nella direzione dello sguardo (sullo schermo): in pianta
## la componente verticale è il doppio.
func aim(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		_light.rotation = Vector2(direction.x, direction.y / GROUND_SQUASH).angle()
