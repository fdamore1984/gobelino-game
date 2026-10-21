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
| Movimento | WASD / frecce | levetta sinistra / croce | levetta virtuale a sinistra |
| Attacco (combo) | J | R1 | pulsante "Attacco" |
| Parata (tieni premuto) | K | L1 | pulsante "Parata" |
| Schivata (ripeti per concatenare) | Spazio | B | pulsante "Schivata" |
| Torna al menù | Esc | Start | pulsante "Menu" |

- **Movimento**: accelerazione e frenata, con interpolazione fisica per restare fluido anche su schermi a 90/120 Hz.
- **Combo**: attacchi ravvicinati formano una combo (3 colpi all'inizio); ogni colpo fa il 50% in più del precedente.
- **Parata**: blocca i colpi frontali; una parata perfetta, iniziata appena prima del colpo, stordisce il nemico e per 4 secondi raddoppia i danni e velocizza gli attacchi.
- **Schivata**: invulnerabilità per un istante; premendo di nuovo durante la schivata se ne concatena un'altra, anche in un'altra direzione (2 all'inizio).
- **Esperienza e livelli**: ogni nemico sconfitto dà esperienza; servono 100 punti per il livello 2, 200 per il 3 e così via. Ogni livello aumenta i danni base e fa scegliere un potenziamento: +1 colpo nella combo, +1 schivata concatenata o +1 punto vita.
- **Nemici** (`data/enemies.json`): esploratori rapidi, guerrieri, bruti lenti e resistenti che fanno 2 danni, evocatori che restano a distanza ed evocano esploratori (colpirli mentre evocano li interrompe). Girano attorno al giocatore con scatti laterali; l'attacco è annunciato dalla zona rossa a terra, con durata variabile, finte e secondi attacchi. Salendo di livello compaiono più spesso i nemici forti.

## Lingue

Il gioco è in italiano e in inglese. Al primo avvio usa la lingua del sistema (italiano, altrimenti inglese); dal menù si può cambiare e la scelta viene salvata. I testi sono in `data/translations.csv`: ogni nuovo testo va aggiunto lì in entrambe le lingue e usato nel codice con `tr("CHIAVE")`.

## Build

Le build vengono prodotte da GitHub Actions (`.github/workflows/build.yml`).
Per una build locale: Progetto → Esporta, usando i preset in `export_presets.cfg`.
