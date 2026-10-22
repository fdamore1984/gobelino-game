class_name HitFeedback
## Sensazione del colpo: vibrazione del controller (e del telefono) e un
## attimo di "fermo" del gioco quando un colpo va a segno, così si sente
## l'impatto.

## Durante il fermo il gioco va a questa frazione della velocità normale.
const STOP_TIME_SCALE := 0.05
## Il fermo più lungo che si può accumulare, in secondi reali.
const MAX_STOP := 0.18

## Fermi ancora in corso: il gioco riparte quando finisce l'ultimo.
static var _pending := 0


## strength tra 0 e 1: un colpo normale vale circa 0,4, un colpo potente
## carico 1. stop: durata del fermo in secondi reali (0 = nessun fermo).
static func hit(tree: SceneTree, strength: float, stop: float) -> void:
	vibrate(strength, 0.08 + 0.12 * strength)
	if stop <= 0.0 or tree == null:
		return
	_pending += 1
	Engine.time_scale = STOP_TIME_SCALE
	# Il timer ignora il rallentamento e la pausa, così il gioco riparte sempre.
	tree.create_timer(minf(stop, MAX_STOP), true, false, true).timeout.connect(func() -> void: _end_stop())


static func vibrate(strength: float, duration: float) -> void:
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, clampf(strength * 0.7, 0.0, 1.0), clampf(strength, 0.0, 1.0), duration)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(int(duration * 1000.0), clampf(strength, 0.1, 1.0))


static func _end_stop() -> void:
	_pending = maxi(_pending - 1, 0)
	if _pending == 0:
		Engine.time_scale = 1.0


## Da chiamare uscendo dalla partita, per non lasciare il gioco rallentato.
static func reset() -> void:
	_pending = 0
	Engine.time_scale = 1.0
