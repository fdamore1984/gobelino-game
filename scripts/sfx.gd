extends Node
## Effetti sonori (autoload "Sfx").
##
## Finché non ci sono file audio veri, i suoni vengono sintetizzati all'avvio
## con forme d'onda semplici. Per sostituirne uno basterà caricare il file
## al posto della sintesi nello stesso dizionario.

const MIX_RATE := 22050
const POOL_SIZE := 16
## Oltre questa distanza i suoni posizionali non si sentono più.
const MAX_DISTANCE := 1400.0

var _streams := {}
var _pool: Array[AudioStreamPlayer2D] = []
var _next := 0
var _ui_player := AudioStreamPlayer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_sounds()
	for i in POOL_SIZE:
		var player := AudioStreamPlayer2D.new()
		player.max_distance = MAX_DISTANCE
		player.attenuation = 1.5
		add_child(player)
		_pool.append(player)
	add_child(_ui_player)


## Suono nel mondo di gioco, posizionato in at. Il tono varia di poco
## a ogni riproduzione, così i suoni ripetuti non stancano.
func play(sound: String, at: Vector2, pitch := 1.0, volume_db := 0.0) -> void:
	if not _streams.has(sound):
		return
	var player := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = _streams[sound]
	player.global_position = at
	player.pitch_scale = pitch * randf_range(0.95, 1.05)
	player.volume_db = volume_db
	player.play()


## Suono dell'interfaccia, non posizionale.
func play_ui(sound: String) -> void:
	if not _streams.has(sound):
		return
	_ui_player.stream = _streams[sound]
	_ui_player.play()


func _build_sounds() -> void:
	# Personaggio
	_streams["swing"] = _render_filtered(0.16, Vector2(0.5, 0.12), func(t: float, d: float) -> float:
		return _noise() * _env(t, d, 0.01) * 0.6)
	_streams["hit"] = _render(0.15, func(t: float, d: float) -> float:
		var tone := sin(TAU * lerpf(150.0, 55.0, t / d) * t)
		return (tone * 0.8 + _noise() * 0.4 * _env(t, 0.03, 0.0)) * _env(t, d, 0.003))
	_streams["dodge"] = _render_filtered(0.22, Vector2(0.12, 0.45), func(t: float, d: float) -> float:
		return _noise() * sin(PI * t / d) * 0.45)
	_streams["block"] = _render(0.25, func(t: float, d: float) -> float:
		var metal := sin(TAU * 1200.0 * t) + sin(TAU * 1870.0 * t) * 0.6 + sin(TAU * 2650.0 * t) * 0.4
		return metal * 0.3 * exp(-t * 18.0))
	_streams["perfect"] = _render(0.55, func(t: float, _d: float) -> float:
		var chime := sin(TAU * 880.0 * t) + sin(TAU * 1320.0 * t) * 0.7
		if t > 0.08:
			chime += sin(TAU * 1760.0 * t) * exp(-(t - 0.08) * 6.0)
		return chime * 0.25 * exp(-t * 5.0))
	_streams["hurt"] = _render(0.25, func(t: float, d: float) -> float:
		var square := signf(sin(TAU * lerpf(220.0, 110.0, t / d) * t))
		return (square * 0.35 + _noise() * 0.25) * _env(t, d, 0.005))
	_streams["death"] = _render(0.7, func(t: float, d: float) -> float:
		return signf(sin(TAU * lerpf(320.0, 50.0, t / d) * t)) * 0.3 * _env(t, d, 0.01))
	_streams["level_up"] = _render(0.5, func(t: float, _d: float) -> float:
		var notes := [523.25, 659.25, 783.99, 1046.5]
		var index := mini(int(t / 0.09), notes.size() - 1)
		var local := t - index * 0.09
		return _triangle(notes[index] * t) * 0.4 * exp(-local * (4.0 if index == 3 else 12.0)))
	# Sferzata del colpo potente: suona al rilascio, con un attacco secco.
	_streams["heavy_swing"] = _render_filtered(0.3, Vector2(0.35, 0.06), func(t: float, d: float) -> float:
		var rumble := sin(TAU * lerpf(90.0, 50.0, t / d) * t) * 0.5
		return (_noise() * 0.7 + rumble) * _env(t, d, 0.008))
	_streams["potion"] = _render(0.45, func(t: float, _d: float) -> float:
		# Bollicine: brevi toni ascendenti in sequenza.
		var local := fmod(t, 0.09)
		var base := 500.0 + int(t / 0.09) * 120.0
		return sin(TAU * (base + local * 2500.0) * t) * 0.22 * exp(-local * 30.0))
	_streams["shield_up"] = _render(0.4, func(t: float, d: float) -> float:
		var shimmer := sin(TAU * lerpf(400.0, 900.0, t / d) * t) + sin(TAU * lerpf(600.0, 1350.0, t / d) * t) * 0.5
		return shimmer * 0.2 * sin(PI * t / d))
	_streams["shield_break"] = _render(0.35, func(t: float, d: float) -> float:
		var glass := sin(TAU * 1800.0 * t) * 0.3 + sin(TAU * 2700.0 * t) * 0.2
		return (glass + _noise() * 0.35) * _env(t, d, 0.002) * exp(-t * 6.0))
	_streams["jump"] = _render(0.18, func(t: float, d: float) -> float:
		return _triangle(lerpf(300.0, 700.0, t / d) * t) * 0.3 * _env(t, d, 0.005))
	_streams["slide"] = _render_filtered(0.4, Vector2(0.25, 0.08), func(t: float, d: float) -> float:
		return _noise() * 0.5 * _env(t, d, 0.02))
	_streams["xp"] = _render(0.08, func(t: float, d: float) -> float:
		return sin(TAU * lerpf(1200.0, 1600.0, t / d) * t) * 0.25 * _env(t, d, 0.005))
	_streams["charge_full"] = _render(0.25, func(t: float, d: float) -> float:
		return (sin(TAU * 1500.0 * t) + sin(TAU * 2250.0 * t) * 0.5) * 0.18 * _env(t, d, 0.003))
	_streams["mana_potion"] = _render(0.5, func(t: float, d: float) -> float:
		var shimmer := sin(TAU * lerpf(700.0, 1400.0, t / d) * t) * 0.6 + sin(TAU * 2100.0 * t) * 0.2
		return shimmer * 0.25 * sin(PI * t / d))
	_streams["stamina_potion"] = _render(0.4, func(t: float, d: float) -> float:
		# Sorso energico: un tono che sale svelto, con un battito.
		var rise := _triangle(lerpf(350.0, 900.0, t / d) * t) * 0.3
		return rise * (0.6 + 0.4 * absf(sin(TAU * 12.0 * t))) * sin(PI * t / d))
	# Magia
	_streams["fireball"] = _render_filtered(0.45, Vector2(0.15, 0.4), func(t: float, d: float) -> float:
		var roar := sin(TAU * lerpf(120.0, 220.0, t / d) * t) * 0.4
		return (_noise() * 0.6 + roar) * _env(t, d, 0.03))
	_streams["fireball_hit"] = _render_filtered(0.5, Vector2(0.5, 0.05), func(t: float, d: float) -> float:
		var boom := sin(TAU * lerpf(110.0, 40.0, t / d) * t) * 0.6
		return (_noise() * 0.7 + boom) * _env(t, d, 0.004))
	# Oggetti
	_streams["torch"] = _render_filtered(0.3, Vector2(0.4, 0.15), func(t: float, d: float) -> float:
		return _noise() * 0.4 * _env(t, d, 0.01))
	_streams["chest_open"] = _render(0.5, func(t: float, d: float) -> float:
		# Cigolio del coperchio e poi un accordo.
		var creak := signf(sin(TAU * (180.0 + 60.0 * sin(TAU * 9.0 * t)) * t)) * 0.12 * exp(-t * 8.0)
		var chord := 0.0
		if t > 0.15:
			var local := t - 0.15
			chord = (sin(TAU * 660.0 * t) + sin(TAU * 880.0 * t) + sin(TAU * 1100.0 * t)) * 0.12 * exp(-local * 5.0)
		return (creak + chord) * _env(t, d, 0.005))
	_streams["pickup"] = _render(0.15, func(t: float, d: float) -> float:
		return _triangle(lerpf(700.0, 1300.0, t / d) * t) * 0.3 * _env(t, d, 0.003))
	# Risatina da goblin: cinque "eh" brevi e nasali, sempre un po' più bassi.
	_streams["giggle"] = _render(0.85, func(t: float, _d: float) -> float:
		var syllable := fmod(t, 0.16)
		var index := floorf(t / 0.16)
		var pitch := 760.0 - index * 45.0 + 35.0 * sin(TAU * 17.0 * t)
		var env := exp(-syllable * 20.0) * (1.0 - exp(-syllable * 220.0))
		return (sin(TAU * pitch * t) * 0.55 + sin(TAU * pitch * 2.0 * t) * 0.3 + _noise() * 0.18 * exp(-syllable * 70.0)) * env * 0.4)
	_streams["coin"] = _render(0.2, func(t: float, _d: float) -> float:
		var note := 1800.0 if t < 0.06 else 2400.0
		return sin(TAU * note * t) * 0.25 * exp(-fmod(t, 0.06) * 25.0))
	# Nemici
	_streams["enemy_windup"] = _render(0.5, func(t: float, d: float) -> float:
		return _triangle(lerpf(180.0, 420.0, t / d) * t) * 0.25 * _env(t, d, 0.05))
	_streams["enemy_strike"] = _render_filtered(0.2, Vector2(0.3, 0.08), func(t: float, d: float) -> float:
		return _noise() * _env(t, d, 0.01) * 0.6)
	# Arciere: la corda dell'arco vibra e la freccia sibila via.
	_streams["bow"] = _render(0.3, func(t: float, d: float) -> float:
		var twang := _triangle(lerpf(190.0, 150.0, t / d) * t) * exp(-t * 14.0)
		return (twang * 0.5 + _noise() * 0.18 * _env(t, 0.12, 0.01)) * _env(t, d, 0.003))
	_streams["enemy_death"] = _render(0.35, func(t: float, d: float) -> float:
		var tone := sin(TAU * lerpf(520.0, 110.0, t / d) * t)
		return (tone * 0.5 + _noise() * 0.2) * _env(t, d, 0.005))
	_streams["stun"] = _render(0.3, func(t: float, _d: float) -> float:
		var local := fmod(t, 0.15)
		var base := 900.0 if t < 0.15 else 700.0
		return sin(TAU * (base - local * 1500.0) * t) * 0.25 * exp(-local * 20.0))
	_streams["summon"] = _render(1.0, func(t: float, d: float) -> float:
		var frequency := lerpf(250.0, 500.0, t / d) + 40.0 * sin(TAU * 12.0 * t)
		return sin(TAU * frequency * t) * 0.22 * sin(PI * t / d))
	_streams["summon_pop"] = _render(0.18, func(t: float, d: float) -> float:
		return (_noise() * 0.4 + sin(TAU * 600.0 * t) * 0.3) * _env(t, d, 0.003))
	# Interfaccia
	_streams["ui_move"] = _render(0.04, func(t: float, d: float) -> float:
		return sin(TAU * 900.0 * t) * 0.2 * _env(t, d, 0.002))
	_streams["ui_confirm"] = _render(0.1, func(t: float, d: float) -> float:
		return _triangle(lerpf(600.0, 950.0, t / d) * t) * 0.3 * _env(t, d, 0.003))


## Genera un AudioStreamWAV mono a 16 bit campionando generator(t, durata).
func _render(duration: float, generator: Callable) -> AudioStreamWAV:
	return _render_filtered(duration, Vector2.ONE, generator)


## Come _render, con un filtro passa-basso che varia nel tempo da
## lowpass.x a lowpass.y (valori tra 0 e 1: più alti = suono più brillante).
func _render_filtered(duration: float, lowpass: Vector2, generator: Callable) -> AudioStreamWAV:
	var count := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var filtered := 0.0
	for i in count:
		var t := float(i) / MIX_RATE
		var sample: float = generator.call(t, duration)
		filtered += lerpf(lowpass.x, lowpass.y, t / duration) * (sample - filtered)
		data.encode_s16(i * 2, int(clampf(filtered, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


## Inviluppo: attacco rapido e poi decadimento fino a zero alla fine.
func _env(t: float, duration: float, attack: float) -> float:
	if attack > 0.0 and t < attack:
		return t / attack
	return clampf(1.0 - (t - attack) / maxf(duration - attack, 0.001), 0.0, 1.0)


func _noise() -> float:
	return randf_range(-1.0, 1.0)


## Onda triangolare; phase è in cicli (frequenza * tempo).
func _triangle(phase: float) -> float:
	return 4.0 * absf(fmod(phase, 1.0) - 0.5) - 1.0
