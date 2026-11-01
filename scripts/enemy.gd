class_name Enemy
extends Node2D
## Nemico di test, disegnato con forme geometriche. Le caratteristiche
## dipendono dal tipo, definito in data/enemies.json (vedi EnemyTypes).
##
## Vaga finché il giocatore non si avvicina, poi gli gira attorno con
## spostamenti laterali e scatti rapidi, finché non decide di attaccare.
## L'attacco è lento e annunciato: durante la carica a terra compare la
## zona colpita, poi il nemico scatta in avanti. Per essere meno
## prevedibile la carica ha durata variabile, a volte è una finta e a
## volte segue subito un secondo attacco più rapido.
## Quando il giocatore attacca lì vicino, a volte (secondo il tipo) alza la
## guardia: i colpi di spada che arrivano da davanti vengono parati, la
## combo del giocatore si interrompe e lui viene respinto; poi spesso
## contrattacca. Attacchi a terra e palle di fuoco passano la guardia. Se
## invece è il giocatore a parare il suo colpo, il colpo si interrompe e il
## nemico viene respinto. Attacca più volte di fila (fino a "max_strikes").
## Gli evocatori restano a distanza ed evocano altri nemici: colpirli
## mentre evocano interrompe l'evocazione. I tipi con "ranged" (lanciatori
## e arcieri) restano a distanza e scagliano dardi magici o frecce (vedi
## EnemyBolt). Quando il giocatore fluttua a mezz'aria caricando lo slam
## aereo (vedi Player.is_air_charging) ne approfittano: tirano subito, con
## una carica più breve, e i loro colpi lo raggiungono anche lassù.
## I tipi con "magic" (il boss) ogni tanto si fermano a caricare una magia e
## scagliano da lontano un ventaglio di dardi grandi.
##
## Vita a punti, come quella del giocatore: ogni tipo ha pochi punti vita
## ("points" in data/enemies.json, che crescono un poco col livello di
## minaccia) mostrati a segmenti sopra la testa. Un colpo toglie 1 punto,
## 2 o 3 i colpi molto forti: il danno del colpo, meno l'armatura, diviso
## per POINT_DAMAGE volte il primo colpo del giocatore al livello 1,
## cresciuto col livello di minaccia del nemico ("hit_damage", più piano
## dei danni del giocatore; vedi points_for), così combo, colpi potenti,
## parata perfetta, oggetti e livelli contano ancora. Colpito resta invulnerabile per
## HURT_INVULNERABLE_TIME secondi e lampeggia, come il giocatore.
##
## I ghoul delle catacombe (tipi con "mutant") combattono come gli altri
## ma senza armi: tanti occhi rossi in disordine, bocca spalancata,
## escrescenze sul corpo e artigli al posto delle mani; quelli che sputano
## ("spit") lanciano bile velenosa dalla bocca invece di tirare frecce.
##
## I non morti delle orde (tipi con "horde", vedi Game) non girano attorno e
## non attaccano: corrono dritti verso il giocatore e, quando lo toccano, si
## disfano facendogli un danno (vedi _rush e _burst). Muoiono con un colpo.
##
## Si muovono sul terreno a gradini come il giocatore: scendono dai gradini
## cadendo e, quando un gradino alto un livello li blocca, ci saltano sopra;
## nei burroni non entrano mai. Il boss resta sempre dentro la sua arena
## (vedi confine).

## Tutti i nemici sono fermi (attacco speciale della Frenesia, vedi
## Player._start_special): niente decisioni, movimenti, attacchi né
## proiettili (vedi EnemyBolt), ma si possono colpire e chi muore cade.
static var frozen := false

signal died(enemy: Enemy)
## Chiede alla scena di gioco di creare i nemici evocati.
signal summon_requested(summoner: Enemy, type_id: String, positions: Array[Vector2])

enum State { WANDER, CHASE, DASH, WINDUP, STRIKE, RECOVER, STUNNED, SUMMON, DEAD, GUARD, SLAM }

const ACCELERATION := 750.0
## Lo sguardo ruota con continuità invece che a scatti.
const TURN_RATE := 9.0
const LEASH_RANGE := 700.0
const SEPARATION_RANGE := 60.0
const KNOCKBACK := 320.0
const HEAVY_KNOCKBACK_FACTOR := 1.6
## Vita a punti (vedi in cima): danno che vale un punto, rispetto al primo
## colpo del giocatore al livello 1, e punti al più per colpo.
const POINT_DAMAGE := 1.25
const MAX_POINTS_PER_HIT := 3
## Dopo un colpo si resta invulnerabili per questo tempo, lampeggiando
## (molto meno del giocatore: le combo devono restare veloci).
const HURT_INVULNERABLE_TIME := 0.12
const HURT_BLINK_RATE := 30.0

## Ogni tanto cambia verso di rotazione o fa uno scatto laterale.
const DECISION_INTERVAL := Vector2(0.5, 1.6)
const DASH_CHANCE := 0.4
## Se il giocatore beve una pozione o si allontana entro questa distanza, il
## nemico gli corre addosso più veloce e attacca subito.
const PUNISH_RANGE := 460.0
const PUNISH_SPEED_FACTOR := 1.4
## Velocità con cui il giocatore si allontana perché conti come ritirata.
const RETREAT_SPEED := 120.0
const DASH_SPEED_FACTOR := 3.0
const DASH_TIME := 0.18

## Distanza dal bordo del giocatore a cui il nemico inizia a caricare l'attacco.
const ATTACK_TRIGGER_GAP := 64.0
## Per una parte della carica (variabile) il nemico segue il giocatore,
## poi la direzione resta bloccata: è il momento di schivare.
const WINDUP_TRACKING := Vector2(0.4, 0.75)
## Probabilità che la carica sia una finta, interrotta a metà con uno scatto.
## Niente finte: ogni attacco ha una carica chiara e arriva sempre.
const FEINT_CHANCE := 0.0
## Probabilità di un altro attacco subito dopo il precedente, con carica più
## breve, fino a "max_strikes" di fila (data/enemies.json).
const COMBO_CHANCE := 0.5
const COMBO_WINDUP_FACTOR := 0.6
const STRIKE_TIME := 0.3
const RECOVER_TIME := 0.9
## Dopo un attacco aspetta un tempo a caso prima di riprovare.
const ATTACK_COOLDOWN := Vector2(0.35, 1.2)
## Guardia: si alza (con probabilità "guard_chance") quando il giocatore
## inizia un attacco entro GUARD_RANGE girato verso il nemico, con la spada
## di traverso davanti al corpo; para i colpi che arrivano entro GUARD_ARC
## davanti. Dopo, per un po', non si rialza.
const GUARD_RANGE := 230.0
const GUARD_ARC := deg_to_rad(150.0)
const GUARD_COOLDOWN := Vector2(1.5, 3.0)
## Dopo una parata contrattacca con questa probabilità.
const COUNTER_CHANCE := 0.6
## Respinto dalla parata del giocatore: spinta e tempo di recupero.
const REPELLED_KNOCKBACK := 380.0
const COLOR_GUARD := Color(0.75, 0.88, 1.0)
const STUN_TIME := 1.6
## Giocatore esposto a mezz'aria (vedi _exposed_shot): i tiratori caricano
## il tiro in questa parte del tempo solito, anche da un po' più lontano e
## durante il recupero dopo un attacco (passata questa parte).
const EXPOSED_WINDUP_FACTOR := 0.5
const EXPOSED_RANGE_FACTOR := 1.25
const EXPOSED_RECOVER_SHARE := 0.3
## Attacco speciale (voce "slam" del tipo in data/enemies.json): si
## accuccia, salta sul punto dove sta il giocatore e colpisce il terreno
## tutto attorno. La zona d'impatto è segnata a terra durante la carica.
## Se il tiro non riesce si riprova dopo un po'; dopo l'impatto il nemico
## resta scoperto più a lungo.
const SLAM_RETRY := Vector2(1.2, 2.5)
const SLAM_RECOVER_EXTRA := 0.6
## Parte della carica in cui la zona d'impatto segue ancora il giocatore.
const SLAM_TRACKING := 0.7
## Alla morte il corpo cade a terra in questo tempo, poi resta steso (lo
## disegna GroundFx) e il nodo sparisce.
const DEATH_FALL_TIME := 0.35
## Sangue perso a ogni colpo (gocce), di più con i colpi potenti.
const BLEED_DROPS := 16
const BLEED_DROPS_HEAVY := 32
## Sangue sul corpo (vedi BodyBlood): ogni colpo ricevuto lo sporca di
## BLOOD_PER_HIT (BLOOD_PER_HEAVY i colpi potenti), che si pulisce in fretta
## (BLOOD_CLEAN al secondo: da sporco del tutto a pulito in 8 secondi).
const BLOOD_PER_HIT := 0.3
const BLOOD_PER_HEAVY := 0.5
const BLOOD_CLEAN := 0.125
const BLOOD_SPOTS := 7
## Pozza di sangue che resta a terra alla morte, rispetto al raggio.
const DEATH_POOL := 2.4
## Tono della voce (vedi Voice): più grosso il nemico, più profonda la voce;
## ognuno ha la sua, un po' diversa (VOICE_SPREAD).
const VOICE_SPREAD := Vector2(0.9, 1.12)
const BOSS_VOICE := 0.85
## I nemici evocati compaiono a questa distanza dall'evocatore.
const SUMMON_DISTANCE := 70.0
## Fuoco amico (vedi hurt_enemy): i colpi dei nemici feriscono anche gli
## altri nemici nella zona d'impatto, ma non oltre questa differenza d'altezza.
const FRIENDLY_HEIGHT_REACH := 40.0
## Salti sui gradini e cadute: gravità, quanti livelli si superano con un
## salto, quanto più in alto del gradino si arriva e attesa tra due salti.
const GRAVITY := 1500.0
const HOP_LEVELS := 1
const HOP_CLEARANCE := 10.0
const HOP_COOLDOWN := 0.6
## Il salto parte se in un passo si è percorsa meno di questa parte del movimento voluto.
const HOP_BLOCKED_SHARE := 0.5

## Gambe: altezza rispetto al raggio del corpo e passo; corte e larghe,
## distanti LEG_SPACING (rispetto al raggio) dal centro e spesse LEG_WIDTH (rispetto al raggio, almeno 4,5 pixel).
const LEG_FACTOR := 0.275
const LEG_SPACING := 0.38
const LEG_WIDTH := 0.25
const WALK_CYCLE := 0.08

## Prestazioni con tanti nemici: la spinta di separazione guarda solo i
## nemici nelle celle vicine di una griglia rifatta a ogni passo di fisica
## (le celle sono più larghe della distanza di separazione più grande), e
## chi è fuori dallo schermo non si ridisegna (VIEW_MARGIN attorno).
const GRID_CELL := 128.0
const VIEW_MARGIN := Vector2(160, 220)
## Oltre questa distanza dal giocatore (fuori dallo schermo, oltre il
## raggio d'inseguimento) ci si aggiorna a passi alterni, oltre
## VERY_FAR_RANGE un passo ogni quattro (con il tempo di tutti).
const FAR_RANGE := 1000.0
const VERY_FAR_RANGE := 1500.0
## Non morti delle orde (anche 200 insieme): a passi alterni oltre
## HORDE_NEAR_RANGE, uno ogni quattro oltre HORDE_FAR_RANGE; la spinta di
## separazione guarda al più SEPARATION_MAX vicini.
const HORDE_NEAR_RANGE := 450.0
const HORDE_FAR_RANGE := 900.0
const SEPARATION_MAX := 10

## Scia rossa: mentre carica l'attacco il nemico si accende di un bagliore
## rosso; quando scatta per colpire (e nel salto con colpo a terra) lascia
## dietro di sé copie rosse del corpo che svaniscono in TRAIL_FADE secondi,
## una ogni TRAIL_INTERVAL.
const TRAIL_INTERVAL := 0.025
const TRAIL_FADE := 0.22
const TRAIL_ALPHA := 0.5
const WINDUP_GLOW_ALPHA := 0.45

const COLOR_WINDUP := Color(1.0, 0.45, 0.2)
const COLOR_STUNNED := Color(0.55, 0.55, 0.8)
const COLOR_DANGER := Color(1.0, 0.25, 0.15)
const COLOR_SUMMON := Color(0.4, 1.0, 0.9)
const COLOR_DAMAGE := Color(1.0, 1.0, 1.0)
## Contorno del nemico dietro a un muro (vedi Silhouette).
const COLOR_SILHOUETTE := Color(1.0, 0.3, 0.25, 0.75)
const SILHOUETTE_INTERVAL := 3
## Tinta del nemico agganciato dal giocatore (vedi set_locked): i valori
## sopra 1 lo illuminano di rosso invece di scurirlo.
const COLOR_LOCKED := Color(1.7, 0.5, 0.45)
## Aspetto casuale (vedi _apply_look): taglia (moltiplica il raggio del
## tipo), sfumatura del colore del tipo e copricapo con il suo colore.
const SIZE_RANGE := Vector2(0.8, 1.25)
const HEADWEARS := ["", "", "helmet", "hood", "horns", "headband"]
const GEAR_COLORS := [Color(0.55, 0.57, 0.62), Color(0.45, 0.3, 0.18), Color(0.25, 0.22, 0.35), Color(0.6, 0.15, 0.12), Color(0.85, 0.82, 0.7), Color(0.2, 0.35, 0.2)]
## Non morti delle orde: carne grigioverde o livida, occhi rossi, velocità
## variabile di questa parte; si disfano toccando il giocatore entro
## CONTACT_MARGIN oltre i due raggi.
const ZOMBIE_TONES := [Color(0.55, 0.62, 0.48), Color(0.48, 0.54, 0.44), Color(0.6, 0.6, 0.55), Color(0.45, 0.5, 0.5)]
const COLOR_ZOMBIE_EYES := Color(1.0, 0.2, 0.1)
const COLOR_RAGS := Color(0.32, 0.27, 0.22)
## Ghoul: escrescenze, artigli e bile.
const COLOR_GROWTH := Color(0.78, 0.55, 0.5)
const COLOR_CLAWS := Color(0.88, 0.85, 0.75)
const COLOR_ACID := Color(0.55, 1.0, 0.25)
const ZOMBIE_SPEED_SPREAD := 0.15
const CONTACT_MARGIN := 6.0
const BURST_SPLATS := 5

var player: Player
var type_id := "warrior"
var radius := 24.0
## Altezza del terreno sotto il nemico: viene disegnato più in alto.
var ground_elevation := 0.0
## Punti vita (vedi in cima).
var health := 4
var max_health := 4
## Esperienza data al giocatore quando viene sconfitto.
var xp_reward := 30
## Danno di un colpo: quello del tipo, cresciuto con il livello di minaccia.
var damage := 1
## Livello di minaccia con cui è stato creato (vedi EnemyTypes.scaled).
var threat_level := 1
## Parte del danno ricevuto assorbita dall'armatura (0 = nessuna).
var armor := 0.0
## Alla morte può lasciare bottino (no per i nemici evocati).
var drops_loot := true
## Evocato da un altro nemico (per i salvataggi).
var is_minion := false

var _type: Dictionary
var _color := Color.WHITE
## Seme dell'aspetto (vedi _apply_look), copricapo scelto e il suo colore.
var _look_seed := 0
## Varianti del goblin (orecchie, occhi, bocca, cicatrici: vedi GoblinLook.variant).
var _goblin := {}
var _headwear := ""
var _headwear_color := Color.WHITE
var _speed := 125.0
var _state := State.WANDER
var _state_time := 0.0
var _velocity := Vector2.ZERO
var _facing := Vector2.RIGHT
var _wander_direction := Vector2.ZERO
var _wander_time := 0.0
var _decision_time := 0.0
var _orbit_sign := 1.0
var _dash_direction := Vector2.ZERO
var _attack_direction := Vector2.RIGHT
var _attack_cooldown := 0.0
var _windup_time := 1.0
var _windup_tracking := 0.6
var _feint_at := -1.0
## Colpi già fatti nella serie in corso.
var _strikes := 0
## Guardia: tempo che dura, attesa prima di poterla rialzare, ultimo attacco
## del giocatore già considerato e lampo della parata.
var _guard_time := 0.0
var _guard_cooldown := 0.0
var _seen_attack := -1
var _guard_flash := 0.0
var _strike_resolved := false
## Nemici già feriti dal fuoco amico in questo colpo (uno per colpo).
var _friendly_struck: Array[Enemy] = []
## Salto con colpo a terra: punto di partenza e d'arrivo, attesa prima di
## riprovarlo e altezza attuale del salto.
var _slam_from := Vector2.ZERO
var _slam_target := Vector2.ZERO
var _slam_cooldown := 0.0
var _slam_landed := false
var _air := 0.0
var _knockback := Vector2.ZERO
var _hit_flash := 0.0
## Invulnerabilità rimasta dopo un colpo (vedi take_points).
var _invulnerable := 0.0
## Altezza sopra il terreno (salendo su un gradino con un salto o cadendo
## da uno), velocità verticale e attesa prima del prossimo salto.
var _height := 0.0
var _height_velocity := 0.0
var _hop_cooldown := 0.0
## Zona da cui non si esce (il boss nella sua arena): centro e raggio in
## rombi; Vector2.INF se non c'è.
var _home := Vector2.INF
var _home_cells := 0.0
## Magia del boss: sta caricando o scagliando una magia (invece di un
## fendente) e attesa prima della prossima.
var _casting := false
var _magic_cooldown := 0.0
## Lato verso cui cade il corpo (+1 destra, -1 sinistra).
var _fall_side := 1.0
var _summon_cooldown := 0.0
var _summon_positions: Array[Vector2] = []
var _minions: Array[Enemy] = []
## Verso del fendente (+1 o -1): cambia a ogni attacco.
var _swing_sign := 1.0
var _walk_phase := 0.0
## Sangue sul corpo, ferite dei colpi ricevuti e voce.
var _blood := BodyBlood.new(randi(), BLOOD_SPOTS, BLOOD_CLEAN)
var _wounds := Wounds.new()
var _voice := Voice.new()
## La zona di pericolo va disegnata sotto i personaggi, non sopra.
var _telegraph := Node2D.new()
## Effetti rossi dell'attacco su nodi propri: dietro al corpo il bagliore
## della carica e le copie della scia, davanti l'arco del fendente. Non
## prendono luce (come _telegraph), così il buio della notte e del
## sotterraneo non li spegne, e si ridisegnano anche se il centro del
## nemico è appena fuori dallo schermo.
var _danger_back := Node2D.new()
var _danger_front := Node2D.new()
## Gli effetti rossi sono disegnati: vanno ancora ridisegnati (per toglierli).
var _danger_shown := false
## Il segnale dell'evocazione è disegnato: va ancora ridisegnato (per toglierlo).
var _telegraph_shown := false
## Scia rossa: posizioni (x, y) con l'altezza del salto (z) e da quanto
## tempo ci si è passati (w); tempo dall'ultima copia lasciata.
var _trail: Array[Vector4] = []
var _trail_time := 0.0
## Mesh del corpo e del suo contorno (vedi Shapes), preparate una volta per raggio.
var _body_mesh: ArrayMesh
var _outline_mesh: ArrayMesh
## Contorno a inchiostro sotto il corpo (stile fumetto, vedi Shapes.ink_mesh).
var _ink_mesh: ArrayMesh
var _shape_radius := -1.0

## Sagoma che si vede quando il nemico è dietro a un muro (vedi Silhouette):
## si controlla un passo di fisica ogni SILHOUETTE_INTERVAL.
var _silhouette := Silhouette.new(COLOR_SILHOUETTE, false)

## Aggiornamento a passi alterni da lontano: in quali passi (da 0 a 3) e tempo saltato.
var _update_slot := randi() % 4
var _skipped_time := 0.0

## Griglia dei nemici vivi (cella -> nemici) e passo di fisica in cui è stata fatta.
static var _grid := {}
static var _grid_frame := -1
## Parte del mondo visibile (con margine) e frame in cui è stata calcolata.
static var _view := Rect2()
static var _view_frame := -1
static var _unshaded: CanvasItemMaterial


## Imposta il tipo prima di aggiungere il nemico alla scena; vita, danno,
## esperienza e armatura crescono con il livello di minaccia.
func setup(id: String, level := 1) -> void:
	type_id = id
	_type = EnemyTypes.get_type(id)
	threat_level = maxi(level, 1)
	radius = _type["radius"]
	max_health = maxi(roundi(EnemyTypes.scaled("points", _type["points"], threat_level)), 1)
	health = max_health
	xp_reward = roundi(EnemyTypes.scaled("xp", _type["xp"], threat_level))
	damage = floori(EnemyTypes.scaled("damage", _type["damage"], threat_level))
	armor = EnemyTypes.armor(float(_type.get("armor", 0.0)), threat_level)
	_speed = _type["speed"]
	var color: Array = _type["color"]
	_color = Color(color[0], color[1], color[2])
	if is_horde():
		_speed *= randf_range(1.0 - ZOMBIE_SPEED_SPREAD, 1.0 + ZOMBIE_SPEED_SPREAD)
	if _type.has("summon"):
		_summon_cooldown = randf_range(1.0, 2.5)
	if _type.has("magic"):
		_magic_cooldown = randf_range(1.5, 3.0)
	_apply_look(randi())


## Stato da salvare: tipo, posizione esatta, vita e valori cambiati dalla
## scena di gioco (boss più forte, nemici evocati).
func save_state() -> Dictionary:
	return {
		"type": type_id, "position": SaveGame.array(position), "health": health, "max_health": max_health, "points": true,
		"xp": xp_reward, "damage": damage, "loot": drops_loot, "minion": is_minion,
		"level": threat_level, "armor": armor,
		"facing": SaveGame.array(_facing), "look": _look_seed,
	}


## Riprende lo stato salvato (dopo setup e prima di aggiungere il nemico
## alla scena); i campi mancanti restano quelli del tipo.
func load_state(data: Dictionary) -> void:
	position = SaveGame.vector(data["position"])
	if data.get("points", false):
		max_health = maxi(int(data.get("max_health", max_health)), 1)
		health = clampi(int(data.get("health", max_health)), 1, max_health)
	else:
		# Salvataggio di prima della vita a punti: si tiene la stessa parte di vita.
		var share := float(data.get("health", 1)) / maxf(float(data.get("max_health", 1)), 1.0)
		health = clampi(ceili(share * max_health), 1, max_health)
	xp_reward = int(data.get("xp", xp_reward))
	damage = int(data.get("damage", damage))
	threat_level = int(data.get("level", threat_level))
	armor = float(data.get("armor", armor))
	drops_loot = bool(data.get("loot", drops_loot))
	is_minion = bool(data.get("minion", false))
	if data.has("facing"):
		var facing := SaveGame.vector(data["facing"])
		if facing != Vector2.ZERO:
			_facing = facing.normalized()
	# Salvataggi precedenti all'aspetto casuale: resta quello scelto in setup.
	if data.has("look"):
		_apply_look(int(data["look"]))


## Aspetto casuale ma ripetibile dal seme (salvato con il nemico): taglia,
## sfumatura del colore e copricapo (elmo, cappuccio, corna o fascia).
## Il boss tiene taglia e colore del tipo e solo la corona.
func _apply_look(look_seed: int) -> void:
	_look_seed = look_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed
	var size := 1.0 if is_boss() else rng.randf_range(SIZE_RANGE.x, SIZE_RANGE.y)
	# Raggi a passi di mezzo pixel: le mesh del corpo (una per raggio, vedi
	# Shapes) restano poche anche con le orde di centinaia di non morti.
	radius = snappedf(float(_type["radius"]) * size, 0.5)
	var color: Array = _type["color"]
	var base := Color(color[0], color[1], color[2])
	if is_horde():
		base = ZOMBIE_TONES[rng.randi() % ZOMBIE_TONES.size()]
	_color = base if is_boss() else Color.from_hsv(wrapf(base.h + rng.randf_range(-0.03, 0.03), 0.0, 1.0),
			clampf(base.s * rng.randf_range(0.85, 1.15), 0.0, 1.0), clampf(base.v * rng.randf_range(0.88, 1.1), 0.0, 1.0))
	_headwear = "" if is_boss() or is_horde() or is_mutant() else HEADWEARS[rng.randi() % HEADWEARS.size()]
	_headwear_color = GEAR_COLORS[rng.randi() % GEAR_COLORS.size()]
	_goblin = GoblinLook.variant(look_seed)
	_shape_radius = -1.0


## Il nemico non esce mai dal cerchio di rombi (raggio in rombi) attorno a
## center: per il boss, la sua arena.
func confine(center: Vector2, cells: float) -> void:
	_home = center
	_home_cells = maxf(cells, 0.5)
	if is_inside_tree():
		position = World.clamp_to_grid_circle(position, _home, _home_cells)


## Sta caricando o scagliando una magia (vedi BossBar).
func is_casting() -> bool:
	return _casting and _state in [State.WINDUP, State.STRIKE]


## Il giocatore si cura o si ritira a portata: è il momento di attaccare.
func _punishing(to_player: Vector2, distance: float) -> bool:
	if distance > PUNISH_RANGE or _type.has("summon") or _is_ranged():
		return false
	return player.is_healing() or player.ground_velocity().dot(to_player.normalized()) > RETREAT_SPEED


func _ready() -> void:
	if _type.is_empty():
		setup(type_id)
	# La torcia lo illumina come il punto del terreno su cui sta, in pianta.
	material = LightShaders.feet()
	add_to_group("enemies")
	if _facing == Vector2.RIGHT:
		_facing = Vector2.from_angle(randf() * TAU)
	_orbit_sign = [-1.0, 1.0].pick_random()
	_telegraph.z_index = -5
	_telegraph.draw.connect(_draw_telegraph)
	add_child(_telegraph)
	_danger_back.show_behind_parent = true
	_danger_back.draw.connect(_draw_danger_back)
	add_child(_danger_back)
	_danger_front.draw.connect(_draw_danger_front)
	add_child(_danger_front)
	for fx: CanvasItem in [_telegraph, _danger_back, _danger_front]:
		fx.material = _unshaded_material()
	add_child(_silhouette)
	_voice.tone = (BOSS_VOICE if is_boss() else randf_range(VOICE_SPREAD.x, VOICE_SPREAD.y)) / pow(float(_type["mass"]), 0.25)
	add_child(_voice)
	if World.current:
		ground_elevation = World.current.elevation_at(position)
		_telegraph.position.y = -ground_elevation


func _physics_process(delta: float) -> void:
	if frozen and _state != State.DEAD:
		# Fermi come statue: i colpi li fanno sanguinare ma non li spostano.
		_knockback = Vector2.ZERO
		_hit_flash = maxf(_hit_flash - delta, 0.0)
		_blood.update(delta)
		_wounds.update(delta)
		if _on_screen():
			queue_redraw()
		return
	# Lontano dal giocatore ci si aggiorna un passo sì e uno no (molto lontano
	# uno su quattro), con il tempo di quelli saltati: non si vede e costa meno.
	if player and _state != State.DEAD:
		var far := global_position.distance_squared_to(player.global_position)
		var interval := 4 if far > VERY_FAR_RANGE * VERY_FAR_RANGE else (2 if far > FAR_RANGE * FAR_RANGE else 1)
		if is_horde():
			# I non morti corrono dritti: anche più vicini basta aggiornarli meno spesso.
			interval = 4 if far > HORDE_FAR_RANGE * HORDE_FAR_RANGE else (2 if far > HORDE_NEAR_RANGE * HORDE_NEAR_RANGE else 1)
		if (Engine.get_physics_frames() + _update_slot) % interval != 0:
			_skipped_time += delta
			return
	delta += _skipped_time
	_skipped_time = 0.0
	_state_time += delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_summon_cooldown = maxf(_summon_cooldown - delta, 0.0)
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	_update_invulnerability(delta)
	_guard_cooldown = maxf(_guard_cooldown - delta, 0.0)
	_guard_flash = maxf(_guard_flash - delta, 0.0)
	_slam_cooldown = maxf(_slam_cooldown - delta, 0.0)
	_magic_cooldown = maxf(_magic_cooldown - delta, 0.0)
	_hop_cooldown = maxf(_hop_cooldown - delta, 0.0)
	_blood.update(delta)
	_wounds.update(delta)

	var target_velocity := Vector2.ZERO
	var to_player := player.global_position - global_position if player else Vector2.INF
	var distance := to_player.length()
	var player_active := player != null and not player.is_dead()

	match _state:
		State.WANDER:
			_wander_time -= delta
			if _wander_time <= 0.0:
				_wander_time = randf_range(1.5, 3.5)
				# A volte resta fermo, a volte cammina in una direzione a caso.
				_wander_direction = Vector2.ZERO if randf() < 0.3 else Vector2.from_angle(randf() * TAU)
			target_velocity = _wander_direction * _speed * 0.4
			if player_active and distance <= _type["aggro_range"]:
				_change_state(State.CHASE)

		State.CHASE:
			if is_horde():
				target_velocity = _rush(to_player, distance, player_active)
			elif not player_active or distance > LEASH_RANGE:
				_change_state(State.WANDER)
			elif _punishing(to_player, distance):
				_attack_cooldown = 0.0
				if distance > _attack_trigger_range():
					target_velocity = to_player.normalized() * _speed * PUNISH_SPEED_FACTOR
				elif _attack_slot_free():
					_strikes = 0
					_begin_windup(_type["windup"][0], _type["windup"][1], true)
				else:
					# Troppi attacchi in corso: si aspetta girando attorno.
					target_velocity = _chase_direction(to_player) * _speed
			elif _exposed_shot(distance) and _attack_slot_free():
				_begin_exposed_shot()
			elif _should_guard(distance):
				_begin_guard()
			elif _can_slam(distance) and _attack_slot_free():
				_begin_slam()
			elif _can_cast(distance) and _attack_slot_free():
				_begin_cast()
			elif _can_summon(distance):
				_begin_summon()
			elif _attack_cooldown == 0.0 and distance <= _attack_trigger_range() and _can_shoot_player() and _attack_slot_free():
				_strikes = 0
				_begin_windup(_type["windup"][0], _type["windup"][1], true)
			else:
				_decision_time -= delta
				if _decision_time <= 0.0:
					_decision_time = randf_range(DECISION_INTERVAL.x, DECISION_INTERVAL.y)
					if randf() < 0.5:
						_orbit_sign = -_orbit_sign
					if distance < _orbit_distance() * 1.8 and randf() < DASH_CHANCE:
						_start_dash(to_player)
				if _state == State.CHASE:
					target_velocity = _chase_direction(to_player) * _speed

		State.DASH:
			_velocity = _dash_direction * _speed * DASH_SPEED_FACTOR
			target_velocity = _velocity
			# Anche durante uno scatto si può alzare la guardia.
			if player_active and _should_guard(distance):
				_begin_guard()
			elif _state_time >= DASH_TIME:
				_change_state(State.CHASE)

		State.WINDUP:
			if player_active and _state_time <= _windup_time * _windup_tracking:
				_attack_direction = to_player.normalized()
			if _feint_at >= 0.0 and _state_time >= _feint_at:
				_attack_cooldown = randf_range(0.3, 0.8)
				_start_dash(to_player)
			elif _state_time >= _windup_time:
				_strike_resolved = false
				_friendly_struck.clear()
				Sfx.play("enemy_strike", global_position, 1.0 / sqrt(_type["mass"]))
				_change_state(State.STRIKE)

		State.STRIKE:
			# Dardi e magie partono da fermi; i fendenti con uno scatto in avanti.
			var shooting := _is_ranged() or _casting
			_velocity = Vector2.ZERO if shooting else _attack_direction * float(_type["lunge_speed"])
			target_velocity = _velocity
			if not shooting:
				_strike_enemies()
			if not shooting and not _strike_resolved and player_active and _player_in_strike_zone():
				_strike_resolved = true
				var result := player.receive_hit(global_position, EnemyTypes.player_damage(is_boss()))
				if result == "parried":
					Sfx.play("stun", global_position)
					_change_state(State.STUNNED)
				elif result == "blocked":
					# Parato dal giocatore: il colpo si interrompe e si viene respinti.
					_knockback = -_attack_direction * REPELLED_KNOCKBACK / float(_type["mass"])
					_velocity = Vector2.ZERO
					_change_state(State.RECOVER)
			if _state == State.STRIKE and shooting:
				_velocity = Vector2.ZERO
				if not _strike_resolved:
					_strike_resolved = true
					# Se intanto il giocatore è finito dietro un ostacolo, niente dardo.
					if _casting:
						if _clear_shot():
							_cast_magic()
					elif _can_shoot_player():
						_shoot_bolt(_attack_direction, _type["ranged"])
			if _state == State.STRIKE and _state_time >= STRIKE_TIME:
				_velocity = _velocity * 0.2
				if _casting:
					_finish_cast()
				elif _strikes < int(_type["max_strikes"]) and player_active and randf() < COMBO_CHANCE:
					_begin_windup(_type["windup"][0] * COMBO_WINDUP_FACTOR, _type["windup"][1] * COMBO_WINDUP_FACTOR, false)
				else:
					_change_state(State.RECOVER)

		State.SLAM:
			_update_slam(player_active)

		State.RECOVER:
			if _state_time >= RECOVER_TIME * EXPOSED_RECOVER_SHARE and _exposed_shot(distance) and _attack_slot_free():
				_begin_exposed_shot()
			elif _state_time >= RECOVER_TIME:
				_attack_cooldown = randf_range(ATTACK_COOLDOWN.x, ATTACK_COOLDOWN.y)
				_change_state(State.CHASE)

		State.GUARD:
			# Fermo (o quasi) e girato verso il giocatore finché dura la guardia.
			if not player_active or _state_time >= _guard_time:
				_guard_cooldown = randf_range(GUARD_COOLDOWN.x, GUARD_COOLDOWN.y)
				_change_state(State.CHASE)

		State.STUNNED:
			if _state_time >= STUN_TIME:
				_attack_cooldown = randf_range(ATTACK_COOLDOWN.x, ATTACK_COOLDOWN.y)
				_change_state(State.CHASE)

		State.SUMMON:
			if _state_time >= _type["summon"]["channel_time"]:
				var positions: Array[Vector2] = []
				for offset in _summon_positions:
					positions.append(global_position + offset)
				Sfx.play("summon_pop", global_position)
				summon_requested.emit(self, _type["summon"]["type"], positions)
				_finish_summon()

		State.DEAD:
			# Il colpo che lo abbatte lo spinge ancora un po' mentre cade.
			_knockback = _knockback.move_toward(Vector2.ZERO, 1200.0 * delta)
			if World.current:
				position = _confined(World.current.move(position, _knockback * delta, radius * 0.8, 0.0, true, false))
				ground_elevation = World.current.elevation_at(position)
			queue_redraw()
			if _state_time >= DEATH_FALL_TIME:
				_silhouette.visible = false
				GroundFx.corpse(global_position, ground_elevation, _corpse_points(1.0), _corpse_color())
				queue_free()
			_redraw_danger()
			return

	if _state in [State.WANDER, State.CHASE]:
		if target_velocity != Vector2.ZERO:
			target_velocity += _separation() * _speed
		_velocity = _velocity.move_toward(target_velocity, ACCELERATION * delta)
	elif _state in [State.WINDUP, State.RECOVER, State.STUNNED, State.SUMMON, State.GUARD, State.SLAM]:
		_velocity = _velocity.move_toward(Vector2.ZERO, ACCELERATION * delta)

	if _state == State.STRIKE:
		_facing = _attack_direction
	elif _state == State.WINDUP:
		_turn_toward(_attack_direction, delta)
	elif _state == State.SLAM and _slam_target != global_position:
		_turn_toward(_slam_target - global_position, delta * 2.0)
	elif _state == State.GUARD and player_active:
		_turn_toward(to_player, delta * 2.0)
	elif _state in [State.CHASE, State.DASH, State.SUMMON] and player_active:
		_turn_toward(to_player, delta)
	elif _velocity.length() > 5.0:
		_turn_toward(_velocity, delta)

	_knockback = _knockback.move_toward(Vector2.ZERO, 1200.0 * delta)
	# Come il giocatore (vedi Player._move): si scende dai gradini cadendo e si
	# sale su quelli più alti solo saltando (climb = altezza del salto); ci si
	# ferma contro gli ostacoli solidi, i cespugli rallentano e nei
	# burroni non si entra.
	var motion := (_velocity + _knockback) * delta
	var world := World.current
	if world:
		_update_height(delta)
		var grounded := _height <= 0.0 and _height_velocity <= 0.0
		if grounded:
			motion *= world.slow_at(position, radius)
		var altitude := ground_elevation + _height
		var start := position
		position = _confined(world.move(position, motion, radius * 0.8, _height + _air, true, false))
		ground_elevation = world.elevation_at(position)
		# Scendendo da un gradino si resta in aria e si cade; sulle rampe no.
		_height = maxf(altitude - ground_elevation, 0.0)
		if grounded and _height <= World.STEP_TOLERANCE:
			_height = 0.0
		if grounded and _state in [State.WANDER, State.CHASE]:
			_try_hop(world, motion, position - start)
		_telegraph.position.y = -ground_elevation
	else:
		position += motion
	_walk_phase += _velocity.length() * delta * WALK_CYCLE
	_update_trail(delta)
	if _on_screen():
		queue_redraw()
		if (Engine.get_physics_frames() + _update_slot) % SILHOUETTE_INTERVAL == 0:
			_update_silhouette()
	elif _silhouette.visible:
		_silhouette.visible = false
	_redraw_danger()
	if _state in [State.SUMMON, State.SLAM] or _telegraph_shown:
		_telegraph_shown = _state in [State.SUMMON, State.SLAM]
		_telegraph.queue_redraw()


## Dietro a un muro si vede la sagoma del nemico (vedi Silhouette).
func _update_silhouette() -> void:
	var lift := _air + _height
	_silhouette.body_center = _body_offset()
	_silhouette.radius = radius
	_silhouette.facing = _facing
	_silhouette.update(position, ground_elevation + lift)


## Ridisegna gli effetti rossi mentre ci sono, e una volta in più per
## toglierli (anche se nel frattempo il nemico è morto o è uscito dallo schermo).
func _redraw_danger() -> void:
	var danger := _state in [State.WINDUP, State.STRIKE] or not _trail.is_empty()
	if danger or _danger_shown:
		_danger_shown = danger
		_danger_back.queue_redraw()
		_danger_front.queue_redraw()


## Materiale senza luci condiviso dagli effetti di pericolo: il colore della
## notte (CanvasModulate) non li scurisce.
static func _unshaded_material() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded


## Scia rossa dell'attacco: si lascia una copia del corpo a intervalli
## mentre si scatta per colpire (non i dardi e le magie) o si salta per il
## colpo a terra; le copie vecchie svaniscono.
func _update_trail(delta: float) -> void:
	for k in range(_trail.size() - 1, -1, -1):
		_trail[k].w += delta
		if _trail[k].w >= TRAIL_FADE:
			_trail.remove_at(k)
	var lunging := _state == State.STRIKE and not _is_ranged() and not _casting and float(_type["lunge_speed"]) > 0.0
	var leaping := _state == State.SLAM and _air > 0.0
	if not lunging and not leaping:
		_trail_time = TRAIL_INTERVAL
		return
	_trail_time += delta
	if _trail_time >= TRAIL_INTERVAL:
		_trail_time = 0.0
		_trail.append(Vector4(global_position.x, global_position.y, _air + _height, 0.0))


## Spinta improvvisa (per esempio dall'impatto dell'attacco a terra del
## giocatore): velocity è la velocità iniziale, che poi si esaurisce.
func shove(velocity: Vector2) -> void:
	if _state != State.DEAD:
		_knockback = velocity


## Punti vita tolti da un colpo con quel danno (vedi in cima): l'armatura
## ne assorbe una parte, ma almeno un punto passa sempre.
func points_for(amount: int) -> int:
	var unit := EnemyTypes.scaled("hit_damage", POINT_DAMAGE * Player.BASE_DAMAGE, threat_level)
	return clampi(roundi(amount * (1.0 - armor) / unit), 1, MAX_POINTS_PER_HIT)


## Colpo del giocatore con quel danno (vedi points_for); heavy: colpo
## finale della combo, spinge più lontano.
func take_damage(amount: int, direction: Vector2, heavy := false) -> void:
	take_points(points_for(amount), direction, heavy)


## Toglie punti vita. Durante l'invulnerabilità dopo un colpo non succede
## nulla, salvo con force (runa del cataclisma, non morto che si disfa) e durante
## l'attacco speciale della Frenesia (i nemici sono fermi e i colpi vanno a raffica).
func take_points(points: int, direction: Vector2, heavy := false, force := false) -> void:
	if _state == State.DEAD or (_invulnerable > 0.0 and not force and not frozen):
		return
	health -= maxi(points, 1)
	_invulnerable = HURT_INVULNERABLE_TIME
	_hit_flash = 0.12
	_knockback = direction * KNOCKBACK * (HEAVY_KNOCKBACK_FACTOR if heavy else 1.0) / float(_type["mass"])
	GroundFx.bleed(global_position, ground_elevation + radius * 0.8, direction, BLEED_DROPS_HEAVY if heavy else BLEED_DROPS)
	_wounds.add(-direction)
	_blood.add(BLOOD_PER_HEAVY if heavy else BLOOD_PER_HIT)
	if health <= 0:
		_fall_side = 1.0 if direction.x >= 0.0 else -1.0
		_trail.clear()
		_silhouette.visible = false
		GroundFx.pool(global_position, radius * DEATH_POOL)
		_change_state(State.DEAD)
		remove_from_group("enemies")
		Sfx.play("enemy_death", global_position, 1.0 / sqrt(_type["mass"]))
		_voice.scream()
		died.emit(self)
		return
	_voice.pain()
	if _state == State.SUMMON:
		# Colpire un evocatore mentre evoca interrompe l'evocazione.
		_finish_summon()
	elif _state == State.WANDER:
		_change_state(State.CHASE)


## Conto alla rovescia dell'invulnerabilità, lampeggiando come il giocatore.
func _update_invulnerability(delta: float) -> void:
	if _invulnerable <= 0.0 and modulate.a >= 1.0:
		return
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	modulate.a = 0.35 if _invulnerable > 0.0 and int(_invulnerable * HURT_BLINK_RATE) % 2 == 0 else 1.0


## Fa partire subito l'inseguimento del giocatore (per esempio nelle sfide).
func alert() -> void:
	if _state == State.WANDER:
		_change_state(State.CHASE)


func is_dead() -> bool:
	return _state == State.DEAD


## Il boss in fondo al sotterraneo (vedi Game).
func is_boss() -> bool:
	return _type.get("boss", false)


## Copricapo scelto a caso (vedi _apply_look), sempre in cima alla testa.
func _draw_headwear() -> void:
	var top := Vector2(0, -radius)
	match _headwear:
		"helmet":
			var dome := PackedVector2Array()
			for k in 9:
				dome.append(top + Vector2.from_angle(PI + PI * k / 8.0) * Vector2(radius * 0.8, radius * 0.55) + Vector2(0, radius * 0.45))
			draw_colored_polygon(dome, _headwear_color)
			draw_line(top + Vector2(-radius * 0.85, radius * 0.45), top + Vector2(radius * 0.85, radius * 0.45), _headwear_color.darkened(0.35), radius * 0.12)
			draw_line(top + Vector2(0, -radius * 0.12), top + Vector2(0, radius * 0.45), _headwear_color.lightened(0.25), maxf(radius * 0.08, 1.5))
		"hood":
			draw_colored_polygon(PackedVector2Array([top + Vector2(-radius * 0.9, radius * 0.6), top + Vector2(-radius * 0.55, -radius * 0.05),
					top + Vector2(0, -radius * 0.3), top + Vector2(radius * 0.55, -radius * 0.05), top + Vector2(radius * 0.9, radius * 0.6)]), _headwear_color)
		"horns":
			for side: float in [-1.0, 1.0]:
				var base := top + Vector2(side * radius * 0.45, radius * 0.25)
				draw_colored_polygon(PackedVector2Array([base + Vector2(-radius * 0.12, 0), base + Vector2(side * radius * 0.35, -radius * 0.55),
						base + Vector2(radius * 0.12, 0)]), Color(0.92, 0.88, 0.75))
		"headband":
			draw_line(Vector2(-radius * 0.92, -radius * 0.45), Vector2(radius * 0.92, -radius * 0.45), _headwear_color, radius * 0.2)


## Non morto di un'orda (vedi Game): corre dritto verso il giocatore.
func is_horde() -> bool:
	return _type.get("horde", false)


## Ghoul delle catacombe (vedi in cima).
func is_mutant() -> bool:
	return _type.get("mutant", false)


## Non morto: velocità verso il giocatore; toccandolo (non se ci salta sopra)
## si disfa e gli fa un danno. Se lo schiva si riprova.
func _rush(to_player: Vector2, distance: float, player_active: bool) -> Vector2:
	if not player_active:
		_change_state(State.WANDER)
		return Vector2.ZERO
	var above := player.altitude() - ground_elevation
	if distance <= radius + Player.RADIUS + CONTACT_MARGIN and above <= Player.JUMP_EVADE_HEIGHT:
		if player.receive_hit(global_position, EnemyTypes.player_damage(false)) != "dodged":
			_burst(to_player)
			return Vector2.ZERO
	return to_player.normalized() * _speed


## Il non morto si disfa addosso al giocatore: sangue tutto attorno, niente
## esperienza né bottino, e sparisce subito (niente corpo a terra).
func _burst(to_player: Vector2) -> void:
	xp_reward = 0
	drops_loot = false
	for k in BURST_SPLATS:
		GroundFx.bleed(global_position, ground_elevation + radius * 0.8, Vector2.from_angle(randf() * TAU), BLEED_DROPS_HEAVY)
	HitSpark.spawn(get_parent(), global_position + to_player.normalized() * radius, ground_elevation + radius * 0.5, 40.0, COLOR_DANGER)
	Sfx.play("splat", global_position)
	take_points(health, to_player.normalized(), true, true)
	queue_free()


## Corona d'oro sopra la testa del boss.
func _draw_crown() -> void:
	var top := Vector2(0, -radius * 1.05)
	var width := radius * 0.7
	var points := PackedVector2Array([top + Vector2(-width, 0), top + Vector2(width, 0)])
	for k in range(4, -1, -1):
		var x := -width + width * 2.0 * k / 4.0
		points.append(top + Vector2(x, -radius * (0.55 if k % 2 == 0 else 0.3)))
	draw_colored_polygon(points, Color(1.0, 0.8, 0.25))
	draw_polyline(_closed(points), Color(0.55, 0.35, 0.05), 2.0)


## True se il nemico sta combattendo: in quel caso non va rimosso
## anche se il giocatore si allontana.
func is_engaged() -> bool:
	return _state != State.WANDER


func add_minion(minion: Enemy) -> void:
	_minions.append(minion)


func _change_state(new_state: State) -> void:
	_state = new_state
	_state_time = 0.0
	# La magia è fatta solo di carica e lancio: qualsiasi altra cosa la interrompe.
	if new_state not in [State.WINDUP, State.STRIKE]:
		_casting = false


## Altezza sopra il terreno: gravità sul salto o sulla caduta da un gradino.
func _update_height(delta: float) -> void:
	if _height <= 0.0 and _height_velocity <= 0.0:
		return
	_height_velocity -= GRAVITY * delta
	_height += _height_velocity * delta
	if _height <= 0.0:
		_height = 0.0
		_height_velocity = 0.0


## Se il movimento voluto (motion) è stato fermato da un gradino più alto di
## al più HOP_LEVELS livelli (non una montagna o la roccia), si salta su.
func _try_hop(world: World, motion: Vector2, moved: Vector2) -> void:
	if _hop_cooldown > 0.0 or motion.length() < 0.5 or moved.length() >= motion.length() * HOP_BLOCKED_SHARE:
		return
	var probe := position + motion.normalized() * (radius * 0.8 + 16.0)
	if world.is_barrier(World.cell_at(probe)):
		return
	var rise := world.elevation_at(probe) - ground_elevation
	if rise <= World.STEP_TOLERANCE or rise > HOP_LEVELS * world.level_height + World.STEP_TOLERANCE:
		return
	_hop_cooldown = HOP_COOLDOWN
	_height_velocity = sqrt(2.0 * GRAVITY * (rise + HOP_CLEARANCE))
	Sfx.play("jump", global_position, 0.8 / sqrt(_type["mass"]), -10.0)


## Il punto, tenuto dentro la zona da cui non si esce (se c'è).
func _confined(point: Vector2) -> Vector2:
	if _home == Vector2.INF:
		return point
	return World.clamp_to_grid_circle(point, _home, _home_cells)


func _turn_toward(direction: Vector2, delta: float) -> void:
	if direction != Vector2.ZERO:
		_facing = Vector2.from_angle(rotate_toward(_facing.angle(), direction.angle(), TURN_RATE * delta))


func _is_ranged() -> bool:
	return _type.has("ranged")


## Il giocatore fluttua a mezz'aria caricando lo slam aereo, a tiro e senza
## ostacoli in mezzo: i tiratori (e le magie del boss) ne approfittano.
func _exposed_shot(distance: float) -> bool:
	if player == null or not player.is_air_charging() or not (_is_ranged() or _type.has("magic")):
		return false
	var reach := float(_type["ranged"]["range"]) if _is_ranged() else float(_type["magic"]["range"])
	return distance <= reach * EXPOSED_RANGE_FACTOR and _clear_shot()


## Tiro rapido verso il giocatore esposto: un dardo o una freccia con una
## carica più breve, o la magia del boss.
func _begin_exposed_shot() -> void:
	_strikes = 0
	if not _is_ranged():
		_begin_cast()
		_windup_time *= EXPOSED_WINDUP_FACTOR
		return
	var windup: Array = _type["windup"]
	_begin_windup(windup[0] * EXPOSED_WINDUP_FACTOR, windup[1] * EXPOSED_WINDUP_FACTOR, false)


## I lanciatori tirano solo se il dardo può arrivare al giocatore (niente
## pareti, montagne, roccia o ostacoli solidi in mezzo); gli altri sempre.
func _can_shoot_player() -> bool:
	if not _is_ranged():
		return true
	return _clear_shot()


## Un dardo partito da qui arriverebbe al giocatore.
func _clear_shot() -> bool:
	if player == null or World.current == null:
		return true
	return World.current.clear_line(global_position, player.global_position, ground_elevation, EnemyBolt.FLIGHT_HEIGHT)


## Dardo magico nella direzione data; ranged: voce del tipo con velocità,
## portata e, se ci sono, grandezza, colore e danno in più del dardo.
func _shoot_bolt(direction: Vector2, ranged: Dictionary) -> void:
	var bolt := EnemyBolt.new()
	bolt.direction = direction
	bolt.speed = ranged["bolt_speed"]
	bolt.damage = damage + int(ranged.get("damage_bonus", 0))
	bolt.player_damage = EnemyTypes.player_damage(is_boss())
	bolt.max_distance = float(ranged["range"]) * 1.3
	bolt.altitude = ground_elevation
	bolt.radius = float(ranged.get("bolt_radius", EnemyBolt.RADIUS))
	bolt.color = World._color(ranged["color"]) if ranged.has("color") else _color.lightened(0.3)
	bolt.arrow = ranged.get("arrow", false)
	bolt.position = position + direction * radius
	bolt.shooter = self
	bolt.threat_level = threat_level
	get_parent().add_child(bolt)
	if bolt.arrow:
		Sfx.play("bow", global_position)
	elif is_mutant():
		Sfx.play("splat", global_position, 1.3 if _casting else 1.6)


## Magia da lontano (voce "magic" del tipo): il giocatore è tra "min_range" e
## "range", nessun ostacolo in mezzo e il tiro con "chance" riesce; se non
## riesce si riprova dopo "retry" secondi.
func _can_cast(distance: float) -> bool:
	if not _type.has("magic") or _magic_cooldown > 0.0 or _attack_cooldown > 0.0:
		return false
	var magic: Dictionary = _type["magic"]
	if distance < float(magic["min_range"]) or distance > float(magic["range"]) or not _clear_shot():
		return false
	if randf() >= float(magic["chance"]):
		var retry: Array = magic["retry"]
		_magic_cooldown = randf_range(retry[0], retry[1])
		return false
	return true


func _begin_cast() -> void:
	var windup: Array = _type["magic"]["windup"]
	_strikes = 0
	_begin_windup(windup[0], windup[1], false)
	_casting = true
	Sfx.play("summon", global_position, 1.3, -6.0)


## Ventaglio di dardi verso il giocatore.
func _cast_magic() -> void:
	var magic: Dictionary = _type["magic"]
	var count := maxi(int(magic["bolts"]), 1)
	var spread := deg_to_rad(float(magic["spread"]))
	for i in count:
		_shoot_bolt(_attack_direction.rotated((i - (count - 1) / 2.0) * spread), magic)
	if not is_mutant():
		Sfx.play("fireball", global_position, 0.7)


func _finish_cast() -> void:
	var cooldown: Array = _type["magic"]["cooldown"]
	_magic_cooldown = randf_range(cooldown[0], cooldown[1])
	_attack_cooldown = randf_range(ATTACK_COOLDOWN.x, ATTACK_COOLDOWN.y)
	_change_state(State.RECOVER)


func _orbit_distance() -> float:
	return _type["orbit_distance"]


func _attack_trigger_range() -> float:
	if _is_ranged():
		return _type["ranged"]["range"]
	return radius + Player.RADIUS + ATTACK_TRIGGER_GAP


func _strike_reach() -> float:
	return float(_type["lunge_speed"]) * STRIKE_TIME + radius + float(_type["strike_reach"])


func _strike_arc() -> float:
	return deg_to_rad(_type["strike_arc"])


## Direzione di movimento attorno al giocatore: si avvicina a spirale
## quando è pronto ad attaccare, altrimenti gli gira attorno. Gli
## evocatori non si avvicinano mai di loro iniziativa.
func _chase_direction(to_player: Vector2) -> Vector2:
	var radial := to_player.normalized()
	var tangent := radial.orthogonal() * _orbit_sign
	var distance := to_player.length()
	if _attack_cooldown == 0.0 and not _type.has("summon") and not _is_ranged():
		return (radial * 0.85 + tangent * 0.35).normalized()
	if distance > _orbit_distance() + 30.0:
		return (radial * 0.8 + tangent * 0.5).normalized()
	if distance < _orbit_distance() - 30.0:
		return (-radial * 0.6 + tangent * 0.7).normalized()
	return tangent


## Scatto laterale rapido, a volte un po' in avanti o all'indietro.
func _start_dash(to_player: Vector2) -> void:
	var radial := to_player.normalized()
	_dash_direction = (radial.orthogonal() * _orbit_sign + radial * randf_range(-0.4, 0.4)).normalized()
	_change_state(State.DASH)


## Il giocatore ha appena iniziato un attacco qui vicino, girato verso di
## noi: si decide una volta per attacco se alzare la guardia.
func _should_guard(distance: float) -> bool:
	if player.attack_serial == _seen_attack or not player.is_attacking():
		return false
	_seen_attack = player.attack_serial
	if _guard_cooldown > 0.0 or distance > GUARD_RANGE:
		return false
	var toward_us := (global_position - player.global_position).normalized()
	return player.facing.dot(toward_us) > 0.3 and randf() < float(_type["guard_chance"])


func _begin_guard() -> void:
	var times: Array = _type["guard_time"]
	_guard_time = randf_range(times[0], times[1])
	Sfx.play("block", global_position, 1.4, -8.0)
	_change_state(State.GUARD)


## Il colpo del giocatore che arriva da from viene parato dalla guardia?
## Se sì, la guardia si illumina e a volte si contrattacca subito.
func blocks(from: Vector2) -> bool:
	if _state != State.GUARD or absf(_facing.angle_to(from - global_position)) > GUARD_ARC / 2.0:
		return false
	_guard_flash = 0.25
	if randf() < COUNTER_CHANCE and _attack_slot_free():
		_guard_cooldown = randf_range(GUARD_COOLDOWN.x, GUARD_COOLDOWN.y)
		_strikes = 0
		_attack_direction = (from - global_position).normalized()
		_begin_windup(_type["windup"][0] * COMBO_WINDUP_FACTOR, _type["windup"][1] * COMBO_WINDUP_FACTOR, false)
	return true


func _begin_windup(min_time: float, max_time: float, can_feint: bool) -> void:
	_strikes += 1
	# I fendenti si alternano: una volta da sinistra, una da destra.
	_swing_sign = -_swing_sign
	_windup_time = randf_range(min_time, max_time)
	_windup_tracking = randf_range(WINDUP_TRACKING.x, WINDUP_TRACKING.y)
	_feint_at = _windup_time * randf_range(0.4, 0.7) if can_feint and randf() < FEINT_CHANCE else -1.0
	if player:
		_attack_direction = (player.global_position - global_position).normalized()
	Sfx.play("enemy_windup", global_position, 1.0 / sqrt(_type["mass"]), -4.0)
	_change_state(State.WINDUP)


func _can_slam(distance: float) -> bool:
	if not _type.has("slam") or _slam_cooldown > 0.0 or _attack_cooldown > 0.0:
		return false
	var slam: Dictionary = _type["slam"]
	if distance > float(slam["range"]) or distance < radius + Player.RADIUS:
		return false
	if randf() >= float(slam["chance"]):
		_slam_cooldown = randf_range(SLAM_RETRY.x, SLAM_RETRY.y)
		return false
	return true


func _begin_slam() -> void:
	_slam_from = global_position
	_slam_target = player.global_position
	_slam_landed = false
	_air = 0.0
	_velocity = Vector2.ZERO
	Sfx.play("enemy_windup", global_position, 0.8 / sqrt(_type["mass"]), -2.0)
	_change_state(State.SLAM)


## Carica accucciati (la zona d'impatto segue il giocatore per un po'),
## salto ad arco verso la zona e colpo a terra all'arrivo.
func _update_slam(player_active: bool) -> void:
	var slam: Dictionary = _type["slam"]
	var windup := float(slam["windup"])
	var air_time := float(slam["air_time"])
	_velocity = Vector2.ZERO
	if _state_time < windup:
		if player_active and _state_time <= windup * SLAM_TRACKING:
			var reach := (player.global_position - _slam_from).limit_length(float(slam["range"]))
			_slam_target = _confined(_slam_from + reach)
		return
	var t := clampf((_state_time - windup) / air_time, 0.0, 1.0)
	_air = sin(PI * t) * float(slam["height"])
	var world := World.current
	var goal := _slam_from.lerp(_slam_target, ease(t, 0.8))
	if world:
		# In volo si sale anche sui gradini più alti dell'altezza del salto.
		position = _confined(world.move(position, goal - position, radius * 0.8, _air, true, false))
	else:
		position = goal
	if t >= 1.0 and not _slam_landed:
		_land_slam(player_active, slam)
	if _state_time >= windup + air_time + 0.05:
		_air = 0.0
		_change_state(State.RECOVER)
		_state_time = -SLAM_RECOVER_EXTRA
		_slam_cooldown = randf_range(SLAM_RETRY.x, SLAM_RETRY.y) * 2.0
		_attack_cooldown = randf_range(ATTACK_COOLDOWN.x, ATTACK_COOLDOWN.y)


func _land_slam(player_active: bool, slam: Dictionary) -> void:
	_slam_landed = true
	_air = 0.0
	var impact_radius := float(slam["radius"])
	GroundFx.shockwave(global_position, ground_elevation, impact_radius)
	Sfx.play("fireball_hit", global_position, 0.5 / sqrt(_type["mass"]))
	for other in _enemies_near(impact_radius):
		hurt_enemy(other, EnemyTypes.player_damage(is_boss()), other.global_position - global_position, true)
	if player_active and player.global_position.distance_to(global_position) <= impact_radius + Player.RADIUS:
		# Anche il colpo a terra si può parare: con una parata perfetta
		# (istantanea, appena prima dell'impatto) si resta storditi.
		if player.receive_hit(global_position, EnemyTypes.player_damage(is_boss())) == "parried":
			Sfx.play("stun", global_position)
			_slam_cooldown = randf_range(SLAM_RETRY.x, SLAM_RETRY.y) * 2.0
			_change_state(State.STUNNED)


func _can_summon(distance: float) -> bool:
	if not _type.has("summon") or _summon_cooldown > 0.0 or distance > LEASH_RANGE:
		return false
	# I servitori sconfitti possono essere già stati liberati: si controlla
	# con is_instance_valid prima di usarli (niente filter con parametri
	# tipizzati, che fallisce sugli oggetti liberati).
	var alive: Array[Enemy] = []
	for minion in _minions:
		if is_instance_valid(minion) and not minion.is_dead():
			alive.append(minion)
	_minions = alive
	return _minions.size() < int(_type["summon"]["max_minions"])


func _begin_summon() -> void:
	var count := mini(int(_type["summon"]["count"]), int(_type["summon"]["max_minions"]) - _minions.size())
	_summon_positions.clear()
	var start := randf() * TAU
	for i in count:
		_summon_positions.append(Vector2.from_angle(start + TAU * i / count) * SUMMON_DISTANCE)
	Sfx.play("summon", global_position)
	_change_state(State.SUMMON)


func _finish_summon() -> void:
	var cooldown: Array = _type["summon"]["cooldown"]
	_summon_cooldown = randf_range(cooldown[0], cooldown[1])
	_change_state(State.CHASE)


func _player_in_strike_zone() -> bool:
	var offset := player.global_position - global_position
	if offset.length() > radius + float(_type["strike_reach"]) + Player.RADIUS:
		return false
	return offset.length() <= radius + Player.RADIUS or absf(_attack_direction.angle_to(offset)) <= _strike_arc() / 2.0


## Sta attaccando il giocatore (carica, colpo o salto con colpo a terra)?
## Al più EnemyTypes.max_simultaneous_attacks nemici attaccano insieme: gli
## altri girano attorno finché uno degli attacchi non finisce (vedi
## _attack_slot_free).
func is_attacking() -> bool:
	return _state in [State.WINDUP, State.STRIKE, State.SLAM]


## C'è posto per un nuovo attacco? Al più EnemyTypes.max_simultaneous_attacks
## nemici attaccano insieme; il controllo avviene quando si decide, uno dopo
## l'altro, così due nemici nello stesso passo non prendono lo stesso posto.
func _attack_slot_free() -> bool:
	var limit := EnemyTypes.max_simultaneous_attacks()
	var busy := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy != null and enemy != self and enemy.is_attacking():
			busy += 1
			if busy >= limit:
				return false
	return true


## Gli altri nemici vivi entro reach (più il loro raggio) e più o meno alla
## stessa altezza.
func _enemies_near(reach: float) -> Array[Enemy]:
	var found: Array[Enemy] = []
	var altitude := ground_elevation + _height + _air
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy == self or enemy.is_dead():
			continue
		if absf(enemy.ground_elevation + enemy._height + enemy._air - altitude) > FRIENDLY_HEIGHT_REACH:
			continue
		if enemy.global_position.distance_to(global_position) <= reach + enemy.radius:
			found.append(enemy)
	return found


## Fuoco amico del fendente: ferisce una volta per colpo gli altri nemici
## nella zona colpita (stessa portata e stesso arco del colpo al giocatore).
func _strike_enemies() -> void:
	for other in _enemies_near(radius + float(_type["strike_reach"])):
		if other in _friendly_struck:
			continue
		var offset := other.global_position - global_position
		if offset.length() > radius + other.radius and absf(_attack_direction.angle_to(offset)) > _strike_arc() / 2.0:
			continue
		_friendly_struck.append(other)
		hurt_enemy(other, EnemyTypes.player_damage(is_boss()), offset, false)


## Colpo di un nemico a un altro nemico (fuoco amico): toglie gli stessi
## punti vita che toglierebbe al giocatore (points).
static func hurt_enemy(other: Enemy, points: int, direction: Vector2, heavy: bool) -> void:
	other.take_points(points, direction.normalized() if direction != Vector2.ZERO else Vector2.DOWN, heavy)
	Sfx.play("hit", other.global_position, 0.8, -6.0)


## Il giocatore l'ha agganciato (vedi Player.lock_target): si colora di rosso.
func set_locked(locked: bool) -> void:
	self_modulate = COLOR_LOCKED if locked else Color.WHITE


## Spinta per non sovrapporsi agli altri nemici.
func _separation() -> Vector2:
	var grid := _enemy_grid()
	var push := Vector2.ZERO
	var home := Vector2i((global_position / GRID_CELL).floor())
	var checked := 0
	for i in range(-1, 2):
		for j in range(-1, 2):
			for node in grid.get(home + Vector2i(i, j), []):
				if node == self or not is_instance_valid(node):
					continue
				checked += 1
				if checked > SEPARATION_MAX:
					return push
				var other := node as Enemy
				var offset := global_position - other.global_position
				var distance := offset.length()
				var range := SEPARATION_RANGE + radius + other.radius - 48.0
				if distance > 0.0 and distance < range:
					push += offset / distance * (1.0 - distance / range)
	return push


## Griglia dei nemici vivi, rifatta al primo uso di ogni passo di fisica.
func _enemy_grid() -> Dictionary:
	var frame := Engine.get_physics_frames()
	if frame != _grid_frame:
		_grid_frame = frame
		_grid.clear()
		for node in get_tree().get_nodes_in_group("enemies"):
			var key := Vector2i(((node as Node2D).global_position / GRID_CELL).floor())
			if _grid.has(key):
				_grid[key].append(node)
			else:
				_grid[key] = [node]
	return _grid


## Il nemico (disegnato sopra il terreno) è nella parte di mondo visibile.
func _on_screen() -> bool:
	var frame := Engine.get_process_frames()
	if frame != _view_frame:
		_view_frame = frame
		var camera := get_viewport().get_camera_2d()
		if camera == null:
			_view = Rect2(-1e9, -1e9, 2e9, 2e9)
		else:
			var half := get_viewport_rect().size / camera.zoom / 2.0 + VIEW_MARGIN
			_view = Rect2(camera.get_screen_center_position() - half, half * 2.0)
	return _view.has_point(global_position - Vector2(0, ground_elevation))


## Cerchi dove compariranno i nemici evocati e bagliore rosso dove atterrerà
## il salto con colpo a terra. L'attacco in carica non ha
## più una zona a terra: si riconosce dal corpo che si accende e dalla spada
## (o dal bastone) portata indietro.
func _draw_telegraph() -> void:
	if _state == State.SLAM and not _slam_landed:
		var slam: Dictionary = _type["slam"]
		var total := float(slam["windup"]) + float(slam["air_time"])
		# Bagliore rosso sfumato sul punto d'impatto, sempre più acceso.
		GroundFx.danger_glow(_telegraph, _slam_target - global_position, float(slam["radius"]), _state_time / total)
	if _state == State.SUMMON:
		var progress: float = _state_time / _type["summon"]["channel_time"]
		# I ghoul richiamano i non morti con un urlo: dove arriveranno sale un vapore verde.
		var smoke := COLOR_ACID if is_mutant() else COLOR_SUMMON
		for offset in _summon_positions:
			Shapes.disc(_telegraph, offset, 24.0, Color(smoke, 0.12))
			Shapes.disc(_telegraph, offset, 24.0 * progress, Color(smoke, 0.3))


func _draw() -> void:
	draw_set_transform(Vector2(0, -ground_elevation))
	var body := _color
	match _state:
		State.WINDUP:
			body = _color.lerp(COLOR_WINDUP, _state_time / _windup_time)
		State.STRIKE:
			body = COLOR_DANGER
		State.STUNNED:
			body = COLOR_STUNNED
		State.SUMMON:
			body = _color.lerp(COLOR_SUMMON, 0.5 + 0.5 * sin(_state_time * 20.0))
		State.SLAM:
			var windup := float(_type["slam"]["windup"])
			body = _color.lerp(COLOR_WINDUP, _state_time / windup) if _state_time < windup else COLOR_DANGER
	if _hit_flash > 0.0:
		body = Color.WHITE
	if _state == State.DEAD:
		draw_set_transform(Vector2(0, -ground_elevation))
		_draw_falling(_color.lerp(_corpse_color(), minf(_state_time / DEATH_FALL_TIME, 1.0)) if _hit_flash <= 0.0 else body)
		return

	# Ombra, gambe e il goblin sopra le gambe: orecchie, testa, arma e per
	# ultima la faccia, con gli occhi che guardano dove va.
	var lift := _air + _height
	Shapes.disc(self, Vector2(0, radius * 0.8), radius * 0.9 * (1.0 - minf(lift, 150.0) / 200.0), Shapes.SHADOW)
	var leg := radius * LEG_FACTOR
	# I salti (attacco speciale, gradini) sollevano tutto tranne l'ombra.
	draw_set_transform(Vector2(0, -ground_elevation - lift))
	var walking := _velocity.length() > 15.0 and _state != State.DEAD
	BodyParts.draw_legs(self, -leg + radius * 0.55, radius * 0.85, radius * LEG_SPACING, maxf(4.5, radius * LEG_WIDTH),
			_walk_phase, _velocity.normalized(), radius * 0.3 if walking else 0.0, _color.darkened(0.4))
	draw_set_transform(_body_offset())
	_prepare_meshes()
	if _hit_flash <= 0.0:
		body = _blood.tint(body)
	# Guardando verso nord l'arma è dietro al corpo, che la copre (vedi
	# BodyParts.gear_behind); la faccia e la corona restano sempre in cima.
	var behind := BodyParts.gear_behind(_facing)
	if behind:
		_draw_gear()
	GoblinLook.ears(self, radius, body.darkened(0.12), _goblin.get("ear_length", 1.0), _goblin.get("ear_droop", 0.0), _goblin.get("torn", 0.0))
	draw_mesh(_ink_mesh, null, Transform2D.IDENTITY, Shapes.INK)
	draw_mesh(_body_mesh, null, Transform2D.IDENTITY, body)
	_blood.draw(self, radius, 1.0)
	_wounds.draw(self, radius, 1.0)
	draw_mesh(_outline_mesh, null, Transform2D.IDENTITY, body.darkened(0.35))
	if not behind:
		_draw_gear()
	if not is_horde() and not is_mutant():
		GoblinLook.face(self, radius, _facing, _goblin.get("eye_size", 0.2), true, _goblin.get("mouth", "grin"), 1.0, _goblin)
	_draw_headwear()
	if is_mutant():
		_draw_growths(body)
	elif is_boss():
		_draw_crown()

	if _state == State.STUNNED:
		for i in 3:
			var angle := _state_time * 4.0 + TAU * i / 3.0
			Shapes.disc(self, Vector2(cos(angle) * 18.0, -radius * 1.6 + sin(angle) * 5.0), 4.0, Color(1, 1, 0.5))

	# Punti vita rimasti sopra la testa, a segmenti come quelli del giocatore.
	if health < max_health and _state != State.DEAD:
		var width := maxf(40.0, radius * 1.8)
		var origin := Vector2(-width / 2.0, -radius * 1.2 - 14.0)
		draw_rect(Rect2(origin - Vector2(2, 2), Vector2(width + 4, 10)), Color(Shapes.INK, 0.85))
		var gap := 1.5 if max_health <= 10 else 0.0
		var segment := (width - gap * (max_health - 1)) / max_health
		for k in health:
			draw_rect(Rect2(origin + Vector2(k * (segment + gap), 0), Vector2(segment, 6)), COLOR_DANGER)


## "Occhio" che indica la direzione, magia e arma.
func _draw_gear() -> void:
	if is_horde():
		_draw_undead()
		return
	if is_mutant():
		_draw_ghoul()
		return
	if is_casting():
		_draw_magic()
	if _is_ranged():
		if _type["ranged"].get("arrow", false):
			_draw_bow()
		else:
			_draw_staff()
	else:
		_draw_sword()


## Ghoul: tanti occhi rossi in disordine e la bocca spalancata (la bile
## gocciola a chi sputa, di più mentre carica), poi gli artigli.
func _draw_ghoul() -> void:
	var across := _facing.orthogonal()
	var eyes := _facing * radius * 0.45 + Vector2(0, -radius * 0.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = _look_seed
	for k in 3 + rng.randi() % 3:
		var at := eyes + across * radius * rng.randf_range(-0.45, 0.45) + Vector2(0, radius * rng.randf_range(-0.35, 0.1))
		Shapes.disc(self, at, radius * rng.randf_range(0.06, 0.12), COLOR_ZOMBIE_EYES)
	var mouth := eyes + Vector2(0, radius * 0.35)
	var open := 0.12 + (0.12 if _state in [State.WINDUP, State.STRIKE, State.SUMMON] else 0.0)
	draw_colored_polygon(PackedVector2Array([mouth - across * radius * 0.25, mouth + across * radius * 0.25, mouth + Vector2(0, radius * open)]), Color(0.12, 0.02, 0.03))
	if _type.get("spit", false) or is_casting():
		var charge := clampf(_state_time / _windup_time, 0.0, 1.0) if _state == State.WINDUP else 0.0
		Shapes.disc(self, mouth + Vector2(0, radius * open), radius * (0.08 + 0.12 * charge), Color(COLOR_ACID, 0.7 + 0.3 * charge))
	_draw_claws()


## Artigli del ghoul: braccia lunghe con tre unghie ricurve. Come le spade,
## durante la carica si portano indietro e poi spazzano l'arco
## dell'attacco; chi sputa le tiene basse e punta la bocca.
func _draw_claws() -> void:
	var angles := _sword_angles()
	var angle := _facing.angle() + 0.5
	match _state:
		State.WINDUP:
			if not _is_ranged() and not is_casting():
				angle = angles.x - _swing_sign * 0.4 * minf(_state_time / _windup_time, 1.0)
		State.STRIKE:
			if not _is_ranged() and not is_casting():
				angle = angles.z
		State.RECOVER:
			angle = angles.y
	if _state == State.WINDUP and (_is_ranged() or is_casting()):
		# Mira dello sputo: una scia verde che si allunga dalla bocca (il momento di schivare).
		var progress := clampf(_state_time / _windup_time, 0.0, 1.0)
		var mouth := _facing * radius * 0.5 + Vector2(0, radius * 0.2)
		draw_line(mouth, mouth + _attack_direction * radius * 6.0 * progress, Color(COLOR_ACID, 0.2 + 0.4 * progress), 1.5)
	var reach := radius * (1.25 if _state in [State.WINDUP, State.STRIKE] else 1.05)
	var hand := Vector2.from_angle(angle) * reach
	var other := _facing * radius * 1.1 - _facing.orthogonal() * radius * 0.55 * _swing_sign
	var shoulder := _facing.orthogonal() * radius * 0.7
	var limb := _color.darkened(0.45)
	for pair: Array in [[shoulder if hand.dot(shoulder) >= 0.0 else -shoulder, hand], [-shoulder if hand.dot(shoulder) >= 0.0 else shoulder, other]]:
		var from: Vector2 = pair[0]
		var to: Vector2 = pair[1]
		draw_line(from, to, limb, maxf(2.5, radius * 0.12))
		var out := (to - from).normalized()
		for k in 3:
			var nail := out.rotated((k - 1) * 0.45)
			var tip := to + nail * radius * 0.4 + nail.orthogonal() * radius * 0.08
			draw_polyline(PackedVector2Array([to, to + nail * radius * 0.25, tip]), COLOR_CLAWS, maxf(1.5, radius * 0.06))


## Escrescenze del ghoul: bolle di carne gonfia sul corpo, sempre uguali
## per lo stesso nemico (dal seme dell'aspetto); il boss ne ha di più.
func _draw_growths(body: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _look_seed + 7
	var growth := body.lerp(COLOR_GROWTH, 0.5)
	for k in 2 + rng.randi() % 3 + (3 if is_boss() else 0):
		var at := Vector2.from_angle(rng.randf_range(-PI, 0.2)) * radius * rng.randf_range(0.55, 0.85)
		var size := radius * rng.randf_range(0.14, 0.26)
		Shapes.disc(self, at, size, growth)
		Shapes.disc(self, at + Vector2(-size * 0.3, -size * 0.3), size * 0.35, growth.lightened(0.25))


## Non morto delle orde: niente armi, due occhi rossi, braccia tese in
## avanti con le mani ossute e stracci che pendono dal corpo.
func _draw_undead() -> void:
	var across := _facing.orthogonal()
	var eyes := _facing * radius * 0.45 + Vector2(0, -radius * 0.15)
	for side: float in [-1.0, 1.0]:
		Shapes.disc(self, eyes + across * radius * 0.25 * side, maxf(radius * 0.1, 2.0), COLOR_ZOMBIE_EYES)
	var reach := _facing * radius * 0.95
	for side: float in [-1.0, 1.0]:
		var hand := reach + across * radius * 0.4 * side
		draw_line(across * radius * 0.6 * side, hand, _color.darkened(0.3), maxf(2.5, radius * 0.16))
		Shapes.disc(self, hand, maxf(radius * 0.12, 2.0), _color.lightened(0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(-radius * 0.75, radius * 0.15), Vector2(radius * 0.75, radius * 0.15),
			Vector2(radius * 0.45, radius * 0.8), Vector2(radius * 0.1, radius * 0.55), Vector2(-radius * 0.4, radius * 0.85)]), COLOR_RAGS)


## Posizione del corpo sopra le gambe: salto, ondeggiare del passo e
## accucciata durante la carica del salto.
func _body_offset() -> Vector2:
	var leg := radius * LEG_FACTOR
	var walking := _velocity.length() > 15.0 and _state != State.DEAD
	# Camminando il corpo ondeggia un poco su e giù.
	var bob := absf(sin(_walk_phase)) * radius * 0.1 if walking else 0.0
	var crouch := 0.0
	if _state == State.SLAM and _state_time < float(_type["slam"]["windup"]):
		crouch = leg * 0.5 * minf(_state_time / float(_type["slam"]["windup"]) * 3.0, 1.0)
	return Vector2(0, -ground_elevation - _air - _height - leg - bob + crouch)


func _prepare_meshes() -> void:
	if _shape_radius != radius:
		_shape_radius = radius
		var key := "goblin:%s" % radius
		_body_mesh = Shapes.polygon_mesh(key, _shape_points())
		_outline_mesh = Shapes.outline_mesh(key + ":outline", _shape_points(), 2.0)
		_ink_mesh = Shapes.ink_mesh(key + ":ink", _shape_points(), Shapes.INK_WIDTH)


## Dietro al corpo: bagliore rosso della carica e copie rosse del corpo
## lasciate dallo scatto dell'attacco (vedi _update_trail).
func _draw_danger_back() -> void:
	if _state == State.DEAD:
		return
	if _state == State.WINDUP and not _is_ranged():
		# Carica dell'attacco: bagliore rosso sempre più acceso attorno al corpo.
		var progress := clampf(_state_time / _windup_time, 0.0, 1.0)
		_danger_back.draw_set_transform(_body_offset())
		Shapes.glow(_danger_back, Vector2.ZERO, radius * (1.6 + 0.6 * progress), Color(COLOR_DANGER, WINDUP_GLOW_ALPHA * maxf(progress, 0.1)))
	if _trail.is_empty():
		return
	_prepare_meshes()
	var leg := radius * LEG_FACTOR
	for point in _trail:
		var fade := 1.0 - point.w / TRAIL_FADE
		var offset := Vector2(point.x, point.y) - global_position
		_danger_back.draw_set_transform(offset + Vector2(0, -ground_elevation - point.z - leg), 0.0, Vector2.ONE * (0.75 + 0.25 * fade))
		_danger_back.draw_mesh(_body_mesh, null, Transform2D.IDENTITY, Color(COLOR_DANGER, TRAIL_ALPHA * fade * fade))


## Davanti al corpo: l'arco rosso lasciato dalla spada che fende.
func _draw_danger_front() -> void:
	if _state != State.STRIKE or _is_ranged():
		return
	var angles := _sword_angles()
	_danger_front.draw_set_transform(_body_offset())
	BodyParts.draw_trail(_danger_front, Vector2.ZERO, angles.x, angles.z, radius * 0.6, radius + float(_type["strike_reach"]), Color(COLOR_DANGER, 0.8))


## Angoli della spada nel fendente: inizio, fine e posizione attuale.
func _sword_angles() -> Vector3:
	var arc := _strike_arc()
	var start := _attack_direction.angle() - _swing_sign * arc / 2.0
	var end := _attack_direction.angle() + _swing_sign * arc / 2.0
	var angle := lerpf(start, end, ease(minf(_state_time / STRIKE_TIME, 1.0), 0.6))
	return Vector3(start, end, angle)


## Spada: a riposo di lato; durante la carica si porta indietro, poi
## fende l'arco dell'attacco (il verso cambia a ogni attacco) lasciando
## una scia.
func _draw_sword() -> void:
	var length := radius + float(_type["strike_reach"]) * 0.6
	var width := maxf(4.0, radius * 0.18)
	var angles := _sword_angles()
	var angle: float
	match _state:
		State.WINDUP:
			angle = angles.x - _swing_sign * 0.4 * minf(_state_time / _windup_time, 1.0)
		State.STRIKE:
			# La scia dell'arco è su _danger_front.
			angle = angles.z
		State.RECOVER:
			angle = angles.y
		_:
			angle = _facing.angle() + 0.6
	var hand := Vector2.from_angle(angle) * radius * 0.8 if _state in [State.WINDUP, State.STRIKE, State.RECOVER] else _facing.orthogonal() * radius * 0.8
	if _state == State.GUARD:
		# In guardia la spada è di traverso davanti al corpo.
		var across := -_facing.orthogonal()
		angle = across.angle()
		hand = _facing * radius * 0.95 - across * length * 0.45
	var tint := Color(1.0, 0.9, 0.9) if _state == State.STRIKE else Color.WHITE
	if _guard_flash > 0.0:
		# La spada in guardia si illumina quando para un colpo.
		var flash := _guard_flash / 0.25
		Shapes.disc(self, hand + Vector2.from_angle(angle) * length * 0.45, 16.0 * flash, Color(COLOR_GUARD, 0.6 * flash))
		tint = Color.WHITE.lerp(Color(1.4, 1.4, 1.5), flash)
	BodyParts.draw_sword(self, hand, angle, length, width, tint)


## Alla morte il corpo cade a terra: si inclina, si abbassa e si stende.
func _draw_falling(color: Color) -> void:
	var points := _corpse_points(ease(minf(_state_time / DEATH_FALL_TIME, 1.0), 0.5))
	draw_colored_polygon(points, color)
	draw_polyline(_closed(points), color.darkened(0.35), 2.0)


## Forma del corpo durante la caduta (t da 0, in piedi, a 1, steso a terra),
## rispetto alla base del nemico.
func _corpse_points(t: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var standing := Vector2(0, -radius * LEG_FACTOR)
	var lying := Vector2(_fall_side * radius * 0.25, radius * 0.15)
	for point in _shape_points():
		var flat := Vector2(point.x * 1.15, point.y * 0.42).rotated(_fall_side * 0.15)
		points.append((point + standing).lerp(flat + lying, t))
	return points


func _corpse_color() -> Color:
	return _color.darkened(0.2).lerp(Color(0.3, 0.27, 0.25), 0.2)


## Sfera della magia sopra la testa: cresce durante la carica.
func _draw_magic() -> void:
	var color := World._color(_type["magic"]["color"])
	var charge := minf(_state_time / _windup_time, 1.0) if _state == State.WINDUP else 1.0
	var at := Vector2(0, -radius * 2.0)
	var size := radius * 0.45 * (0.3 + 0.7 * charge)
	Shapes.disc(self, at, size * 1.8, Color(color, 0.25 * charge))
	Shapes.disc(self, at, size, color.lightened(0.2))
	Shapes.disc(self, at, size * 0.45, Color(1, 1, 1, 0.9))


## Bastone del lanciatore con la sfera che si accende caricando il dardo.
func _draw_staff() -> void:
	var hand := _facing.orthogonal() * radius * 0.8
	var top := hand + Vector2(0, -radius * 1.4)
	if _state == State.GUARD:
		# In guardia il bastone è di traverso davanti al corpo.
		hand = _facing * radius * 0.9 + _facing.orthogonal() * radius * 0.7
		top = hand - _facing.orthogonal() * radius * 1.4
	draw_line(hand + Vector2(0, radius * 0.5), top, Color(0.45, 0.3, 0.18), maxf(3.0, radius * 0.15))
	var glow := 0.4
	if _state == State.WINDUP:
		glow = 0.4 + 0.6 * _state_time / _windup_time
	Shapes.disc(self, top, radius * 0.35 * (1.0 + glow * 0.4), Color(_color.lightened(0.4), 0.35 * glow))
	Shapes.disc(self, top, radius * 0.22, _color.lightened(0.3 + 0.4 * glow))


## Arco dell'arciere: la corda si tende caricando il tiro, con la freccia
## incoccata (che parte al momento del tiro).
func _draw_bow() -> void:
	var pull := minf(_state_time / _windup_time, 1.0) if _state == State.WINDUP else 0.0
	var center := _facing * radius * 0.9
	var across := _facing.orthogonal()
	var points := PackedVector2Array()
	for i in 7:
		var t := i / 6.0
		points.append(center + across * radius * lerpf(1.1, -1.1, t) + _facing * radius * 0.45 * sin(PI * t))
	var wood := Color(0.5, 0.33, 0.18)
	draw_polyline(points, wood, maxf(3.0, radius * 0.15))
	var nock := center - _facing * radius * 0.6 * pull
	draw_polyline(PackedVector2Array([points[0], nock, points[6]]), Color(0.9, 0.88, 0.8, 0.8), 1.5)
	if _state == State.WINDUP:
		var tip := nock + _facing * radius * 1.7
		draw_line(nock, tip, wood.lightened(0.3), 2.0)
		draw_colored_polygon(PackedVector2Array([tip + _facing * 7.0, tip + across * 3.5, tip - across * 3.5]), Color(0.8, 0.82, 0.85))


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	result.append(points[0])
	return result


## Poligono regolare (o stella con inner < 1) centrato, a punta in su.
func _polygon(sides: int, scale: float, inner := 1.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := sides * (2 if inner < 1.0 else 1)
	for i in count:
		var length := radius * scale * (inner if inner < 1.0 and i % 2 == 1 else 1.0)
		points.append(Vector2.from_angle(TAU * i / count - PI / 2.0) * length)
	return points


## Testa tonda del goblin (anche per la caduta alla morte e le scie).
func _shape_points() -> PackedVector2Array:
	return _polygon(20, 1.0)
