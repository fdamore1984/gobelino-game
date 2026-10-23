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
| Languages | English |
| Inputs | Keyboard, Xbox controller, Playstation controller |
| Cover image | `cover_en.png` (630×500) |
| Screenshots | `en_1_combat.png`, `en_2_parry.png`, `en_5_challenge.png`, `en_6_inventory.png`, `en_9_slam.png`, `en_11_cave.png`, `en_12_dungeon.png`, `en_7_merchant.png`, `en_8_shop.png`, `en_3_level_up.png`, `en_4_menu.png`, `en_10_controls.png` (per ora il gioco è solo in inglese) |

### Tags

Su itch.io se ne possono mettere al massimo 10:

```
action-rpg, fantasy, medieval, goblins, isometric, 2d, controller, singleplayer, procedural-generation, prototype
```

---

## Short description or tagline

```
A feral goblin, a world to explore, real-time combat.
```

---

## Description

Da incollare così com'è nel campo *Description* (l'editor accetta il testo
formattato; i titoli si possono rendere in grassetto).

```
Gobelino is a 2D medieval fantasy action RPG with an isometric view.

You are a lone goblin with no past, living in a den like a wild animal. Starting from the woods around your den, you will explore the world beyond, grow stronger and meet those who will open new paths for you.

⚠️ This is a prototype build: the goblin is drawn in code in an ink-sketch style, enemies are placeholder geometric shapes and the sounds are synthesized placeholders. It's here to test the combat.

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
- Ground attacks that hit every enemy around: a power strike right after a combo makes you leap and slam the ground (every chained power strike after the combo does it too), attacking in mid-air plunges you onto the ground, and attacking during an air dash smashes a wide area
- Hold the power strike to charge it up to double damage; every hit you land freezes the action for an instant, throws sparks, knocks the enemy back and spills blood that stays on the ground; fallen enemies lie on the ground for a while. Whatever blocks your way (rocks, trees, chests, walls too high to climb) lights up while you bump into it
- Cast fireballs that seek out and chase the nearest enemy (they cost mana: drink mana potions to refill); they crash into trees, rocks and walls
- Defeated enemies sometimes drop gold or items, and once in a while a rare one
- Day turns to night: light your torch to see a wide area in the dark. A minimap shows the area around you, enemies as red dots, chests, totems and merchants
- Open chests to find gold, weapons, armor, boots, amulets, rings, spell books and potions; equip them, read the books and drink the potions from your inventory
- Travelling merchants are scattered around the world: touch their stall to sell the items you don't use and to buy potions and rare gear you won't find in chests (dragon sword, plate armor, wind boots, archmage amulet, inferno ring, meteor and vigor tomes, elixirs)
- Play as an angry, arrogant goblin whose face changes with the action: he snarls when he attacks, winces when hit and lets out a goblin giggle when he beats a boss
- Long mountain ranges and deep ravines cut across the land: mountains can't be crossed, ravines can swallow you, but a running jump and a couple of air dashes can carry you over the narrow ones. Now and then a cave opens in a mountain wall
- Walk into a cave to explore a dark underground of tunnels and caverns: find the passage down in the cave walls on each level (2 to 5 levels) and face the Cave Guardian, a tough boss that grows with your level, in its arena on the last one. Beat it for gold and special items you can't find anywhere else
- The game saves automatically every 5 minutes and whenever you enter a cave; you can also save from the pause menu, as long as no enemies are nearby and you are standing still. Continue your game from the title screen
- Lock on to the nearest enemy with R3 and press again to switch target: you always face it, your strikes and fireballs go its way and the camera keeps it in view
- Tall walls, mountains and cliffs that hide your character turn fully transparent around you, so you always see what is happening
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
- Lock on the nearest enemy (press again to switch target): R3 / C
- Pause menu (save, controls, quit): Start / Esc
- Special attacks: power strike right after a combo = leap and slam; attack in mid-air = plunge; attack during an air dash = dash strike

Play with a controller (Steam Deck built-in controls included) or keyboard. The full list of controls is in the main menu. English only for now.

PLATFORMS
Linux and SteamOS (Steam Deck).
```

---

## Download instructions

Campo *Download & install instructions* (sotto la sezione Uploads).

```
HOW TO INSTALL

Linux / Steam Deck: download the Linux file, extract it and run Gobelino.x86_64 (if needed, make it executable first: right click → Properties → Allow executing, or chmod +x Gobelino.x86_64). On Steam Deck do this in Desktop Mode, then add it to Steam as a non-Steam game (Steam → Games → Add a Non-Steam Game) and always launch it from Steam: this way the built-in controller works as a gamepad, both in Game Mode and in Desktop Mode. If you launch it from the itch.io app in Desktop Mode instead, hold the Menu (Start) button for 1 second to switch the built-in controls to controller mode: while a controller is connected the game ignores the keys Steam's desktop layout keeps sending. The main menu shows the detected controller and whether its buttons are recognized.

Tip: with the itch.io app (https://itch.io/app) the game updates automatically to the latest build.
```
