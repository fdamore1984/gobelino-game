class_name LowHealthVignette
extends ColorRect
## Effetti a tutto schermo sopra il mondo (non sull'interfaccia, che viene
## disegnata dopo).
##
## Vita bassa: con un terzo della vita o meno i bordi dello schermo si
## tingono di rosso e pulsano come un battito, più forte quanto meno vita
## resta.
##
## Modalità focus (tenendo premuto "focus", R2 / V): il mondo perde colore
## e luce (saturazione e gamma più bassi) e i bordi si scuriscono con una
## vignettatura nera. Il giocatore e gli elementi con cui interagire (oggetti
## a terra, casse chiuse, ingressi, mercanti, totem pronti) restano a colori
## pieni: sono i nodi del gruppo FOCUS_GROUP, che con focus_spot() dicono
## dove stanno sullo schermo e quanto sono grandi; attorno disegnano da sé
## un'aura bianca.
##
## Attacco speciale della Frenesia (vedi Player.special_darkness): lo
## sfondo diventa quasi nero, con un velo rosso, tranne attorno al goblin, che
## resta a colori con il suo bagliore.
##
## Gli effetti compaiono e spariscono con una dissolvenza; quando nessuno
## è attivo il nodo è nascosto e non costa niente.

const FADE_SPEED := 2.5
## Forza del rosso al limite della vita bassa e con un solo punto vita.
const INTENSITY_LOW := 0.45
const INTENSITY_LAST := 0.8
const PULSE_SPEED := 6.0
const PULSE_AMOUNT := 0.25
## Gruppo dei nodi che in modalità focus restano a colori (vedi focus_spot).
const FOCUS_GROUP := "focus_targets"
## Quanti se ne passano al massimo allo shader (i più vicini al giocatore).
const MAX_FOCUS_TARGETS := 24
const FOCUS_FADE_SPEED := 6.0
const FOCUS_SATURATION := 0.3
const FOCUS_GAMMA := 1.45
const FOCUS_VIGNETTE := 0.9
## Attacco speciale: quanto resta della luce dello sfondo, il suo colore e
## quanto è largo (rispetto al raggio di focus_spot) il cerchio attorno a
## goblin che resta a colori.
const SPECIAL_LIGHT := 0.1
const SPECIAL_TINT := Color(0.12, 0.0, 0.01)
const SPECIAL_SPOT_FACTOR := 1.25
const SHADER_CODE := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float intensity = 0.0;
uniform vec4 tint : source_color = vec4(0.8, 0.0, 0.02, 1.0);
uniform float focus = 0.0;
uniform float saturation = 0.3;
uniform float gamma = 1.45;
uniform float vignette = 0.9;
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform int target_count = 0;
uniform vec3 targets[24];
uniform float dark = 0.0;
uniform vec3 hero = vec3(0.0);
uniform float dark_light = 0.1;
uniform vec4 dark_tint : source_color = vec4(0.12, 0.0, 0.01, 1.0);
void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float edge = length(centered * vec2(1.0, 0.9));
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	if (dark > 0.0) {
		// Attacco speciale: tutto quasi nero tranne il cerchio attorno al goblin.
		float keep = 1.0 - smoothstep(hero.z * 0.55, hero.z, distance(UV * rect_size, hero.xy));
		vec3 night = color * dark_light + dark_tint.rgb;
		color = mix(color, mix(night, color, keep), dark);
	}
	if (focus > 0.0) {
		// Attorno al giocatore e agli elementi importanti i colori restano pieni.
		vec2 pixel = UV * rect_size;
		float keep = 0.0;
		for (int i = 0; i < target_count; i++) {
			float d = distance(pixel, targets[i].xy);
			keep = max(keep, 1.0 - smoothstep(targets[i].z * 0.6, targets[i].z, d));
		}
		float grey = dot(color, vec3(0.299, 0.587, 0.114));
		vec3 dull = pow(mix(vec3(grey), color, saturation), vec3(gamma));
		dull *= 1.0 - smoothstep(0.3, 1.25, edge) * vignette;
		color = mix(color, mix(dull, color, keep), focus);
	}
	color = mix(color, tint.rgb, smoothstep(0.55, 1.35, edge) * intensity);
	COLOR = vec4(color, 1.0);
}
"""

var player: Player

var _shown := 0.0
var _time := 0.0
var _focus := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color.WHITE
	var shader := Shader.new()
	shader.code = SHADER_CODE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("saturation", FOCUS_SATURATION)
	shader_material.set_shader_parameter("gamma", FOCUS_GAMMA)
	shader_material.set_shader_parameter("vignette", FOCUS_VIGNETTE)
	shader_material.set_shader_parameter("dark_light", SPECIAL_LIGHT)
	shader_material.set_shader_parameter("dark_tint", SPECIAL_TINT)
	material = shader_material
	visible = false


## Modalità focus attiva: tenendo premuto "focus" in gioco (non in pausa né da morti).
static func focus_held() -> bool:
	return UiNav.game_held("focus")


func _process(delta: float) -> void:
	var target := 0.0
	if player and player.health > 0 and player.health <= maxf(1.0, player.max_health / 3.0):
		var threshold := maxf(1.0, player.max_health / 3.0)
		var depth := 1.0 - (player.health - 1.0) / maxf(threshold - 1.0, 1.0)
		target = lerpf(INTENSITY_LOW, INTENSITY_LAST, clampf(depth, 0.0, 1.0))
	elif player and player.is_dead():
		target = INTENSITY_LAST
	_shown = move_toward(_shown, target, FADE_SPEED * delta)
	var focusing := player != null and not player.is_dead() and not get_tree().paused and focus_held()
	_focus = move_toward(_focus, 1.0 if focusing else 0.0, FOCUS_FADE_SPEED * delta)
	# La dissolvenza del buio la fa già il giocatore (con un Tween).
	var dark := player.special_darkness() if player else 0.0
	visible = _shown > 0.0 or _focus > 0.0 or dark > 0.0
	if not visible:
		return
	_time += delta
	var pulse := 1.0 - PULSE_AMOUNT + PULSE_AMOUNT * absf(sin(_time * PULSE_SPEED))
	var shader_material := material as ShaderMaterial
	shader_material.set_shader_parameter("intensity", _shown * pulse)
	shader_material.set_shader_parameter("focus", _focus)
	shader_material.set_shader_parameter("dark", dark)
	shader_material.set_shader_parameter("rect_size", size)
	if dark > 0.0:
		var to_screen := get_viewport().get_canvas_transform()
		var spot := player.focus_spot()
		var at := to_screen * Vector2(spot.x, spot.y)
		shader_material.set_shader_parameter("hero", Vector3(at.x, at.y, spot.z * to_screen.get_scale().x * SPECIAL_SPOT_FACTOR))
	if _focus > 0.0:
		_update_targets(shader_material)


## Posizioni sullo schermo (in pixel di questo rettangolo) e raggi dei nodi
## che restano a colori: solo quelli visibili, i più vicini al giocatore.
func _update_targets(shader_material: ShaderMaterial) -> void:
	var to_screen := get_viewport().get_canvas_transform()
	var scale_factor := to_screen.get_scale().x
	var view := Rect2(Vector2.ZERO, size)
	var found: Array[Vector3] = []
	for node in get_tree().get_nodes_in_group(FOCUS_GROUP):
		var spot: Vector3 = node.call("focus_spot")
		if spot.z <= 0.0:
			continue
		var at := to_screen * Vector2(spot.x, spot.y)
		var radius := spot.z * scale_factor
		if view.grow(radius).has_point(at):
			found.append(Vector3(at.x, at.y, radius))
	if found.size() > MAX_FOCUS_TARGETS:
		var middle := size / 2.0
		found.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			return Vector2(a.x, a.y).distance_squared_to(middle) < Vector2(b.x, b.y).distance_squared_to(middle))
		found.resize(MAX_FOCUS_TARGETS)
	var targets := PackedVector3Array(found)
	targets.resize(MAX_FOCUS_TARGETS)
	shader_material.set_shader_parameter("targets", targets)
	shader_material.set_shader_parameter("target_count", found.size())
	shader_material.set_shader_parameter("rect_size", size)
