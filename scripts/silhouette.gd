class_name Silhouette
extends Node2D
## Sagoma di un personaggio (giocatore o nemico) che sta dietro a un muro:
## i muri non diventano trasparenti, ma sopra di loro si vedono, in
## trasparenza, solo i contorni del corpo, senza gambe (vedi
## World.is_covered). Il personaggio controlla ogni tanto se è coperto
## (update) e la sagoma copia la sua posa: centro e raggio del corpo e
## direzione dello sguardo. Per il giocatore, in più, il muro davanti diventa
## trasparente attorno al corpo (vedi World.update_cutout).
##
## La sagoma del goblin si vede sempre (senza luci); quella dei nemici prende
## la luce come i loro piedi (LightShaders.feet): al buio si vede solo se la
## torcia li raggiunge.

## Disegnata sopra il terreno e i personaggi.
const Z_INDEX := 50
const WIDTH := 2.0
const SEGMENTS := 24
## Punti del corpo controllati: centro, sopra la testa e piedi (frazioni del raggio).
const CHECK_POINTS := [0.0, -0.9, 1.4]

var color := Color(1, 1, 1, 0.6)
## Posa da disegnare, rispetto all'origine del personaggio (i piedi a terra).
var body_center := Vector2.ZERO
var radius := 20.0
var facing := Vector2.RIGHT


func _init(line_color: Color, always_visible: bool) -> void:
	color = line_color
	z_index = Z_INDEX
	z_as_relative = false
	visible = false
	material = Enemy._unshaded_material() if always_visible else LightShaders.feet()


## Controlla se il personaggio (piedi in feet, alla quota altitude) è
## coperto da un muro e aggiorna la posa; restituisce se si vede.
func update(feet: Vector2, altitude: float) -> bool:
	var world := World.current
	var covered := false
	if world:
		var points := PackedVector2Array()
		for share: float in CHECK_POINTS:
			points.append(feet + body_center + Vector2(0, radius * share))
		covered = world.is_covered(feet, altitude, points)
	if covered or visible:
		queue_redraw()
	visible = covered
	return covered


func _draw() -> void:
	var outline := PackedVector2Array()
	for k in SEGMENTS + 1:
		outline.append(body_center + Vector2.from_angle(TAU * k / SEGMENTS) * radius)
	draw_polyline(outline, color, WIDTH, true)
	# "Naso" che indica la direzione.
	var side := facing.orthogonal() * radius * 0.35
	var base := body_center + facing * radius * 0.85
	draw_polyline(PackedVector2Array([base + side, body_center + facing * (radius + 10.0), base - side]), color, WIDTH, true)
