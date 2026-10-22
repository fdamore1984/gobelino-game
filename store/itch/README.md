# Pagina itch.io di Gobelino

Testi e immagini della pagina https://fdamore1984.itch.io/gobelino, allineati
all'ultima versione del gioco. Vanno aggiornati a ogni modifica che cambia ciò
che il gioco fa o mostra (vedi `CLAUDE.md`).

itch.io non ha un'API per modificare la pagina: `butler` carica solo le build.
Testi e immagini si inseriscono a mano da **Dashboard → Gobelino → Edit game**.

Le immagini si rigenerano con lo strumento di cattura (serve una finestra):

```bash
godot --path . --resolution 1280x720 res://tools/store_capture.tscn -- screenshots
godot --path . --resolution 1260x1000 res://tools/store_capture.tscn -- cover
```

---

## Campi della pagina

| Campo su itch.io | Valore |
|---|---|
| Kind of project | Downloadable |
| Release status | Prototype |
| Pricing | No payments (oppure "Donate" se vuoi accettare offerte) |
| Uploads | Caricato dalla CI con butler solo il canale `linux`: in *Edit game → Uploads* spunta la piattaforma Linux. I vecchi caricamenti `windows` e `android` vanno eliminati dalla stessa pagina |
| Genre | Role Playing |
| Tags | vedi sotto |
| AI generation disclosure | Sì: codice, testi e grafica provvisoria sono stati prodotti con l'aiuto di un'IA (Claude) |
| Languages | English, Italian |
| Inputs | Keyboard, Xbox controller, Playstation controller |
| Cover image | `cover_en.png` (630×500) |
| Screenshots | `en_1_combat.png`, `en_2_parry.png`, `en_5_challenge.png`, `en_6_inventory.png`, `en_3_level_up.png`, `en_4_menu.png` (le versioni `it_` sono le stesse in italiano) |

### Tags

Su itch.io se ne possono mettere al massimo 10:

```
action-rpg, fantasy, medieval, goblins, isometric, 2d, controller, singleplayer, procedural-generation, prototype
```

---

## Short description or tagline

```
A feral goblin, a world to explore, real-time combat. · Un goblin selvatico, un mondo da esplorare, combattimenti in tempo reale.
```

---

## Description

Da incollare così com'è nel campo *Description* (l'editor accetta il testo
formattato; i titoli si possono rendere in grassetto).

```
🇬🇧 ENGLISH

Gobelino is a 2D medieval fantasy action RPG with an isometric view.

You are a lone goblin with no past, living in a den like a wild animal. Starting from the woods around your den, you will explore the world beyond, grow stronger and meet those who will open new paths for you.

⚠️ This is a prototype build: characters and enemies are placeholder geometric shapes and the sounds are synthesized placeholders. It's here to test the combat.

IN THIS PROTOTYPE
- A boundless, randomly generated 3D isometric world made of blocks: grassy platforms stacked in steps at different heights, sloping ramps and dirt paths. Jump to climb onto higher blocks (multiple jumps reach the tallest ones) and drop down to lower ground. Here and there trees, rocks, bushes and thorny brambles (bushes and brambles slow you down, brambles prick)
- Real-time combat: chain up to 3 attacks in a combo, each hit stronger than the last, and finish it with a power strike for a big bonus
- Parry, and time it right before the hit for a perfect parry: the enemy is stunned and your attacks are empowered for a few seconds (double damage, faster swings)
- Dodge with a roll on the ground or an air dash mid-jump, steer it while dodging, and press again mid-dodge to chain another one. Dodge and parry are always available and cancel your combo; attacking cancels a dodge into an immediate strike. You can keep moving while attacking: every strike is a sword slash, alternating left and right
- Jump over enemy attacks (unlock multiple jumps in mid-air) and combine jumps with dodges
- Hold R2 to run; dodge while running to slide, and attack, dodge, jump or parry out of the slide
- Healing potions (you start with 2) and a magic shield that absorbs one hit, recharging in 30 seconds
- Eight kinds of enemies: quick scouts, warriors, heavy brutes, summoners that call in reinforcements (hit them while they summon to interrupt them), lancers with long thrusts, whirlers that strike all around, huge golems and casters that hurl magic bolts from afar
- Enemies circle around you with quick sidesteps; their sword slashes are slow and wide but unpredictable: watch them wind up (they light up and pull back their weapon), beware of feints and follow-up strikes
- Hold the power strike to charge it up to double damage; every hit you land shakes the controller, freezes the action for an instant, throws sparks and knocks the enemy back. Whatever blocks your way (rocks, trees, chests, walls too high to climb) lights up while you bump into it
- Cast fireballs that seek out and chase the nearest enemy (they cost mana: drink mana potions to refill)
- Day turns to night: light your torch to see in the dark. A minimap shows the area around you, enemies as red dots, chests and totems
- Open chests to find gold, weapons, armor, boots, amulets, rings, spell books and potions; equip them, read the books and drink the potions from your inventory
- Stone totems stand in the middle of wide open arenas: touch one to start a 30-second survival challenge with waves of enemies matched to your level, and earn experience and a potion
- Earn experience to level up: every level raises your base damage and lets you choose an upgrade: one more combo hit, one more chained power strike, one more chained dodge, one more jump, one more health point, one more potion, a faster shield recharge, a faster run, more mana or a stronger spell, picked from a grid of cards with icons. Your skill levels are always shown on screen, and the active power-ups are listed on the right

CONTROLS
- Move: left stick / WASD / on-screen stick
- Attack (combo): R1 / J
- Power strike (ends the combo; hold to charge): L2 / L
- Parry (hold): L1 / K
- Dodge (press again to chain): B / Space
- Jump: A / F
- Run (hold; dodge while running = slide): R2 / Shift
- Fireball: X / U
- Shield: Y / R
- Potion: D-pad left / Q
- Mana potion: D-pad right / T
- Torch: D-pad down / G
- Inventory: D-pad up / I
- Menu: Start / Esc

Play with a controller (Steam Deck built-in controls included) or keyboard. Available in English and Italian.

PLATFORMS
Linux and SteamOS (Steam Deck).

--------------------------------------------------------------

🇮🇹 ITALIANO

Gobelino è un RPG d'azione 2D fantasy medievale con visuale isometrica.

Sei un goblin solitario e senza passato, che vive in una tana come un animale selvatico. Partendo dai dintorni della tana esplorerai il mondo che ti circonda, diventerai più forte e incontrerai chi ti aprirà nuove strade.

⚠️ Questa è una build di prototipo: personaggi e nemici sono forme geometriche provvisorie e i suoni sono provvisori, sintetizzati. Serve a provare il combattimento.

IN QUESTO PROTOTIPO
- Un mondo isometrico 3D senza confini, fatto di blocchi e generato a caso: piattaforme d'erba a gradini su diverse altezze, rampe inclinate e sentieri sterrati. Salta per salire sui blocchi più alti (con più salti in aria raggiungi i più alti) e lasciati cadere verso quelli più bassi. Qua e là alberi, sassi, cespugli e rovi spinosi (cespugli e rovi rallentano, i rovi pungono)
- Combattimento in tempo reale: concatena fino a 3 attacchi in combo, ogni colpo più forte del precedente, e chiudila con un colpo potente per un grosso bonus
- Para, e fallo appena prima del colpo per una parata perfetta: il nemico resta stordito e i tuoi attacchi sono potenziati per qualche secondo (doppio danno, colpi più rapidi)
- Schiva con una capriola a terra o uno scatto in aria durante il salto, cambia direzione durante la schivata, e premi di nuovo per concatenarne un'altra. Schivata e parata sono sempre disponibili e interrompono la combo; attaccare interrompe la schivata con un colpo immediato. Mentre attacchi puoi continuare a muoverti: ogni colpo è un fendente di spada, alternato da sinistra e da destra
- Salta per evitare gli attacchi dei nemici (sblocca più salti in aria) e combina salti e schivate
- Tieni premuto R2 per correre; schiva mentre corri per una scivolata, da cui puoi attaccare, schivare, saltare o parare
- Pozioni curative (ne hai 2 all'inizio) e uno scudo magico che assorbe un colpo e si ricarica in 30 secondi
- Otto tipi di nemici: esploratori rapidi, guerrieri, bruti corazzati, evocatori che chiamano rinforzi (colpiscili mentre evocano per interromperli), lancieri con affondi lunghi, rotanti che colpiscono tutto attorno, golem enormi e lanciatori che scagliano dardi magici da lontano
- I nemici ti girano attorno con scatti laterali; i loro fendenti di spada sono lenti e ampi ma imprevedibili: guardali caricare (si accendono e portano indietro l'arma), attento alle finte e ai secondi colpi
- Tieni premuto il colpo potente per caricarlo fino al doppio del danno; ogni colpo a segno fa vibrare il controller, ferma l'azione per un istante, fa scintille e spinge indietro il nemico. Quello che ti blocca il passo (sassi, alberi, casse, muri troppo alti da salire) si illumina finché ci sbatti contro
- Lancia palle di fuoco che cercano e inseguono il nemico più vicino (costano mana: bevi le pozioni di mana per ricaricarlo)
- Il giorno lascia il posto alla notte: accendi la torcia per vedere al buio. Una minimappa mostra l'area attorno, i nemici come puntini rossi, le casse e i totem
- Apri le casse per trovare monete, armi, armature, stivali, amuleti, anelli, libri di magia e pozioni; dall'inventario puoi equipaggiarli, leggere i libri e bere le pozioni
- Al centro di ampie arene ci sono totem di pietra: toccane uno per avviare una sfida di sopravvivenza di 30 secondi con ondate di nemici adatte al tuo livello, e guadagna esperienza e una pozione
- Guadagna esperienza per salire di livello: ogni livello aumenta i danni base e ti fa scegliere un potenziamento: un colpo in più nella combo, un colpo potente concatenato in più, una schivata concatenata in più, un salto in più, un punto vita in più, una pozione in più, una ricarica più rapida dello scudo, una corsa più veloce, più mana o una magia più potente, scelti da una griglia di schede con icone. I livelli delle abilità sono sempre visibili a schermo e i potenziamenti attivi sono elencati a destra

COMANDI
- Movimento: levetta sinistra / WASD / levetta a schermo
- Attacco (combo): R1 / J
- Colpo potente (chiude la combo; tieni premuto per caricarlo): L2 / L
- Parata (tieni premuto): L1 / K
- Schivata (premi di nuovo per concatenare): B / Spazio
- Salto: A / F
- Corsa (tieni premuto; schivata mentre corri = scivolata): R2 / Maiusc
- Palla di fuoco: X / U
- Scudo: Y / R
- Pozione: croce sinistra / Q
- Pozione di mana: croce destra / T
- Torcia: croce giù / G
- Inventario: croce su / I
- Menù: Start / Esc

Gioca con il controller (anche i comandi integrati dello Steam Deck) o con la tastiera. Disponibile in italiano e in inglese.

PIATTAFORME
Linux e SteamOS (Steam Deck).
```

---

## Download instructions

Campo *Download & install instructions* (sotto la sezione Uploads).

```
🇬🇧 HOW TO INSTALL

Linux / Steam Deck: download the Linux file, extract it and run Gobelino.x86_64 (if needed, make it executable first: right click → Properties → Allow executing, or chmod +x Gobelino.x86_64). On Steam Deck do this in Desktop Mode, then add it to Steam as a non-Steam game (Steam → Games → Add a Non-Steam Game) and always launch it from Steam: this way the built-in controller works as a gamepad, both in Game Mode and in Desktop Mode. If you launch it from the itch.io app in Desktop Mode instead, hold the Menu (Start) button for 1 second to switch the built-in controls to controller mode: while a controller is connected the game ignores the keys Steam's desktop layout keeps sending. The main menu shows the detected controller and whether its buttons are recognized.

Tip: with the itch.io app (https://itch.io/app) the game updates automatically to the latest build.

🇮🇹 COME INSTALLARE

Linux / Steam Deck: scarica il file per Linux, estrailo e avvia Gobelino.x86_64 (se serve, rendilo prima eseguibile: tasto destro → Proprietà → Consenti l'esecuzione, oppure chmod +x Gobelino.x86_64). Su Steam Deck fallo in modalità Desktop, poi aggiungilo a Steam come gioco non Steam (Steam → Giochi → Aggiungi un gioco non Steam) e avvialo sempre da Steam: così i comandi integrati funzionano come un controller, sia in modalità Gioco sia in modalità Desktop. Se invece lo avvii dall'app di itch.io in modalità Desktop, tieni premuto il tasto Menu (Start) per 1 secondo per passare i comandi integrati alla modalità controller: finché c'è un controller il gioco ignora i tasti che il layout desktop di Steam continua a mandare. Il menù iniziale mostra il controller rilevato e se i suoi pulsanti sono riconosciuti.

Consiglio: con l'app di itch.io (https://itch.io/app) il gioco si aggiorna da solo all'ultima build.
```
