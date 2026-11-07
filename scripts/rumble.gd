class_name Rumble
## Vibrazione del controller (opzione Vibrazione, vedi Settings): breve e
## leggera per i colpi dati, più forte per i colpi potenti e il
## contrattacco, forte per i colpi subiti, per le esplosioni sempre più
## debole con la distanza. Vibrano i controller collegati; nella Modalità
## Touch del browser, dove il telefono lo permette, vibra il telefono.
##
## Ogni effetto: [motore leggero, motore pesante, durata in secondi].

const HIT := [0.28, 0.0, 0.08]
const HEAVY_HIT := [0.45, 0.5, 0.15]
const COUNTER := [0.7, 0.75, 0.22]
const HURT := [0.55, 0.85, 0.25]
const PARRY := [0.35, 0.15, 0.1]
const EXPLOSION := [0.6, 1.0, 0.4]
## Oltre questa distanza un'esplosione non fa vibrare.
const EXPLOSION_RANGE := 800.0


## Un colpo a segno (heavy: colpo potente o finale della combo).
static func hit_dealt(heavy := false) -> void:
	_play(HEAVY_HIT if heavy else HIT)


static func counter() -> void:
	_play(COUNTER)


static func hurt() -> void:
	_play(HURT)


static func parry() -> void:
	_play(PARRY)


## Esplosione (missile, palla di fuoco, bomba H, runa) a distance pixel dal giocatore.
static func explosion(distance: float) -> void:
	var strength := clampf(1.0 - distance / EXPLOSION_RANGE, 0.0, 1.0)
	if strength > 0.0:
		_play([EXPLOSION[0] * strength, EXPLOSION[1] * strength, EXPLOSION[2]])


static func _play(effect: Array) -> void:
	if not Settings.vibration:
		return
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, effect[0], effect[1], effect[2])
	if Platform.touch_mode:
		Input.vibrate_handheld(roundi(float(effect[2]) * 1000.0), maxf(effect[0], effect[1]))
