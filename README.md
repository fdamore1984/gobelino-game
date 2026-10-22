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

All'avvio c'è un menù (Inizia / Esci / lingua). Il livello di test è un mondo senza limiti generato a caso, con nemici di vari tipi sparsi a caso; per ora personaggi e nemici sono forme geometriche e i suoni sono sintetizzati in `scripts/sfx.gd`, in attesa degli asset definitivi.

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
| Torna al menù | Esc | Start | pulsante "Menu" |

- **Movimento**: accelerazione e frenata, con interpolazione fisica per restare fluido anche su schermi a 90/120 Hz.
- **Mondo** (`scripts/world.gd`, parametri in `data/world.json`): terreno isometrico 3D a blocchi quadrati modulari (erba o sentiero sterrato sopra, pareti di terra a strati ai lati) disposti su 6 livelli di altezza presi dal rumore, che formano piattaforme a gradini, colline e altopiani; alcuni blocchi sono rampe inclinate che salgono di un livello. Si sale su un blocco più alto solo saltando abbastanza in alto (il salto normale supera 1-2 livelli, per dislivelli maggiori servono i salti in aria) e si scende cadendo dal bordo; i nemici non saltano e restano sul loro livello, salvo le rampe. Colpi dati e ricevuti arrivano solo tra chi sta più o meno alla stessa altezza. Ostacoli naturali (`scripts/obstacle.gd`), pochi e mai sui sentieri: alberi e sassi bloccano, cespugli e rovi rallentano (non durante schivate e scivolate) e i rovi pungono (1 danno ogni 2 secondi). La partenza è sempre in piano e libera. Il mondo viene generato a pezzi attorno alla telecamera; i blocchi più alti di quelli dietro vengono ridisegnati tra i personaggi, così coprono chi ci passa dietro.
- **Combo**: attacchi ravvicinati formano una combo (3 colpi all'inizio); ogni colpo fa il 50% in più del precedente. Le pressioni in più a combo finita vengono ignorate. Mentre si attacca ci si può muovere (più piano) in qualsiasi direzione, ma il colpo resta nella direzione in cui è partito. Ogni attacco è un fendente di spada, una volta da sinistra e una da destra.
- **Colpo potente**: più lento e ampio, 2,5 volte i danni base; in fondo a una combo prende anche il bonus dei colpi già fatti. Chiude la combo, a meno di aver sbloccato altri colpi potenti concatenati (ognuno +50% del precedente). Tenendo premuto il tasto si carica (anello attorno al personaggio): in 0,9 secondi arriva al massimo, che raddoppia il danno.
- **Sensazione del colpo** (`scripts/hit_feedback.gd`): quando un colpo va a segno il controller vibra (anche il telefono su Android) e il gioco si ferma per un attimo, più a lungo per i colpi potenti e carichi.
- **Mana e palla di fuoco**: la palla di fuoco costa 20 mana, cerca il nemico più vicino, lo insegue curvando e lo colpisce; illumina attorno a sé. Il mana (60 all'inizio) si ricarica piano da solo o con le pozioni di mana. Danni 18 + 4 per livello, aumentati dai potenziamenti, dagli anelli e dai libri.
- **Torcia e notte**: il giorno e la notte si alternano (ciclo di 4 minuti, `data/world.json`); di notte il mondo è buio e la torcia illumina attorno al personaggio.
- **Minimappa** (in alto a destra): il terreno attorno, i nemici come puntini rossi, casse (gialle), totem e oggetti a terra.
- **Casse e inventario** (`data/items.json`): le casse si aprono toccandole e lasciano monete e oggetti a caso, adatti al livello, da raccogliere passandoci sopra: armi (danni +%), armature (vita massima), stivali (velocità), amuleti (mana massimo), anelli (potenza della magia), libri di magia (bonus permanente quando si leggono) e pozioni. Nell'inventario si indossa un oggetto per tipo, si leggono i libri e si bevono le pozioni; il gioco è in pausa mentre è aperto.
- **Salto**: serve per salire sui blocchi più alti del terreno (il salto normale supera 1-2 livelli) e in aria gli attacchi dei nemici passano sotto. Un salto all'inizio, i potenziamenti ne aggiungono altri in aria. Salti e schivate si combinano (schivata in aria, salto durante la schivata).
- **Corsa e scivolata**: tenendo premuto R2 si corre (+60%); schivando mentre si corre si fa una scivolata, durante la quale si può attaccare continuando la combo (con lo slancio della scivolata), schivare, saltare o parare.
- **Pozioni**: curano 3 punti vita; se ne hanno 2 all'inizio.
- **Scudo** (Y): assorbe un colpo da qualsiasi direzione; ricarica di 30 secondi dall'attivazione.
- **Parata**: blocca i colpi frontali; una parata perfetta, iniziata appena prima del colpo, stordisce il nemico e per 4 secondi raddoppia i danni e velocizza gli attacchi.
- **Interruzioni**: schivata e parata si possono usare in qualsiasi momento, anche durante una combo, che si interrompe; attaccare durante una schivata la interrompe e attacca subito.
- **Schivata**: invulnerabilità per un istante; premendo di nuovo durante la schivata (o subito dopo) se ne concatena un'altra (2 all'inizio). Per tutta la schivata la direzione segue la levetta (subito all'inizio, poi curvando), così ci si può spostare in altre direzioni.
- **Esperienza e livelli**: ogni nemico sconfitto dà esperienza; servono 100 punti per il livello 2, 200 per il 3 e così via. Ogni livello aumenta i danni base e fa scegliere un potenziamento: +1 colpo nella combo, +1 colpo potente concatenato, +1 schivata concatenata, +1 salto, +1 punto vita, +1 pozione, ricarica dello scudo -2%, velocità di corsa +2%, mana massimo +20 o potenza della magia +20%. I potenziamenti si scelgono da una griglia di schede con icone geometriche (`scripts/upgrade_icon.gd`); i livelli delle abilità sono mostrati nell'HUD e i potenziamenti attivi (scelti ed effetti temporanei come la parata perfetta e lo scudo) sono elencati a destra.
- **Nemici** (`data/enemies.json`): esploratori rapidi, guerrieri, bruti lenti e resistenti che fanno 2 danni, evocatori che restano a distanza ed evocano esploratori (colpirli mentre evocano li interrompe). Girano attorno al giocatore con scatti laterali; l'attacco è un fendente di spada lento e ampio (alternato da sinistra e da destra), annunciato dalla zona rossa a terra, con durata variabile, finte e secondi attacchi. Salendo di livello compaiono più spesso i nemici forti. Giocatore e nemici hanno le gambe, che camminano mentre si muovono.
- **Sfide del totem** (`data/challenge.json`): qua e là ci sono arene, ampie zone piane e senza ostacoli con al centro un totem di pietra. Toccandolo parte una sfida di sopravvivenza di 30 secondi: arrivano tre ondate di nemici dal bordo dell'arena, più numerose e più forti salendo di livello. Superarla dà esperienza (60 × livello) e una pozione; ogni totem si usa una volta sola.

## Steam Deck

In modalità Desktop, se il gioco è avviato fuori da Steam (per esempio dall'app di itch.io), Steam trasforma i comandi integrati in tastiera e mouse e il gioco non vede un controller. Per usarli come controller: tenere premuto il tasto Menu (Start) per 1 secondo, che passa alla modalità controller, oppure aggiungere il gioco a Steam come gioco non Steam e avviarlo da lì. Il gioco riconosce il Deck anche fuori da Steam (dal modello dell'hardware) e in quel caso, finché non vede un controller, mostra queste istruzioni nel menù e in gioco. Avviato fuori da Steam, in modalità Desktop Steam trasforma i comandi in tastiera e mouse: i menù accettano comunque croce, frecce, WASD, Invio/Spazio e J, e in basso a sinistra mostrano quale controller vede il gioco e l'ultimo comando ricevuto.

## Lingue

Il gioco è in italiano e in inglese. Al primo avvio usa la lingua del sistema (italiano, altrimenti inglese); dal menù si può cambiare e la scelta viene salvata. I testi sono in `data/translations.csv`: ogni nuovo testo va aggiunto lì in entrambe le lingue e usato nel codice con `tr("CHIAVE")`.

## Build

Le build vengono prodotte da GitHub Actions (`.github/workflows/build.yml`).
Windows e Linux sono un unico eseguibile con i dati incorporati (PCK incorporato), così l'app di itch.io ha un solo file da avviare.
Per una build locale: Progetto → Esporta, usando i preset in `export_presets.cfg`.
