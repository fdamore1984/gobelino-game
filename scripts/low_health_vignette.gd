class_name LowHealthVignette
extends ColorRect
## Con poca vita (un terzo o meno) i bordi dello schermo si tingono di rosso
## e pulsano come un battito, più forte quanto meno vita resta. Compare e
## sparisce con una dissolvenza.

const FADE_SPEED := 2.5
## Forza del rosso al limite della vita bassa e con un solo punto vita.
const INTENSITY_LOW := 0.45
const INTENSITY_LAST := 0.8
const PULSE_SPEED := 6.0
const PULSE_AMOUNT := 0.25
const SHADER_CODE := """
shader_type canvas_item;
uniform float intensity = 0.0;
uniform vec4 tint : source_color = vec4(0.8, 0.0, 0.02, 1.0);
void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float edge = length(centered * vec2(1.0, 0.9));
	COLOR = vec4(tint.rgb, smoothstep(0.55, 1.35, edge) * intensity);
}
"""

var player: Player

var _shown := 0.0
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color.WHITE
	var shader := Shader.new()
	shader.code = SHADER_CODE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	material = shader_material
	visible = false


func _process(delta: float) -> void:
	var target := 0.0
	if player and player.health > 0 and player.health <= maxf(1.0, player.max_health / 3.0):
		var threshold := maxf(1.0, player.max_health / 3.0)
		var depth := 1.0 - (player.health - 1.0) / maxf(threshold - 1.0, 1.0)
		target = lerpf(INTENSITY_LOW, INTENSITY_LAST, clampf(depth, 0.0, 1.0))
	elif player and player.is_dead():
		target = INTENSITY_LAST
	_shown = move_toward(_shown, target, FADE_SPEED * delta)
	visible = _shown > 0.0
	if not visible:
		return
	_time += delta
	var pulse := 1.0 - PULSE_AMOUNT + PULSE_AMOUNT * absf(sin(_time * PULSE_SPEED))
	(material as ShaderMaterial).set_shader_parameter("intensity", _shown * pulse)
