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
godot --path . --resolution 1280x720 res://tools/store_capture.tscn -- tutorial
```

L'ultimo comando rigenera le immagini del tutorial del gioco (`assets/tutorial/`), non quelle della pagina.

---

## Campi della pagina

| Campo su itch.io | Valore |
|---|---|
| Kind of project | Downloadable |
| Release status | Prototype |
| Pricing | No payments (oppure "Donate" se vuoi accettare offerte) |
| Uploads | Caricati dalla CI con butler i canali `linux` e `windows`: in *Edit game → Uploads* spunta la piattaforma Linux sul primo e Windows sul secondo (e rendi di nuovo visibile `windows` se l'avevi nascosto). I vecchi caricamenti `android` vanno eliminati dalla stessa pagina |
| Genre | Role Playing |
| Tags | vedi sotto |
| AI generation disclosure | Sì: codice, testi e grafica provvisoria sono stati prodotti con l'aiuto di un'IA (Claude) |
| Languages | English, Italian |
| Inputs | Keyboard, Mouse, Xbox controller, Playstation controller, Touchscreen |
| Cover image | `cover_en.png` (630×500; `cover_it.png` è la versione italiana) |
| Screenshots | `en_1_combat.png`, `en_2_parry.png`, `en_5_challenge.png`, `en_6_inventory.png`, `en_17_frenzy.png`, `en_16_rune.png`, `en_9_slam.png`, `en_14_air_charge.png`, `en_11_cave.png`, `en_13_map.png`, `en_12_dungeon.png`, `en_18_metro.png`, `en_19_horde.png`, `en_7_merchant.png`, `en_8_shop.png`, `en_3_level_up.png`, `en_4_menu.png`, `en_10_controls.png`, `en_15_options.png` (in inglese, la lingua della pagina; quelle `it_*` sono le stesse in italiano) |

### Tags

Su itch.io se ne possono mettere al massimo 10:

```
action-rpg, fantasy, medieval, goblins, isometric, undead, controller, singleplayer, procedural-generation, prototype
```

---

## Short description or tagline

```
A feral goblin, a world to explore, deadly Souls-like combat.
```

---

## Description

Da incollare così com'è nel campo *Description*: brevissima, i dettagli li
spiega il tutorial del gioco.

```
Gobelino is a 2D medieval fantasy action RPG with an isometric view: a feral goblin with a sword and a fireball explores boundless lands, caves and catacombs full of monsters and undead.

Fast, deadly Souls-like combat: combos, parries, dodges, jumps and the Frenzy special attack. Prototype with placeholder graphics and sounds.

Controller, keyboard and mouse or touch. English and Italian. Windows, Linux and Steam Deck.
```

---

## Sito ufotizio.com

Descrizione brevissima mostrata dal sito sotto il gioco, nella lingua del
sito (non va su itch.io; vedi `public/assets/itch.js` del repo ufotizio-site).

### Italiano

```
Action RPG fantasy: un goblin selvaggio con spada e palle di fuoco, terre senza confini, grotte e catacombe, combattimenti veloci e mortali.
```

### English

```
Fantasy action RPG: a feral goblin with a sword and fireballs, boundless lands, caves and catacombs, fast and deadly fights.
```

---

## Download instructions

Campo *Download & install instructions* (sotto la sezione Uploads).

```
HOW TO INSTALL

Linux / Steam Deck: download the Linux file, extract it and run Gobelino.x86_64 (if needed, make it executable first: right click → Properties → Allow executing, or chmod +x Gobelino.x86_64). On Steam Deck the game always starts in fullscreen, in Desktop Mode too. Do this in Desktop Mode, then add it to Steam as a non-Steam game (Steam → Games → Add a Non-Steam Game) and always launch it from Steam: this way the built-in controller works as a gamepad, both in Game Mode and in Desktop Mode. If you launch it from the itch.io app in Desktop Mode instead, hold the Menu (Start) button for 1 second to switch the built-in controls to controller mode: while a controller is connected the game ignores the keys Steam's desktop layout keeps sending. The main menu shows the detected controller and whether its buttons are recognized.

Windows / MSI Claw 8: download the Windows file, extract it and run Gobelino.exe (if Windows SmartScreen warns you, click More info → Run anyway). On handheld gaming PCs like the MSI Claw 8 the game starts in fullscreen; play with the built-in controller (XInput mode) or touch the screen to show the on-screen controls. You can also add it to Steam as a non-Steam game.

Tip: with the itch.io app (https://itch.io/app) the game updates automatically to the latest build.
```
