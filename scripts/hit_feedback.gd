class_name HitFeedback
## Sensazione del colpo: un attimo di "fermo" del gioco quando un colpo va
## a segno, così si sente l'impatto. Il controller non vibra.

## Durante il fermo il gioco va a questa frazione della velocità normale.
const STOP_TIME_SCALE := 0.05
## Il fermo più lungo che si può accumulare, in secondi reali.
const MAX_STOP := 0.18

## Fermi ancora in corso: il gioco riparte quando finisce l'ultimo.
static var _pending := 0


## stop: durata del fermo in secondi reali (0 = nessun fermo).
static func hit(tree: SceneTree, stop: float) -> void:
	if stop <= 0.0 or tree == null:
		return
	_pending += 1
	Engine.time_scale = STOP_TIME_SCALE
	# Il timer ignora il rallentamento e la pausa, così il gioco riparte sempre.
	tree.create_timer(minf(stop, MAX_STOP), true, false, true).timeout.connect(func() -> void: _end_stop())


static func _end_stop() -> void:
	_pending = maxi(_pending - 1, 0)
	if _pending == 0:
		Engine.time_scale = 1.0


## Da chiamare uscendo dalla partita, per non lasciare il gioco rallentato.
static func reset() -> void:
	_pending = 0
	Engine.time_scale = 1.0
