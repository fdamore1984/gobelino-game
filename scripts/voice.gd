class_name Voice
extends AudioStreamPlayer2D
## Voce di un personaggio (giocatore e nemici): un verso breve e secco a
## onda quadra (stile 8 bit) quando viene colpito e uno appena più lungo
## quando muore (suoni sintetizzati in Sfx). Ognuno ha il suo tono (tone: 1 = voce normale, più basso = più
## profonda). I versi di dolore partono da questo nodo e non si
## accavallano: un nuovo colpo non interrompe un verso appena iniziato, e in
## tutto il gioco ne partono al più MAX_PAINS insieme (per esempio quando un
## attacco a terra colpisce molti nemici). Il verso di morte usa un lettore di Sfx,
## così continua anche dopo che il nemico morto è sparito.

const PAIN_VOLUME := -4.0
const SCREAM_VOLUME := -3.0
const PAIN_MIN_GAP := 0.2
const MAX_PAINS := 3
const PAIN_WINDOW := 0.25

## Quando sono partiti gli ultimi versi di dolore (millisecondi).
static var _recent: Array[int] = []

var tone := 1.0
var _started := -100000


func _ready() -> void:
	max_distance = Sfx.MAX_DISTANCE
	attenuation = 1.5
	volume_db = PAIN_VOLUME


func pain() -> void:
	var now := Time.get_ticks_msec()
	if playing and now - _started < PAIN_MIN_GAP * 1000.0:
		return
	while not _recent.is_empty() and now - _recent[0] >= PAIN_WINDOW * 1000.0:
		_recent.pop_front()
	if _recent.size() >= MAX_PAINS:
		return
	_recent.append(now)
	_started = now
	stream = Sfx.voice("pain")
	pitch_scale = tone * randf_range(0.94, 1.06)
	play()


func scream() -> void:
	stop()
	Sfx.play_voice("scream", global_position, tone, SCREAM_VOLUME)
