class_name LightShaders
## Materiali per la luce della torcia (vedi Flashlight e World): in
## isometrico pareti, personaggi e oggetti sono disegnati più in alto del
## punto del pavimento su cui stanno, quindi luce e ombra vanno calcolate in
## quel punto, non dove sono disegnati (altrimenti una parete sarebbe
## sempre "dietro" al proprio muro, o illuminata anche oltre i muri).
##
## ground(): per i blocchi del terreno, ogni vertice dice nella coordinata
## UV.y di quanti pixel scendere per arrivare a terra (vedi World._light_uvs).
## feet(): per personaggi e oggetti, tutto è illuminato come i piedi (l'origine del nodo).

static var _ground: ShaderMaterial
static var _feet: ShaderMaterial


static func ground() -> ShaderMaterial:
	if _ground == null:
		_ground = _material("""
shader_type canvas_item;

void fragment() {
	SHADOW_VERTEX += vec2(0.0, UV.y);
	LIGHT_VERTEX.xy += vec2(0.0, UV.y);
}
""")
	return _ground


static func feet() -> ShaderMaterial:
	if _feet == null:
		_feet = _material("""
shader_type canvas_item;

varying vec2 to_feet;

void vertex() {
	to_feet = -VERTEX;
}

void fragment() {
	SHADOW_VERTEX += to_feet;
	LIGHT_VERTEX.xy += to_feet;
}
""")
	return _feet


static func _material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	return material
