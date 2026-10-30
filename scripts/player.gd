class_name Player
extends Node2D
## Personaggio giocabile. Per ora è disegnato con forme geometriche:
## verrà sostituito dagli sprite definitivi.
##
## Azioni: movimento in tutte le direzioni con accelerazione e frenata,
## attacchi consecutivi in combo sempre più potenti (R1), attacco potente
## che chiude la combo con un bonus (L2), parata tenendo premuto (L1),
## schivate concatenate con cambio di direzione (B), salti anche multipli (A),
## corsa tenendo premuto R2, palla di fuoco che insegue i nemici (X, costa
## mana), scudo che assorbe un colpo (Y), pozioni di vita (croce sinistra),
## di mana (croce destra) e di vigore (croce giù). Un tocco di L3 accende o
## spegne la corsa, tenendolo premuto si accende o spegne la torcia (vedi
## _update_run_button). Il colpo potente si
## carica tenendo premuto, fino al doppio del danno. Equipaggiamento e libri
## dell'inventario migliorano le caratteristiche (vedi Inventory).
## Parata, schivata e salto sono istantanei: annullano subito qualsiasi
## altra azione (combo, carica, attacco a terra, rinculo, sorso; non lo
## stordimento); attaccare durante una schivata la interrompe e attacca
## subito. Salti e schivate si combinano; schivando mentre si corre si fa una
## scivolata, durante la quale si può attaccare (anche in combo), schivare,
## saltare o parare. Una parata perfetta potenzia gli attacchi per qualche
## secondo.
## Con R3 si aggancia il nemico più vicino: il personaggio lo guarda sempre,
## gli attacchi e la palla di fuoco vanno verso di lui; premendo di nuovo non
## si sgancia mai, si aggancia il nemico che in quel momento è più vicino.
## L'aggancio ignora muri e ostacoli; se il bersaglio muore o si allontana
## troppo si sgancia, senza passare a un altro nemico.
## Tenendo premuto R1 si continua ad attaccare; in aria R1 fa un attacco
## aereo. Tenendo premuto il colpo potente il primo colpo si carica e, a
## carica piena (o al rilascio), i colpi potenti successivi si concatenano da
## soli finché si tiene premuto; se il primo è stato caricato, quelli
## concatenati dopo fanno danni in più. Un colpo potente subito dopo una
## combo di colpi normali (combo mista) è un colpo potente con un bonus ai
## danni. Attacchi a terra, che colpiscono tutti i nemici attorno: il colpo
## potente in aria, premuto e lasciato, fa piombare a terra con uno slam
## (costa mana e vigore); tenuto premuto, con una runa del cataclisma nella
## cintura, è la runa. Durante uno scatto in aria è un colpo più ampio.
## Durante gli attacchi a terra si passa
## attraverso i nemici; all'impatto quelli attorno (non i boss) vengono
## respinti lontano.
## Ogni colpo potente a terra consuma un po' di mana (HEAVY_MANA) e altro
## finché si tiene premuto (HEAVY_CHARGE_MANA): senza mana la carica si
## interrompe. La runa del cataclisma in carica fa fluttuare a mezz'aria ed
## espone a dardi e frecce.
## Col mouse: clic sinistro per attaccare e destro per il colpo potente
## verso il cursore, centrale (move_click) per camminarci (vedi _unhandled_input).
## Sconfiggere nemici dà esperienza; a ogni livello aumentano i danni
## base e si sceglie un potenziamento.
## Frenesia (da 0 a FRENZY_MAX): cresce a ogni colpo di spada a segno,
## anche se la guardia del nemico lo para, e cala da sola se si smette di
## attaccare per FRENZY_DECAY_DELAY secondi. Piena, L1 + R1 insieme (parata
## e attacco) scatenano l'attacco speciale (stato SPECIAL, vedi
## _start_special): i nemici si fermano, lo sfondo si scurisce attorno al
## goblin che urla avvolto da un bagliore e la telecamera si avvicina; poi
## il goblin si teletrasporta da un nemico all'altro colpendo a raffica (fino a
## max_special_hits colpi, +2 a ogni potenziamento "frenzy").

signal health_changed(current: int, maximum: int)
signal experience_changed(current: int, needed: int, level: int)
signal leveled_up(level: int)
signal died
## La Frenesia è cambiata (per l'HUD).
signal frenzy_changed(current: float, maximum: float)
## Inizio e fine dell'attacco speciale della Frenesia.
signal special_started
signal special_finished

enum State { NORMAL, ATTACK, PARRY, DODGE, SLIDE, HURT, DEAD, SLAM, FALL, RECOIL, DRINK, SPECIAL }

const RADIUS := 22.0
const START_HEALTH := 5
## Vita massima in più ogni tanti livelli, oltre ai potenziamenti: tiene
## il passo con il danno dei nemici, che cresce con il livello.
const HEALTH_LEVELS := 4
const SPEED := 220.0

## Da fermo si parte piano; più si va veloci, più si accelera.
const ACCELERATION_START := 600.0
const ACCELERATION_FULL := 2800.0
## Quando si lascia la direzione ci si ferma dopo un breve scivolamento.
const DECELERATION := 1100.0
## La direzione in cui si guarda ruota in modo continuo invece che a scatti.
const TURN_SPEED := 18.0

## Danni del primo colpo a livello 1, e aumento per ogni livello.
const BASE_DAMAGE := 10
const DAMAGE_PER_LEVEL := 3
## Ogni colpo consecutivo della combo fa questo in più (0.5 = +50%).
const COMBO_DAMAGE_STEP := 0.5
const START_COMBO_HITS := 3
## Dopo un attacco c'è questo tempo per continuare la combo.
const COMBO_WINDOW := 0.35
## Colpi normali ampi e istantanei: la carica dura appena due frame, il
## colpo arriva subito.
const ATTACK_WINDUP := 0.03
const ATTACK_ACTIVE := 0.18
const ATTACK_RECOVERY := 0.34
## Il colpo finale della combo ha un recupero più lungo.
const FINISHER_RECOVERY := 0.5
## Pausa tra la fine di un colpo normale e l'inizio del successivo della combo.
const ATTACK_CHAIN_DELAY := 0.14
## I colpi normali colpiscono sempre la stessa area davanti al personaggio.
const ATTACK_RANGE := 108.0
const ATTACK_ARC := deg_to_rad(150.0)
## Movimenti dei colpi normali a terra, a turno (ogni colpo è diverso dal
## precedente): fendente, rovescio, colpo dall'alto, affondo.
const ATTACK_STYLES := ["slash", "backhand", "chop", "thrust"]
## Rotazione del corpo che accompagna fendente e rovescio.
const ATTACK_TWIST := 0.18
const ATTACK_LUNGE_SPEED := 210.0
## Durante un attacco ci si muove a questa frazione della velocità normale.
const ATTACK_MOVE_FACTOR := 0.55

## Attacco potente: più lento, più ampio e molto più forte. In fondo a una
## combo prende anche il bonus dei colpi già fatti; chiude la combo, a
## meno che non si possano concatenare altri colpi potenti.
const HEAVY_WINDUP := 0.22
const HEAVY_ACTIVE := 0.12
const HEAVY_RECOVERY := 0.35
const HEAVY_DAMAGE_FACTOR := 2.5
## Ogni colpo potente concatenato fa questo in più del precedente.
const HEAVY_CHAIN_DAMAGE_STEP := 0.5
## Il colpo potente copre un'area più ampia dei colpi normali.
const HEAVY_RANGE := 145.0
const HEAVY_ARC := deg_to_rad(210.0)
const HEAVY_LUNGE_SPEED := 220.0
const START_HEAVY_CHAIN := 1
## Combo mista: il colpo potente che segue colpi normali fa questo in più.
const MIXED_COMBO_DAMAGE_FACTOR := 1.5
## Se il primo colpo potente della combo è stato caricato, i colpi potenti
## concatenati dopo fanno in più questa parte della carica raggiunta
## (0.5 = +50% a carica piena).
const CHARGED_CHAIN_BONUS := 0.5
## Attacco aereo: i colpi normali in aria fendono un arco più ampio,
## arrivano anche ai nemici sotto di sé fino a AIR_ATTACK_REACH e, mentre si
## colpisce, si scende più piano.
const AIR_ATTACK_ARC := deg_to_rad(200.0)
const AIR_ATTACK_REACH := 110.0
const AIR_ATTACK_GRAVITY_FACTOR := 0.45
## Attacchi a terra: il colpo potente in aria fa piombare a terra con la
## runa del cataclisma ("plunge", vedi H_BOMB_*), durante uno scatto in aria con
## un colpo di spada più ampio ("dash").
const SLAM_GRAVITY := 2600.0
## In picchiata ci si ferma un attimo in aria, poi si scende veloci.
const SLAM_HANG := 0.1
const SLAM_DIVE_SPEED := 650.0
const SLAM_RECOVERY := 0.32
## Se per qualche motivo non si tocca terra, l'impatto arriva comunque.
const SLAM_MAX_TIME := 2.0
const SLAM_RADIUS := {"dash": 165.0, "air": 135.0}
## Runa del cataclisma: il colpo potente in aria tenuto premuto, con una runa nella
## cintura (se ne portano START_H_BOMB_CAPACITY, una in più per ogni
## potenziamento "h_bomb"); senza, in aria il colpo potente non parte. La
## spada sparisce e il goblin alza sopra la testa una grossa runa del
## cataclisma (id "h_bomb");
## tenendo premuto si fluttua salendo piano (AIR_SLAM_RISE_SPEED, sempre più
## piano con la carica, con un leggero ondeggiare di AIR_SLAM_BOB pixel)
## fino a HEAVY_CHARGE_TIME, poi parte da sola; intanto si è esposti a dardi
## e frecce dei nemici (vedi receive_hit). Al rilascio (o con un tocco
## breve, senza carica) si piomba giù e si spacca la runa sul terreno:
## l'esplosione (vedi HBombBlast), larga da H_BOMB_MIN_RADIUS a
## H_BOMB_MAX_RADIUS secondo la carica, uccide i nemici attorno (al boss
## toglie H_BOMB_BOSS_DAMAGE della vita massima). Il goblin resta intatto ma
## si annerisce di fuliggine (vedi soot). La runa si consuma all'impatto:
## annullando la picchiata (parata, schivata, salto) resta nella cintura.
const START_H_BOMB_CAPACITY := 3
const H_BOMB_MIN_RADIUS := 190.0
const H_BOMB_MAX_RADIUS := 280.0
const H_BOMB_BOSS_DAMAGE := 0.5
const AIR_SLAM_RISE_SPEED := 45.0
const AIR_SLAM_BOB := 3.0
## Fuliggine dell'esplosione: il corpo si annerisce (fino a SOOT_STRENGTH
## verso COLOR_SOOT) e si pulisce in SOOT_CLEAN_TIME secondi.
const SOOT_CLEAN_TIME := 10.0
const SOOT_STRENGTH := 0.8
const COLOR_SOOT := Color(0.13, 0.12, 0.11)
## Runa tenuta sopra la testa: centro e grandezza, rispetto al centro del corpo.
const H_BOMB_HELD := Vector2(0, -RADIUS - 20.0)
const H_BOMB_LENGTH := 74.0
const DASH_SLAM_DAMAGE_FACTOR := 2.4
## Colpo potente in aria: se lo si lascia entro AIR_HEAVY_HOLD_TIME è lo
## slam ("air"), che costa AIR_SLAM_MANA di mana e STAMINA_HEAVY di
## vigore (senza, non parte) e fa AIR_SLAM_DAMAGE_FACTOR volte il danno
## base; tenuto premuto più a lungo, con una runa, è la runa. Intanto
## si resta sospesi ("pending", vedi _update_slam).
const AIR_HEAVY_HOLD_TIME := 0.15
const AIR_SLAM_MANA := 10.0
const AIR_SLAM_DAMAGE_FACTOR := 2.0
## Aggancio del bersaglio (vedi _update_lock). Automatico: il nemico vivo
## più vicino entro LOCK_RANGE che si vede, mai uno oltre un muro, un
## palazzo o un ostacolo solido (World.clear_line, ricontrollato ogni
## LOCK_SIGHT_INTERVAL secondi); si passa a un altro nemico quando è più
## vicino di almeno LOCK_SWITCH_MARGIN pixel, così con due nemici quasi
## alla stessa distanza l'aggancio non salta avanti e indietro. Manuale: R3
## aggancia il nemico più vicino che si vede e lo tiene, senza cambiare da
## solo (anche dietro un muro), finché non muore o va oltre
## LOCK_BREAK_RANGE; allora l'aggancio torna automatico. Il nemico
## agganciato si colora di rosso (Enemy.set_locked) e ha un anello rosso ai
## piedi (LockMarker). La telecamera si sposta verso il bersaglio di
## questa parte della distanza, fino a LOCK_CAMERA_MAX.
const LOCK_RANGE := 480.0
const LOCK_BREAK_RANGE := 900.0
const LOCK_SWITCH_MARGIN := 40.0
const LOCK_SIGHT_INTERVAL := 0.1
const LOCK_CAMERA_SHARE := 0.3
const LOCK_CAMERA_MAX := 170.0
## Porte nelle pareti (edifici, scale, uscite): chi ci passa davanti le
## sovrappone, ma l'ordine per altezza sullo schermo a volte le metterebbe
## davanti al giocatore; così, entro PASSAGE_REACH pixel da una porta, il
## giocatore sale di PASSAGE_Z livelli di disegno (vedi _update_passage_z).
const PASSAGES := ["cave", "stairs", "exit"]
const PASSAGE_REACH := 40.0
const PASSAGE_Z := 1
## All'impatto la telecamera trema, sempre meno.
const CAMERA_SHAKE := 9.0
const CAMERA_SHAKE_DECAY := 4.0

## Frenesia: punti per ogni colpo di spada a segno (anche parato dalla
## guardia), di più per il colpo potente e gli attacchi a terra. Dopo
## FRENZY_DECAY_DELAY secondi senza attaccare cala di FRENZY_DECAY al secondo.
const FRENZY_MAX := 100.0
const FRENZY_PER_HIT := 8.0
const FRENZY_PER_HEAVY := 14.0
const FRENZY_DECAY_DELAY := 4.0
const FRENZY_DECAY := 12.0
## Attacco speciale della Frenesia (L1 + R1 a Frenesia piena, con almeno un
## nemico entro SPECIAL_RANGE). Cinematica: per SPECIAL_INTRO_TIME secondi i
## nemici sono fermi, lo sfondo si scurisce (in SPECIAL_DARK_IN secondi,
## poi torna normale in SPECIAL_DARK_OUT) e la telecamera si avvicina di
## SPECIAL_ZOOM in SPECIAL_ZOOM_IN_TIME secondi. Poi un colpo ogni
## SPECIAL_HIT_INTERVAL secondi: ci si teletrasporta accanto al nemico più
## vicino entro SPECIAL_RANGE e lo si colpisce finché non muore, poi si passa
## al successivo; senza nemici a tiro la raffica finisce. Alla fine la
## telecamera torna com'era in SPECIAL_ZOOM_OUT_TIME e si resta
## invulnerabili per SPECIAL_END_INVULNERABLE secondi.
const START_SPECIAL_HITS := 10
const SPECIAL_HITS_UPGRADE := 2
const SPECIAL_RANGE := 520.0
const SPECIAL_DAMAGE_FACTOR := 1.6
const SPECIAL_INTRO_TIME := 1.1
const SPECIAL_DARK_IN := 0.15
const SPECIAL_DARK_HOLD := 0.65
const SPECIAL_DARK_OUT := 0.3
const SPECIAL_ZOOM := 1.4
const SPECIAL_ZOOM_IN_TIME := 0.6
const SPECIAL_ZOOM_OUT_TIME := 0.45
const SPECIAL_HIT_INTERVAL := 0.13
## Distanza tra il bordo del nemico e quello del goblin dopo il teletrasporto.
const SPECIAL_GAP := 6.0
const SPECIAL_END_INVULNERABLE := 0.6
const COLOR_FRENZY := Color(1.0, 0.18, 0.12)

## Mentre si para ci si muove più lentamente.
const PARRY_SPEED_FACTOR := 0.35
## La parata copre i colpi che arrivano entro questo angolo dal davanti.
const PARRY_ARC := deg_to_rad(140.0)
## Una parata iniziata appena prima del colpo stordisce il nemico
## e potenzia gli attacchi.
const PERFECT_PARRY_WINDOW := 0.2

## Bonus della parata perfetta: attacchi più forti e più rapidi.
const EMPOWER_TIME := 4.0
const EMPOWER_DAMAGE_FACTOR := 2.0
const EMPOWER_ATTACK_SPEED := 1.7

const DODGE_SPEED := 620.0
const DODGE_TIME := 0.28
const DODGE_INVULNERABLE_TIME := 0.24
## Premendo di nuovo durante una schivata (o subito dopo) se ne concatena
## un'altra, fino al numero massimo di schivate.
const START_CHAINED_DODGES := 1
const DODGE_CHAIN_MIN_TIME := 0.04
const DODGE_CHAIN_GRACE := 0.15
## All'inizio di ogni schivata la direzione segue ancora la levetta, così
## cambiare direzione è facile anche premendo un attimo prima di girarla.
const DODGE_STEER_TIME := 0.1
## Poi la schivata curva verso la direzione della levetta a questa velocità.
const DODGE_TURN_RATE := 10.0
## Per la direzione delle schivate basta inclinare poco la levetta.
const DODGE_STICK_DEADZONE := 0.2
const DODGE_COOLDOWN := 0.4

## Corsa (L3): molto più veloce del passo normale. Ogni
## potenziamento aggiunge il 5% alla velocità di corsa.
const RUN_SPEED_FACTOR := 2.25
const RUN_SPEED_UPGRADE := 0.05

## Scivolata: schivando mentre si corre si scivola in avanti, rallentando.
const SLIDE_TIME := 0.55
const SLIDE_SPEED_FACTOR := 1.35
const SLIDE_INVULNERABLE_TIME := 0.25

## Salto: serve per salire sui blocchi più alti del terreno (vedi World)
## e in aria gli attacchi dei nemici passano sotto. Si parte con un salto;
## i potenziamenti permettono salti consecutivi in aria.
const JUMP_SPEED := 480.0
## In aria la velocità orizzontale scende a questa parte.
const AIR_SPEED_FACTOR := 0.85
const GRAVITY := 1800.0
## A terra la schivata è una capriola; in aria è uno scatto nella direzione
## di movimento, durante il quale si scende più piano.
const AIR_DODGE_GRAVITY_FACTOR := 0.3
const ROLL_CURL := 0.45
const AIR_DASH_TRAIL := 3
## Sopra questa altezza i colpi dei nemici non arrivano.
const JUMP_EVADE_HEIGHT := 18.0
## Colpi dati e ricevuti arrivano solo tra chi sta più o meno alla stessa
## altezza (per esempio non a un nemico sul gradino di sotto).
const HIT_HEIGHT_REACH := 40.0
## La telecamera segue con dolcezza l'altezza del terreno e anticipa un
## poco la direzione di movimento.
const CAMERA_HEIGHT_FOLLOW := 6.0
const CAMERA_SMOOTHING := 7.0
const CAMERA_LOOK_AHEAD := 0.18
const CAMERA_LOOK_AHEAD_MAX := 70.0
const CAMERA_LOOK_AHEAD_FOLLOW := 2.5
## Il corpo si inclina nella direzione di corsa e si schiaccia atterrando.
const LEAN_ANGLE := 0.12
const SQUASH_AMOUNT := 0.22
const SQUASH_RECOVERY := 5.0
const START_JUMPS := 1

## Mana (carburante): serve per missili e colpi potenti e non si ricarica
## da solo, solo con le taniche.
const START_MANA := 60.0
const MANA_UPGRADE := 20.0
const MANA_POTION_RESTORE := 40.0
const START_MANA_POTIONS := 1
## Palla di fuoco: costo, attesa tra un lancio e l'altro, danni (crescono
## con il livello e con i potenziamenti della magia, +20% ciascuno).
const SPELL_COST := 20.0
const SPELL_COOLDOWN := 0.45
const FIREBALL_DAMAGE := 18
const FIREBALL_DAMAGE_PER_LEVEL := 4
const SPELL_UPGRADE := 0.2

## Tenendo premuto il colpo potente si carica: in questo tempo arriva al
## massimo, che raddoppia il danno.
const HEAVY_CHARGE_TIME := 0.9
## Ogni colpo potente consuma mana per ogni secondo in cui si tiene premuto
## il tasto (carica compresa, a terra e in aria): senza mana la carica si
## interrompe e il colpo parte con quella raggiunta (senza mana non si carica).
const HEAVY_CHARGE_MANA := 20.0
## Mana consumato da ogni colpo potente a terra, anche senza caricarlo
## (senza mana il colpo parte lo stesso).
const HEAVY_MANA := 4.0
const COLOR_CHARGE_GLOW := Color(0.55, 0.8, 1.0)

## Mouse: il tasto di "move_click" (centrale) fa camminare verso il punto
## del terreno sotto il cursore (tenendolo premuto lo si segue); ci si ferma
## entro CLICK_ARRIVE_DISTANCE o se si resta bloccati per CLICK_STUCK_TIME.
## Gli attacchi partiti con un tasto del mouse (il sinistro è l'attacco,
## il destro il colpo potente) vanno verso il cursore.
const CLICK_ARRIVE_DISTANCE := 10.0
const CLICK_STUCK_TIME := 0.4

## Torcia: un fascio di luce a cono nella direzione dello sguardo (vedi
## Flashlight), accesa e spenta tenendo premuto L3 (o Maiusc) per
## TORCH_HOLD_TIME secondi; un tocco più breve è la corsa.
const TORCH_HOLD_TIME := 0.45
## Con la torcia accesa e il fascio almeno così forte (vedi
## Flashlight.strength) il personaggio è disegnato con i colori del giorno.
const TORCH_SELF_LIGHT := 0.5

## Ogni pozione cura questi punti vita.
const POTION_HEAL := 3
## Pozioni di vita (e di mana e di vigore) che si possono portare; ogni
## potenziamento "potion_slots" ne aggiunge una di ciascun tipo.
const MAX_POTIONS := 10
## Potenziamenti delle pozioni: +1 punto vita curato, +5% di mana ridato.
const POTION_HEAL_UPGRADE := 1
const MANA_RESTORE_UPGRADE := 0.05
const START_POTIONS := 2
## Pozioni verdi (vigore) di partenza; quanto vigore ridanno sta in
## data/items.json ("restore_stamina", parte del vigore massimo).
const START_STAMINA_POTIONS := 1
## Lo scudo assorbe un colpo; poi va ricaricato. Ogni potenziamento
## riduce la ricarica del 5%.
const SHIELD_COOLDOWN := 30.0
const SHIELD_COOLDOWN_UPGRADE := 0.95

## Rimbalzo contro ostacoli e pareti: solo sopra BOUNCE_MIN_SPEED verso
## l'ostacolo, con una parte della velocità d'urto (al massimo BOUNCE_MAX_SPEED).
const BOUNCE_MIN_SPEED := 200.0
const BOUNCE_FACTOR := 0.45
const BOUNCE_MAX_SPEED := 180.0
## I nemici sono solidi: non ci si passa attraverso (si salta sopra solo
## più in alto di JUMP_EVADE_HEIGHT, e durante gli attacchi a terra si
## ignorano). Andarci addosso non fa danni.
## All'impatto dell'attacco a terra i nemici entro il raggio più questo
## margine (non i boss) vengono respinti a questa velocità.
const SLAM_PUSH_MARGIN := 70.0
const SLAM_PUSH_SPEED := 700.0

## Colpo parato dalla guardia di un nemico: la combo si interrompe e si
## viene respinti indietro per REPEL_TIME secondi (schivata e parata restano
## possibili).
const REPEL_SPEED := 420.0
const REPEL_TIME := 0.35
const COLOR_GUARD_SPARK := Color(0.8, 0.9, 1.0)

## Vigore (stamina): attacchi, schivate, scivolate, salti e colpi parati lo
## consumano, la corsa lo consuma finché dura; si ricarica dopo un attimo
## di pausa (più piano mentre si para). Senza vigore non si agisce e un
## colpo parato rompe la guardia.
const MAX_STAMINA := 100.0
## Ogni potenziamento della stamina aggiunge il 10% della stamina di partenza.
const STAMINA_UPGRADE := 0.1
const STAMINA_REGEN := 45.0
const STAMINA_REGEN_DELAY := 0.55
const STAMINA_PARRY_REGEN_FACTOR := 0.35
const STAMINA_ATTACK := 12.0
const STAMINA_HEAVY := 32.0
const STAMINA_DODGE := 28.0
const STAMINA_JUMP := 12.0
## Aura bianca della modalità focus: altezza del centro e raggio rispetto
## al raggio del corpo, colore.
const FOCUS_AURA_HEIGHT := 0.6
const FOCUS_AURA_RADIUS := 2.6
const COLOR_FOCUS_AURA := Color(1, 1, 1, 0.5)
## Curva dell'esperienza (vedi experience_for): punti per il livello 2,
## aumento lineare e quadratico per livello.
const XP_CURVE_BASE := 40.0
const XP_CURVE_STEP := 25.0
const XP_CURVE_QUAD := 2.5
## Curva della versione 2 (a tratti), per convertire i salvataggi.
const XP_CURVE_FAST_LEVELS := 10
const XP_CURVE_LATE := 32.0
## Versione della curva salvata con l'esperienza (1: lineare, 2: a tratti,
## 3: quadratica continua).
const XP_CURVE_VERSION := 3
const STAMINA_BLOCK := 30.0
const STAMINA_RUN := 16.0
## Guardia rotta: si resta storditi per questo tempo.
const GUARD_BREAK_TIME := 0.8
## Bere una pozione richiede tempo: ci si muove piano e non si può fare
## altro. L'effetto arriva subito, all'inizio del sorso; la fiaschetta
## sale alla bocca in DRINK_EFFECT_TIME.
const DRINK_TIME := 0.95
const DRINK_EFFECT_TIME := 0.6
const DRINK_SPEED_FACTOR := 0.3

const HURT_TIME := 0.25
const HURT_KNOCKBACK := 420.0
## Dopo un colpo si resta invulnerabili per HURT_INVULNERABLE_TIME secondi
## (vedi _start_invulnerability), lampeggiando: un'opacità ogni
## INVULNERABLE_BLINK secondi, che scende fino a INVULNERABLE_ALPHA.
const HURT_INVULNERABLE_TIME := 0.8
const INVULNERABLE_BLINK := 0.08
const INVULNERABLE_ALPHA := 0.35

## Gambe: il corpo sta sopra di LEG_LENGTH; i passi seguono la velocità.
## Corte e larghe: le gambe sono distanti LEG_SPACING dal centro e spesse LEG_WIDTH.
const LEG_LENGTH := 11.0
const LEG_SPACING := 9.0
const LEG_WIDTH := 7.0
const WALK_CYCLE := 0.08
const STRIDE := 7.0
## Spada: lunghezza e larghezza della lama (il colpo potente usa una spada più grande).
const SWORD_LENGTH := 46.0
const HEAVY_SWORD_LENGTH := 58.0
const SWORD_WIDTH := 5.0

const COLOR_BODY := Color(0.35, 0.75, 0.4)
## Sangue sul corpo (vedi BodyBlood): ogni nemico ucciso sporca il corpo di
## BLOOD_PER_KILL e ogni ferita di BLOOD_PER_WOUND (fino a 1), che poi si
## pulisce (BLOOD_CLEAN al secondo: da sporco del tutto a pulito in 40
## secondi). Il corpo si tinge di rosso e compaiono via via fino a
## BLOOD_SPOTS schizzi.
## Gocce di sangue che schizzano a ogni colpo ricevuto.
const BLEED_DROPS := 12
const BLOOD_PER_KILL := 0.15
const BLOOD_PER_WOUND := 0.12
const BLOOD_CLEAN := 0.025
const BLOOD_SPOTS := 9
## Pozza di sangue che resta a terra quando muore (vedi GroundFx.pool).
const DEATH_POOL := 64.0
## Tono della voce del goblin (vedi Voice): stridula, più acuta della media.
const VOICE_TONE := 1.25
## Burroni: cadendoci si precipita per FALL_TIME secondi, poi si riappare
## sul bordo (l'ultimo punto sicuro) perdendo vita (data/world.json). Si
## cade quando si scende sotto il bordo di FALL_DEPTH pixel.
const FALL_TIME := 0.8
const FALL_DEPTH := 48.0
const COLOR_HURT := Color(0.95, 0.35, 0.3)
const COLOR_DEAD := Color(0.4, 0.4, 0.4)
const COLOR_SLASH := Color(1.0, 1.0, 0.85)
const COLOR_HEAVY := Color(1.0, 0.5, 0.2)
const COLOR_EMPOWERED := Color(1.0, 0.8, 0.25)
const COLOR_HEAL := Color(0.5, 1.0, 0.5)
const COLOR_BUBBLE := Color(0.55, 0.85, 1.0)
const COLOR_MANA := Color(0.45, 0.65, 1.0)
const COLOR_FLAME := Color(1.0, 0.6, 0.2)
const COLOR_HEALTH_FLASK := Color(0.9, 0.2, 0.25)
const COLOR_MANA_FLASK := Color(0.3, 0.5, 1.0)
const COLOR_STAMINA_FLASK := Color(0.3, 0.85, 0.3)

var max_health := START_HEALTH
## Vita massima senza l'equipaggiamento (cresce con i potenziamenti).
var _base_max_health := START_HEALTH
var mana := START_MANA
var max_mana := START_MANA
var _base_max_mana := START_MANA
## Pozioni nella cintura: non hanno limite.
var mana_potions := START_MANA_POTIONS
var stamina_potions := START_STAMINA_POTIONS
## Rune del cataclisma (h_bomb) nella cintura (vedi h_bomb_capacity).
var h_bombs := 0
## Fuliggine sul corpo dopo l'esplosione di una runa (da 0 a 1).
var soot := 0.0
## Bonus alla potenza della magia dai potenziamenti (0.2 = +20%).
var spell_bonus := 0.0
var inventory := Inventory.new()
var torch_on := false
var health := START_HEALTH
var level := 1
var experience := 0
var max_combo_hits := START_COMBO_HITS
var max_heavy_chain := START_HEAVY_CHAIN
var max_chained_dodges := START_CHAINED_DODGES
var max_jumps := START_JUMPS
## Bonus alla velocità di corsa (0.02 = +2%).
var run_speed_bonus := 0.0
var potions := START_POTIONS
var shield_cooldown_max := SHIELD_COOLDOWN
## Ricarica dello scudo rimasta, e se lo scudo è attivo in questo momento.
var shield_cooldown := 0.0
var shield_active := false
var facing := Vector2.RIGHT

var _state := State.NORMAL
@onready var _camera: Camera2D = get_node_or_null("Camera")
var _state_time := 0.0
var _velocity := Vector2.ZERO
var _target_facing := Vector2.RIGHT
var _dodge_direction := Vector2.RIGHT
var _dodges_used := 0
var _dodge_cooldown := 0.0
## Dopo una schivata resta un attimo per concatenarne un'altra.
var _dodge_chain_grace := 0.0
## Invulnerabilità dopo un colpo: finché il timer corre si ignorano altri
## danni e il personaggio lampeggia (_invulnerable_blink).
var _invulnerable_timer := Timer.new()
var _invulnerable_blink: Tween
## Colpi normali e colpi potenti della combo in corso, e tempo rimasto per continuarla.
var _combo_step := 0
var _heavy_step := 0
var _combo_timer := 0.0
## Attacco in corso: normale o potente.
var _attack_heavy := false
## Attacco premuto durante quello in corso: "", "attack" o "heavy".
var _queued_attack := ""
var _attack_resolved := false
## Velocità dell'attacco in corso: resta quella con cui è iniziato.
var _attack_speed := 1.0
var stamina := MAX_STAMINA
## Stamina massima: si ricalcola dai potenziamenti presi (non si salva).
var max_stamina := MAX_STAMINA
var _stamina_delay := 0.0
## Si sta correndo (consuma vigore).
var _running := false
## Pozione che si sta bevendo ("potion", "mana_potion" o "stamina_potion").
var _drinking := ""
## Corsa accesa (si alterna premendo "run").
var _run_on := false
## Stordimento dopo una guardia rotta (si usa lo stato HURT, più lungo).
var _hurt_time := HURT_TIME
## C'è un elemento con cui interagire qui vicino (lo decide Game).
var can_interact := false
## Cresce a ogni attacco di spada (non gli attacchi a terra): i nemici lo
## guardano per decidere se alzare la guardia (vedi Enemy).
var attack_serial := 0
## L'attacco in corso è partito in aria (attacco aereo).
var _air_attack := false
## Movimento del colpo normale in corso (indice in ATTACK_STYLES).
var _attack_style := 0
var _empowered_time := 0.0
var _block_flash := 0.0
## Altezza da terra durante i salti e velocità verticale.
var _height := 0.0
var _height_velocity := 0.0
var _jumps_used := 0
var _slide_direction := Vector2.RIGHT
var _slide_speed := 0.0
## Slancio che resta quando si attacca durante una scivolata.
var _carry_velocity := Vector2.ZERO
## Movimento durante l'attacco, senza l'affondo del colpo.
var _walk_velocity := Vector2.ZERO
## Verso del fendente in corso (+1 o -1): cambia a ogni attacco.
var _swing_sign := 1.0
## Fase del passo per l'animazione delle gambe.
var _walk_phase := 0.0
## Schiacciamento dopo un atterraggio (0-1) e anticipo della telecamera.
var _squash := 0.0
var _look_ahead := Vector2.ZERO
var _camera_height := 0.0
var _spell_cooldown := 0.0
## La schivata in corso è uno scatto in aria (altrimenti è una capriola).
var _air_dash := false
## Attacco a terra in corso: "plunge" o "dash", e se ha già toccato terra.
var _slam_kind := ""
var _slam_landed := false
## Altezza da cui parte la picchiata e se lo slam aereo è stato caricato.
## Da quanto si tiene premuto L3 (-1: tasto non premuto o già usato).
var _run_hold := -1.0
## Tremolio della telecamera (0-1).
var _shake := 0.0
## Ultimo punto a terra fuori dai burroni e la sua altezza: si riappare lì.
var _safe_position := Vector2.ZERO
var _safe_altitude := 0.0
## Nemico agganciato (null se nessuno, vedi _update_lock), se l'ha scelto
## il giocatore con R3 (manuale) e il suo anello rosso.
var lock_target: Enemy
var lock_manual := false
var _lock_marker := LockMarker.new()
var _lock_sight_time := 0.0
## Quanto è sporco di sangue (0-1), con gli schizzi sul corpo, e le ferite
## temporanee dei colpi ricevuti.
var blood_stain: float:
	get:
		return _blood.amount
	set(value):
		_blood.amount = value
var _blood := BodyBlood.new(0, BLOOD_SPOTS, BLOOD_CLEAN)
var _wounds := Wounds.new()
var _voice := Voice.new()
## Carica del colpo potente (0-1) e se il tasto è ancora tenuto premuto.
var _charge := 0.0
var _charging := false
## Carica raggiunta dal primo colpo potente della combo: dà il bonus ai
## colpi potenti concatenati dopo (vedi CHARGED_CHAIN_BONUS).
var _chain_charge := 0.0
## Il suono del colpo potente parte al rilascio della carica, una volta sola.
var _heavy_swing_played := false
## Tempo passato in carica (per l'animazione della magia sulla spada).
var _charge_time := 0.0
## Movimento col mouse: in corso, punto del terreno da raggiungere e da
## quanto si è bloccati.
var _click_moving := false
var _click_target := Vector2.ZERO
var _click_stuck := 0.0
## L'attacco è partito con un tasto del mouse: si mira al cursore finché
## lo si tiene premuto; direzione verso il cursore (zero se non si mira).
var _aim_cursor := false
var _aim := Vector2.ZERO
var _torch := Flashlight.new()
## Potenziamento -> quante volte è stato scelto, nell'ordine di scelta.
var upgrades_taken := {}
## Frenesia (0-FRENZY_MAX, non si salva) e da quanto non si attacca.
var frenzy := 0.0
var _frenzy_idle := 0.0
## Colpi dell'attacco speciale (si ricalcola dai potenziamenti "frenzy").
var max_special_hits := START_SPECIAL_HITS
## Attacco speciale in corso: colpi già dati, nemico che si sta colpendo,
## da dove ci si è teletrasportati all'ultimo colpo (rispetto alla posizione
## attuale, per la scia), buio dello sfondo (0-1, vedi special_darkness) e
## zoom della telecamera da ripristinare alla fine.
var _special_hits := 0
var _special_target: Enemy
var _special_from := Vector2.ZERO
var _special_last_hit := 0.0
var _special_dark := 0.0
var _special_zoom := Vector2.ONE
var _zoom_tween: Tween
## Altezza del terreno sotto il personaggio (vedi World.elevation_at).
var ground_elevation := 0.0


func _ready() -> void:
	# In modalità focus il giocatore resta a colori, con un'aura bianca.
	add_to_group(LowHealthVignette.FOCUS_GROUP)
	if not _lock_marker.is_inside_tree():
		add_child(_lock_marker)
	if not _torch.is_inside_tree():
		_torch.enabled = torch_on
		_torch.aim(facing)
		add_child(_torch)
	if not _voice.is_inside_tree():
		_voice.tone = VOICE_TONE
		add_child(_voice)
	if not _invulnerable_timer.is_inside_tree():
		_invulnerable_timer.one_shot = true
		_invulnerable_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
		_invulnerable_timer.timeout.connect(_end_invulnerability)
		add_child(_invulnerable_timer)
	if World.current:
		ground_elevation = World.current.elevation_at(position)
	_safe_position = position
	_safe_altitude = ground_elevation
	if _camera:
		_camera_height = -ground_elevation
		_camera.position = Vector2(0, _camera_height)
		_camera.position_smoothing_enabled = true
		_camera.position_smoothing_speed = CAMERA_SMOOTHING
		_camera.reset_smoothing()


func _physics_process(delta: float) -> void:
	_state_time += delta
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	_dodge_chain_grace = maxf(_dodge_chain_grace - delta, 0.0)
	_empowered_time = maxf(_empowered_time - delta, 0.0)
	_block_flash = maxf(_block_flash - delta, 0.0)
	soot = maxf(soot - delta / SOOT_CLEAN_TIME, 0.0)
	_combo_timer = maxf(_combo_timer - delta, 0.0)
	shield_cooldown = maxf(shield_cooldown - delta, 0.0)
	_spell_cooldown = maxf(_spell_cooldown - delta, 0.0)
	_stamina_delay = maxf(_stamina_delay - delta, 0.0)
	if _stamina_delay == 0.0 and not _running and _state != State.DEAD:
		var regen := STAMINA_REGEN * (STAMINA_PARRY_REGEN_FACTOR if _state == State.PARRY else 1.0)
		stamina = minf(stamina + regen * delta, max_stamina)
	# Senza attaccare per un po' la Frenesia cala.
	if _state != State.SPECIAL:
		_frenzy_idle += delta
		if _frenzy_idle >= FRENZY_DECAY_DELAY and frenzy > 0.0:
			_set_frenzy(frenzy - FRENZY_DECAY * delta)

	# I tasti si leggono con UiNav.game_pressed / game_held: quello che ha
	# appena chiuso un menù (A su Riprendi, B) non conta finché non si rilascia.
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dodge_input := Input.get_vector("move_left", "move_right", "move_up", "move_down", DODGE_STICK_DEADZONE)
	# Tastiera e levetta hanno la precedenza sul movimento col mouse.
	if input != Vector2.ZERO:
		_click_moving = false
	else:
		input = _click_input(delta)
		if dodge_input == Vector2.ZERO:
			dodge_input = input
	_update_aim()
	# Gli attacchi col mouse partono verso il cursore.
	var attack_input := _aim if _aim != Vector2.ZERO else input

	if _state not in [State.DEAD, State.HURT, State.SPECIAL]:
		if UiNav.game_pressed("potion"):
			_start_drink("potion")
		if UiNav.game_pressed("shield"):
			_raise_shield()
		if UiNav.game_pressed("mana_potion"):
			_start_drink("mana_potion")
		if UiNav.game_pressed("stamina_potion"):
			_start_drink("stamina_potion")
		if UiNav.game_pressed("spell"):
			_cast_fireball(input)
	if _state != State.DEAD:
		if UiNav.game_pressed("lock_on"):
			_lock_manually()
		_update_lock(delta)
		_update_passage_z()
		_update_run_button(delta)

	# Frenesia piena: L1 + R1 insieme (parata e attacco, in qualsiasi ordine)
	# scatenano l'attacco speciale, annullando l'azione in corso.
	if UiNav.game_chord("parry", "attack") and _can_start_special():
		_start_special()
	# La parata è istantanea: annulla subito attacchi (anche in carica),
	# schivate, scivolate, attacchi a terra, rinculo e il bere.
	elif UiNav.game_pressed("parry") and _state in [State.NORMAL, State.ATTACK, State.DODGE,
			State.SLIDE, State.SLAM, State.RECOIL, State.DRINK]:
		_start_parry(input)
	# Allo stesso modo schivata e salto annullano subito attacchi (anche in
	# carica), attacchi a terra, parata, rinculo e il bere (se c'è vigore; in
	# NORMAL, DODGE e SLIDE si gestiscono più sotto).
	elif _state in [State.ATTACK, State.SLAM, State.PARRY, State.RECOIL, State.DRINK]:
		if UiNav.game_pressed("dodge") and stamina > 0.0:
			_interrupt_action()
			_start_dodge(dodge_input)
		elif _jump_pressed() and _can_jump():
			_interrupt_action()
			_change_state(State.NORMAL)
			_jump()

	match _state:
		State.NORMAL:
			if input != Vector2.ZERO:
				_target_facing = input.normalized()
			_face_lock()
			# La corsa si accende e si spegne con un tocco di L3 (o Maiusc, vedi
			# _update_run_button); si spegne da sola fermandosi.
			if input == Vector2.ZERO:
				_run_on = false
			var running := _run_on and stamina > 0.0 and not is_airborne()
			_running = running
			if running:
				stamina = maxf(stamina - STAMINA_RUN * delta, 0.0)
				_stamina_delay = STAMINA_REGEN_DELAY
			# In aria si avanza un po' più piano: il salto porta meno lontano.
			var air := AIR_SPEED_FACTOR if is_airborne() else 1.0
			_velocity = _accelerate(_velocity, input * (run_speed() if running else walk_speed()) * air, delta)
			if _jump_pressed():
				_jump()
			if UiNav.game_pressed("dodge"):
				if running and not is_airborne():
					_start_slide(input)
				elif _dodge_chain_grace > 0.0 and _dodges_used < max_chained_dodges:
					_chain_dodge(dodge_input)
				elif _dodge_cooldown == 0.0:
					_start_dodge(dodge_input)
			elif UiNav.game_pressed("heavy_attack"):
				_start_heavy(attack_input)
			elif UiNav.game_pressed("attack") or UiNav.game_held("attack"):
				# Tenendo premuto si continua ad attaccare (anche un tocco rapidissimo
				# conta); in aria è un attacco aereo.
				_start_attack(_next_combo_step(), attack_input)
			elif UiNav.game_held("parry"):
				_start_parry(input)

		State.ATTACK:
			# Un attacco iniziato si interrompe con parata, schivata o salto;
			# si può concatenare il successivo.
			_running = false
			_update_attack(input, attack_input, delta)

		State.PARRY:
			if input != Vector2.ZERO:
				_target_facing = input.normalized()
			_face_lock()
			_velocity = _accelerate(_velocity, input * walk_speed() * PARRY_SPEED_FACTOR, delta)
			if not UiNav.game_held("parry"):
				_change_state(State.NORMAL)

		State.DODGE:
			# A terra la schivata non si interrompe. Durante lo scatto in aria il
			# colpo potente fa piombare a terra con un colpo ampio, quello
			# normale è un attacco aereo.
			_running = false
			if is_airborne() and _air_dash and UiNav.game_pressed("heavy_attack"):
				_end_combo()
				_start_slam("dash", input)
			elif is_airborne() and UiNav.game_pressed("attack"):
				_end_combo()
				_start_attack(1, attack_input)
			elif UiNav.game_pressed("dodge") and _dodges_used < max_chained_dodges \
					and _state_time >= DODGE_CHAIN_MIN_TIME:
				_chain_dodge(dodge_input)
			elif _jump_pressed():
				# Salto e schivata si combinano: la schivata continua in aria come scatto.
				_jump()
				_air_dash = true
			elif dodge_input != Vector2.ZERO:
				# La schivata segue la levetta per tutta la sua durata: subito
				# all'inizio, poi curvando verso la nuova direzione.
				var wanted := dodge_input.normalized()
				if _state_time <= DODGE_STEER_TIME:
					_dodge_direction = wanted
				else:
					_dodge_direction = Vector2.from_angle(lerp_angle(_dodge_direction.angle(), wanted.angle(), minf(DODGE_TURN_RATE * delta, 1.0)))
				_target_facing = _dodge_direction
			if _state == State.DODGE:
				# Scatto rapido che rallenta verso la fine.
				var t := _state_time / DODGE_TIME
				_velocity = _dodge_direction * DODGE_SPEED * (1.0 - t * t)
				if _state_time >= DODGE_TIME:
					_dodge_cooldown = DODGE_COOLDOWN
					_dodge_chain_grace = DODGE_CHAIN_GRACE
					_change_state(State.NORMAL)

		State.SLIDE:
			# Durante la scivolata si può attaccare (continuando la combo),
			# schivare, saltare o parare (vedi sopra): la scivolata si interrompe.
			if UiNav.game_pressed("attack"):
				_carry_velocity = _velocity
				_start_attack(_next_combo_step(), attack_input)
			elif UiNav.game_pressed("heavy_attack"):
				_carry_velocity = _velocity
				_start_heavy(attack_input)
			elif UiNav.game_pressed("dodge") and _dodge_cooldown == 0.0:
				_start_dodge(dodge_input)
			elif _jump_pressed():
				_change_state(State.NORMAL)
				_jump()
			else:
				var t := _state_time / SLIDE_TIME
				_velocity = _slide_direction * _slide_speed * (1.0 - 0.7 * t)
				if _state_time >= SLIDE_TIME:
					_change_state(State.NORMAL)

		State.SLAM:
			_update_slam(input, attack_input, delta)

		State.SPECIAL:
			_running = false
			_update_special()

		State.RECOIL:
			_velocity = _velocity.move_toward(Vector2.ZERO, DECELERATION * 1.5 * delta)
			if _state_time >= REPEL_TIME:
				_change_state(State.NORMAL)

		State.FALL:
			_velocity = _velocity.move_toward(Vector2.ZERO, DECELERATION * delta)
			if _state_time >= FALL_TIME:
				_climb_out_of_ravine()

		State.HURT:
			_velocity = _velocity.move_toward(Vector2.ZERO, HURT_KNOCKBACK * 4.0 * delta)
			if _state_time >= _hurt_time:
				_hurt_time = HURT_TIME
				_change_state(State.NORMAL)

		State.DRINK:
			# Si beve: ci si muove piano e non si fa altro finché non si finisce
			# (parata, schivata e salto interrompono il sorso).
			_running = false
			if input != Vector2.ZERO:
				_target_facing = input.normalized()
			_velocity = _accelerate(_velocity, input * walk_speed() * DRINK_SPEED_FACTOR, delta)
			if _state_time >= DRINK_TIME:
				_drinking = ""
				_change_state(State.NORMAL)

		State.DEAD:
			_velocity = Vector2.ZERO

	# Rotazione continua verso la direzione voluta.
	if _state != State.DEAD:
		var angle := facing.angle()
		var target := _target_facing.angle()
		facing = Vector2.from_angle(angle + clampf(angle_difference(angle, target), -TURN_SPEED * delta, TURN_SPEED * delta))

	_update_height(delta)
	_move(delta)
	_walk_phase += _velocity.length() * delta * WALK_CYCLE
	_blood.update(delta)
	_wounds.update(delta)
	if torch_on:
		# Il fascio parte dal terreno in pianta, sotto il personaggio, verso lo sguardo.
		_torch.position = Vector2(0, RADIUS * 0.6)
		_torch.aim(facing)
	update_torch_light()
	_squash = move_toward(_squash, 0.0, SQUASH_RECOVERY * delta)
	if _camera:
		# Mentre si precipita nel burrone la telecamera resta al bordo.
		if _state != State.FALL:
			_camera_height = lerpf(_camera_height, -ground_elevation, minf(CAMERA_HEIGHT_FOLLOW * delta, 1.0))
		var ahead := (_velocity * CAMERA_LOOK_AHEAD).limit_length(CAMERA_LOOK_AHEAD_MAX)
		if lock_target:
			# Agganciato: la telecamera tiene in vista anche il bersaglio.
			ahead = ((lock_target.global_position - global_position) * LOCK_CAMERA_SHARE).limit_length(LOCK_CAMERA_MAX)
		_look_ahead = _look_ahead.lerp(ahead, minf(CAMERA_LOOK_AHEAD_FOLLOW * delta, 1.0))
		_camera.position = Vector2(0, _camera_height) + _look_ahead
		# Il tremolio va sullo scostamento, che non viene ammorbidito.
		_shake = move_toward(_shake, 0.0, CAMERA_SHAKE_DECAY * delta)
		_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * CAMERA_SHAKE * _shake * _shake
	queue_redraw()


## Spostamento nel mondo: si sale sui blocchi più alti solo saltando
## abbastanza in alto, si scende dai gradini cadendo; gli ostacoli solidi
## fermano il personaggio, i cespugli lo rallentano (ma non durante
## schivate e scivolate).
func _move(delta: float) -> void:
	var world := World.current
	if world == null:
		position += _velocity * delta
		return
	var motion := _velocity * delta
	var grounded := not is_airborne()
	if grounded and _state != State.DODGE and _state != State.SLIDE:
		motion *= world.slow_at(position, RADIUS)
	var altitude := world.elevation_at(position) + _height
	var start := position
	position = world.move(position, motion, RADIUS * 0.8, _height, true)
	ground_elevation = world.elevation_at(position)
	# Una luce bianca nel punto in cui si tocca quello che blocca il
	# movimento (ostacoli, blocchi di terreno troppo alti da salire) e,
	# sbattendoci contro, un piccolo rimbalzo.
	world.highlight_contacts(position, RADIUS * 0.8, altitude)
	_bounce(motion - (position - start), delta)
	_collide_enemies(world)
	# L'altezza dal terreno cambia con il terreno sotto: scendendo da un
	# gradino si cade, salendo su un blocco si atterra sopra.
	_height = altitude - ground_elevation
	if (grounded and absf(_height) <= World.STEP_TOLERANCE) or _height < 0.0:
		_height = 0.0
		if _height_velocity <= 0.0:
			_land()
	# Burroni: chi scende sotto il bordo precipita; a terra altrove si
	# ricorda il punto sicuro per riapparire.
	if world.kind_of(World.cell_at(position)) == World.Kind.RAVINE:
		if _state not in [State.FALL, State.DEAD] and altitude() < _safe_altitude - FALL_DEPTH:
			_fall_into_ravine()
	elif not is_airborne():
		_safe_position = position
		_safe_altitude = ground_elevation


## Urto: la parte del movimento fermata da un ostacolo o da una parete fa
## rimbalzare indietro di poco, se ci si andava contro abbastanza veloci
## (così spingendo contro un muro non si rimbalza di continuo).
func _bounce(blocked: Vector2, delta: float) -> void:
	if _state != State.NORMAL or delta <= 0.0:
		return
	var impact := blocked.length() / delta
	if impact < BOUNCE_MIN_SPEED:
		return
	var away := -blocked / blocked.length()
	_velocity += away * (maxf(_velocity.dot(-away), 0.0) + minf(impact * BOUNCE_FACTOR, BOUNCE_MAX_SPEED))


## Spinge fuori dai nemici vivi alla stessa quota, senza danni: la parte
## della velocità diretta contro il nemico si annulla. Durante gli attacchi a
## terra e l'attacco speciale si passa attraverso i nemici.
func _collide_enemies(world: World) -> void:
	if _state in [State.DEAD, State.FALL, State.SLAM, State.SPECIAL]:
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead() or absf(enemy.ground_elevation - ground_elevation) > HIT_HEIGHT_REACH \
				or altitude() - enemy.ground_elevation > JUMP_EVADE_HEIGHT:
			continue
		var offset := position - enemy.position
		var minimum := RADIUS + enemy.radius
		var distance := offset.length()
		if distance >= minimum:
			continue
		var away := offset / distance if distance > 0.01 else -facing
		var into := _velocity.dot(-away)
		position = world.move(position, away * (minimum - distance), RADIUS * 0.8)
		if into > 0.0:
			_velocity += away * into


## Spinta senza passare attraverso dirupi e ostacoli.
func _push(offset: Vector2) -> void:
	position = World.current.move(position, offset, RADIUS * 0.8) if World.current else position + offset


## Salto e caduta: con più salti disponibili si può saltare di nuovo in aria.
func _update_height(delta: float) -> void:
	if _height <= 0.0 and _height_velocity <= 0.0:
		return
	var gravity := GRAVITY * (AIR_DODGE_GRAVITY_FACTOR if _state == State.DODGE else 1.0)
	if _state == State.ATTACK and _air_attack and _height_velocity < 0.0:
		gravity *= AIR_ATTACK_GRAVITY_FACTOR
	if _state == State.SLAM and not _slam_landed:
		# Mentre si carica lo slam aereo si fluttua (vedi _update_slam).
		gravity = 0.0 if _charging or _slam_kind == "pending" or _state_time < SLAM_HANG else SLAM_GRAVITY
	_height_velocity -= gravity * delta
	_height += _height_velocity * delta
	if _height <= 0.0:
		# Più forte la caduta, più il corpo si schiaccia atterrando.
		_squash = clampf(-_height_velocity / 900.0, 0.0, 1.0)
		_height = 0.0
		_land()


func _land() -> void:
	_height_velocity = 0.0
	_jumps_used = 0
	if _state == State.SLAM and not _slam_landed:
		_slam_impact()


## Avanzamento dell'attacco in corso: affondo, colpo, combo e recupero.
## aim: direzione del colpo (il cursore se l'attacco è partito col mouse).
func _update_attack(input: Vector2, aim: Vector2, delta: float) -> void:
	var windup := (HEAVY_WINDUP if _attack_heavy else ATTACK_WINDUP) / _attack_speed
	var active := (HEAVY_ACTIVE if _attack_heavy else ATTACK_ACTIVE) / _attack_speed
	var recovery := _attack_recovery() / _attack_speed
	if _charging:
		# Finché si tiene premuto, il colpo potente resta in carica (e consuma
		# mana); intanto ci si gira con la levetta (o verso il bersaglio
		# agganciato, o verso il cursore).
		if aim != Vector2.ZERO:
			_target_facing = aim.normalized()
		_face_lock()
		_charge_time += delta
		if not UiNav.game_held("heavy_attack"):
			_charging = false
		elif not _drain_charge(delta):
			# Mana finito: il colpo parte con la carica raggiunta.
			_charging = false
		elif _state_time >= windup * 0.9:
			_charge = minf(_charge + delta / HEAVY_CHARGE_TIME, 1.0)
			_state_time = windup * 0.9
			if _charge >= 1.0:
				# A carica piena il colpo parte da solo: tenendo ancora premuto
				# si concatenano i colpi potenti successivi.
				Sfx.play("charge_full", global_position)
				_charging = false
	# Lo slancio di una scivolata si esaurisce durante l'attacco.
	_carry_velocity = _carry_velocity.move_toward(Vector2.ZERO, DECELERATION * delta)
	# Mentre si attacca ci si può muovere (più piano) in qualsiasi
	# direzione; il colpo resta nella direzione in cui è partito (il colpo
	# potente in quella in cui si guarda al rilascio), con un piccolo affondo
	# in avanti.
	_walk_velocity = _accelerate(_walk_velocity, input * walk_speed() * ATTACK_MOVE_FACTOR, delta)
	var lunge := Vector2.ZERO
	# Durante la carica del colpo potente si resta fermi sul posto (ci si
	# può solo spostare piano); l'affondo parte al rilascio.
	if _state_time >= windup * 0.5 and _state_time < windup + active and not _charging:
		# Sferzata del colpo potente: nessun suono in carica, solo al rilascio.
		if _attack_heavy and not _heavy_swing_played:
			_heavy_swing_played = true
			Sfx.play("heavy_swing", global_position, (1.0 + 0.08 * (_heavy_step - 1)) * (1.0 - 0.12 * _charge))
		lunge = facing * (HEAVY_LUNGE_SPEED if _attack_heavy else ATTACK_LUNGE_SPEED * (1.0 + 0.2 * (_combo_step - 1)))
	_velocity = _walk_velocity + lunge + _carry_velocity
	# Si memorizza la pressione solo se può davvero continuare la combo:
	# alla fine della combo le pressioni in più vengono ignorate.
	if UiNav.game_pressed("heavy_attack") and _can_chain_heavy():
		_queued_attack = "heavy"
	elif UiNav.game_held("heavy_attack") and _attack_heavy and not _charging and _queued_attack == "" \
			and _state_time >= windup and _can_chain_heavy():
		# Tenendo premuto il colpo potente, il successivo parte da solo.
		_queued_attack = "heavy_held"
	elif _can_chain_attack() and (UiNav.game_pressed("attack") \
			or (UiNav.game_held("attack") and _queued_attack == "" and _state_time >= windup)):
		# Tenendo premuto il tasto, il colpo successivo parte da solo.
		_queued_attack = "attack"
	if not _attack_resolved and _state_time >= windup:
		_attack_resolved = true
		_resolve_attack()
		# Parato dalla guardia di un nemico: si è stati respinti.
		if _state != State.ATTACK:
			return
	# Tra un colpo normale e il successivo della combo c'è una breve pausa.
	var chain_at := windup + active + (0.0 if _attack_heavy else ATTACK_CHAIN_DELAY / _attack_speed)
	if _queued_attack != "" and _state_time >= chain_at:
		if _queued_attack == "attack":
			_start_attack(_combo_step + 1, aim)
		else:
			_start_heavy(aim, _queued_attack == "heavy_held")
	elif _state_time >= windup + active + recovery:
		if _combo_finished():
			_end_combo()
		else:
			_combo_timer = COMBO_WINDOW
		_carry_velocity = Vector2.ZERO
		_velocity = _walk_velocity
		_change_state(State.NORMAL)


func _end_combo() -> void:
	_combo_step = 0
	_heavy_step = 0
	_chain_charge = 0.0
	_combo_timer = 0.0
	_queued_attack = ""


## Un nemico colpisce il giocatore. Restituisce l'esito, così il nemico
## può reagire (per esempio restare stordito dopo una parata perfetta).
## projectile: colpo a distanza (dardi, frecce), che raggiunge anche chi
## fluttua a mezz'aria caricando lo slam aereo.
func receive_hit(from: Vector2, damage: int, projectile := false) -> String:
	# Durante l'attacco speciale niente può colpire il goblin.
	if _state in [State.DEAD, State.FALL, State.SPECIAL] or is_invulnerable():
		return "ignored"
	if (_state == State.DODGE and _state_time <= DODGE_INVULNERABLE_TIME) \
			or (_state == State.SLIDE and _state_time <= SLIDE_INVULNERABLE_TIME):
		return "dodged"
	# Sopra il nemico (saltando o su un gradino più alto) il colpo passa sotto.
	var attacker_height := World.current.elevation_at(from) if World.current else 0.0
	var above := altitude() - attacker_height
	if above > JUMP_EVADE_HEIGHT and not (projectile and is_air_charging()):
		if not is_airborne():
			return "ignored"
		return "dodged"
	if above < -HIT_HEIGHT_REACH:
		return "ignored"

	var to_attacker := (from - global_position).normalized()
	if _state == State.PARRY and absf(facing.angle_to(to_attacker)) <= PARRY_ARC / 2.0:
		_block_flash = 0.2
		if _state_time <= PERFECT_PARRY_WINDOW:
			_empowered_time = EMPOWER_TIME
			Sfx.play("perfect", global_position)
			return "parried"
		stamina -= STAMINA_BLOCK
		_stamina_delay = STAMINA_REGEN_DELAY
		if stamina < 0.0:
			# Senza vigore la guardia si rompe: si resta storditi, esposti.
			stamina = 0.0
			_hurt_time = GUARD_BREAK_TIME
			_change_state(State.HURT)
			_velocity = -to_attacker * HURT_KNOCKBACK * 0.6
			Sfx.play("shield_break", global_position)
			return "broken"
		_push(-to_attacker * 12.0)
		Sfx.play("block", global_position)
		return "blocked"

	if shield_active:
		# Lo scudo assorbe un colpo da qualsiasi direzione e poi si rompe.
		shield_active = false
		_start_invulnerability(0.3)
		Sfx.play("shield_break", global_position)
		return "shielded"

	health = maxi(health - damage, 0)
	health_changed.emit(health, max_health)
	# Colpiti si perde la carica (per esempio dello slam aereo: si cade giù).
	_charging = false
	_charge = 0.0
	GroundFx.bleed(global_position, altitude() + LEG_LENGTH + RADIUS * 0.5, -to_attacker, BLEED_DROPS)
	_wound(to_attacker)
	if health == 0:
		_die()
	else:
		_change_state(State.HURT)
		_velocity = -to_attacker * HURT_KNOCKBACK
		_start_invulnerability(HURT_INVULNERABLE_TIME)
		Sfx.play("hurt", global_position)
		_voice.pain()
	return "hit"


func is_dead() -> bool:
	return _state == State.DEAD


## Invulnerabile dopo un colpo: gli altri colpi vengono ignorati.
func is_invulnerable() -> bool:
	return not _invulnerable_timer.is_stopped()


## Invulnerabilità per time secondi, con il personaggio che lampeggia.
func _start_invulnerability(time: float) -> void:
	_invulnerable_timer.start(time)
	if _invulnerable_blink:
		_invulnerable_blink.kill()
	modulate.a = 1.0
	_invulnerable_blink = create_tween().set_loops()
	_invulnerable_blink.tween_property(self, "modulate:a", INVULNERABLE_ALPHA, INVULNERABLE_BLINK / 2.0)
	_invulnerable_blink.tween_property(self, "modulate:a", 1.0, INVULNERABLE_BLINK / 2.0)


func _end_invulnerability() -> void:
	if _invulnerable_blink:
		_invulnerable_blink.kill()
		_invulnerable_blink = null
	modulate.a = 1.0


## Una ferita (from: da dove arriva il colpo): lo squarcio sul corpo che
## svanisce in fretta e un po' di sangue che resta addosso.
func _wound(from: Vector2) -> void:
	_wounds.add(from)
	_blood.add(BLOOD_PER_WOUND)


## Morte: l'urlo e la pozza di sangue che resta a terra.
func _die() -> void:
	_change_state(State.DEAD)
	Sfx.play("death", global_position)
	_voice.scream()
	GroundFx.pool(global_position, DEATH_POOL)
	died.emit()


## Un nemico ucciso: il corpo si sporca ancora un po' di sangue.
func stain_with_blood() -> void:
	_blood.add(BLOOD_PER_KILL)


## Risatina da goblin, per esempio dopo aver sconfitto un boss.
func laugh() -> void:
	Sfx.play("giggle", global_position)


## Salto richiesto: vicino a un elemento con cui interagire, il tasto che
## salta e interagisce insieme (A) serve a interagire (vedi Game).
func _jump_pressed() -> bool:
	return UiNav.game_pressed("jump") and not (can_interact and UiNav.game_pressed("interact"))


## Sta precipitando in un burrone.
func is_falling() -> bool:
	return _state == State.FALL


## L'attacco è in corso (i nemici possono alzare la guardia).
func is_attacking() -> bool:
	return _state == State.ATTACK


## Un nemico in guardia (in from) ha parato il colpo: la combo si
## interrompe e si viene respinti indietro, con un lampo e un suono di metallo.
func _repel(from: Vector2) -> void:
	_end_combo()
	_charging = false
	_carry_velocity = Vector2.ZERO
	_velocity = (global_position - from).normalized() * REPEL_SPEED
	_shake = maxf(_shake, 0.35)
	_change_state(State.RECOIL)
	Sfx.play("block", global_position)
	HitFeedback.hit(get_tree(), 0.07)


## Sta caricando lo slam aereo: fluttua a mezz'aria, esposto a dardi e
## frecce (i nemici a distanza ne approfittano, vedi Enemy).
func is_air_charging() -> bool:
	return _state == State.SLAM and _charging


## Punto in cui salvare la posizione: si può salvare anche camminando o in
## aria; in aria si salva l'ultimo punto sicuro a terra (mai sopra un burrone).
func save_position() -> Vector2:
	return _safe_position if is_airborne() else position


func _fall_into_ravine() -> void:
	_end_combo()
	lock_manual = false
	_set_lock_target(null)
	_change_state(State.FALL)
	Sfx.play("jump", global_position, 0.5, -4.0)


## Dopo la caduta si riappare sul bordo, perdendo un po' di vita.
func _climb_out_of_ravine() -> void:
	teleport(_safe_position)
	var data: Dictionary = World.DATA.data["terrain"]
	health = maxi(health - int(data["ravine_damage"]), 0)
	health_changed.emit(health, max_health)
	GroundFx.bleed(global_position, ground_elevation + LEG_LENGTH + RADIUS * 0.5, Vector2.from_angle(randf() * TAU), BLEED_DROPS)
	_wound(Vector2(randf_range(-1.0, 1.0), 1.0))
	if health == 0:
		_die()
	else:
		_start_invulnerability(HURT_INVULNERABLE_TIME)
		Sfx.play("hurt", global_position)
		_voice.pain()


## Spostamento istantaneo (entrando o uscendo da una caverna, caricando una
## partita): niente scie, slanci o telecamera che insegue da lontano.
func teleport(at: Vector2) -> void:
	# Un cambio di posto chiude l'attacco speciale (nemici di nuovo liberi).
	if _state == State.SPECIAL:
		_finish_special()
	position = at
	_velocity = Vector2.ZERO
	_walk_velocity = Vector2.ZERO
	_carry_velocity = Vector2.ZERO
	_height = 0.0
	_height_velocity = 0.0
	_change_state(State.NORMAL)
	ground_elevation = World.current.elevation_at(at) if World.current else 0.0
	_safe_position = at
	_safe_altitude = ground_elevation
	reset_physics_interpolation()
	if _camera:
		_camera_height = -ground_elevation
		_look_ahead = Vector2.ZERO
		_camera.position = Vector2(0, _camera_height)
		_camera.reset_physics_interpolation()
		_camera.reset_smoothing()


## Il nemico vivo più vicino entro LOCK_RANGE che si vede (null se
## nessuno): mai uno oltre un muro, un palazzo o un ostacolo solido. Con
## sticky quello già agganciato conta come più vicino di LOCK_SWITCH_MARGIN.
func _lock_nearest(sticky: bool) -> Enemy:
	var candidates: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var distance := enemy.global_position.distance_to(global_position)
		if sticky and enemy == lock_target:
			distance -= LOCK_SWITCH_MARGIN
		if distance <= LOCK_RANGE:
			candidates.append([distance, enemy])
	# Dal più vicino: la linea di vista si controlla solo finché serve.
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for candidate: Array in candidates:
		var enemy: Enemy = candidate[1]
		if World.current == null or World.current.clear_line(global_position, enemy.global_position, ground_elevation):
			return enemy
	return null


## R3: aggancio manuale del nemico più vicino che si vede (premendo di
## nuovo, di quello che ora è più vicino); se non se ne vede nessuno non
## cambia niente.
func _lock_manually() -> void:
	var nearest := _lock_nearest(false)
	if nearest == null:
		return
	_set_lock_target(nearest)
	lock_manual = true
	Sfx.play_ui("ui_move")


## Aggancio manuale: resta sul bersaglio scelto finché è vivo ed entro
## LOCK_BREAK_RANGE, poi torna automatico. Automatico: ogni
## LOCK_SIGHT_INTERVAL secondi (e subito se il bersaglio muore) si aggancia
## il nemico più vicino che si vede, o nessuno. Mentre si cade in una
## fessura non si aggancia niente.
func _update_lock(delta: float) -> void:
	if _state == State.FALL:
		lock_manual = false
		_set_lock_target(null)
		return
	if not is_instance_valid(lock_target):
		lock_target = null
		_lock_marker.target = null
	var alive := lock_target != null and not lock_target.is_dead()
	if lock_manual:
		if alive and lock_target.global_position.distance_to(global_position) <= LOCK_BREAK_RANGE:
			return
		lock_manual = false
		alive = false
	_lock_sight_time -= delta
	if _lock_sight_time > 0.0 and (alive or lock_target == null):
		return
	_lock_sight_time = LOCK_SIGHT_INTERVAL
	_set_lock_target(_lock_nearest(true))


## Vicino a una porta nella parete il giocatore è disegnato sempre davanti
## a lei, mai dietro (vedi PASSAGES).
func _update_passage_z() -> void:
	var near := false
	if World.current:
		for type_id: String in PASSAGES:
			if not World.current.touched(type_id, position, PASSAGE_REACH).is_empty():
				near = true
				break
	z_index = PASSAGE_Z if near else 0


## Cambia bersaglio: il vecchio torna del suo colore, il nuovo si colora di rosso.
func _set_lock_target(target: Enemy) -> void:
	if not is_instance_valid(lock_target):
		lock_target = null
	if target == lock_target:
		return
	if lock_target:
		lock_target.set_locked(false)
	lock_target = target
	if lock_target:
		lock_target.set_locked(true)
	_lock_marker.target = lock_target


## Con un bersaglio agganciato si guarda verso di lui. Restituisce true se
## c'è un bersaglio.
func _face_lock() -> bool:
	if lock_target == null:
		return false
	var to_target := lock_target.global_position - global_position
	if to_target.length() > 1.0:
		_target_facing = to_target.normalized()
	return true


## Stato da salvare: livello, caratteristiche, potenziamenti e inventario.
func save_state() -> Dictionary:
	return {
		"level": level, "experience": experience, "xp_curve": XP_CURVE_VERSION, "health": health, "base_max_health": _base_max_health,
		"mana": mana, "base_max_mana": _base_max_mana, "potions": potions,
		"mana_potions": mana_potions, "stamina_potions": stamina_potions, "h_bombs": h_bombs, "spell_bonus": spell_bonus,
		"max_combo_hits": max_combo_hits, "max_heavy_chain": max_heavy_chain,
		"max_chained_dodges": max_chained_dodges, "max_jumps": max_jumps, "run_speed_bonus": run_speed_bonus,
		"shield_cooldown_max": shield_cooldown_max, "torch_on": torch_on, "upgrades_taken": upgrades_taken,
		"items": inventory.items, "equipped": inventory.equipped, "gold": inventory.gold, "learned": inventory.learned,
		# Solo per mostrarle nello slot del menù (vedi SaveGame.summary): al
		# caricamento si ricalcolano.
		"stats": {
			"max_health": max_health, "max_mana": roundi(max_mana), "damage": base_damage(),
			"potions": potions, "mana_potions": mana_potions,
		},
	}


## Ripristina lo stato salvato (i numeri dal JSON arrivano come decimali).
## I campi mancanti (salvataggi di versioni precedenti) restano come sono.
func load_state(data: Dictionary) -> void:
	level = int(data.get("level", level))
	experience = int(data.get("experience", experience))
	# Salvataggi con la vecchia curva lineare: si tiene la stessa parte del
	# livello già fatta, sulla curva nuova.
	var curve := int(data.get("xp_curve", 1))
	if curve < XP_CURVE_VERSION:
		var old_needed := _old_experience_for(level) if curve == 1 else _v2_experience_for(level)
		experience = floori(float(experience) / old_needed * experience_for(level))
	experience = clampi(experience, 0, experience_needed() - 1)
	_base_max_health = int(data.get("base_max_health", _base_max_health))
	_base_max_mana = float(data.get("base_max_mana", _base_max_mana))
	potions = int(data.get("potions", potions))
	mana_potions = int(data.get("mana_potions", mana_potions))
	# Salvataggi precedenti alle pozioni verdi: si parte con la scorta iniziale.
	stamina_potions = int(data.get("stamina_potions", stamina_potions))
	spell_bonus = float(data.get("spell_bonus", spell_bonus))
	max_combo_hits = int(data.get("max_combo_hits", max_combo_hits))
	max_heavy_chain = int(data.get("max_heavy_chain", max_heavy_chain))
	max_chained_dodges = int(data.get("max_chained_dodges", max_chained_dodges))
	max_jumps = int(data.get("max_jumps", max_jumps))
	run_speed_bonus = float(data.get("run_speed_bonus", run_speed_bonus))
	shield_cooldown_max = float(data.get("shield_cooldown_max", shield_cooldown_max))
	torch_on = bool(data.get("torch_on", torch_on))
	_torch.enabled = torch_on
	upgrades_taken.clear()
	var taken: Dictionary = data.get("upgrades_taken", {})
	for key: String in taken:
		upgrades_taken[key] = int(taken[key])
	# Le schivate di partenza sono cambiate (da 2 a 1): si ricalcolano dai
	# potenziamenti scelti, se il salvataggio li ha.
	if data.has("upgrades_taken"):
		max_chained_dodges = START_CHAINED_DODGES + int(upgrades_taken.get("dodge", 0))
	# I colpi dell'attacco speciale non si salvano: si ricalcolano dai
	# potenziamenti (nei salvataggi precedenti nessuno).
	max_special_hits = START_SPECIAL_HITS + SPECIAL_HITS_UPGRADE * int(upgrades_taken.get("frenzy", 0))
	_refresh_stamina()
	stamina = max_stamina
	# Salvataggi precedenti alle rune del cataclisma: nessuna runa.
	h_bombs = clampi(int(data.get("h_bombs", h_bombs)), 0, h_bomb_capacity())
	# Oggetti che questa versione non conosce più vengono scartati.
	inventory.items.clear()
	var known: Dictionary = Items.DATA.data["items"]
	var kept := {}
	var saved_items: Array = data.get("items", [])
	for k in saved_items.size():
		# Le pozioni di vita e di mana non stanno più nell'inventario: vanno nella cintura.
		if saved_items[k] == "potion_health":
			potions += 1
		elif saved_items[k] == "potion_mana":
			mana_potions += 1
		elif saved_items[k] == "potion_stamina":
			stamina_potions += 1
		elif known.has(saved_items[k]):
			kept[k] = inventory.items.size()
			inventory.items.append(saved_items[k])
	inventory.equipped.clear()
	var equipped: Dictionary = data.get("equipped", {})
	for slot: String in equipped:
		if kept.has(int(equipped[slot])):
			inventory.equipped[slot] = kept[int(equipped[slot])]
	inventory.gold = int(data.get("gold", inventory.gold))
	inventory.learned = (data.get("learned", {}) as Dictionary).duplicate()
	_refresh_stats()
	health = clampi(int(data.get("health", max_health)), 1, max_health)
	mana = clampf(float(data.get("mana", max_mana)), 0.0, max_mana)
	health_changed.emit(health, max_health)
	experience_changed.emit(experience, experience_needed(), level)


func is_empowered() -> bool:
	return _empowered_time > 0.0


## Secondi rimasti del potenziamento della parata perfetta.
func empowered_time() -> float:
	return _empowered_time


## Altezza dei piedi sullo schermo: terreno più salto.
func altitude() -> float:
	return ground_elevation + _height


func is_airborne() -> bool:
	return _height > 0.0


## Velocità del passo, con il bonus degli stivali.
func walk_speed() -> float:
	return SPEED * (1.0 + inventory.bonus("speed"))


func run_speed() -> float:
	return walk_speed() * RUN_SPEED_FACTOR * (1.0 + run_speed_bonus)


## Danni della palla di fuoco.
func spell_damage() -> int:
	var base := FIREBALL_DAMAGE + FIREBALL_DAMAGE_PER_LEVEL * (level - 1)
	return roundi(base * (1.0 + spell_bonus + inventory.bonus("spell")))


## Danni del primo colpo della combo al livello attuale.
func base_damage() -> int:
	return damage_at(level)


## Danni del primo colpo della combo a un livello: +30% del valore di
## partenza a livello, poco più della vita dei nemici (vedi EnemyTypes.scaled).
static func damage_at(at_level: int) -> int:
	return BASE_DAMAGE + DAMAGE_PER_LEVEL * maxi(at_level - 1, 0)


## Modalità focus: dove resta a colori e quanto è grande (vedi LowHealthVignette).
func focus_spot() -> Vector3:
	if is_dead():
		return Vector3.ZERO
	var at := global_position - Vector2(0, altitude() + RADIUS * FOCUS_AURA_HEIGHT)
	return Vector3(at.x, at.y, RADIUS * FOCUS_AURA_RADIUS)


## Esperienza necessaria per passare al livello successivo (vedi experience_for).
func experience_needed() -> int:
	return experience_for(level)


## Curva dell'esperienza, continua e senza salti: 40 punti per il livello
## 2, poi base + passo * n + quadratico * n^2 (n = livelli già fatti):
## circa 470 al 10, 880 al 15, 1400 al 20, 2900 al 30. Dato che anche
## l'esperienza dei nemici cresce del 10% a livello, le uccisioni per
## livello salgono piano (circa 3 al primo, 17 al decimo, 33 al ventesimo).
static func experience_for(from_level: int) -> int:
	var n := float(maxi(from_level - 1, 0))
	return roundi(XP_CURVE_BASE + XP_CURVE_STEP * n + XP_CURVE_QUAD * n * n)


## Curva della versione 2, per convertire i salvataggi precedenti.
static func _v2_experience_for(from_level: int) -> int:
	var early := XP_CURVE_BASE + XP_CURVE_STEP * (from_level - 1)
	var beyond := maxi(from_level - XP_CURVE_FAST_LEVELS, 0)
	return roundi(early + XP_CURVE_LATE * pow(beyond, 1.5))


## Vecchia curva (100 per livello), per convertire i salvataggi precedenti.
static func _old_experience_for(from_level: int) -> int:
	return 100 * from_level


func add_experience(amount: int) -> void:
	if _state == State.DEAD:
		return
	experience += amount
	while experience >= experience_needed():
		experience -= experience_needed()
		level += 1
		_refresh_stats()
		Sfx.play("level_up", global_position)
		leveled_up.emit(level)
	experience_changed.emit(experience, experience_needed(), level)


## Potenziamento scelto salendo di livello.
func apply_upgrade(upgrade: String) -> void:
	upgrades_taken[upgrade] = upgrades_taken.get(upgrade, 0) + 1
	match upgrade:
		"combo":
			max_combo_hits += 1
		"heavy":
			max_heavy_chain += 1
		"dodge":
			max_chained_dodges += 1
		"health":
			_base_max_health += 1
			health += 1
			_refresh_stats()
		"shield":
			shield_cooldown_max *= SHIELD_COOLDOWN_UPGRADE
			shield_cooldown = minf(shield_cooldown, shield_cooldown_max)
		"jump":
			max_jumps += 1
		"run":
			run_speed_bonus += RUN_SPEED_UPGRADE
		"mana":
			_base_max_mana += MANA_UPGRADE
			mana += MANA_UPGRADE
			_refresh_stats()
		"spell":
			spell_bonus += SPELL_UPGRADE
		"stamina":
			_refresh_stamina()
			stamina = max_stamina
		"frenzy":
			max_special_hits += SPECIAL_HITS_UPGRADE


func _refresh_stamina() -> void:
	max_stamina = MAX_STAMINA * (1.0 + STAMINA_UPGRADE * int(upgrades_taken.get("stamina", 0)))
	stamina = minf(stamina, max_stamina)


func _change_state(new_state: State) -> void:
	_state = new_state
	_state_time = 0.0


## Avvicina la velocità a quella voluta: partenza graduale che poi
## accelera, frenata con un breve scivolamento.
func _accelerate(current: Vector2, target: Vector2, delta: float) -> Vector2:
	if target == Vector2.ZERO:
		return current.move_toward(Vector2.ZERO, DECELERATION * delta)
	var speed_ratio := clampf(current.length() / SPEED, 0.0, 1.0)
	var acceleration := lerpf(ACCELERATION_START, ACCELERATION_FULL, speed_ratio)
	return current.move_toward(target, acceleration * delta)


## Un colpo normale può seguire solo colpi normali, fino al massimo della combo.
func _can_chain_attack() -> bool:
	return not _attack_heavy and _combo_step < max_combo_hits


## Un colpo potente può chiudere la combo o seguire altri colpi potenti,
## finché non si raggiunge il massimo di colpi potenti concatenati.
func _can_chain_heavy() -> bool:
	return _heavy_step < max_heavy_chain


func _combo_finished() -> bool:
	if _attack_heavy:
		return _heavy_step >= max_heavy_chain
	return _combo_step >= max_combo_hits and max_heavy_chain == 0


func _attack_recovery() -> float:
	if _attack_heavy:
		return HEAVY_RECOVERY
	return FINISHER_RECOVERY if _combo_step >= max_combo_hits else ATTACK_RECOVERY


func _start_attack(step: int, input: Vector2) -> void:
	if not _use_stamina(STAMINA_ATTACK):
		return
	_combo_step = clampi(step, 1, max_combo_hits)
	_heavy_step = 0
	_attack_heavy = false
	_begin_attack(input)
	Sfx.play("swing", global_position, 1.0 + 0.12 * (_combo_step - 1))


## held: concatenato tenendo premuto il tasto (non si carica).
func _start_heavy(input: Vector2, held := false) -> void:
	# In aria il colpo potente è lo slam o la runa del cataclisma: si decide
	# da quanto si tiene premuto (vedi _resolve_air_heavy).
	if is_airborne():
		_start_slam("pending", input)
		return
	if not _use_stamina(STAMINA_HEAVY):
		return
	mana = maxf(mana - HEAVY_MANA, 0.0)
	# Fuori dalla combo il colpo potente parte da solo, senza bonus.
	if _combo_timer == 0.0 and _state not in [State.ATTACK, State.SLAM]:
		_combo_step = 0
		_heavy_step = 0
	if _heavy_step >= max_heavy_chain:
		_heavy_step = 0
		_combo_step = 0
	if _heavy_step == 0:
		_chain_charge = 0.0
	_heavy_step += 1
	# Dopo una combo di colpi normali (combo mista) resta un colpo potente
	# normale, con il bonus MIXED_COMBO_DAMAGE_FACTOR (vedi _attack_damage).
	_attack_heavy = true
	_begin_attack(input)
	_charging = not held


func _begin_attack(input: Vector2) -> void:
	_attack_speed = EMPOWER_ATTACK_SPEED if is_empowered() else 1.0
	_charge = 0.0
	_charge_time = 0.0
	_charging = false
	_heavy_swing_played = false
	_air_attack = is_airborne()
	attack_serial += 1
	_frenzy_idle = 0.0
	if _state != State.ATTACK:
		_walk_velocity = _velocity.limit_length(walk_speed() * ATTACK_MOVE_FACTOR)
		# In aria lo slancio del salto (o dello scatto) continua e si esaurisce piano.
		if _air_attack:
			_carry_velocity = _velocity - _walk_velocity
	# I fendenti si alternano: una volta da sinistra, una da destra; i colpi
	# normali a terra cambiano movimento a ogni colpo.
	_swing_sign = -_swing_sign
	if not _attack_heavy and not _air_attack:
		_attack_style = (_attack_style + 1) % ATTACK_STYLES.size()
	_queued_attack = ""
	_attack_resolved = false
	_combo_timer = 0.0
	# Si attacca subito nella direzione indicata (o verso il bersaglio
	# agganciato), senza aspettare la rotazione.
	if input != Vector2.ZERO:
		_target_facing = input.normalized()
		facing = _target_facing
	if _face_lock():
		facing = _target_facing
	_change_state(State.ATTACK)


## Colpo successivo: continua la combo se c'è ancora tempo, altrimenti
## ricomincia (anche dopo un colpo potente o dopo l'ultimo colpo).
func _next_combo_step() -> int:
	var continues := _combo_timer > 0.0 and _heavy_step == 0 and _combo_step < max_combo_hits
	return _combo_step + 1 if continues else 1


## Inizia un attacco a terra: sosta in aria prima di piombare giù (pending,
## che diventa air o plunge, e dash).
func _start_slam(kind: String, input: Vector2) -> void:
	# Il colpo dallo scatto in aria paga qui, lo slam in _resolve_air_heavy
	# (la runa costa la runa).
	if kind == "dash" and not _use_stamina(STAMINA_HEAVY):
		return
	_slam_kind = kind
	_slam_landed = false
	_attack_heavy = false
	_frenzy_idle = 0.0
	_attack_speed = EMPOWER_ATTACK_SPEED if is_empowered() else 1.0
	_charge = 0.0
	_charge_time = 0.0
	_charging = false
	_queued_attack = ""
	_combo_timer = 0.0
	_carry_velocity = Vector2.ZERO
	if kind == "dash":
		_target_facing = _dodge_direction
	elif input != Vector2.ZERO:
		_target_facing = input.normalized()
	if kind != "dash":
		_face_lock()
	facing = _target_facing
	_height_velocity = 0.0
	if kind == "dash":
		Sfx.play("heavy_swing", global_position, 0.85)
	_change_state(State.SLAM)


## Colpo potente in aria deciso: lasciato subito (o senza rune) è lo slam,
## che costa mana e vigore; tenuto premuto, con una runa del cataclisma, la
## runa, che continua a caricarsi a mezz'aria finché la si tiene.
func _resolve_air_heavy(held: bool) -> void:
	if held and h_bombs > 0:
		_slam_kind = "plunge"
		_charging = true
		_state_time = 0.0
		Sfx.play("h_bomb_lift", global_position)
		return
	if mana < AIR_SLAM_MANA or not _use_stamina(STAMINA_HEAVY):
		# Senza mana o vigore non parte: si ricade e basta.
		_change_state(State.NORMAL)
		return
	mana -= AIR_SLAM_MANA
	_slam_kind = "air"
	_state_time = SLAM_HANG
	Sfx.play("heavy_swing", global_position, 0.85)


## Attacco a terra: sosta in aria, discesa e, toccato terra, l'impatto
## (vedi _land); poi un breve recupero.
## aim: direzione verso cui girarsi in carica (il cursore se lo slam è
## partito col mouse).
func _update_slam(input: Vector2, aim: Vector2, delta: float) -> void:
	if _slam_kind == "pending":
		# Sospesi un attimo, finché non si capisce se il tasto è tenuto premuto.
		_velocity = _velocity.move_toward(Vector2.ZERO, DECELERATION * delta)
		if not UiNav.game_held("heavy_attack"):
			_resolve_air_heavy(false)
		elif _state_time >= AIR_HEAVY_HOLD_TIME:
			_resolve_air_heavy(true)
		return
	if _charging:
		# A mezz'aria si fluttua salendo piano (sempre più piano con la carica):
		# ci si gira con la levetta (o verso il bersaglio, o il cursore) finché
		# si tiene premuto; a carica piena la picchiata parte da sola.
		_height_velocity = AIR_SLAM_RISE_SPEED * (1.0 - 0.6 * _charge)
		_velocity = _velocity.move_toward(Vector2.ZERO, DECELERATION * 2.0 * delta)
		if aim != Vector2.ZERO:
			_target_facing = aim.normalized()
		_face_lock()
		_state_time = 0.0
		_charge_time += delta
		if not UiNav.game_held("heavy_attack"):
			_charging = false
		else:
			_charge = minf(_charge + delta / HEAVY_CHARGE_TIME, 1.0)
			if _charge >= 1.0:
				Sfx.play("charge_full", global_position)
				_charging = false
		if not _charging:
			_height_velocity = 0.0
			facing = _target_facing
			Sfx.play("heavy_swing", global_position, 0.6)
		return
	if not _slam_landed:
		if _state_time >= SLAM_HANG and _height_velocity > -SLAM_DIVE_SPEED:
			_height_velocity = -SLAM_DIVE_SPEED
		# In aria ci si sposta piano; lo scatto continua nella sua direzione.
		var target := input * walk_speed() * ATTACK_MOVE_FACTOR
		if _slam_kind == "dash":
			target = _dodge_direction * DODGE_SPEED * 0.45
		_velocity = _velocity.move_toward(target, ACCELERATION_FULL * delta)
		if _state_time >= SLAM_MAX_TIME:
			_slam_impact()
		return
	_velocity = _velocity.move_toward(Vector2.ZERO, DECELERATION * 2.0 * delta)
	if _state_time < SLAM_RECOVERY / _attack_speed:
		return
	_end_combo()
	_change_state(State.NORMAL)


## Il colpo tocca terra: danni a tutti i nemici nel raggio, onda d'urto,
## un attimo di fermo e la telecamera che trema.
func _slam_impact() -> void:
	_slam_landed = true
	_state_time = 0.0
	_squash = 1.0
	_shake = 1.0
	if _slam_kind == "plunge":
		_h_bomb_impact()
		return
	var radius := _slam_radius()
	var damage := _slam_damage()
	var landed := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead() or absf(enemy.ground_elevation - ground_elevation) > HIT_HEIGHT_REACH:
			continue
		var offset := enemy.global_position - global_position
		var direction := offset.normalized() if offset != Vector2.ZERO else facing
		if offset.length() > radius + enemy.radius:
			# Poco più in là non si fanno danni, ma si viene comunque respinti.
			if offset.length() <= radius + enemy.radius + SLAM_PUSH_MARGIN and not enemy.is_boss():
				enemy.shove(direction * SLAM_PUSH_SPEED)
			continue
		enemy.take_damage(damage, direction, true)
		if not enemy.is_boss():
			enemy.shove(direction * SLAM_PUSH_SPEED)
		HitSpark.spawn(get_parent(), enemy.global_position - direction * enemy.radius * 0.8, enemy.ground_elevation + enemy.radius * 0.5, 40.0, COLOR_HEAVY)
		landed = true
	GroundFx.shockwave(global_position, ground_elevation, radius)
	Sfx.play("fireball_hit", global_position, 0.6)
	if landed:
		Sfx.play("hit", global_position, 0.7)
		HitFeedback.hit(get_tree(), 0.14)
		_add_frenzy(FRENZY_PER_HEAVY)


## La runa del cataclisma si spacca sul terreno: i nemici attorno muoiono
## (il boss perde una parte della vita), il goblin resta intatto ma annerito.
func _h_bomb_impact() -> void:
	h_bombs = maxi(h_bombs - 1, 0)
	var radius := _slam_radius()
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead() or absf(enemy.ground_elevation - ground_elevation) > HIT_HEIGHT_REACH:
			continue
		var offset := enemy.global_position - global_position
		if offset.length() > radius + enemy.radius:
			continue
		var direction := offset.normalized() if offset != Vector2.ZERO else facing
		if enemy.is_boss():
			# L'armatura non attenua la runa.
			enemy.take_points(ceili(enemy.max_health * H_BOMB_BOSS_DAMAGE), direction, true, true)
		else:
			enemy.take_points(enemy.health, direction, true, true)
			enemy.shove(direction * SLAM_PUSH_SPEED)
	var blast := HBombBlast.new()
	blast.radius = radius
	blast.position = position
	blast.altitude = ground_elevation
	get_parent().add_child(blast)
	GroundFx.shockwave(global_position, ground_elevation, radius)
	soot = 1.0
	_shake = 1.6
	Sfx.play("h_bomb", global_position)
	Sfx.play("fireball_hit", global_position, 0.6)
	HitFeedback.hit(get_tree(), 0.16)


## Raggio dell'esplosione della runa (secondo la carica), dello slam o del colpo dallo scatto.
func _slam_radius() -> float:
	if _slam_kind == "plunge":
		return lerpf(H_BOMB_MIN_RADIUS, H_BOMB_MAX_RADIUS, _charge)
	return SLAM_RADIUS[_slam_kind]


## Danno dello slam e del colpo dallo scatto in aria (la runa uccide e basta).
func _slam_damage() -> int:
	var multiplier := DASH_SLAM_DAMAGE_FACTOR if _slam_kind == "dash" else AIR_SLAM_DAMAGE_FACTOR
	if _attack_speed > 1.0:
		multiplier *= EMPOWER_DAMAGE_FACTOR
	return roundi(base_damage() * multiplier * (1.0 + inventory.bonus("damage")))


# --- Frenesia e attacco speciale ---------------------------------------

## Frenesia piena (il goblin si accende di rosso, vedi _draw).
func is_frenzy_full() -> bool:
	return frenzy >= FRENZY_MAX


## Attacco speciale in corso (Game rimanda la scelta dei potenziamenti).
func is_special_active() -> bool:
	return _state == State.SPECIAL


## Buio dello sfondo durante la cinematica dell'attacco speciale (0-1):
## LowHealthVignette scurisce tutto lo schermo tranne il goblin.
func special_darkness() -> float:
	return _special_dark


func _set_frenzy(value: float) -> void:
	value = clampf(value, 0.0, FRENZY_MAX)
	if value == frenzy:
		return
	var was_full := is_frenzy_full()
	frenzy = value
	if is_frenzy_full() and not was_full:
		Sfx.play("frenzy_ready", global_position)
	frenzy_changed.emit(frenzy, FRENZY_MAX)


## Un colpo a segno: la Frenesia cresce e il calo riparte da capo.
func _add_frenzy(amount: float) -> void:
	_frenzy_idle = 0.0
	_set_frenzy(frenzy + amount)


## Si può scatenare l'attacco speciale: Frenesia piena, nessuno stordimento
## o caduta in corso e almeno un nemico a tiro.
func _can_start_special() -> bool:
	return is_frenzy_full() and _state in [State.NORMAL, State.ATTACK, State.PARRY, State.DODGE, State.SLIDE, State.RECOIL] \
			and _special_nearest() != null


## Cinematica d'inizio: nemici fermi (Enemy.frozen), sfondo scuro, urlo e
## bagliore attorno al goblin, zoom sulla telecamera. Lo sfondo torna
## normale prima dei colpi, lo zoom resta fino alla fine (vedi _finish_special).
func _start_special() -> void:
	_interrupt_action()
	_queued_attack = ""
	_velocity = Vector2.ZERO
	_special_hits = 0
	_special_target = null
	_special_from = Vector2.ZERO
	_special_last_hit = 0.0
	Enemy.frozen = true
	_change_state(State.SPECIAL)
	var dark := create_tween()
	dark.tween_property(self, "_special_dark", 1.0, SPECIAL_DARK_IN)
	dark.tween_interval(SPECIAL_DARK_HOLD)
	dark.tween_property(self, "_special_dark", 0.0, SPECIAL_DARK_OUT)
	if _camera:
		_special_zoom = _camera.zoom
		_tween_zoom(_special_zoom * SPECIAL_ZOOM, SPECIAL_ZOOM_IN_TIME)
	_shake = maxf(_shake, 0.4)
	Sfx.play("frenzy_roar", global_position)
	Sfx.play("heavy_swing", global_position, 0.7)
	special_started.emit()


## Zoom della telecamera verso to in time secondi, con una curva morbida.
func _tween_zoom(to: Vector2, time: float) -> void:
	if _zoom_tween:
		_zoom_tween.kill()
	_zoom_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(_camera, "zoom", to, time)


## Dopo la cinematica un colpo ogni SPECIAL_HIT_INTERVAL secondi, fino a
## max_special_hits; poi (o se non c'è più nessuno a tiro) si chiude.
func _update_special() -> void:
	_velocity = Vector2.ZERO
	if _state_time < SPECIAL_INTRO_TIME:
		_face_lock()
		return
	var since := _state_time - _special_last_hit
	if _special_hits >= max_special_hits:
		if since >= SPECIAL_HIT_INTERVAL:
			_finish_special()
		return
	if _special_hits == 0 or since >= SPECIAL_HIT_INTERVAL:
		_special_strike()


## Un colpo dell'attacco speciale: si resta sul nemico finché non muore,
## poi si passa al più vicino a tiro; ci si teletrasporta accanto a lui.
func _special_strike() -> void:
	var target := _special_target
	if not is_instance_valid(target) or target.is_dead():
		target = _special_nearest()
	if target == null:
		_finish_special()
		return
	_special_target = target
	var start := position
	var offset := target.position - position
	if offset.length() > RADIUS + target.radius + SPECIAL_GAP * 2.0:
		position = _special_landing(target)
		_height = 0.0
		_height_velocity = 0.0
		ground_elevation = World.current.elevation_at(position) if World.current else ground_elevation
		reset_physics_interpolation()
		offset = target.position - position
	_special_from = start - position
	var direction := offset.normalized() if offset != Vector2.ZERO else facing
	facing = direction
	_target_facing = direction
	_swing_sign = -_swing_sign
	_special_hits += 1
	_special_last_hit = _state_time
	var damage := roundi(base_damage() * SPECIAL_DAMAGE_FACTOR * (EMPOWER_DAMAGE_FACTOR if is_empowered() else 1.0) \
			* (1.0 + inventory.bonus("damage")))
	# I nemici sono fermi: il colpo passa sempre, anche la guardia.
	target.take_damage(damage, direction, _special_hits == max_special_hits)
	HitSpark.spawn(get_parent(), target.global_position - direction * target.radius * 0.8,
			target.ground_elevation + target.radius * 0.9, 44.0, COLOR_FRENZY)
	Sfx.play("swing", global_position, 1.1 + 0.05 * _special_hits)
	Sfx.play("hit", global_position, 1.0 + 0.04 * _special_hits)
	HitFeedback.hit(get_tree(), 0.05)
	_shake = maxf(_shake, 0.35)
	# La barra si svuota man mano che si colpisce.
	_set_frenzy(FRENZY_MAX * (1.0 - float(_special_hits) / max_special_hits))


## Fine dell'attacco speciale: la telecamera torna allo zoom di prima, i
## nemici ripartono, la Frenesia si azzera e il goblin torna normale (con un
## attimo di invulnerabilità).
func _finish_special() -> void:
	if _camera:
		_tween_zoom(_special_zoom, SPECIAL_ZOOM_OUT_TIME)
	Enemy.frozen = false
	_special_target = null
	_special_from = Vector2.ZERO
	_set_frenzy(0.0)
	_frenzy_idle = 0.0
	_start_invulnerability(SPECIAL_END_INVULNERABLE)
	_change_state(State.NORMAL)
	special_finished.emit()


## Il nemico vivo più vicino entro SPECIAL_RANGE alla stessa quota (null se nessuno).
func _special_nearest() -> Enemy:
	var nearest: Enemy = null
	var best := SPECIAL_RANGE
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead() or absf(enemy.ground_elevation - ground_elevation) > HIT_HEIGHT_REACH:
			continue
		var distance := enemy.position.distance_to(position)
		if distance <= best:
			best = distance
			nearest = enemy
	return nearest


## Punto accanto al nemico dove comparire: dal lato da cui si arriva, se
## no girandogli attorno; se non c'è posto si resta dove si è.
func _special_landing(enemy: Enemy) -> Vector2:
	var reach := RADIUS + enemy.radius + SPECIAL_GAP
	var side := (position - enemy.position).normalized() if position != enemy.position else -facing
	for k in 9:
		var turn := ceilf(k / 2.0) * 0.7 * (1.0 if k % 2 == 1 else -1.0)
		var candidate := enemy.position + side.rotated(turn) * reach
		if _can_stand(candidate, enemy.ground_elevation):
			return candidate
	return position


## Ci si può stare: terreno percorribile alla quota data, niente ostacoli solidi.
func _can_stand(point: Vector2, elevation: float) -> bool:
	var world := World.current
	if world == null:
		return true
	if world.is_barrier(World.cell_at(point)) or absf(world.elevation_at(point) - elevation) > World.STEP_TOLERANCE:
		return false
	for obstacle: Dictionary in world.obstacles_close(point):
		if obstacle["solid"] and point.distance_to(obstacle["position"]) < RADIUS * 0.8 + float(obstacle["collision"]):
			return false
	return true


func _can_jump() -> bool:
	return _jumps_used < max_jumps and stamina > 0.0


func _jump() -> void:
	if _jumps_used >= max_jumps or not _use_stamina(STAMINA_JUMP):
		return
	_jumps_used += 1
	_height_velocity = JUMP_SPEED
	Sfx.play("jump", global_position, 1.0 + 0.15 * (_jumps_used - 1))


## La scivolata parte almeno alla velocità di corsa, così funziona anche
## subito dopo un attacco, quando non si è ancora ripresa velocità.
func _start_slide(input: Vector2) -> void:
	if not _use_stamina(STAMINA_DODGE):
		return
	_slide_direction = input.normalized()
	_slide_speed = maxf(_velocity.length(), run_speed()) * SLIDE_SPEED_FACTOR
	_target_facing = _slide_direction
	Sfx.play("slide", global_position)
	_change_state(State.SLIDE)


func _start_dodge(input: Vector2) -> void:
	if not _use_stamina(STAMINA_DODGE):
		return
	# Senza direzione a terra si rotola all'indietro; in aria si scatta in avanti.
	_set_air_dash()
	_dodge_direction = input.normalized() if input != Vector2.ZERO else (facing if _air_dash else -facing)
	_dodges_used = 1
	_carry_velocity = Vector2.ZERO
	_combo_step = 0
	_heavy_step = 0
	Sfx.play("dodge", global_position)
	_change_state(State.DODGE)


## Parata istantanea: annulla l'azione in corso (combo, carica, schivata,
## scivolata, attacco a terra, rinculo, sorso) e si gira subito verso la
## levetta o il bersaglio agganciato, così la guardia copre il lato giusto
## già dal primo istante (la finestra della parata perfetta parte da qui).
func _start_parry(input: Vector2) -> void:
	# Interrompendo una schivata non se ne può fare subito un'altra.
	if _state in [State.DODGE, State.SLIDE]:
		_dodge_cooldown = DODGE_COOLDOWN
	_interrupt_action()
	_velocity = _velocity.limit_length(walk_speed() * PARRY_SPEED_FACTOR)
	if input != Vector2.ZERO:
		_target_facing = input.normalized()
	_face_lock()
	facing = _target_facing
	_change_state(State.PARRY)


## Annulla l'azione in corso (combo, carica, attacco a terra, sorso) per
## parare, schivare o saltare subito.
func _interrupt_action() -> void:
	_end_combo()
	_charging = false
	_charge = 0.0
	_carry_velocity = Vector2.ZERO
	_walk_velocity = Vector2.ZERO
	_drinking = ""
	_running = false


## In aria la schivata è uno scatto: si smette di cadere e si scivola nell'aria.
func _set_air_dash() -> void:
	_air_dash = is_airborne()
	if _air_dash:
		_height_velocity = maxf(_height_velocity, 0.0)


## Schivata concatenata: riparte a piena velocità, nella nuova direzione.
func _chain_dodge(input: Vector2) -> void:
	if not _use_stamina(STAMINA_DODGE):
		return
	_dodges_used += 1
	_set_air_dash()
	if input != Vector2.ZERO:
		_dodge_direction = input.normalized()
		_target_facing = _dodge_direction
	Sfx.play("dodge", global_position, 1.0 + 0.1 * _dodges_used)
	_change_state(State.DODGE)


## Inizia a bere una pozione (solo fermi a terra, senza fare altro): la
## pozione si consuma subito, l'effetto arriva dopo un attimo (vedi DRINK).
func _start_drink(kind: String) -> void:
	if _state != State.NORMAL or is_airborne():
		return
	if kind == "potion":
		if potions == 0 or health >= max_health:
			return
		potions -= 1
	elif kind == "stamina_potion":
		if stamina_potions == 0 or stamina >= max_stamina:
			return
		stamina_potions -= 1
	else:
		if mana_potions == 0 or mana >= max_mana:
			return
		mana_potions -= 1
	_drinking = kind
	_end_combo()
	_change_state(State.DRINK)
	_apply_drink()


func _apply_drink() -> void:
	if _drinking == "potion":
		health = mini(health + potion_heal(), max_health)
		health_changed.emit(health, max_health)
		Sfx.play("potion", global_position)
	elif _drinking == "stamina_potion":
		stamina = minf(stamina + stamina_potion_restore(), max_stamina)
		Sfx.play("stamina_potion", global_position)
	else:
		mana = minf(mana + mana_potion_restore(), max_mana)
		Sfx.play("mana_potion", global_position)


## Velocità attuale sul terreno (i nemici la usano per capire se ci si ritira).
func ground_velocity() -> Vector2:
	return _velocity


## Sta bevendo una pozione (i nemici ne approfittano).
func is_healing() -> bool:
	return _state == State.DRINK


## Consuma vigore per un'azione; senza vigore l'azione non parte.
func _use_stamina(cost: float) -> bool:
	if stamina <= 0.0:
		_queued_attack = ""
		return false
	stamina = maxf(stamina - cost, 0.0)
	_stamina_delay = STAMINA_REGEN_DELAY
	return true


## Consumo della carica del colpo potente per un passo: mana (vedi
## HEAVY_CHARGE_MANA). Restituisce false se è finito: la carica va interrotta.
func _drain_charge(delta: float) -> bool:
	mana = maxf(mana - HEAVY_CHARGE_MANA * delta, 0.0)
	return mana > 0.0


## Tasti del mouse premuti sul mondo (non sui pulsanti dell'interfaccia,
## che li consumano prima): movimento verso il cursore e mira degli
## attacchi. I tocchi sullo schermo arrivano anche come clic emulati: lì ci
## sono già i controlli touch, quindi si ignorano.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if _state == State.DEAD or Platform.ignores_desktop_input():
		return
	if event.is_action_pressed("move_click"):
		_click_moving = true
		_click_target = _cursor_ground()
		_click_stuck = 0.0
	if event.is_action_pressed("heavy_attack") or event.is_action_pressed("attack"):
		_aim_cursor = true


## Direzione del movimento col mouse (zero se non ci si sta muovendo così):
## tenendo premuto il tasto si segue il cursore; arrivati, o bloccati da un
## ostacolo, ci si ferma.
func _click_input(delta: float) -> Vector2:
	if not _click_moving or _state == State.DEAD:
		_click_moving = false
		return Vector2.ZERO
	if Input.is_action_pressed("move_click"):
		_click_target = _cursor_ground()
	var to_target := _click_target - position
	if _state == State.NORMAL and _state_time > CLICK_STUCK_TIME and _velocity.length() < SPEED * 0.1:
		_click_stuck += delta
	else:
		_click_stuck = 0.0
	if to_target.length() <= CLICK_ARRIVE_DISTANCE or _click_stuck >= CLICK_STUCK_TIME:
		_click_moving = false
		return Vector2.ZERO
	return to_target.normalized()


## Mira col mouse: finché si tiene premuto il tasto che ha fatto partire
## l'attacco si mira al cursore.
func _update_aim() -> void:
	_aim = Vector2.ZERO
	if not _aim_cursor:
		return
	var to_cursor := _cursor_ground() - position
	if to_cursor.length() > 1.0:
		_aim = to_cursor.normalized()
	if not Input.is_action_pressed("heavy_attack") and not Input.is_action_pressed("attack"):
		_aim_cursor = false


## Punto del terreno sotto il cursore: il terreno è disegnato più in alto
## della sua altezza, quindi si cerca il punto che, sollevato, cade sotto il
## cursore (bastano pochi passi).
func _cursor_ground() -> Vector2:
	var parent := get_parent() as Node2D
	var at := parent.to_local(get_global_mouse_position()) if parent else get_global_mouse_position()
	if World.current == null:
		return at
	var point := at
	for i in 3:
		point = at + Vector2(0, World.current.elevation_at(point))
	return point


## Palla di fuoco verso dove si guarda (o si punta la levetta): poi
## insegue da sola il nemico più vicino.
func _cast_fireball(input: Vector2) -> void:
	if _spell_cooldown > 0.0:
		return
	if mana < SPELL_COST:
		_spell_cooldown = SPELL_COOLDOWN
		return
	mana -= SPELL_COST
	_spell_cooldown = SPELL_COOLDOWN
	var fireball := Fireball.new()
	fireball.direction = input.normalized() if input != Vector2.ZERO else facing
	if lock_target:
		fireball.target = lock_target
		fireball.direction = (lock_target.global_position - global_position).normalized()
	fireball.damage = spell_damage()
	fireball.altitude = ground_elevation
	fireball.position = position + fireball.direction * RADIUS
	get_parent().add_child(fireball)
	Sfx.play("fireball", global_position)


## Bombe H che si possono portare (vedi START_H_BOMB_CAPACITY).
func h_bomb_capacity() -> int:
	return START_H_BOMB_CAPACITY + int(upgrades_taken.get("h_bomb", 0))


## Pozioni di ciascun tipo che si possono portare.
func potion_capacity() -> int:
	return MAX_POTIONS + int(upgrades_taken.get("potion_slots", 0))


func potion_heal() -> int:
	return POTION_HEAL + POTION_HEAL_UPGRADE * int(upgrades_taken.get("potion_heal", 0))


func mana_potion_restore() -> float:
	return MANA_POTION_RESTORE * (1.0 + MANA_RESTORE_UPGRADE * int(upgrades_taken.get("mana_restore", 0)))


## Vigore ridato dalla pozione verde.
func stamina_potion_restore() -> float:
	return max_stamina * Items.stat("potion_stamina", "restore_stamina")


## Si può prendere l'oggetto: le pozioni solo finché la cintura non è piena.
func can_pick_up(id: String) -> bool:
	match id:
		"potion_health":
			return potions < potion_capacity()
		"potion_mana":
			return mana_potions < potion_capacity()
		"potion_stamina":
			return stamina_potions < potion_capacity()
		"h_bomb":
			return h_bombs < h_bomb_capacity()
	return true


## Raccoglie un oggetto: le monete vanno nel borsello, le pozioni di vita,
## di mana e di vigore nella cintura (fino a potion_capacity, mai nell'inventario),
## le rune del cataclisma anche (fino a h_bomb_capacity), il resto nell'inventario.
## Restituisce false se la cintura è piena.
func pickup(id: String, amount := 1) -> bool:
	if not can_pick_up(id):
		return false
	match id:
		"gold":
			inventory.gold += amount
			Sfx.play("coin", global_position)
			return true
		"potion_health":
			potions = mini(potions + amount, potion_capacity())
			Sfx.play("pickup", global_position)
			return true
		"potion_mana":
			mana_potions = mini(mana_potions + amount, potion_capacity())
			Sfx.play("pickup", global_position)
			return true
		"potion_stamina":
			stamina_potions = mini(stamina_potions + amount, potion_capacity())
			Sfx.play("pickup", global_position)
			return true
		"h_bomb":
			h_bombs = mini(h_bombs + amount, h_bomb_capacity())
			Sfx.play("pickup", global_position)
			return true
	inventory.add(id)
	Sfx.play("pickup", global_position)
	return true


## Usa un oggetto dell'inventario: indossa o toglie l'equipaggiamento,
## legge i libri (bonus permanente), beve le pozioni.
func use_item(index: int) -> void:
	var id := inventory.items[index]
	match Items.category(id):
		"book":
			inventory.learn(id)
			inventory.remove(index)
			Sfx.play("level_up", global_position, 1.3)
		"potion":
			var heal := int(Items.stat(id, "heal"))
			var restore := Items.stat(id, "restore_mana")
			if (heal > 0 and health >= max_health) or (restore > 0.0 and mana >= max_mana):
				return
			health = mini(health + heal, max_health)
			mana = minf(mana + restore, max_mana)
			health_changed.emit(health, max_health)
			inventory.remove(index)
			Sfx.play("potion" if heal > 0 else "mana_potion", global_position)
		_:
			inventory.toggle_equip(index)
			Sfx.play("block", global_position, 1.4, -8.0)
	_refresh_stats()


## Ricalcola vita e mana massimi con equipaggiamento e libri.
func _refresh_stats() -> void:
	var old_max_health := max_health
	max_health = _base_max_health + floori((level - 1) / float(HEALTH_LEVELS)) + int(inventory.bonus("health"))
	health = clampi(health + maxi(max_health - old_max_health, 0), 1 if health > 0 else 0, max_health)
	var old_max_mana := max_mana
	max_mana = _base_max_mana + inventory.bonus("mana")
	mana = clampf(mana + maxf(max_mana - old_max_mana, 0.0), 0.0, max_mana)
	health_changed.emit(health, max_health)


## L3 (o Maiusc): un tocco accende o spegne la corsa (al rilascio), tenendo
## premuto per TORCH_HOLD_TIME si accende o spegne la torcia.
func _update_run_button(delta: float) -> void:
	if UiNav.game_pressed("run"):
		_run_hold = 0.0
	elif _run_hold < 0.0:
		return
	if UiNav.game_held("run"):
		_run_hold += delta
		if _run_hold >= TORCH_HOLD_TIME:
			_run_hold = -1.0
			set_torch(not torch_on)
	else:
		_run_hold = -1.0
		_run_on = not _run_on


## Al buio con la torcia accesa il goblin si vede come di giorno: il buio
## della notte e dei sotterranei non lo scurisce (niente luci su di lui).
## Altrimenti la luce lo prende come il punto del terreno ai suoi piedi.
func update_torch_light() -> void:
	var lit := _torch.strength() >= TORCH_SELF_LIGHT
	var wanted: Material = Enemy._unshaded_material() if lit else LightShaders.feet()
	if material != wanted:
		material = wanted


func set_torch(on: bool) -> void:
	if on == torch_on:
		return
	torch_on = on
	_torch.enabled = on
	_torch.aim(facing)
	if _state != State.DEAD:
		Sfx.play("torch", global_position, 1.0 if on else 0.7)


func _raise_shield() -> void:
	if shield_active or shield_cooldown > 0.0:
		return
	shield_active = true
	shield_cooldown = shield_cooldown_max
	Sfx.play("shield_up", global_position)


func _attack_range() -> float:
	if _attack_heavy:
		return HEAVY_RANGE
	return ATTACK_RANGE


func _attack_arc() -> float:
	if _attack_heavy:
		return HEAVY_ARC
	if _air_attack:
		return AIR_ATTACK_ARC
	return ATTACK_ARC


func _attack_damage() -> int:
	var multiplier: float
	if _attack_heavy:
		# Il colpo potente prende il bonus dei colpi normali che lo precedono
		# nella combo e cresce a ogni colpo potente concatenato.
		multiplier = HEAVY_DAMAGE_FACTOR * (1.0 + COMBO_DAMAGE_STEP * _combo_step) \
				* (1.0 + HEAVY_CHAIN_DAMAGE_STEP * (_heavy_step - 1))
		# Combo mista (colpi normali e poi potente): bonus ai danni.
		if _combo_step > 0:
			multiplier *= MIXED_COMBO_DAMAGE_FACTOR
		# Primo colpo potente caricato: i concatenati dopo fanno di più.
		if _heavy_step > 1:
			multiplier *= 1.0 + CHARGED_CHAIN_BONUS * _chain_charge
	else:
		multiplier = 1.0 + COMBO_DAMAGE_STEP * (_combo_step - 1)
	if _attack_speed > 1.0:
		multiplier *= EMPOWER_DAMAGE_FACTOR
	# Carica del colpo potente (fino al doppio) e bonus dell'arma.
	multiplier *= (1.0 + _charge) * (1.0 + inventory.bonus("damage"))
	return roundi(base_damage() * multiplier)


func _resolve_attack() -> void:
	var damage := _attack_damage()
	# La carica del primo colpo potente resta per i colpi potenti concatenati.
	if _attack_heavy and _heavy_step == 1:
		_chain_charge = _charge
	var heavy := _attack_heavy or _combo_step >= max_combo_hits
	var landed := false
	# In aria si arriva anche ai nemici sotto di sé.
	var reach_below := AIR_ATTACK_REACH if _air_attack or is_airborne() else HIT_HEIGHT_REACH
	var blocked_by: Enemy = null
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var rise := altitude() - enemy.ground_elevation
		if rise < -HIT_HEIGHT_REACH or rise > reach_below:
			continue
		var offset := enemy.global_position - global_position
		if offset.length() > _attack_range() + enemy.radius:
			continue
		# A contatto si colpisce sempre, altrimenti serve essere girati verso il nemico.
		if offset.length() <= RADIUS + enemy.radius or absf(facing.angle_to(offset)) <= _attack_arc() / 2.0:
			if enemy.blocks(global_position):
				# La guardia para il colpo: lampo nel punto d'incontro.
				blocked_by = enemy
				HitSpark.spawn(get_parent(), enemy.global_position - offset.normalized() * (enemy.radius + 10.0),
						enemy.ground_elevation + enemy.radius * 0.9, 56.0, COLOR_GUARD_SPARK)
				continue
			enemy.take_damage(damage, offset.normalized(), heavy)
			landed = true
			# Scintilla nel punto di contatto, sul lato del nemico rivolto verso di noi.
			var contact := enemy.global_position - offset.normalized() * enemy.radius * 0.8
			HitSpark.spawn(get_parent(), contact, enemy.ground_elevation + enemy.radius * 0.9,
					40.0 if _attack_heavy else 28.0, COLOR_HEAVY if _attack_heavy else COLOR_SLASH)
	# Ogni colpo a segno carica la Frenesia, anche se la guardia l'ha parato.
	if landed or blocked_by:
		_add_frenzy(FRENZY_PER_HEAVY if _attack_heavy else FRENZY_PER_HIT)
	if blocked_by:
		_repel(blocked_by.global_position)
	if landed:
		Sfx.play("hit", global_position, 0.8 if _attack_heavy else 1.0 + 0.1 * (_combo_step - 1))
		# Un attimo di fermo: si sente il colpo (più lungo per il colpo potente).
		if _attack_heavy:
			HitFeedback.hit(get_tree(), 0.12 + 0.05 * _charge)
		else:
			HitFeedback.hit(get_tree(), 0.1 if _combo_step >= max_combo_hits else 0.09)


func _draw() -> void:
	var body := COLOR_BODY
	if _state == State.DEAD:
		body = COLOR_DEAD
	elif _state == State.HURT:
		body = COLOR_HURT
	# Precipitando in un burrone svanisce nel buio.
	self_modulate.a = 1.0 - clampf(_state_time / FALL_TIME, 0.0, 1.0) if _state == State.FALL else 1.0

	# L'ombra resta a terra e si rimpicciolisce durante il salto; tutto il
	# resto sale con il personaggio. In scivolata il corpo si schiaccia.
	var shadow_scale := clampf(1.0 - _height / 160.0, 0.5, 1.0)
	Shapes.disc(self, Vector2(0, RADIUS * 0.8 - ground_elevation), RADIUS * 0.9 * shadow_scale, Color(0, 0, 0, 0.25))
	var body_scale := Vector2(1.2, 0.6) if _state == State.SLIDE else Vector2.ONE
	var lift := -altitude() + (RADIUS * 0.4 if _state == State.SLIDE else 0.0)
	# Caricando lo slam aereo si ondeggia piano a mezz'aria.
	if is_air_charging():
		lift += sin(_charge_time * 5.0) * AIR_SLAM_BOB
	if LowHealthVignette.focus_held() and _state != State.DEAD:
		Shapes.glow(self, Vector2(0, lift - RADIUS * FOCUS_AURA_HEIGHT), RADIUS * FOCUS_AURA_RADIUS, COLOR_FOCUS_AURA)
	draw_set_transform(Vector2(0, lift), 0.0, body_scale)
	# Gambe: camminano quando ci si muove, raccolte in aria e in scivolata.
	var walking := _velocity.length() > 20.0 and not is_airborne() and _state != State.DEAD
	var rolling := _state == State.DODGE and not _air_dash
	var dashing := _state == State.DODGE and _air_dash
	if dashing:
		# Scatto in aria: immagini che restano indietro lungo la traiettoria.
		for k in range(AIR_DASH_TRAIL, 0, -1):
			Shapes.disc(self, -_dodge_direction * k * 16.0 + Vector2(0, -LEG_LENGTH), RADIUS * (1.0 - 0.15 * k), Color(body, 0.35 / k))
	if _state == State.SPECIAL:
		_draw_special_streak(body)
	if _state != State.SLIDE and not rolling:
		var foot_y := RADIUS * 0.85 - (6.0 if is_airborne() else 0.0)
		BodyParts.draw_legs(self, -LEG_LENGTH + RADIUS * 0.55, foot_y, LEG_SPACING, LEG_WIDTH, _walk_phase,
				_velocity.normalized(), STRIDE if walking else 0.0, body.darkened(0.35))
	# Il corpo ondeggia camminando, si inclina nella direzione di corsa, si
	# allunga salendo e si schiaccia atterrando.
	var bob := absf(sin(_walk_phase)) * 2.5 if walking else 0.0
	var lean := clampf(_velocity.x / run_speed(), -1.0, 1.0) * LEAN_ANGLE if _state != State.DEAD else 0.0
	var squash := Vector2(1.0 + SQUASH_AMOUNT * _squash, 1.0 - SQUASH_AMOUNT * _squash)
	if _height_velocity > 200.0:
		squash = Vector2(0.92, 1.08)
	var rotation_angle := lean
	var body_lift := lift - LEG_LENGTH - bob
	if rolling:
		# Capriola: il corpo raccolto fa un giro completo nel verso del movimento.
		var t := clampf(_state_time / DODGE_TIME, 0.0, 1.0)
		rotation_angle = TAU * ease(t, 0.7) * (1.0 if _dodge_direction.x >= 0.0 else -1.0)
		body_lift = lift - LEG_LENGTH * ROLL_CURL
		squash = Vector2(1.05, 0.92)
	elif dashing:
		squash = Vector2(1.15, 0.88)
	var pose := _attack_body_pose()
	rotation_angle += pose[0]
	squash *= pose[1]
	draw_set_transform(Vector2(0, body_lift), rotation_angle, body_scale * squash)

	# Aura del potenziamento, corpo e "naso" che indica la direzione.
	if is_empowered() and _state != State.DEAD:
		var pulse := 0.5 + 0.5 * sin(_empowered_time * 10.0)
		Shapes.disc(self, Vector2.ZERO, RADIUS + 8.0 + pulse * 4.0, Color(COLOR_EMPOWERED, 0.25))
		draw_arc(Vector2.ZERO, RADIUS + 8.0 + pulse * 4.0, 0.0, TAU, 32, Color(COLOR_EMPOWERED, 0.8), 2.0)
	if _state == State.SPECIAL:
		_draw_special_aura()
	elif is_frenzy_full() and _state != State.DEAD:
		# Frenesia piena: un anello rosso che pulsa, pronto per L1 + R1.
		var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		draw_arc(Vector2.ZERO, RADIUS + 5.0 + beat * 3.0, 0.0, TAU, 32, Color(COLOR_FRENZY, 0.45 + 0.35 * beat), 2.5)
	if _state != State.DEAD:
		body = _blood.tint(body)
		if soot > 0.0:
			body = Color(body.lerp(COLOR_SOOT, soot * SOOT_STRENGTH), body.a)
	# Guardando verso nord il "naso", la spada, la torcia e le fiaschette
	# sono dietro al corpo, che li copre (vedi BodyParts.gear_behind).
	var behind := BodyParts.gear_behind(facing)
	if behind:
		_draw_gear(body)
	Shapes.disc(self, Vector2.ZERO, RADIUS, body)
	_blood.draw(self, RADIUS, body.a)
	_wounds.draw(self, RADIUS, body.a)
	if not behind:
		_draw_gear(body)

	# Scudo attivo: una bolla attorno al personaggio.
	if shield_active and _state != State.DEAD:
		Shapes.disc(self, Vector2.ZERO, RADIUS + 16.0, Color(COLOR_BUBBLE, 0.15))
		draw_arc(Vector2.ZERO, RADIUS + 16.0, 0.0, TAU, 40, Color(COLOR_BUBBLE, 0.7), 2.5)
	if holding_h_bomb():
		_draw_h_bomb()
	draw_set_transform(Vector2.ZERO)


## Sta reggendo la runa sopra la testa (picchiata non ancora arrivata a terra).
func holding_h_bomb() -> bool:
	return _state == State.SLAM and _slam_kind == "plunge" and not _slam_landed


## Runa sopra la testa, sempre davanti a tutto (è più in alto del
## corpo): in carica l'anello si riempie e la runa si accende.
func _draw_h_bomb() -> void:
	if _charging and _charge > 0.0:
		_draw_charge_ring()
	var glow := _charge if _charging else 0.0
	HBombBlast.draw_bomb(self, H_BOMB_HELD, H_BOMB_LENGTH, glow, facing.x < 0.0)


## "Naso" che indica la direzione e, da vivo, la spada, la fiaschetta in
## uso e la lanterna.
func _draw_gear(body: Color) -> void:
	var tip := facing * (RADIUS + 12.0)
	var side := facing.orthogonal() * 9.0
	draw_primitive(PackedVector2Array([tip, facing * RADIUS * 0.6 + side, facing * RADIUS * 0.6 - side]), PackedColorArray([body.darkened(0.3)]), PackedVector2Array())
	if _state != State.DEAD:
		_draw_sword()
		if _state == State.DRINK:
			_draw_flask()
		if torch_on and not holding_h_bomb():
			_draw_torch()


## Bevendo: la fiaschetta (rossa, blu o verde) sale alla bocca e si inclina.
func _draw_flask() -> void:
	var color := COLOR_MANA_FLASK
	if _drinking == "potion":
		color = COLOR_HEALTH_FLASK
	elif _drinking == "stamina_potion":
		color = COLOR_STAMINA_FLASK
	var t := clampf(_state_time / DRINK_EFFECT_TIME, 0.0, 1.0)
	var at := facing * RADIUS * lerpf(1.2, 0.7, t) + Vector2(0, lerpf(4.0, -8.0, t))
	var neck := Vector2.from_angle(-PI / 2.0 + facing.x * 1.2 * t) * 10.0
	draw_line(at, at + neck, Color(0.85, 0.8, 0.7), 4.0)
	Shapes.disc(self, at, 7.5, Color(0, 0, 0, 0.6))
	Shapes.disc(self, at, 6.0, color)
	Shapes.disc(self, at + Vector2(-2, -2), 2.0, Color(1, 1, 1, 0.6))


## Spada: a riposo è tenuta di lato; nell'attacco si porta indietro durante
## la carica e poi fende l'arco del colpo, alternando il verso a ogni
## attacco, lasciando una scia.
func _draw_sword() -> void:
	var tint := Color.WHITE
	if inventory.equipped.has("weapon"):
		tint = Items.color(inventory.items[inventory.equipped["weapon"]]).lightened(0.3)
	if is_empowered():
		tint = Color(1.0, 0.95, 0.7)
	if _state == State.SLAM and _slam_kind == "plunge":
		# Con la runa la spada sparisce: la runa è sopra la testa (vedi
		# _draw_h_bomb) e, dopo l'impatto, le mani restano vuote.
		return
	if _state == State.SLAM:
		_draw_slam_sword(tint)
		return
	if _state == State.SPECIAL:
		_draw_special_sword()
		return
	if _state == State.PARRY:
		# In parata la spada è di traverso davanti al corpo: si illumina
		# all'inizio (quando la parata sarebbe perfetta) e quando para un colpo.
		var across := -facing.orthogonal()
		var center := facing * RADIUS * 0.95
		if _state_time <= PERFECT_PARRY_WINDOW or _block_flash > 0.0:
			tint = Color(1.3, 1.3, 1.4)
		BodyParts.draw_sword(self, center - across * SWORD_LENGTH * 0.45, across.angle(), SWORD_LENGTH, SWORD_WIDTH, tint)
		return
	if _state != State.ATTACK:
		var rest := facing.angle() + 0.6
		BodyParts.draw_sword(self, facing.orthogonal() * RADIUS * 0.8, rest, SWORD_LENGTH, SWORD_WIDTH, tint)
		return
	if not _attack_heavy and not _air_attack:
		_draw_attack_sword(tint)
		return
	var windup := (HEAVY_WINDUP if _attack_heavy else ATTACK_WINDUP) / _attack_speed
	var active := (HEAVY_ACTIVE if _attack_heavy else ATTACK_ACTIVE) / _attack_speed
	var arc := _attack_arc()
	var start := facing.angle() - _swing_sign * arc / 2.0
	var end := facing.angle() + _swing_sign * arc / 2.0
	var angle := end
	if _state_time < windup:
		# Carica: la spada si porta un po' più indietro.
		angle = start - _swing_sign * 0.35 * _state_time / windup
		if _attack_heavy:
			draw_arc(Vector2.ZERO, RADIUS + 6.0, facing.angle() - arc / 2.0, facing.angle() + arc / 2.0, 24, Color(COLOR_HEAVY, _state_time / windup), 4.0)
			if _charge > 0.0:
				_draw_charge_ring()
	elif _state_time < windup + active:
		angle = lerpf(start, end, ease((_state_time - windup) / active, 0.6))
		var slash := COLOR_HEAVY if _attack_heavy else COLOR_SLASH
		if _attack_speed > 1.0:
			slash = COLOR_EMPOWERED
		# I colpi successivi della combo hanno una scia più accesa.
		var alpha := 0.85 if _attack_heavy else 0.5 + 0.15 * (_combo_step - 1)
		BodyParts.draw_trail(self, Vector2.ZERO, start, angle, RADIUS + 6.0, _attack_range() + RADIUS, Color(slash, minf(alpha, 0.9)))
	var length := HEAVY_SWORD_LENGTH if _attack_heavy else SWORD_LENGTH
	BodyParts.draw_sword(self, Vector2.from_angle(angle) * RADIUS * 0.8, angle, length, SWORD_WIDTH * (1.3 if _attack_heavy else 1.0), tint)
	if _attack_heavy and _charging:
		_draw_charge_magic(Vector2.from_angle(angle) * RADIUS * 0.8, angle, length)


## Colpo normale a terra: carica (la spada si porta indietro e la punta
## luccica), colpo con la scia e accompagnamento che si spegne tornando in
## guardia. Il movimento cambia a ogni colpo (ATTACK_STYLES), l'area colpita
## è sempre la stessa, mostrata da un velo chiaro mentre si colpisce.
func _draw_attack_sword(tint: Color) -> void:
	var windup := ATTACK_WINDUP / _attack_speed
	var active := ATTACK_ACTIVE / _attack_speed
	var recovery := _attack_recovery() / _attack_speed
	var phase := 0
	var t := clampf(_state_time / windup, 0.0, 1.0)
	if _state_time >= windup + active:
		phase = 2
		t = clampf((_state_time - windup - active) / recovery, 0.0, 1.0)
	elif _state_time >= windup:
		phase = 1
		t = (_state_time - windup) / active
	var forward := facing.angle()
	var half := ATTACK_ARC / 2.0
	var reach := _attack_range() + RADIUS
	var slash := COLOR_EMPOWERED if _attack_speed > 1.0 else COLOR_SLASH
	var trail_alpha := minf(0.55 + 0.12 * (_combo_step - 1), 0.9)
	var rest := forward + 0.6
	var angle := forward
	var hand := Vector2.ZERO
	var length := SWORD_LENGTH
	match ATTACK_STYLES[_attack_style]:
		"slash", "backhand":
			# Fendente da un lato all'altro (il rovescio nel verso opposto).
			var side := 1.0 if ATTACK_STYLES[_attack_style] == "slash" else -1.0
			var from := forward - side * half
			var to := forward + side * half
			match phase:
				0:
					angle = lerp_angle(rest, from - side * 0.6, ease(t, 0.5))
				1:
					angle = lerpf(from - side * 0.6, to, ease(t, 0.45))
					BodyParts.draw_trail(self, Vector2.ZERO, from, clampf(angle, minf(from, to), maxf(from, to)), RADIUS + 6.0, reach, Color(slash, trail_alpha))
				2:
					# Accompagnamento oltre la fine dell'arco, poi in guardia.
					angle = lerpf(to, to + side * 0.4, ease(minf(t / 0.35, 1.0), 0.5)) if t < 0.35 \
							else lerp_angle(to + side * 0.4, rest, ease((t - 0.35) / 0.65, 2.0))
					BodyParts.draw_trail(self, Vector2.ZERO, from, to, RADIUS + 6.0, reach, Color(slash, trail_alpha * 0.5 * (1.0 - t)))
			hand = Vector2.from_angle(angle) * RADIUS * 0.8
		"chop":
			# Dall'alto: la spada si alza sopra la testa e cala in avanti.
			var up := -PI / 2.0
			var down := up + wrapf(forward - up, -PI, PI)
			match phase:
				0:
					angle = lerp_angle(rest, up - 0.25, ease(t, 0.5))
					hand = Vector2(0, -RADIUS * 0.9 * ease(t, 0.5))
				1:
					angle = lerpf(up - 0.25, down, ease(t, 0.35))
					hand = Vector2(0, -RADIUS * 0.9 * (1.0 - t)) + facing * RADIUS * 0.6 * t
					length = SWORD_LENGTH * (1.0 + 0.15 * t)
					BodyParts.draw_trail(self, Vector2.ZERO, up, angle, RADIUS * 0.5, reach, Color(slash, trail_alpha * 0.8))
				2:
					angle = down if t < 0.4 else lerp_angle(down, rest, ease((t - 0.4) / 0.6, 2.0))
					hand = facing * RADIUS * 0.6 * (1.0 - t)
					length = SWORD_LENGTH * 1.15
			if hand == Vector2.ZERO:
				hand = Vector2.from_angle(angle) * RADIUS * 0.8
		"thrust":
			# Affondo: la spada si ritrae, poi scatta dritta in avanti.
			var side_offset := facing.orthogonal() * RADIUS * 0.5
			match phase:
				0:
					angle = lerp_angle(rest, forward, ease(t, 0.5))
					hand = side_offset - facing * RADIUS * 0.5 * ease(t, 0.5)
				1:
					angle = forward
					hand = side_offset.lerp(Vector2.ZERO, t) + facing * lerpf(-RADIUS * 0.5, RADIUS * 0.9, ease(t, 0.3))
					length = SWORD_LENGTH * (1.0 + 0.3 * t)
					# Scia dritta lungo la lama.
					var tip := hand + facing * length
					var width := facing.orthogonal() * 7.0 * (1.0 - t * 0.5)
					draw_primitive(PackedVector2Array([facing * RADIUS * 0.5 + width, tip + width * 0.3, tip - width * 0.3, facing * RADIUS * 0.5 - width]),
							PackedColorArray([Color(slash, trail_alpha)]), PackedVector2Array())
				2:
					angle = forward if t < 0.3 else lerp_angle(forward, rest, ease((t - 0.3) / 0.7, 2.0))
					hand = facing * RADIUS * 0.9 * (1.0 - t)
					length = SWORD_LENGTH * (1.3 - 0.3 * t)
	# Area colpita: un velo chiaro su tutto l'arco, uguale per ogni movimento.
	if phase == 1:
		BodyParts.draw_trail(self, Vector2.ZERO, forward - half, forward + half, RADIUS + 6.0, reach, Color(slash, 0.16 * (1.0 - t)))
	BodyParts.draw_sword(self, hand, angle, length, SWORD_WIDTH, tint)
	# Alla fine della carica la punta della spada luccica.
	if phase == 0 and t > 0.6:
		var tip := hand + Vector2.from_angle(angle) * length
		var glint := (t - 0.6) / 0.4
		draw_line(tip - Vector2(7, 0) * glint, tip + Vector2(7, 0) * glint, Color(1, 1, 1, glint), 2.0)
		draw_line(tip - Vector2(0, 7) * glint, tip + Vector2(0, 7) * glint, Color(1, 1, 1, glint), 2.0)


## Il corpo accompagna i colpi normali a terra: ruota con fendente e
## rovescio, si allunga caricando il colpo dall'alto e si schiaccia
## calandolo. Restituisce la rotazione in più e la scala.
func _attack_body_pose() -> Array:
	if _state != State.ATTACK or _attack_heavy or _air_attack:
		return [0.0, Vector2.ONE]
	var windup := ATTACK_WINDUP / _attack_speed
	var active := ATTACK_ACTIVE / _attack_speed
	var style: String = ATTACK_STYLES[_attack_style]
	var side := 1.0 if style == "slash" else -1.0
	var screen_side := side * (1.0 if facing.x >= 0.0 else -1.0)
	if _state_time < windup:
		var t := ease(_state_time / windup, 0.5)
		if style == "chop":
			return [0.0, Vector2(1.0 - 0.06 * t, 1.0 + 0.08 * t)]
		if style == "thrust":
			return [0.0, Vector2(1.0 + 0.05 * t, 1.0 - 0.04 * t)]
		return [-screen_side * ATTACK_TWIST * t, Vector2.ONE]
	var t := clampf((_state_time - windup) / (active * 2.0), 0.0, 1.0)
	if style == "chop":
		return [0.0, Vector2(1.0 + 0.1 * (1.0 - t), 1.0 - 0.1 * (1.0 - t))]
	if style == "thrust":
		return [0.0, Vector2.ONE]
	return [screen_side * ATTACK_TWIST * (1.0 - t), Vector2.ONE]


## Attacco a terra: spada alzata sopra la testa in salita, che cala con una
## scia scendendo e resta piantata nel terreno dopo l'impatto. Gli angoli
## sono pensati guardando a destra e specchiati guardando a sinistra.
func _draw_slam_sword(tint: Color) -> void:
	var mirror := facing.x < 0.0
	var raised := -PI / 2.0 - 0.5
	var down := PI / 2.0 - 0.35
	var angle := raised
	if _charging and _charge > 0.0:
		_draw_charge_ring()
	if _slam_landed:
		angle = down
	elif _height_velocity < 0.0:
		angle = lerpf(raised, down, clampf(-_height_velocity / 900.0, 0.0, 1.0))
		var start := PI - raised if mirror else raised
		var end := PI - angle if mirror else angle
		BodyParts.draw_trail(self, Vector2.ZERO, start, end, RADIUS + 6.0, HEAVY_SWORD_LENGTH + RADIUS, Color(COLOR_HEAVY, 0.7))
	if mirror:
		angle = PI - angle
	BodyParts.draw_sword(self, Vector2.from_angle(angle) * RADIUS * 0.8, angle, HEAVY_SWORD_LENGTH, SWORD_WIDTH * 1.3, tint)
	if _charging:
		_draw_charge_magic(Vector2.from_angle(angle) * RADIUS * 0.8, angle, HEAVY_SWORD_LENGTH)


## Attacco speciale: nella cinematica un bagliore rosso che cresce e pulsa
## con i raggi dell'urlo; durante i colpi un alone più piccolo.
func _draw_special_aura() -> void:
	var t := _state_time
	if t >= SPECIAL_INTRO_TIME:
		Shapes.glow(self, Vector2.ZERO, RADIUS * 1.9, Color(COLOR_FRENZY, 0.35))
		return
	var grow := clampf(t / 0.25, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(t * 30.0)
	Shapes.glow(self, Vector2.ZERO, RADIUS * (2.0 + 0.8 * grow + 0.3 * pulse), Color(COLOR_FRENZY, 0.6 * grow))
	for k in 12:
		var direction := Vector2.from_angle(TAU * k / 12.0 + t * 2.0)
		var length := RADIUS * (0.5 + 0.6 * grow * (0.6 + 0.4 * sin(t * 24.0 + k * 1.7)))
		draw_line(direction * (RADIUS + 6.0), direction * (RADIUS + 6.0 + length), Color(1.0, 0.75, 0.35, 0.85 * grow), 3.0)


## Scia del teletrasporto: dal punto di partenza al goblin, copie del corpo
## che svaniscono prima del colpo successivo.
func _draw_special_streak(body: Color) -> void:
	var fade := 1.0 - clampf((_state_time - _special_last_hit) / SPECIAL_HIT_INTERVAL, 0.0, 1.0)
	if fade <= 0.0 or _special_from == Vector2.ZERO:
		return
	var lift := Vector2(0, -LEG_LENGTH)
	draw_line(_special_from + lift, lift, Color(COLOR_FRENZY, 0.5 * fade), RADIUS * 1.2 * fade)
	for k in 4:
		Shapes.disc(self, _special_from.lerp(Vector2.ZERO, k / 4.0) + lift, RADIUS * (0.7 + 0.075 * k), Color(body, 0.25 * fade * (k + 1) / 4.0))


## Spada dell'attacco speciale: rovente, alzata sopra la testa nella
## cinematica, poi un fendente ampio con la scia rossa a ogni colpo.
func _draw_special_sword() -> void:
	var heat := Color(1.4, 0.75, 0.6)
	if _state_time < SPECIAL_INTRO_TIME:
		var raised := -PI / 2.0 - 0.5
		if facing.x < 0.0:
			raised = PI - raised
		BodyParts.draw_sword(self, Vector2.from_angle(raised) * RADIUS * 0.8, raised, HEAVY_SWORD_LENGTH, SWORD_WIDTH * 1.3, heat)
		return
	var t := clampf((_state_time - _special_last_hit) / (SPECIAL_HIT_INTERVAL * 0.6), 0.0, 1.0)
	var start := facing.angle() - _swing_sign * HEAVY_ARC / 2.0
	var end := facing.angle() + _swing_sign * HEAVY_ARC / 2.0
	var angle := lerpf(start, end, ease(t, 0.5))
	BodyParts.draw_trail(self, Vector2.ZERO, start, angle, RADIUS + 6.0, ATTACK_RANGE + RADIUS, Color(COLOR_FRENZY, 0.75 * (1.0 - t * 0.5)))
	BodyParts.draw_sword(self, Vector2.from_angle(angle) * RADIUS * 0.8, angle, HEAVY_SWORD_LENGTH, SWORD_WIDTH * 1.3, heat)


## Carica del colpo potente: un anello che si riempie e diventa bianco al massimo.
func _draw_charge_ring() -> void:
	var ring := Color.WHITE if _charge >= 1.0 else COLOR_CHARGE_GLOW
	draw_arc(Vector2.ZERO, RADIUS + 14.0, -PI / 2.0, -PI / 2.0 + TAU * _charge, 32, ring, 4.0)


## Magia della carica sulla spada (hand: impugnatura, angle: direzione
## della lama): un alone azzurro lungo la lama che pulsa e cresce con la
## carica, scintille che le girano attorno salendo verso la punta e una
## punta che brilla; a carica piena tutto diventa bianco, con un lampo.
func _draw_charge_magic(hand: Vector2, angle: float, length: float) -> void:
	var along := Vector2.from_angle(angle)
	var across := along.orthogonal()
	var power := 0.25 + 0.75 * _charge
	var pulse := 0.5 + 0.5 * sin(_charge_time * 14.0)
	var color := Color.WHITE if _charge >= 1.0 else COLOR_CHARGE_GLOW
	Shapes.glow(self, hand + along * length * 0.6, length * (0.55 + 0.25 * power), Color(color, 0.25 + 0.3 * power))
	for k in 5:
		var at := hand + along * length * (0.25 + 0.18 * k)
		Shapes.disc(self, at, (6.0 + 5.0 * power) * (1.0 + 0.15 * pulse), Color(color, 0.1 + 0.12 * power))
	for k in 6:
		var t := fposmod(_charge_time * 1.6 + k / 6.0, 1.0)
		var swirl := sin(_charge_time * 9.0 + k * 2.1) * (10.0 + 8.0 * power) * (1.0 - t * 0.5)
		Shapes.disc(self, hand + along * length * t + across * swirl, 2.5 + 2.0 * power, Color(color.lightened(0.6), 1.0 - 0.7 * t))
	var tip := hand + along * length
	Shapes.disc(self, tip, (5.0 + 6.0 * power) * (0.8 + 0.4 * pulse), Color(color, 0.45))
	Shapes.disc(self, tip, 2.5 + 2.0 * power, Color(1, 1, 1, 0.9))
	if _charge >= 1.0:
		var flash := 10.0 + 6.0 * pulse
		draw_line(tip - Vector2(flash, 0), tip + Vector2(flash, 0), Color(1, 1, 1, 0.9), 2.0)
		draw_line(tip - Vector2(0, flash), tip + Vector2(0, flash), Color(1, 1, 1, 0.9), 2.0)


## Torcia nell'altra mano: bastone e fiamma che tremola.
func _draw_torch() -> void:
	var hand := -facing.orthogonal() * RADIUS * 0.9
	var top := hand + Vector2(0, -18)
	draw_line(hand + Vector2(0, 6), top, Color(0.4, 0.26, 0.14), 4.0)
	var flicker := randf_range(0.85, 1.15)
	Shapes.disc(self, top + Vector2(0, -4), 7.0 * flicker, Color(COLOR_FLAME, 0.85))
	Shapes.disc(self, top + Vector2(0, -6), 4.0 * flicker, Color(1.0, 0.95, 0.6))
