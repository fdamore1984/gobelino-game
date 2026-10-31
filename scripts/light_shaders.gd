class_name LightShaders
## Materiali per la luce della torcia (vedi Flashlight e World): in
## isometrico pareti, personaggi e oggetti sono disegnati più in alto del
## punto del pavimento su cui stanno.
##
## Godot (4.4) prende la forma della luce (la texture del fascio) sempre nel
## punto in cui il pixel è disegnato, qualunque cosa dica LIGHT_VERTEX:
## per questo la torcia sta ai piedi del giocatore, all'altezza del terreno
## su cui si trova (anche in cima a un altopiano), e il fascio si stende
## sullo schermo da lì. Le ombre invece si calcolano in pianta, dove stanno
## gli ostacoli per la luce (vedi World): nel punto del pavimento sotto
## quello che si disegna, alzato quanto il terreno sotto il giocatore
## (set_lift; World alza allo stesso modo gli ostacoli). Così pareti e
## montagne fanno ombra giusta a qualunque altezza.
##
## ground(): per i blocchi del terreno, ogni vertice dice nella coordinata
## UV.y di quanti pixel scendere per arrivare in pianta (vedi World._light_uvs).
## feet(): per personaggi e oggetti, l'ombra si calcola ai piedi (l'origine del nodo).
## cutout(): come ground(), ma trasparente in un cerchio attorno al
## giocatore: per i blocchi che lo coprono (vedi World.update_cutout).
##
## Gli spostamenti sono in pixel del mondo: gli shader li portano in pixel
## dello schermo, compresi lo zoom della telecamera e la scala della finestra.

## Trasparenza dei muri dentro il cerchio attorno al giocatore (vedi cutout).
const CUTOUT_ALPHA := 0.25

static var _ground: ShaderMaterial
static var _feet: ShaderMaterial
static var _cutout: ShaderMaterial
static var _lift := 0.0

const _GROUND_CODE := """
shader_type canvas_item;

uniform float lift = 0.0;
varying vec2 drop;

void vertex() {
	drop = (CANVAS_MATRIX * MODEL_MATRIX * vec4(0.0, UV.y - lift, 0.0, 0.0)).xy;
}

void fragment() {
	SHADOW_VERTEX += drop;
}
"""


static func ground() -> ShaderMaterial:
	if _ground == null:
		_ground = _material(_GROUND_CODE)
	return _ground


static func feet() -> ShaderMaterial:
	if _feet == null:
		_feet = _material("""
shader_type canvas_item;

uniform float lift = 0.0;
varying vec2 to_feet;

void vertex() {
	to_feet = (CANVAS_MATRIX * MODEL_MATRIX * vec4(-VERTEX.x, -VERTEX.y - lift, 0.0, 0.0)).xy;
}

void fragment() {
	SHADOW_VERTEX += to_feet;
}
""")
	return _feet


static func cutout() -> ShaderMaterial:
	if _cutout == null:
		_cutout = _material("""
shader_type canvas_item;

uniform float lift = 0.0;
uniform vec2 hole_center = vec2(0.0);
uniform float hole_radius = 80.0;
uniform float hole_strength = 0.0;
varying vec2 drop;
varying vec2 world;

void vertex() {
	drop = (CANVAS_MATRIX * MODEL_MATRIX * vec4(0.0, UV.y - lift, 0.0, 0.0)).xy;
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	SHADOW_VERTEX += drop;
	float inside = 1.0 - smoothstep(hole_radius * 0.55, hole_radius, distance(world, hole_center));
	COLOR.a *= 1.0 - inside * hole_strength * (1.0 - %s);
}
""" % str(CUTOUT_ALPHA))
	return _cutout


## Altezza del terreno sotto il giocatore (dove sta la torcia), per le ombre.
static func set_lift(lift: float) -> void:
	_lift = lift
	for material in [ground(), feet(), cutout()]:
		material.set_shader_parameter("lift", lift)


static func lift() -> float:
	return _lift


static func _material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	return material
