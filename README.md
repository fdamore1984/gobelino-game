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
- **Input**: solo azioni dell'Input Map (`move_*`, `interact`, `attack`, `parry`, `dodge`, `menu`, più `ui_accept` / `ui_cancel` estese al gamepad per i menù), mai tasti scritti nel codice. Tastiera e gamepad sono mappati nel progetto; i controlli touch (`scripts/touch_controls.gd`) premono le stesse azioni
- **UI**: ancoraggi e container, stretch "expand", orientamento landscape
- **Piattaforma**: il codice chiede a `Platform` (`scripts/platform.gd`) cosa è disponibile (touch, Steam, Deck) invece di controllare il sistema operativo
- **Salvataggi**: sempre in `user://`

## Flusso di lavoro

- `main`: ramo unico, sempre in stato funzionante
- Lavoro in branch di feature (`feature/nome`) con Pull Request verso `main`
- Ogni push su `main` genera le build Windows, Linux e Android (APK di debug) e le carica su itch.io; sulle Pull Request la CI verifica solo che l'export riesca

## Livello di test

All'avvio c'è un menù (Inizia / Esci / lingua). Il livello di test è un piano senza limiti con nemici di vari tipi sparsi a caso; per ora personaggi e nemici sono forme geometriche e i suoni sono sintetizzati in `scripts/sfx.gd`, in attesa degli asset definitivi.

| Azione | Tastiera | Gamepad | Touch |
|---|---|---|---|
| Movimento | WASD / frecce | levetta sinistra | levetta virtuale a sinistra |
| Attacco (combo) | J | R1 | pulsante "Attacco" |
| Colpo potente (chiude la combo) | L | L2 | pulsante "Potente" |
| Parata (tieni premuto) | K | L1 | pulsante "Parata" |
| Schivata (ripeti per concatenare) | Spazio | B | pulsante "Schivata" |
| Salto | F | Y | pulsante "Salto" |
| Corsa (tieni premuto) | Maiusc | R2 | pulsante "Corsa" |
| Pozione | Q | croce sinistra | pulsante "Pozione" |
| Scudo | R | croce destra | pulsante "Scudo" |
| Torna al menù | Esc | Start | pulsante "Menu" |

- **Movimento**: accelerazione e frenata, con interpolazione fisica per restare fluido anche su schermi a 90/120 Hz.
- **Combo**: attacchi ravvicinati formano una combo (3 colpi all'inizio); ogni colpo fa il 50% in più del precedente. Le pressioni in più a combo finita vengono ignorate.
- **Colpo potente**: più lento e ampio, 2,5 volte i danni base; in fondo a una combo prende anche il bonus dei colpi già fatti. Chiude la combo, a meno di aver sbloccato altri colpi potenti concatenati (ognuno +50% del precedente).
- **Salto**: l'altezza è solo visiva, ma in aria gli attacchi dei nemici passano sotto. Un salto all'inizio, i potenziamenti ne aggiungono altri in aria. Salti e schivate si combinano (schivata in aria, salto durante la schivata).
- **Corsa e scivolata**: tenendo premuto R2 si corre (+60%); schivando mentre si corre si fa una scivolata, durante la quale si può attaccare continuando la combo (con lo slancio della scivolata), schivare, saltare o parare.
- **Pozioni**: curano 3 punti vita; se ne hanno 2 all'inizio.
- **Scudo**: assorbe un colpo da qualsiasi direzione; ricarica di 30 secondi dall'attivazione.
- **Parata**: blocca i colpi frontali; una parata perfetta, iniziata appena prima del colpo, stordisce il nemico e per 4 secondi raddoppia i danni e velocizza gli attacchi.
- **Interruzioni**: schivata e parata si possono usare in qualsiasi momento, anche durante una combo, che si interrompe; attaccare durante una schivata la interrompe e attacca subito.
- **Schivata**: invulnerabilità per un istante; premendo di nuovo durante la schivata (o subito dopo) se ne concatena un'altra (2 all'inizio). All'inizio di ogni schivata la direzione segue ancora la levetta, così cambiare direzione è facile.
- **Esperienza e livelli**: ogni nemico sconfitto dà esperienza; servono 100 punti per il livello 2, 200 per il 3 e così via. Ogni livello aumenta i danni base e fa scegliere un potenziamento: +1 colpo nella combo, +1 colpo potente concatenato, +1 schivata concatenata, +1 salto, +1 punto vita, +1 pozione, ricarica dello scudo -2% o velocità di corsa +2%. I livelli delle abilità sono mostrati nell'HUD.
- **Nemici** (`data/enemies.json`): esploratori rapidi, guerrieri, bruti lenti e resistenti che fanno 2 danni, evocatori che restano a distanza ed evocano esploratori (colpirli mentre evocano li interrompe). Girano attorno al giocatore con scatti laterali; l'attacco è annunciato dalla zona rossa a terra, con durata variabile, finte e secondi attacchi. Salendo di livello compaiono più spesso i nemici forti.

## Steam Deck

In modalità Desktop, se il gioco è avviato fuori da Steam (per esempio dall'app di itch.io), Steam trasforma i comandi integrati in tastiera e mouse e il gioco non vede un controller. Per usarli come controller: tenere premuto il tasto Menu (Start) per 1 secondo, che passa alla modalità controller, oppure aggiungere il gioco a Steam come gioco non Steam e avviarlo da lì. Il gioco riconosce il Deck anche fuori da Steam (dal modello dell'hardware) e in quel caso, finché non vede un controller, mostra queste istruzioni nel menù e in gioco. Avviato fuori da Steam, in modalità Desktop Steam trasforma i comandi in tastiera e mouse: i menù accettano comunque croce, frecce, WASD, Invio/Spazio e J, e in basso a sinistra mostrano quale controller vede il gioco e l'ultimo comando ricevuto.

## Lingue

Il gioco è in italiano e in inglese. Al primo avvio usa la lingua del sistema (italiano, altrimenti inglese); dal menù si può cambiare e la scelta viene salvata. I testi sono in `data/translations.csv`: ogni nuovo testo va aggiunto lì in entrambe le lingue e usato nel codice con `tr("CHIAVE")`.

## Build

Le build vengono prodotte da GitHub Actions (`.github/workflows/build.yml`).
Windows e Linux sono un unico eseguibile con i dati incorporati (PCK incorporato), così l'app di itch.io ha un solo file da avviare.
Per una build locale: Progetto → Esporta, usando i preset in `export_presets.cfg`.
