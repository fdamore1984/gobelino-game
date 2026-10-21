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
| `data/` | Dati di gioco in JSON/risorse: oggetti, nemici, quest |
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
- **Input**: solo azioni dell'Input Map (`move_*`, `interact`, `attack`, `parry`, `dodge`, `menu`), mai tasti scritti nel codice. Tastiera e gamepad sono mappati nel progetto; i controlli touch (`scripts/touch_controls.gd`) premono le stesse azioni
- **UI**: ancoraggi e container, stretch "expand", orientamento landscape
- **Piattaforma**: il codice chiede a `Platform` (`scripts/platform.gd`) cosa è disponibile (touch, Steam, Deck) invece di controllare il sistema operativo
- **Salvataggi**: sempre in `user://`

## Flusso di lavoro

- `main`: ramo unico, sempre in stato funzionante
- Lavoro in branch di feature (`feature/nome`) con Pull Request verso `main`
- Ogni push su `main` genera le build Windows, Linux e Android (APK di debug) e le carica su itch.io; sulle Pull Request la CI verifica solo che l'export riesca

## Livello di test

All'avvio c'è un menù (Inizia / Esci). Il livello di test è un piano senza limiti con nemici sparsi a caso; per ora personaggi e nemici sono forme geometriche, in attesa degli asset grafici.

| Azione | Tastiera | Gamepad | Touch |
|---|---|---|---|
| Movimento | WASD / frecce | levetta sinistra / croce | levetta virtuale a sinistra |
| Attacco | J | R1 | pulsante "Attacco" |
| Parata (tieni premuto) | K | L1 | pulsante "Parata" |
| Schivata | Spazio | B | pulsante "Schivata" |
| Torna al menù | Esc | Start | pulsante "Menu" |

I nemici caricano un attacco lento: a terra compare la zona che verrà colpita, poi scattano in avanti. La schivata rende invulnerabili per un istante; una parata iniziata appena prima del colpo (parata perfetta) lascia il nemico stordito.

## Build

Le build vengono prodotte da GitHub Actions (`.github/workflows/build.yml`).
Per una build locale: Progetto → Esporta, usando i preset in `export_presets.cfg`.
