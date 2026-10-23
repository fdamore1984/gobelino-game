# Gobelino

RPG fantasy medievale 2D sviluppato con **Godot 4**, destinato alla pubblicazione su Steam.

> Nota: questo progetto non ha relazione con la piattaforma MDM "Gobelino". Condivide solo il nome provvisorio.

## Requisiti

- [Godot 4.4](https://godotengine.org/download) (versione standard, non Mono)
- [Git LFS](https://git-lfs.com/) per gli asset pesanti

## Primi passi

```bash
git clone https://github.com/fdamore1984/gobelino-game
cd gobelino-game
git lfs install
```

Poi apri la cartella da Godot (Importa progetto → `project.godot`) e premi F5.

## Struttura

| Cartella | Contenuto |
|---|---|
| `scenes/` | Scene Godot (`.tscn`) |
| `scripts/` | Script GDScript (`.gd`) |
| `assets/` | Sprite, audio, font (gestiti con LFS) |
| `data/` | Dati di gioco: nemici (`enemies.json`), traduzioni (`translations.csv`) |
| `store/itch/` | Testi e immagini della pagina itch.io |
| `tools/` | Strumenti di sviluppo esclusi dalle build (cattura screenshot per lo store) |
| `docs/` | Documentazione, incluso il [GDD](docs/GDD.md) |
| `.github/workflows/` | Build automatiche |

## Piattaforme

| Piattaforma | Come | Note |
|---|---|---|
| Windows | export "Windows Desktop" | Distribuzione su Steam |
| Linux / SteamOS | export "Linux" | La build Linux gira nativa sullo Steam Deck (16:10, controller) |
| Android | export "Android" | Distribuzione su Google Play, non su Steam |

Regole di progetto per restare multipiattaforma:

- **Renderer**: Compatibility (OpenGL), il più compatibile per 2D su mobile e PC datati
- **Input**: solo azioni dell'Input Map (`move_*`, `interact`, `attack`, `heavy_attack`, `parry`, `dodge`, `jump`, `run`, `spell`, `shield`, `potion`, `mana_potion`, `torch`, `inventory`, `menu`, più `ui_accept` / `ui_cancel` estese al gamepad per i menù), mai tasti scritti nel codice. Tastiera e gamepad sono mappati nel progetto; i controlli touch (`scripts/touch_controls.gd`) premono le stesse azioni
- **UI**: ancoraggi e container, stretch "expand", orientamento landscape
- **Piattaforma**: il codice chiede a `Platform` (`scripts/platform.gd`) cosa è disponibile (touch, Steam, Deck) invece di controllare il sistema operativo
- **Salvataggi**: sempre in `user://`

## Flusso di lavoro

- `main`: ramo unico, sempre in stato funzionante
- Lavoro in branch di feature (`feature/nome`) con Pull Request verso `main`
- Ogni push su `main` genera la build Linux (SteamOS / Steam Deck) e la carica su itch.io (per ora Windows e Android non vengono pubblicati: i preset restano in `export_presets.cfg` per quando si riattiveranno); sulle Pull Request la CI verifica solo che l'export riesca

## Livello di test

All'avvio c'è un menù (Start / Controls / Quit): *Controls* mostra l'elenco dei comandi e degli attacchi speciali (`scripts/controls_panel.gd`); durante il gioco le istruzioni non sono più sullo schermo. Il livello di test è un mondo senza limiti generato a caso, con nemici di vari tipi sparsi a caso; per ora personaggi e nemici sono forme geometriche e i suoni sono sintetizzati in `scripts/sfx.gd`, in attesa degli asset definitivi.

| Azione | Tastiera | Gamepad | Touch |
|---|---|---|---|
| Movimento | WASD / frecce | levetta sinistra | levetta virtuale a sinistra |
| Attacco (combo) | J | R1 | pulsante "Attacco" |
| Colpo potente (chiude la combo; tieni premuto per caricarlo) | L | L2 | pulsante "Potente" |
| Parata (tieni premuto) | K | L1 | pulsante "Parata" |
| Schivata (ripeti per concatenare) | Spazio | B | pulsante "Schivata" |
| Salto | F | A | pulsante "Salto" |
| Corsa (tieni premuto) | Maiusc | R2 | pulsante "Corsa" |
| Palla di fuoco | U | X | pulsante "Magia" |
| Scudo | R | Y | pulsante "Scudo" |
| Pozione | Q | croce sinistra | pulsante "Pozione" |
| Pozione di mana | T | croce destra | pulsante "Mana" |
| Torcia | G | croce giù | pulsante "Torcia" |
| Inventario | I / Tab | croce su | pulsante "Zaino" |
| Menù di pausa (riprendi, salva, comandi, esci) | Esc | Start | pulsante "Menu" |

- **HUD** (`scripts/hud_status.gd`, `scripts/hud_actions.gd`): in alto a sinistra un pannello con ritratto e livello, vita a segmenti, mana, esperienza, livelli delle abilità, monete e nemici sconfitti; in basso a sinistra la barra delle azioni (pozioni, scudo con la ricarica, palla di fuoco, torcia, inventario) con il tasto del controller; in alto a destra minimappa e potenziamenti attivi. Il pannello in alto a sinistra è disegnato più piccolo (scala 0,72) per coprire meno l'area di gioco.
- **Movimento**: accelerazione e frenata morbide, con interpolazione fisica per restare fluido anche su schermi a 90/120 Hz. La telecamera segue con dolcezza e anticipa un poco la direzione di movimento; il corpo ondeggia camminando, si inclina nella direzione di corsa e si schiaccia atterrando.
- **Mondo** (`scripts/world.gd`, parametri in `data/world.json`): terreno isometrico 3D a blocchi quadrati modulari (erba o sentiero sterrato sopra, pareti di terra a strati ai lati) disposti su 6 livelli di altezza presi dal rumore, che formano piattaforme a gradini, colline e altopiani; alcuni blocchi sono rampe inclinate che salgono di un livello. Si sale su un blocco più alto solo saltando abbastanza in alto (il salto normale supera 1-2 livelli, per dislivelli maggiori servono i salti in aria) e si scende cadendo dal bordo; i nemici non saltano e restano sul loro livello, salvo le rampe. Colpi dati e ricevuti arrivano solo tra chi sta più o meno alla stessa altezza. Ostacoli naturali (`scripts/obstacle.gd`), pochi e mai sui sentieri: alberi e sassi bloccano, cespugli e rovi rallentano (non durante schivate e scivolate) e i rovi pungono (1 danno ogni 2 secondi). La partenza è sempre in piano e libera. Il mondo viene generato a pezzi attorno alla telecamera; i blocchi più alti di quelli dietro vengono ridisegnati tra i personaggi, così coprono chi ci passa dietro.
- **Montagne, burroni e caverne**: lunghe catene di montagne (rocce a gradini con la cima innevata) e burroni profondi seguono le linee di un rumore, con qualche passaggio; non si attraversano mai, nemmeno con i salti. Mai vicino alla partenza, alle arene o ai mercanti. Nei tratti dritti delle pareti delle montagne si apre ogni tanto una caverna (arco buio con il bordo di pietre): entrandoci si scende nel sotterraneo.
- **Sotterraneo** (`scripts/dungeon.gd`, voce `dungeon` di `data/world.json`): caverne collegate da gallerie, generate a caso ma sempre uguali per la stessa caverna; da 2 a 5 piani, piccoli (una griglia di 34 rombi, +4 per piano). È buio (la torcia serve), con funghi luminosi, stalagmiti, casse e nemici più forti scendendo. Si arriva su una scala che riporta in superficie e si cerca la scala che scende; all'ultimo piano, nella caverna più lontana, c'è un'arena con il boss (il Guardiano della caverna, con la corona: vita e danni crescono col livello del giocatore, evoca esploratori). Sconfitto il boss lascia monete e due oggetti rari, al centro dell'arena compare l'uscita e la caverna resta chiusa.
- **Salvataggi** (`scripts/save_game.gd`, un file JSON in `user://`): la partita si salva da sola ogni 5 minuti ed entrando in una caverna; dal menù di pausa (Esc / Start) si salva a mano, ma solo senza nemici entro 700 px e stando completamente fermi (altrimenti il pulsante è spento e c'è il motivo). Si salvano livello, caratteristiche, potenziamenti, inventario, posizione (anche nel sotterraneo), casse aperte, totem usati, scorte dei mercanti e caverne completate. Nel menù iniziale *Continue* riprende la partita salvata.
- **Prestazioni**: i dati del terreno (livelli, rampe, sentieri, ostacoli) di una regione di 25 × 25 pezzi attorno al giocatore sono generati all'avvio; quando ci si avvicina al bordo il gioco si ferma un attimo con una barra di avanzamento e genera la regione nuova. I pezzi da disegnare vengono creati poco prima che entrino nello schermo, uno per frame; la minimappa si aggiorna a righe, su più frame. Ogni rombo calcola livello, tipo, rampa e sentiero una volta sola.
- **Combo**: attacchi ravvicinati formano una combo (3 colpi all'inizio); ogni colpo fa il 50% in più del precedente. Le pressioni in più a combo finita vengono ignorate. Mentre si attacca ci si può muovere (più piano) in qualsiasi direzione, ma il colpo resta nella direzione in cui è partito. Ogni attacco è un fendente di spada, una volta da sinistra e una da destra.
- **Colpo potente**: più lento e ampio, 2,5 volte i danni base; in fondo a una combo prende anche il bonus dei colpi già fatti. Chiude la combo, a meno di aver sbloccato altri colpi potenti concatenati (ognuno +50% del precedente). Tenendo premuto il tasto si carica (anello attorno al personaggio): in 0,9 secondi arriva al massimo, che raddoppia il danno.
- **Attacchi a terra**: colpiscono tutti i nemici attorno al punto d'impatto, con un'onda d'urto, crepe nel terreno e la telecamera che trema. Un colpo potente subito dopo almeno 2 colpi normali della combo fa saltare e colpire il terreno (raggio 140, danni del colpo potente all'80%); con più colpi potenti concatenati lo fanno tutti quelli dopo la combo. Attaccando in aria ci si ferma un attimo e si piomba a terra (raggio 105, 1,6 volte i danni base); attaccando durante uno scatto in aria si piomba a terra continuando lo scatto, con un colpo più ampio (raggio 165, 2,4 volte i danni base).
- **Sensazione del colpo** (`scripts/hit_feedback.gd`): quando un colpo va a segno il gioco si ferma per circa 0,1 secondi (di più per i colpi potenti e carichi); nel punto di contatto compare una scintilla (`scripts/hit_spark.gd`) e il nemico viene spinto indietro (meno se pesante). Il controller non vibra.
- **Sangue e corpi** (`scripts/ground_fx.gd`): i nemici colpiti perdono gocce di sangue rosso che schizzano nella direzione del colpo e restano a terra come macchie per 30 secondi; i nemici abbattuti cadono a terra e restano stesi per 20 secondi, su una pozza di sangue, poi svaniscono. Un solo nodo disegna tutti questi effetti tra il terreno e i personaggi.
- **Collisioni**: quando il personaggio sbatte contro un ostacolo solido (alberi, sassi, casse, totem) l'ostacolo si illumina con un bagliore e un anello alla base; quando un blocco di terreno è troppo alto da salire se ne illumina il contorno. Dura per tutto il contatto, così si capisce subito cosa blocca il movimento.
- **Mana e palla di fuoco**: la palla di fuoco costa 20 mana, cerca il nemico più vicino, lo insegue curvando e lo colpisce; illumina attorno a sé. Il mana (60 all'inizio) si ricarica piano da solo o con le pozioni di mana. Danni 18 + 4 per livello, aumentati dai potenziamenti, dagli anelli e dai libri.
- **Torcia e notte**: il giorno e la notte si alternano (ciclo di 4 minuti, `data/world.json`); di notte il mondo è buio e la torcia illumina un'ampia zona di terreno attorno al personaggio con un'ellisse che segue la prospettiva isometrica.
- **Minimappa** (in alto a destra): il terreno attorno (montagne grigie e bianche, burroni neri), i nemici come puntini rossi, casse (gialle), totem, mercanti (tenda rosa), caverne e scale, e oggetti a terra.
- **Casse e inventario** (`data/items.json`): le casse si aprono toccandole e lasciano monete e oggetti a caso, adatti al livello, da raccogliere passandoci sopra: armi (danni +%), armature (vita massima), stivali (velocità), amuleti (mana massimo), anelli (potenza della magia), libri di magia (bonus permanente quando si leggono) e pozioni. Nell'inventario si indossa un oggetto per tipo, si leggono i libri e si bevono le pozioni; il gioco è in pausa mentre è aperto.
- **Mercanti** (`data/world.json`, voce `merchant`; `scripts/shop_panel.gd`): banchi sparsi a caso nel mondo, su uno spiazzo piano lontano dalla partenza e dalle arene. Toccando il banco si apre il negozio (gioco in pausa): vende pozioni e da 4 a 6 oggetti rari che nelle casse non si trovano (`"shop_only"` in `data/items.json`, finiscono quando li si compra) e compra gli oggetti non indossati a metà del loro prezzo (`"value"`). Per riaprirlo bisogna allontanarsi un po'.
- **Salto**: serve per salire sui blocchi più alti del terreno (il salto normale supera 1-2 livelli) e in aria gli attacchi dei nemici passano sotto. Un salto all'inizio, i potenziamenti ne aggiungono altri in aria. Salti e schivate si combinano (schivata in aria, salto durante la schivata).
- **Corsa e scivolata**: tenendo premuto R2 si corre (+60%); schivando mentre si corre si fa una scivolata, durante la quale si può attaccare continuando la combo (con lo slancio della scivolata), schivare, saltare o parare.
- **Pozioni**: curano 3 punti vita; se ne hanno 2 all'inizio.
- **Scudo** (Y): assorbe un colpo da qualsiasi direzione; ricarica di 30 secondi dall'attivazione.
- **Parata**: blocca i colpi frontali; una parata perfetta, iniziata appena prima del colpo, stordisce il nemico e per 4 secondi raddoppia i danni e velocizza gli attacchi.
- **Interruzioni**: schivata e parata si possono usare in qualsiasi momento, anche durante una combo, che si interrompe; attaccare durante una schivata la interrompe e attacca subito.
- **Schivata**: a terra è una capriola, in aria uno scatto nella direzione di movimento (si smette di cadere per un attimo); invulnerabilità per un istante; premendo di nuovo durante la schivata (o subito dopo) se ne concatena un'altra (2 all'inizio). Per tutta la schivata la direzione segue la levetta (subito all'inizio, poi curvando), così ci si può spostare in altre direzioni.
- **Esperienza e livelli**: ogni nemico sconfitto dà esperienza; servono 100 punti per il livello 2, 200 per il 3 e così via. Ogni livello aumenta i danni base e fa scegliere un potenziamento: +1 colpo nella combo, +1 colpo potente concatenato, +1 schivata concatenata, +1 salto, +1 punto vita, +1 pozione, ricarica dello scudo -2%, velocità di corsa +2%, mana massimo +20 o potenza della magia +20%. I potenziamenti si scelgono da una griglia di schede con icone geometriche (`scripts/upgrade_icon.gd`); i livelli delle abilità sono mostrati nell'HUD e i potenziamenti attivi (scelti ed effetti temporanei come la parata perfetta e lo scudo) sono elencati a destra.
- **Nemici** (`data/enemies.json`): esploratori rapidi, guerrieri, bruti lenti e resistenti che fanno 2 danni, evocatori che restano a distanza ed evocano esploratori (colpirli mentre evocano li interrompe), lancieri (pentagoni) con un affondo lungo e stretto, rotanti (stelle) che colpiscono tutto attorno, golem (ottagoni) lentissimi e resistentissimi dal livello 2, lanciatori (croci) che restano a distanza e scagliano dardi magici da schivare o parare. Lo sguardo dei nemici ruota con continuità, camminando ondeggiano e alla morte cadono a terra (vedi *Sangue e corpi*). Girano attorno al giocatore con scatti laterali; l'attacco è un fendente di spada lento e ampio (alternato da sinistra e da destra), annunciato dal corpo che si accende e dalla spada (o dal bastone) portata indietro, con durata variabile, finte e secondi attacchi. Salendo di livello compaiono più spesso i nemici forti. Giocatore e nemici hanno le gambe, che camminano mentre si muovono.
- **Sfide del totem** (`data/challenge.json`): qua e là ci sono arene, ampie zone piane e senza ostacoli con al centro un totem di pietra. Toccandolo parte una sfida di sopravvivenza di 30 secondi: arrivano tre ondate di nemici dal bordo dell'arena, più numerose e più forti salendo di livello. Superarla dà esperienza (60 × livello) e una pozione; ogni totem si usa una volta sola.

## Steam Deck

In modalità Desktop, se il gioco è avviato fuori da Steam (per esempio dall'app di itch.io), Steam trasforma i comandi integrati in tastiera e mouse e il gioco non vede un controller. Per usarli come controller: tenere premuto il tasto Menu (Start) per 1 secondo, che passa alla modalità controller, oppure aggiungere il gioco a Steam come gioco non Steam e avviarlo da lì. Il gioco riconosce il Deck anche fuori da Steam (dal modello dell'hardware) e in quel caso, finché non vede un controller, mostra queste istruzioni nel menù e in gioco. Avviato fuori da Steam, in modalità Desktop Steam trasforma i comandi in tastiera e mouse: i menù accettano comunque croce, frecce, WASD, Invio/Spazio e J, e in basso a sinistra mostrano quale controller vede il gioco e l'ultimo comando ricevuto.

## Lingue

Per ora il gioco è solo in inglese. I testi sono comunque in `data/translations.csv` (colonna `en`) e nel codice si usano con `tr("CHIAVE")`, così altre lingue si potranno aggiungere più avanti con una nuova colonna.

## Build

Le build vengono prodotte da GitHub Actions (`.github/workflows/build.yml`).
Windows e Linux sono un unico eseguibile con i dati incorporati (PCK incorporato), così l'app di itch.io ha un solo file da avviare.
Per una build locale: Progetto → Esporta, usando i preset in `export_presets.cfg`.
