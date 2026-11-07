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
## ma senza armi: tre occhi rossi, bocca spalancata,
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
## Campo dei percorsi verso il giocatore per le orde (rombo -> passi, vedi
## World.reach_field), aggiornato da Game mentre c'è un'orda.
static var horde_field := {}

signal died(enemy: Enemy)
## Chiede alla scena di gioco di creare i nemici evocati.
signal summon_requested(summoner: Enemy, type_id: String, positions: Array[Vector2])

enum State { WANDER, CHASE, DASH, WINDUP, STRIKE, RECOVER, STUNNED, SUMMON, DEAD, GUARD, SLAM, STAGGER }

const ACCELERATION := 750.0
## Lo sguardo ruota con continuità invece che a scatti.
const TURN_RATE := 9.0
const LEASH_RANGE := 700.0
const SEPARATION_RANGE := 60.0
## Respinta dei colpi (vedi take_points e knock): la strada percorsa da un
## nemico di massa 1 dopo un colpo della combo e dopo un colpo potente (il
## colpo finale della combo, il colpo potente, gli attacchi a terra, le
## esplosioni), divisa per massa^KNOCKBACK_MASS_EXPONENT (i boss la
## dividono ancora per BOSS_KNOCKBACK_DIVISOR: si spostano appena). La
## spinta frena in modo morbido: la velocità cala in modo esponenziale,
## KNOCKBACK_DAMPING al secondo (la strada è velocità / KNOCKBACK_DAMPING).
const KNOCKBACK_DISTANCE := 90.0
const HEAVY_KNOCKBACK_DISTANCE := 220.0
const KNOCKBACK_MASS_EXPONENT := 0.6
const BOSS_KNOCKBACK_DIVISOR := 3.5
const KNOCKBACK_DAMPING := 9.0
## Sotto questa velocità la spinta si ferma del tutto.
const KNOCKBACK_STOP := 6.0
## Le spinte date con shove (velocità iniziale) percorrono la stessa strada
## di quando frenavano a velocità costante, SHOVE_DECELERATION px/s².
const SHOVE_DECELERATION := 1200.0
## Contro un muro (gradini troppo alti, montagne, roccia, ostacoli solidi) una spinta di almeno
## WALL_HIT_SPEED px/s si ferma con uno sbuffo di polvere e un piccolo
## rimbalzo indietro (WALL_BOUNCE della velocità d'urto); conta come muro
## quando si percorre meno di WALL_HIT_SHARE della strada voluta.
const WALL_HIT_SPEED := 240.0
const WALL_BOUNCE := 0.3
const WALL_HIT_SHARE := 0.4
## Barcollamento (stato STAGGER, vedi _stagger): colpito, il nemico si
## inclina all'indietro, si schiaccia e interrompe l'attacco per un tempo
## tra STAGGER_TIME.x (colpi della combo) e STAGGER_TIME.y (colpi potenti),
## un po' a caso. Chi barcolla dipende dalla voce "stagger" del tipo
## (data/enemies.json): "light" (predefinito) da ogni colpo, "heavy" (bruti,
## golem, ghoul gonfi) solo dai colpi potenti e dal colpo finale della
## combo, "none" mai; i boss mai. Finito, aspetta un attimo prima di attaccare.
const STAGGER_TIME := Vector2(0.18, 0.32)
const STAGGER_TIME_LIMITS := Vector2(0.15, 0.35)
const STAGGER_COOLDOWN := Vector2(0.25, 0.55)
## Reazione a ogni colpo (vedi _draw e _body_transform): il corpo si
## schiaccia e rimbalza (ampiezza HURT_SQUASH, colpi potenti
## HURT_SQUASH_HEAVY, molla smorzata) e si inclina all'indietro, dalla
## parte opposta al colpo (HURT_TILT radianti, che si raddrizzano), con la
## smorfia di dolore (occhi socchiusi) per PAIN_FACE_TIME secondi.
const HURT_SQUASH := 0.16
const HURT_SQUASH_HEAVY := 0.26
const HURT_SQUASH_DAMPING := 9.0
const HURT_SQUASH_FREQUENCY := 28.0
const HURT_TILT := 0.32
const HURT_TILT_HEAVY := 0.45
const HURT_TILT_RECOVERY := 7.0
const PAIN_FACE_TIME := 0.28
## Resistenza ai colpi (voce "poise" del tipo in data/enemies.json, per i
## nemici grossi e i boss; vedi _take_poise): ogni colpo svuota la barra
## gialla sotto la vita (un colpo della combo 1, il colpo finale 2, un colpo
## potente o un attacco a terra 3, il contrattacco tutta); vuota, il nemico
## barcolla più a lungo (POISE_BREAK_TIME, anche i boss, che altrimenti non
## barcollano mai) e poi torna piena. Senza colpi per POISE_REGEN_DELAY
## secondi si riempie da sola ("poise_regen" al secondo, se no in
## POISE_REFILL_TIME secondi).
const POISE_BREAK_TIME := 0.6
const POISE_REGEN_DELAY := 2.5
const POISE_REFILL_TIME := 1.5
const COLOR_POISE := Color(1.0, 0.82, 0.25)
## Nemici élite (vedi make_elite e la voce "elites" di data/world.json): più
## grossi, più resistenti, con più esperienza e bottino sicuro, avvolti da
## un'aura che pulsa (ELITE_AURA_*), che il buio non spegne.
const COLOR_ELITE_AURA := Color(1.0, 0.75, 0.2)
const ELITE_AURA_RADIUS := 1.7
const ELITE_AURA_ALPHA := 0.4
## Attacchi che non si possono parare (voce "unblockable" del tipo o del suo
## "slam" in data/enemies.json): mentre li carica, sopra la testa c'è un
## triangolo rosso col punto esclamativo (vedi _draw_unblockable_icon).
const COLOR_UNBLOCKABLE := Color(0.95, 0.12, 0.08)
## Contrattacco possibile (vedi show_counter_glint): un luccichio dorato
## sopra il nemico stordito, finché il giocatore può colpirlo.
const COLOR_COUNTER_GLINT := Color(1.0, 0.86, 0.3)
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
## Velocità più alta del salto rispetto alla media (vedi _slam_air_time).
const SLAM_EASE_PEAK := 1.25
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
## Raggio del nemico più grosso (il boss della metro), per le ricerche nella griglia.
const MAX_ENEMY_RADIUS := 60.0

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
## Aspetto standard (vedi _apply_look): niente variazioni a caso, la taglia
## e il colore sono quelli del tipo, la faccia è la stessa per tutti
## (occhi grandi EYE_SIZE, ghigno che si spalanca attaccando) e così le
## orecchie.
const EYE_SIZE := 0.2
## Non morti delle orde: carne grigioverde, occhi rossi, velocità variabile
## di questa parte (sempre sotto il tetto, vedi max_speed); si disfano
## toccando il giocatore entro CONTACT_MARGIN oltre i due raggi.
const COLOR_ZOMBIE_SKIN := Color(0.52, 0.58, 0.46)
const COLOR_ZOMBIE_EYES := Color(1.0, 0.2, 0.1)
const COLOR_RAGS := Color(0.32, 0.27, 0.22)
## Ghoul: escrescenze, artigli e bile.
const COLOR_GROWTH := Color(0.78, 0.55, 0.5)
## Ghoul: tre occhi rossi ed escrescenze sempre nello stesso posto
## (posizione rispetto al raggio e grandezza; il boss ne ha di più).
const GHOUL_EYES := [Vector3(-0.3, -0.15, 0.1), Vector3(0.05, -0.3, 0.12), Vector3(0.32, -0.08, 0.09)]
const GHOUL_GROWTHS := [Vector3(-0.62, -0.45, 0.22), Vector3(0.6, -0.55, 0.18), Vector3(-0.2, -0.8, 0.16)]
const BOSS_GROWTHS := [Vector3(0.75, -0.1, 0.2), Vector3(-0.78, 0.05, 0.17), Vector3(0.3, -0.85, 0.14)]
const COLOR_CLAWS := Color(0.88, 0.85, 0.75)
const COLOR_ACID := Color(0.55, 1.0, 0.25)
const ZOMBIE_SPEED_SPREAD := 0.15
const CONTACT_MARGIN := 6.0
## Non morti delle orde bloccati dal terreno (vedi _slide_along_wall): se in un
## passo fanno meno di SLIDE_BLOCKED_SHARE della strada voluta, scivolano
## lungo la parete girando il movimento di uno degli angoli SLIDE_ANGLES
## (prima dalla parte già scelta); bloccati per più di FIELD_AFTER_BLOCKED
## secondi seguono per FIELD_FOLLOW_TIME secondi il campo dei percorsi verso
## il giocatore (horde_field), che li porta attorno agli ostacoli; arrivati
## sul rombo del giocatore o su uno vicino corrono di nuovo dritti.
const SLIDE_BLOCKED_SHARE := 0.5
const SLIDE_ANGLES := [0.6, 1.1, 1.57]
const FIELD_AFTER_BLOCKED := 0.3
const FIELD_FOLLOW_TIME := 2.5
const BURST_SPLATS := 3

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
## Fa parte del gruppo di una missione (vedi Game e Missions): non si salva
## e non sparisce allontanandosi.
var in_mission := false

var _type: Dictionary
var _color := Color.WHITE
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
## Reazione all'ultimo colpo (vedi _body_transform): da quanto è arrivato,
## ampiezza dello schiacciamento, inclinazione (radianti, positiva verso
## destra) e quanto dura il barcollamento in corso.
var _hurt_age := 10.0
var _hurt_squash := 0.0
var _hurt_tilt := 0.0
var _stagger_time := 0.0
## Il barcollamento in corso viene dalla resistenza ai colpi esaurita.
var _poise_broken := false
## Resistenza ai colpi (vedi POISE_*): massima, attuale e attesa prima che
## si riempia da sola.
var _poise_max := 0.0
var _poise := 0.0
var _poise_wait := 0.0
## Nemico élite (vedi make_elite).
var is_elite := false
## Secondi rimasti del luccichio del contrattacco (vedi show_counter_glint).
var _counter_glint := 0.0
var _hit_flash := 0.0
## Invulnerabilità rimasta dopo un colpo (vedi take_points).
var _invulnerable := 0.0
## Altezza sopra il terreno (salendo su un gradino con un salto o cadendo
## da uno), velocità verticale e attesa prima del prossimo salto.
var _height := 0.0
var _height_velocity := 0.0
var _hop_cooldown := 0.0
## Orde (vedi _slide_along_wall): da quanto si è bloccati, da che parte si
## scivola lungo la parete e per quanto si segue ancora il campo dei percorsi.
var _blocked_time := 0.0
var _slide_side := 1.0
var _field_follow := 0.0
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
## Mesh del corpo (vedi Shapes), preparata una volta per raggio.
var _body_mesh: ArrayMesh
## Contorno a inchiostro sotto il corpo (stile fumetto, vedi Shapes.ink_mesh),
## spesso quanto le linee nere di occhi e bocca (vedi ink_width).
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
## Nemici vivi (vedi alive_list) e attacchi in corso (vedi _attack_slot_free).
static var _alive: Array[Enemy] = []
static var _alive_stamp := -1
static var _attack_count := 0
static var _attack_frame := -1
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
	_poise_max = float(_type.get("poise", 0.0))
	_poise = _poise_max
	_speed = _type["speed"]
	var color: Array = _type["color"]
	_color = Color(color[0], color[1], color[2])
	if is_horde():
		_speed *= randf_range(1.0 - ZOMBIE_SPEED_SPREAD, 1.0 + ZOMBIE_SPEED_SPREAD)
	if _type.has("summon"):
		_summon_cooldown = randf_range(1.0, 2.5)
	if _type.has("magic"):
		_magic_cooldown = randf_range(1.5, 3.0)
	_apply_look()


## Nemico élite (dopo setup, prima di aggiungerlo alla scena): più grosso,
## con più punti vita (gli zombie/non morti delle orde ne hanno
## "zombie_points"), più esperienza, più resistenza ai colpi e il bottino
## sicuro (vedi Game._on_enemy_died); un'aura lo distingue.
func make_elite() -> void:
	var data: Dictionary = EnemyTypes.WORLD_DATA.data["elites"]
	is_elite = true
	radius = float(_type["radius"]) * float(data["size"])
	_shape_radius = -1.0
	max_health = int(data["zombie_points"]) if is_horde() else ceili(max_health * float(data["points"]))
	health = max_health
	xp_reward = roundi(xp_reward * float(data["xp"]))
	_poise_max *= float(data["poise"])
	_poise = _poise_max
	drops_loot = true


## Stato da salvare: tipo, posizione esatta, vita e valori cambiati dalla
## scena di gioco (boss più forte, nemici evocati, élite).
func save_state() -> Dictionary:
	return {
		"elite": is_elite,
		"type": type_id, "position": SaveGame.array(position), "health": health, "max_health": max_health, "points": true,
		"xp": xp_reward, "damage": damage, "loot": drops_loot, "minion": is_minion,
		"level": threat_level, "armor": armor,
		"facing": SaveGame.array(_facing),
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
	# Salvataggi di prima degli élite: nessun élite.
	if bool(data.get("elite", false)):
		var elites: Dictionary = EnemyTypes.WORLD_DATA.data["elites"]
		is_elite = true
		radius = float(_type["radius"]) * float(elites["size"])
		_shape_radius = -1.0
		_poise_max *= float(elites["poise"])
		_poise = _poise_max
	if data.has("facing"):
		var facing := SaveGame.vector(data["facing"])
		if facing != Vector2.ZERO:
			_facing = facing.normalized()
	# Il seme dell'aspetto ("look") dei salvataggi vecchi non serve più:
	# l'aspetto è uguale per tutti i nemici dello stesso tipo.


## Aspetto standard, uguale per tutti i nemici dello stesso tipo: la taglia
## e il colore del tipo (i non morti hanno la loro carne grigioverde), senza
## copricapi né variazioni a caso.
func _apply_look() -> void:
	radius = float(_type["radius"])
	var color: Array = _type["color"]
	_color = COLOR_ZOMBIE_SKIN if is_horde() else Color(color[0], color[1], color[2])
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
		_update_hurt(delta)
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
	_update_hurt(delta)
	_update_poise(delta)
	_counter_glint = maxf(_counter_glint - delta, 0.0)
	_update_invulnerability(delta)
	_guard_cooldown = maxf(_guard_cooldown - delta, 0.0)
	_guard_flash = maxf(_guard_flash - delta, 0.0)
	_slam_cooldown = maxf(_slam_cooldown - delta, 0.0)
	_magic_cooldown = maxf(_magic_cooldown - delta, 0.0)
	_hop_cooldown = maxf(_hop_cooldown - delta, 0.0)
	_field_follow = maxf(_field_follow - delta, 0.0)
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
				var result := player.receive_hit(global_position, EnemyTypes.player_damage(is_boss()), false, false, _attack_unblockable())
				if result == "parried":
					Sfx.play("stun", global_position)
					_change_state(State.STUNNED)
					player.offer_counter(self)
				elif result == "blocked":
					# Parato dal giocatore: il colpo si interrompe e si viene respinti.
					shove(-_attack_direction * REPELLED_KNOCKBACK / float(_type["mass"]))
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

		State.STAGGER:
			# Barcolla all'indietro (vedi _stagger), poi riprende ma non attacca subito.
			if _state_time >= _stagger_time:
				_attack_cooldown = maxf(_attack_cooldown, randf_range(STAGGER_COOLDOWN.x, STAGGER_COOLDOWN.y))
				if _poise_broken:
					# Dopo la rottura la resistenza torna piena.
					_poise_broken = false
					_poise = _poise_max
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
			_damp_knockback(delta)
			if World.current:
				var fall_start := position
				position = _confined(World.current.move(position, _knockback * delta, radius * 0.8, 0.0, true, false))
				ground_elevation = World.current.elevation_at(position)
				_check_wall_hit(position - fall_start, delta)
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
	elif _state in [State.WINDUP, State.RECOVER, State.STUNNED, State.SUMMON, State.GUARD, State.SLAM, State.STAGGER]:
		_velocity = _velocity.move_toward(Vector2.ZERO, ACCELERATION * delta)

	# Tetto di velocità: mai più veloce di Ciccio che cammina.
	_velocity = _velocity.limit_length(max_speed())

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
	elif _state == State.STAGGER:
		pass
	elif _velocity.length() > 5.0:
		_turn_toward(_velocity, delta)

	_damp_knockback(delta)
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
		if is_horde() and grounded and _state == State.CHASE and _knockback == Vector2.ZERO:
			position = _slide_along_wall(world, start, motion, position, delta)
		ground_elevation = world.elevation_at(position)
		_check_wall_hit(position - start, delta)
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
	var danger := _state in [State.WINDUP, State.STRIKE] or not _trail.is_empty() or is_elite or _counter_glint > 0.0 \
			or (_state == State.SLAM and _attack_unblockable())
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


## Spinta improvvisa (per esempio quando il giocatore, colpito durante
## un'orda, respinge i non morti attorno): velocity è la velocità iniziale;
## la strada percorsa è quella di una frenata costante di
## SHOVE_DECELERATION, uguale per tutti i nemici.
func shove(velocity: Vector2) -> void:
	if _state != State.DEAD:
		var speed := velocity.length()
		_knockback = velocity * KNOCKBACK_DAMPING * speed / (2.0 * SHOVE_DECELERATION)


## Respinta di un colpo: il nemico scivola via nella direzione data per
## distance pixel (per un nemico di massa 1, vedi KNOCKBACK_DISTANCE),
## divisi per la sua resistenza alle spinte (vedi knock_resistance), al più
## max_push pixel (il giocatore tiene i nemici a portata del colpo
## successivo della combo, vedi Player._push_limit).
func knock(direction: Vector2, distance: float, max_push := INF) -> void:
	var push := minf(distance / knock_resistance(), max_push)
	if push <= 0.0 or direction == Vector2.ZERO:
		_knockback = Vector2.ZERO
		return
	_knockback = direction.normalized() * push * KNOCKBACK_DAMPING


## Quanto il nemico resiste alle spinte: massa^KNOCKBACK_MASS_EXPONENT, i
## boss ancora BOSS_KNOCKBACK_DIVISOR volte di più.
func knock_resistance() -> float:
	return pow(maxf(float(_type["mass"]), 0.1), KNOCKBACK_MASS_EXPONENT) * (BOSS_KNOCKBACK_DIVISOR if is_boss() else 1.0)


## La spinta frena in modo morbido (vedi KNOCKBACK_DAMPING).
func _damp_knockback(delta: float) -> void:
	_knockback *= exp(-KNOCKBACK_DAMPING * delta)
	if _knockback.length_squared() < KNOCKBACK_STOP * KNOCKBACK_STOP:
		_knockback = Vector2.ZERO


## Spinti contro un muro (moved: la strada fatta in questo passo): uno
## sbuffo di polvere dove si sbatte e un piccolo rimbalzo indietro.
func _check_wall_hit(moved: Vector2, delta: float) -> void:
	var speed := _knockback.length()
	if speed < WALL_HIT_SPEED or delta <= 0.0:
		return
	var direction := _knockback / speed
	if moved.dot(direction) >= speed * delta * WALL_HIT_SHARE:
		return
	GroundFx.dust(global_position + direction * radius * 0.9, ground_elevation + radius * 0.5, -direction, radius)
	_knockback = -direction * speed * WALL_BOUNCE
	_hurt_age = 0.0
	_hurt_squash = maxf(_hurt_squash, HURT_SQUASH)
	Sfx.play("impact", global_position, 1.5 / sqrt(float(_type["mass"])), -12.0)


## Reazione a un colpo (vedi _body_transform e _draw_face): lampeggio bianco
## (in take_points), corpo che si schiaccia e rimbalza, inclinazione
## all'indietro dalla parte opposta al colpo e smorfia di dolore. I nemici
## più pesanti si inclinano meno.
func _react(direction: Vector2, heavy: bool) -> void:
	_hurt_age = 0.0
	_hurt_squash = HURT_SQUASH_HEAVY if heavy else HURT_SQUASH
	var side := signf(direction.x) if absf(direction.x) > 0.05 else (1.0 if randf() < 0.5 else -1.0)
	_hurt_tilt = side * (HURT_TILT_HEAVY if heavy else HURT_TILT) / sqrt(knock_resistance())


## La reazione al colpo si esaurisce: l'inclinazione si raddrizza (non
## mentre si barcolla, che resta inclinati).
func _update_hurt(delta: float) -> void:
	_hurt_age += delta
	if _state != State.STAGGER:
		_hurt_tilt *= exp(-HURT_TILT_RECOVERY * delta)


## Barcollamento dopo un colpo (vedi STAGGER_TIME e la voce "stagger" dei
## dati): interrompe l'attacco in corso (anche la carica del salto, non il
## salto già partito), l'evocazione e la guardia; chi è stordito resta stordito.
func _stagger(heavy: bool) -> void:
	if is_boss() or is_horde() or _state in [State.DEAD, State.STUNNED]:
		return
	if _state == State.SLAM and _state_time >= float(_type["slam"]["windup"]):
		return
	match str(_type.get("stagger", "light")):
		"none":
			return
		"heavy":
			if not heavy:
				return
	var time := STAGGER_TIME.y * randf_range(0.9, 1.1) if heavy else STAGGER_TIME.x * randf_range(0.85, 1.15)
	_stagger_time = clampf(time, STAGGER_TIME_LIMITS.x, STAGGER_TIME_LIMITS.y)
	_air = 0.0
	_change_state(State.STAGGER)


## Sta barcollando dopo un colpo.
func is_staggered() -> bool:
	return _state == State.STAGGER


## Velocità massima dei movimenti del nemico: quella di Ciccio che cammina
## (vedi Player.walk_speed, con i bonus dell'equipaggiamento).
func max_speed() -> float:
	return player.speed_cap() if player else _speed


## Punti vita tolti da un colpo con quel danno (vedi in cima): l'armatura
## ne assorbe una parte, ma almeno un punto passa sempre.
func points_for(amount: int) -> int:
	var unit := EnemyTypes.scaled("hit_damage", POINT_DAMAGE * Player.BASE_DAMAGE, threat_level)
	return clampi(roundi(amount * (1.0 - armor) / unit), 1, MAX_POINTS_PER_HIT)


## Colpo del giocatore con quel danno (vedi points_for); heavy: colpo
## potente o finale della combo, spinge più lontano e fa barcollare anche i
## nemici pesanti; max_push: respinta massima in pixel (vedi knock); poise:
## quanto svuota la resistenza ai colpi (vedi _take_poise; -1: 2 per i colpi
## potenti, 1 per gli altri).
func take_damage(amount: int, direction: Vector2, heavy := false, max_push := INF, poise := -1.0) -> void:
	take_points(points_for(amount), direction, heavy, false, max_push, poise)


## Toglie punti vita. Durante l'invulnerabilità dopo un colpo non succede
## nulla, salvo con force (runa del cataclisma, non morto che si disfa) e durante
## l'attacco speciale della Frenesia (i nemici sono fermi e i colpi vanno a raffica).
## Ogni colpo spinge via (vedi knock), fa reagire il corpo (vedi _react),
## schizza sangue nel verso del colpo, mostra i punti persi (vedi
## DamagePopups; critical: il contrattacco) e può far barcollare (vedi
## _stagger e _take_poise).
func take_points(points: int, direction: Vector2, heavy := false, force := false, max_push := INF, poise := -1.0, critical := false) -> void:
	if _state == State.DEAD or (_invulnerable > 0.0 and not force and not frozen):
		return
	health -= maxi(points, 1)
	DamagePopups.spawn(global_position, ground_elevation + _air + _height + radius * 2.4, maxi(points, 1),
			"critical" if critical else ("heavy" if heavy else "normal"))
	_invulnerable = HURT_INVULNERABLE_TIME
	_hit_flash = 0.12
	knock(direction, HEAVY_KNOCKBACK_DISTANCE if heavy else KNOCKBACK_DISTANCE, max_push)
	_react(direction, heavy)
	GroundFx.bleed(global_position, ground_elevation + radius * 0.8, direction, BLEED_DROPS_HEAVY if heavy else BLEED_DROPS, heavy)
	_wounds.add(-direction)
	_blood.add(BLOOD_PER_HEAVY if heavy else BLOOD_PER_HIT)
	if health <= 0:
		_fall_side = 1.0 if direction.x >= 0.0 else -1.0
		_trail.clear()
		_silhouette.visible = false
		# I non morti che si disfano non lasciano la pozza (solo gli schizzi).
		if not force or not is_horde():
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
	if not frozen and not _take_poise(poise if poise >= 0.0 else (2.0 if heavy else 1.0)):
		_stagger(heavy)


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
		if player.receive_hit(global_position, EnemyTypes.player_damage(false), false, true) != "dodged":
			_burst(to_player)
			return Vector2.ZERO
	# Bloccato dal terreno da un po': segue il campo dei percorsi attorno
	# agli ostacoli (vedi _slide_along_wall e _field_direction).
	if _field_follow > 0.0:
		var along := _field_direction()
		if along != Vector2.ZERO:
			return along * _speed
	return to_player.normalized() * _speed


## Il non morto si disfa addosso al giocatore: sangue tutto attorno, niente
## esperienza né bottino, e sparisce subito (niente corpo a terra).
func _burst(to_player: Vector2) -> void:
	xp_reward = 0
	drops_loot = false
	for k in BURST_SPLATS:
		GroundFx.bleed(global_position, ground_elevation + radius * 0.8, Vector2.from_angle(randf() * TAU), BLEED_DROPS)
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
	var was_attacking := is_attacking()
	_state = new_state
	_state_time = 0.0
	# Conto degli attacchi in corso di questo passo (vedi _attack_slot_free).
	if _attack_frame == Engine.get_physics_frames() and was_attacking != is_attacking():
		_attack_count += 1 if is_attacking() else -1
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
	var rise := _hop_rise(world, motion)
	if rise <= 0.0:
		return
	_hop_cooldown = HOP_COOLDOWN
	_height_velocity = sqrt(2.0 * GRAVITY * (rise + HOP_CLEARANCE))
	Sfx.play("jump", global_position, 0.8 / sqrt(_type["mass"]), -10.0)


## Quanto si salirebbe saltando sul gradino davanti nella direzione di
## motion (0 se non c'è un gradino da saltare: piano, parete invalicabile o
## più alta di HOP_LEVELS livelli).
func _hop_rise(world: World, motion: Vector2) -> float:
	var probe := position + motion.normalized() * (radius * 0.8 + 16.0)
	if world.is_barrier(World.cell_at(probe)):
		return 0.0
	var rise := world.elevation_at(probe) - ground_elevation
	if rise <= World.STEP_TOLERANCE or rise > HOP_LEVELS * world.level_height + World.STEP_TOLERANCE:
		return 0.0
	return rise


## Non morto di un'orda fermato da una parete (from: dove era, motion: il
## movimento voluto, to: dove la parete l'ha fermato): se davanti c'è un
## gradino da saltare ci pensa _try_hop; altrimenti scivola lungo la parete,
## girando il movimento prima dalla parte già scelta. Restituisce la
## posizione nuova.
func _slide_along_wall(world: World, from: Vector2, motion: Vector2, to: Vector2, delta: float) -> Vector2:
	var wanted := motion.length()
	if wanted < 0.5 or (to - from).length() >= wanted * SLIDE_BLOCKED_SHARE:
		_blocked_time = maxf(_blocked_time - delta, 0.0)
		return to
	_blocked_time += delta
	if _blocked_time >= FIELD_AFTER_BLOCKED:
		_field_follow = FIELD_FOLLOW_TIME
	if _hop_cooldown <= 0.0 and _hop_rise(world, motion) > 0.0:
		return to
	for angle: float in SLIDE_ANGLES:
		for side: float in [_slide_side, -_slide_side]:
			var turned := motion.rotated(side * angle) * lerpf(1.0, 0.75, angle / (PI / 2.0))
			var slid := _confined(world.move(from, turned, radius * 0.8, _height + _air, true, false))
			if (slid - from).length() >= turned.length() * 0.6:
				_slide_side = side
				return slid
	return to


## Direzione lungo il campo dei percorsi delle orde (horde_field): verso il
## rombo vicino più vicino al giocatore in cui si può passare da qui (non
## più alto di un salto, come in World.reach_field). Zero se si è fuori dal
## campo, sul rombo del giocatore o su uno vicino.
func _field_direction() -> Vector2:
	var world := World.current
	var cell := World.cell_at(global_position)
	if world == null or not horde_field.has(cell) or int(horde_field[cell]) <= 1:
		return Vector2.ZERO
	var best := cell
	var best_steps: int = horde_field[cell]
	var climb := HOP_LEVELS * world.level_height + World.STEP_TOLERANCE
	var height := world.elevation_at(World.cell_center(cell))
	for offset: Vector2i in World.NEIGHBORS:
		var other: Vector2i = cell + offset
		var steps: int = horde_field.get(other, best_steps)
		if steps < best_steps and world.elevation_at(World.cell_center(other)) <= height + climb:
			best = other
			best_steps = steps
	if best == cell:
		return Vector2.ZERO
	return (World.cell_center(best) - global_position).normalized()


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
	Sfx.play(_windup_sound(), global_position, 1.0 / sqrt(_type["mass"]), -4.0)
	_change_state(State.WINDUP)


## Suono della carica, diverso per ogni tipo di attacco (si riconosce senza
## guardare): fendente, tiro a distanza, sputo, colpo che gira tutto attorno.
func _windup_sound() -> String:
	if _is_ranged():
		return "windup_spit" if _type.get("spit", false) else "windup_ranged"
	if _type.get("unblockable", false):
		return "windup_spin"
	return "enemy_windup"


## L'attacco in corso non si può parare (vedi la voce "unblockable").
func _attack_unblockable() -> bool:
	if _state == State.SLAM:
		return bool((_type["slam"] as Dictionary).get("unblockable", false))
	return _state in [State.WINDUP, State.STRIKE] and not _is_ranged() and not _casting and bool(_type.get("unblockable", false))


## Il giocatore ha parato alla perfezione: può contrattaccare per time
## secondi (vedi Player.offer_counter), intanto sopra la testa luccica.
func show_counter_glint(time: float) -> void:
	_counter_glint = time


## Resistenza ai colpi rimasta, da 0 a 1 (1 anche per chi non ne ha).
func poise_ratio() -> float:
	return _poise / _poise_max if _poise_max > 0.0 else 1.0


## La resistenza ai colpi si riempie da sola dopo un po' senza colpi.
func _update_poise(delta: float) -> void:
	if _poise_max <= 0.0 or _poise_broken or _poise >= _poise_max:
		return
	_poise_wait -= delta
	if _poise_wait <= 0.0:
		_poise = minf(_poise + float(_type.get("poise_regen", _poise_max / POISE_REFILL_TIME)) * delta, _poise_max)


## Un colpo svuota la resistenza (amount); vuota, il nemico barcolla a
## lungo (anche i boss). Restituisce true se l'ha rotta.
func _take_poise(amount: float) -> bool:
	if _poise_max <= 0.0 or _poise_broken or is_horde():
		return false
	_poise = maxf(_poise - amount, 0.0)
	_poise_wait = POISE_REGEN_DELAY
	if _poise > 0.0 or _state in [State.DEAD, State.STUNNED]:
		return false
	# In volo (salto con colpo a terra) si rompe all'atterraggio, al colpo dopo.
	if _state == State.SLAM and _state_time >= float(_type["slam"]["windup"]):
		return false
	_poise_broken = true
	_stagger_time = POISE_BREAK_TIME
	_air = 0.0
	_change_state(State.STAGGER)
	Sfx.play("stun", global_position, 0.8)
	return true


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
	# Il salto con colpo a terra ha il suo suono (un ringhio che sale).
	Sfx.play("windup_slam", global_position, 0.9 / sqrt(_type["mass"]), -2.0)
	_change_state(State.SLAM)


## Carica accucciati (la zona d'impatto segue il giocatore per un po'),
## salto ad arco verso la zona e colpo a terra all'arrivo.
func _update_slam(player_active: bool) -> void:
	var slam: Dictionary = _type["slam"]
	var windup := float(slam["windup"])
	var air_time := _slam_air_time(slam)
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


## Durata del salto: quella del tipo, o di più se il salto è lungo, così
## anche in volo il nemico non va più veloce di Ciccio che cammina (la
## curva del salto, ease 0,8, all'inizio va 1,25 volte la media).
func _slam_air_time(slam: Dictionary) -> float:
	var distance := _slam_from.distance_to(_slam_target)
	return maxf(float(slam["air_time"]), SLAM_EASE_PEAK * distance / maxf(max_speed(), 1.0))


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
		if player.receive_hit(global_position, EnemyTypes.player_damage(is_boss()), false, false, _attack_unblockable()) == "parried":
			Sfx.play("stun", global_position)
			_slam_cooldown = randf_range(SLAM_RETRY.x, SLAM_RETRY.y) * 2.0
			_change_state(State.STUNNED)
			player.offer_counter(self)


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
## Gli attacchi in corso si contano una volta per passo di fisica (vedi
## _attack_count) e il conto si aggiorna quando qualcuno inizia o smette
## di attaccare (vedi _change_state).
func _attack_slot_free() -> bool:
	var frame := Engine.get_physics_frames()
	if frame != _attack_frame:
		_attack_frame = frame
		_attack_count = 0
		for enemy in alive_list():
			if enemy.is_attacking():
				_attack_count += 1
	var busy := _attack_count - (1 if is_attacking() else 0)
	return busy < EnemyTypes.max_simultaneous_attacks()


## Gli altri nemici vivi entro reach (più il loro raggio) e più o meno alla
## stessa altezza (cercati nelle celle vicine della griglia, vedi _enemy_grid).
func _enemies_near(reach: float) -> Array[Enemy]:
	var found: Array[Enemy] = []
	var altitude := ground_elevation + _height + _air
	var grid := _enemy_grid()
	var home := Vector2i((global_position / GRID_CELL).floor())
	var cells := ceili((reach + MAX_ENEMY_RADIUS) / GRID_CELL)
	for i in range(-cells, cells + 1):
		for j in range(-cells, cells + 1):
			for enemy: Enemy in grid.get(home + Vector2i(i, j), []):
				if enemy == self or not is_instance_valid(enemy) or enemy.is_dead():
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
static func _enemy_grid() -> Dictionary:
	var frame := Engine.get_physics_frames()
	if frame != _grid_frame:
		_grid_frame = frame
		_grid.clear()
		for enemy in alive_list():
			var key := Vector2i((enemy.global_position / GRID_CELL).floor())
			if _grid.has(key):
				_grid[key].append(enemy)
			else:
				_grid[key] = [enemy]
	return _grid


## Nemici vivi, in un elenco rifatto al più una volta per frame (di fisica o
## di disegno) e condiviso da nemici, proiettili, missili, giocatore e
## scena di gioco: costa molto meno di get_nodes_in_group chiamato da
## ognuno. Chi lo scorre controlla is_instance_valid e is_dead (nello stesso
## frame qualcuno può morire o sparire).
static func alive_list() -> Array[Enemy]:
	var stamp := Engine.get_physics_frames() * 1000003 + Engine.get_process_frames()
	if stamp != _alive_stamp:
		_alive_stamp = stamp
		_alive.clear()
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			for node in tree.get_nodes_in_group("enemies"):
				var enemy := node as Enemy
				if enemy != null and not enemy.is_queued_for_deletion():
					_alive.append(enemy)
	return _alive


## Nemici vivi che potrebbero stare entro reach da point (più il loro
## raggio): quelli nelle celle vicine della griglia (vedi _enemy_grid), da
## controllare poi uno per uno. Per chi si muove a ogni frame (giocatore,
## proiettili) è molto meno che scorrere tutti i nemici.
static func near_point(point: Vector2, reach: float) -> Array:
	var grid := _enemy_grid()
	var home := Vector2i((point / GRID_CELL).floor())
	var cells := ceili((reach + MAX_ENEMY_RADIUS) / GRID_CELL)
	var found := []
	for i in range(-cells, cells + 1):
		for j in range(-cells, cells + 1):
			var list: Variant = grid.get(home + Vector2i(i, j))
			if list != null:
				found.append_array(list)
	return found


## Il nemico vivo più vicino a point entro reach (nessuno: null).
static func nearest_to(point: Vector2, reach: float, exclude: Enemy = null) -> Enemy:
	var best: Enemy = null
	var best_distance := reach * reach
	for enemy in alive_list():
		if enemy == exclude or not is_instance_valid(enemy) or enemy.is_dead():
			continue
		var distance := enemy.global_position.distance_squared_to(point)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best


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
		var total := float(slam["windup"]) + _slam_air_time(slam)
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
	# Il corpo reagisce ai colpi: si schiaccia, rimbalza e si inclina (vedi _body_transform).
	draw_set_transform_matrix(_body_transform())
	_prepare_meshes()
	if _hit_flash <= 0.0:
		body = _blood.tint(body)
	# Guardando verso nord l'arma è dietro al corpo, che la copre (vedi
	# BodyParts.gear_behind); la faccia e la corona restano sempre in cima.
	var behind := BodyParts.gear_behind(_facing)
	if behind:
		_draw_gear()
	# Orecchie, corpo, occhi e bocca hanno tutti il contorno nero dello stesso
	# spessore (vedi ink_width).
	GoblinLook.ears(self, radius, body.darkened(0.12), 1.0, 0.0, 0.0, ink_width())
	draw_mesh(_ink_mesh, null, Transform2D.IDENTITY, Shapes.INK)
	draw_mesh(_body_mesh, null, Transform2D.IDENTITY, body)
	_blood.draw(self, radius, 1.0)
	_wounds.draw(self, radius, 1.0)
	if not behind:
		_draw_gear()
	if not is_horde() and not is_mutant():
		# Appena colpito fa la smorfia di dolore: occhi socchiusi e bocca aperta.
		var attacking := _state in [State.WINDUP, State.STRIKE, State.SLAM]
		var pained := in_pain()
		GoblinLook.face(self, radius, _facing, EYE_SIZE, true, "open" if attacking or pained else "grin", 1.0,
				{"squint": true} if pained else {}, ink_width())
	if is_mutant():
		_draw_growths(body)
	elif is_boss():
		_draw_crown()

	# Stelline dello stordimento e vita restano dritte sopra la testa.
	draw_set_transform(_body_offset())
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
	# Resistenza ai colpi: una barra gialla sottile sotto la vita, quando non è piena.
	if _poise_max > 0.0 and not is_boss() and _state != State.DEAD and (_poise < _poise_max or _poise_broken):
		var poise_width := maxf(40.0, radius * 1.8)
		var poise_origin := Vector2(-poise_width / 2.0, -radius * 1.2 - 2.0)
		draw_rect(Rect2(poise_origin - Vector2(2, 1), Vector2(poise_width + 4, 6)), Color(Shapes.INK, 0.85))
		var flash := _poise_broken and int(Time.get_ticks_msec() / 80) % 2 == 0
		draw_rect(Rect2(poise_origin, Vector2(poise_width * poise_ratio(), 4)), Color.WHITE if flash else COLOR_POISE)


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


## Ghoul: tre occhi rossi (sempre nello stesso posto) e la bocca spalancata (la bile
## gocciola a chi sputa, di più mentre carica), poi gli artigli.
func _draw_ghoul() -> void:
	var across := _facing.orthogonal()
	var eyes := _facing * radius * 0.45 + Vector2(0, -radius * 0.2)
	var pained := in_pain()
	for eye: Vector3 in GHOUL_EYES:
		var at := eyes + across * radius * eye.x + Vector2(0, radius * eye.y)
		if pained:
			# Smorfia di dolore: gli occhi si strizzano in due fessure.
			var size := radius * eye.z
			var ink := ink_width() * 0.6
			Shapes.oval(self, at, Vector2(size + ink, size * 0.3 + ink), Shapes.INK)
			Shapes.oval(self, at, Vector2(size, size * 0.3), COLOR_ZOMBIE_EYES)
		else:
			Shapes.ink_disc(self, at, radius * eye.z, COLOR_ZOMBIE_EYES, ink_width() * 0.6)
	var mouth := eyes + Vector2(0, radius * 0.35)
	var open := 0.12 + (0.12 if pained or _state in [State.WINDUP, State.STRIKE, State.SUMMON] else 0.0)
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


## Escrescenze del ghoul: bolle di carne gonfia sul corpo, sempre nello
## stesso posto (GHOUL_GROWTHS); il boss ne ha di più (BOSS_GROWTHS).
func _draw_growths(body: Color) -> void:
	var growth := body.lerp(COLOR_GROWTH, 0.5)
	var growths: Array = GHOUL_GROWTHS + BOSS_GROWTHS if is_boss() else GHOUL_GROWTHS
	for spot: Vector3 in growths:
		var at := Vector2(spot.x, spot.y) * radius
		var size := radius * spot.z
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


## Trasformazione del corpo (vedi _body_offset) con la reazione all'ultimo
## colpo (vedi _react): lo schiacciamento che rimbalza (una molla smorzata;
## barcollando resta un po' schiacciato) e l'inclinazione all'indietro,
## imperniati sul fondo del corpo, così i piedi restano a terra.
func _body_transform() -> Transform2D:
	var offset := _body_offset()
	var squash := _hurt_squash * exp(-HURT_SQUASH_DAMPING * _hurt_age) * cos(HURT_SQUASH_FREQUENCY * _hurt_age)
	if _state == State.STAGGER:
		squash = maxf(squash, _hurt_squash * 0.5)
	if absf(squash) < 0.002 and absf(_hurt_tilt) < 0.002:
		return Transform2D(0.0, offset)
	var bottom := Vector2(0, radius)
	return Transform2D(_hurt_tilt, Vector2(1.0 + squash, 1.0 - squash), 0.0, offset + bottom) * Transform2D(0.0, -bottom)


## Smorfia di dolore: occhi socchiusi e bocca aperta subito dopo un colpo
## e mentre barcolla.
func in_pain() -> bool:
	return _state != State.DEAD and (_hurt_age < PAIN_FACE_TIME or _state == State.STAGGER)


func _prepare_meshes() -> void:
	if _shape_radius != radius:
		_shape_radius = radius
		var key := "goblin:%s" % radius
		_body_mesh = Shapes.polygon_mesh(key, _shape_points())
		_ink_mesh = Shapes.ink_mesh(key + ":ink:face", _shape_points(), ink_width())


## Spessore delle linee nere del nemico: il contorno del corpo e delle
## orecchie e quello di occhi e bocca sono uguali, proporzionati al raggio
## (Shapes.INK_WIDTH per un goblin grande come il giocatore).
func ink_width() -> float:
	return Shapes.INK_WIDTH * radius / Player.RADIUS


## Dietro al corpo: bagliore rosso della carica e copie rosse del corpo
## lasciate dallo scatto dell'attacco (vedi _update_trail).
func _draw_danger_back() -> void:
	if _state == State.DEAD:
		return
	if is_elite:
		# Aura dell'élite: un bagliore dorato che pulsa piano.
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004 + _update_slot)
		_danger_back.draw_set_transform(_body_offset())
		Shapes.glow(_danger_back, Vector2.ZERO, radius * ELITE_AURA_RADIUS * (0.92 + 0.12 * pulse), Color(COLOR_ELITE_AURA, ELITE_AURA_ALPHA * (0.7 + 0.3 * pulse)))
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


## Davanti al corpo: l'arco rosso lasciato dalla spada che fende, l'icona
## degli attacchi che non si possono parare e il luccichio del contrattacco.
func _draw_danger_front() -> void:
	if _state == State.DEAD:
		return
	var unblockable := _attack_unblockable() and (_state == State.WINDUP or (_state == State.SLAM and not _slam_landed))
	if unblockable or (_counter_glint > 0.0 and _state == State.STUNNED):
		var above := _body_offset() + Vector2(0, -radius * 1.2 - 38.0)
		_danger_front.draw_set_transform(Vector2.ZERO)
		if unblockable:
			_draw_unblockable_icon(above)
		else:
			_draw_counter_glint(above)
	if _state != State.STRIKE or _is_ranged():
		return
	var angles := _sword_angles()
	_danger_front.draw_set_transform(_body_offset())
	BodyParts.draw_trail(_danger_front, Vector2.ZERO, angles.x, angles.z, radius * 0.6, radius + float(_type["strike_reach"]), Color(COLOR_DANGER, 0.8))


## Triangolo rosso col punto esclamativo (contorno a inchiostro) che pulsa
## sopra la testa: l'attacco che sta caricando non si può parare.
func _draw_unblockable_icon(at: Vector2) -> void:
	var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.02)
	var size := 15.0 * pulse
	var points := PackedVector2Array([at + Vector2(0, -size), at + Vector2(size * 1.05, size * 0.75), at + Vector2(-size * 1.05, size * 0.75)])
	var outline := PackedVector2Array()
	var middle := at + Vector2(0, size * 0.15)
	for point in points:
		outline.append(middle + (point - middle) * 1.32)
	_danger_front.draw_primitive(outline, PackedColorArray([Shapes.INK]), PackedVector2Array())
	_danger_front.draw_primitive(points, PackedColorArray([COLOR_UNBLOCKABLE]), PackedVector2Array())
	_danger_front.draw_line(at + Vector2(0, -size * 0.5), at + Vector2(0, size * 0.22), Color.WHITE, 3.5)
	Shapes.disc(_danger_front, at + Vector2(0, size * 0.48), 2.2, Color.WHITE)


## Luccichio dorato a croce sopra il nemico che si può contrattaccare.
func _draw_counter_glint(at: Vector2) -> void:
	var spin := Time.get_ticks_msec() * 0.006
	var size := 13.0 + 3.0 * sin(Time.get_ticks_msec() * 0.025)
	Shapes.glow(_danger_front, at, size * 1.8, Color(COLOR_COUNTER_GLINT, 0.55))
	for k in 4:
		var direction := Vector2.from_angle(spin + PI / 2.0 * k)
		var length := size * (1.0 if k % 2 == 0 else 0.6)
		_danger_front.draw_primitive(PackedVector2Array([at + direction * length, at + direction.orthogonal() * 3.0,
				at - direction.orthogonal() * 3.0]), PackedColorArray([COLOR_COUNTER_GLINT]), PackedVector2Array())
	Shapes.disc(_danger_front, at, 4.0, Color.WHITE)


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
	# A metà caduta la sagoma schiacciata e girata può incrociarsi su sé
	# stessa e non si riempie (errore "triangulation failed"): resta il contorno.
	if not Geometry2D.triangulate_polygon(points).is_empty():
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
