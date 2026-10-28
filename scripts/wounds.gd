class_name Wounds
extends RefCounted
## Ferite temporanee sul corpo di chi viene colpito (giocatore e nemici):
## a ogni colpo compare uno squarcio (vedi BloodSplatter.wound_texture) sul
## lato da cui arriva il colpo, di traverso rispetto al colpo, che si apre
## in un attimo, cola un rivolo di sangue verso il basso e dopo LIFETIME
## secondi è svanito (sfuma negli ultimi FADE_TIME).

const LIFETIME := 1.6
const FADE_TIME := 0.7
const OPEN_TIME := 0.07
const MAX_WOUNDS := 5
## Lunghezza della ferita (metà) rispetto al raggio del corpo.
const LENGTH := Vector2(0.32, 0.48)
## Il rivolo che cola arriva a questa parte del raggio, in DRIP_TIME secondi.
const DRIP_LENGTH := 0.4
const DRIP_TIME := 0.9
const COLOR_DRIP := Color(0.5, 0.02, 0.03)

## Ferite in corso: posizione sul corpo (raggio 1), angolo, lunghezza ed età.
var _wounds: Array[Dictionary] = []


## Un colpo che arriva dalla direzione from (dal corpo verso chi colpisce).
func add(from: Vector2) -> void:
	var side := from.normalized() if from != Vector2.ZERO else Vector2.from_angle(randf() * TAU)
	var at := side.rotated(randf_range(-0.5, 0.5)) * randf_range(0.15, 0.4)
	_wounds.append({"at": at, "angle": side.angle() + PI / 2.0 + randf_range(-0.5, 0.5),
			"length": randf_range(LENGTH.x, LENGTH.y), "age": 0.0})
	if _wounds.size() > MAX_WOUNDS:
		_wounds.pop_front()


## Restituisce true finché c'è qualche ferita da disegnare.
func update(delta: float) -> bool:
	for wound in _wounds:
		wound["age"] += delta
	while not _wounds.is_empty() and _wounds[0]["age"] >= LIFETIME:
		_wounds.pop_front()
	return not _wounds.is_empty()


func clear() -> void:
	_wounds.clear()


## Ferite su un corpo tondo di raggio radius centrato in center.
func draw(canvas: CanvasItem, radius: float, alpha: float, center := Vector2.ZERO) -> void:
	for wound in _wounds:
		var age: float = wound["age"]
		var fade := clampf((LIFETIME - age) / FADE_TIME, 0.0, 1.0) * alpha
		var open := ease(minf(age / OPEN_TIME, 1.0), 0.5)
		var at := center + (wound["at"] as Vector2) * radius
		var length: float = wound["length"] * radius * (0.5 + 0.5 * open)
		var drip := DRIP_LENGTH * radius * ease(minf(age / DRIP_TIME, 1.0), 0.6)
		if drip > 1.0:
			canvas.draw_line(at, at + Vector2(0, drip), Color(COLOR_DRIP, 0.85 * fade), maxf(radius * 0.08, 1.5))
			Shapes.disc(canvas, at + Vector2(0, drip), maxf(radius * 0.06, 1.2), Color(COLOR_DRIP, 0.85 * fade))
		BloodSplatter.draw(canvas, BloodSplatter.wound_texture(), at, length, BloodSplatter.WOUND_CORE, wound["angle"], Color(1, 1, 1, fade))
