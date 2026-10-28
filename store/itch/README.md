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
| Languages | English |
| Inputs | Keyboard, Mouse, Xbox controller, Playstation controller, Touchscreen |
| Cover image | `cover_en.png` (630×500) |
| Screenshots | `en_1_combat.png`, `en_2_parry.png`, `en_5_challenge.png`, `en_6_inventory.png`, `en_17_frenzy.png`, `en_16_rune.png`, `en_9_slam.png`, `en_14_air_charge.png`, `en_11_cave.png`, `en_13_map.png`, `en_12_dungeon.png`, `en_7_merchant.png`, `en_8_shop.png`, `en_3_level_up.png`, `en_4_menu.png`, `en_10_controls.png`, `en_15_options.png` (per ora il gioco è solo in inglese) |

### Tags

Su itch.io se ne possono mettere al massimo 10:

```
action-rpg, fantasy, medieval, goblins, isometric, 2d, controller, singleplayer, procedural-generation, prototype
```

---

## Short description or tagline

```
A feral goblin, a world to explore, deadly Souls-like combat.
```

---

## Description

Da incollare così com'è nel campo *Description* (l'editor accetta il testo
formattato; i titoli si possono rendere in grassetto).

```
Gobelino is a 2D medieval fantasy action RPG with an isometric view.

You are a lone goblin with no past, living in a den like a wild animal. Starting from the woods around your den, you will explore the world beyond, grow stronger and meet those who will open new paths for you.

⚠️ This is a prototype build: the goblin and the enemies are placeholder geometric shapes and the sounds are synthesized placeholders. It's here to test the combat.

IN THIS PROTOTYPE
- A boundless, randomly generated 3D isometric world made of blocks: grassy platforms stacked in steps at different heights, sloping ramps and dirt paths. Jump to climb onto higher blocks (multiple jumps reach the tallest ones) and drop down to lower ground. Here and there trees, rocks and bushes (bushes slow you down)
- Souls-like combat, fast and deadly for both sides: every enemy blow costs you one heart (two from the boss), so a few mistakes and you're dead; after a hit you blink for a moment and can't be hit again. Every enemy attack has a clear wind-up, so when you get hit it's on you. Your strikes land instantly; no more than two enemies attack at once while the others circle around, waiting for their turn
- Stamina: attacking, dodging, jumping, blocking and running all drain it. Empty it and you can't swing or roll, and a block can break your guard. Green stamina potions (D-pad down) refill it in a hurry. Drinking a potion takes a moment, and enemies rush in to punish you when you heal or back away
- Real-time combat: chain up to 3 attacks in a combo, each hit stronger than the last, and finish it with a power strike for a big bonus (a mixed combo multiplies the power strike's damage). Strikes are deliberate and sweep a wide arc, power strikes an even wider one; hold the attack button to keep swinging
- Frenzy: every sword hit that lands fills the red Frenzy bar (it drains if you stop attacking for 4 seconds). When it's full, press parry and attack together (L1 + R1) for the special attack: time stops, the world goes dark, the goblin roars in a red glow and then teleports from enemy to enemy striking in a flurry (10 hits, more with the "Frenzy strikes" upgrade). You can't be hit while it lasts
- Parry with your sword across your body: the enemy's strike is cut short and the enemy is pushed back. Time it right before the hit for a perfect parry: the enemy is stunned and your attacks are empowered for a few seconds (double damage, faster swings)
- Dodge with a roll on the ground or an air dash mid-jump, steer it while dodging, and unlock upgrades to chain more dodges in a row. Parrying, dodging or jumping instantly cancels whatever you are doing, even mid-strike; attacking during an air dash turns it into an immediate strike. You can keep moving while attacking and every swing carries you well forward: every strike is different from the last (slash, backhand, overhead chop, thrust) and always hits the same area in front of you
- Jump over enemy attacks (unlock multiple jumps in mid-air) and combine jumps with dodges
- Tap L3 to start or stop running (it stops by itself when you stand still); dodge while running to slide, and attack, dodge, jump or parry out of the slide
- Hold R2 for focus mode: the world dims and loses its colors, with dark edges around the screen, while you, the items to pick up, closed chests, merchants, totems and passages stay in full color with a white aura, so you never miss them
- Healing, mana and stamina potions: carry up to 10 of each (more with upgrades); the ones you find or buy go straight to your belt (you start with 2 healing potions, 1 mana potion and 1 green stamina potion) and drinking restores you right away and a magic shield that absorbs one hit, recharging in 30 seconds
- Nine kinds of enemies: quick scouts, warriors, heavy brutes, summoners that call in reinforcements (hit them while they summon to interrupt them), lancers with long thrusts, whirlers that strike all around, huge golems, casters that hurl magic bolts and archers that shoot arrows from afar. Each enemy looks a little different (size, colors and a helmet, hood, horns or headband). There are only a few of them around at first, more and more as you level up, and they grow tougher with you (and deeper in the caves): more health, harder hits and, for brutes, golems and the boss, armor that soaks up part of your damage. You grow too: every level makes your strikes stronger and every few levels adds to your health
- Enemies are solid: you can't walk through them, but bumping into one doesn't hurt. They circle around you with quick sidesteps; watch them wind up (they glow red and pull back their weapon) and lunge leaving a red trail (bright even in the dark): the wind-up is short, so react fast, and beware of chains of strikes. Warriors, brutes, golems and the boss can also leap at you and slam the ground: a red glow on the ground marks where they will land, so get out, dodge or jump. They follow you across the terrain: they drop down ledges and jump up one-level steps (but never into ravines). Their strikes, slams and arrows hurt the other monsters too. They know how to defend: when they raise their guard your strike bounces off with a flash, your combo breaks and you are pushed back, often into a counterattack. Strike them from the side or from behind, or use ground attacks and fireballs to get through
- Walk up to chests, merchants, totems, caves and stairs and an "Interact" prompt appears: press A (or E) to use them. Loading screens cover every change of place, so the game never freezes
- No numbers or words pop up over the fighters: when your health runs low the edges of the screen pulse red
- Aerial attacks: attack in mid-air for wide slashes that also reach the enemies below you, and chain them into an air combo
- Cataclysm runes: in mid-air, with a rune in your belt, the power strike makes you lift the rune over your head (hold it to float slowly upward and widen the blast) and smash it on the ground: an arcane blast kills every enemy around and takes 35% of the boss's health, leaving you unharmed but blackened with soot. While you float archers and casters seize the chance to shoot you down. You carry up to 3 runes (one more with an upgrade): find them in chests, on enemies, at the merchants and always on the boss. A power strike during an air dash smashes a wide area. While slamming you pass through enemies, and the impact throws back everyone around (except bosses)
- Hold the power strike to charge it up to double damage (every power strike drains mana for as long as you hold it: with no mana left it fires uncharged), and keep holding to chain the next power strikes: if the first one was charged, every power strike chained after it in that combo deals extra damage; every hit you land freezes the action for an instant, throws sparks, knocks the enemy back and spills blood that splatters on the ground and on the fighters (wounds flash on the body, a pool of blood stays where someone dies, and every kill stains the goblin a little more); hit and death cries are short 8-bit yelps; fallen enemies lie on the ground for a while. Bump into whatever blocks your way (rocks, trees, chests, walls too high to climb) and it lights up for an instant (only the obstacle or the stretch of wall you hit), bouncing you back a little
- Cast fireballs that seek out and chase the nearest enemy in sight (never one behind a wall or an obstacle) (they cost mana, which never refills by itself: drink mana potions); they crash into trees, rocks and walls
- Defeated enemies often drop gold or potions (healing, mana or stamina), sometimes a Cataclysm rune, rarely an item, and once in a while a rare one
- Day slowly turns to night (a dial next to the minimap shows the sun and the moon crossing the sky): hold L3 (or Shift) to light your torch or put it out: its light falls in a wide cone in front of you, so you can see at night and underground. Facing north, your sword and gear go behind your body. A minimap shows the area around you, enemies as red dots, chests, totems, merchants, cave entrances, stairs and exits. Press Select for the full map
- Open chests to find gold, weapons, armor, boots, amulets, rings, spell books and potions; equip the gear and read the books from your inventory, a scrolling grid you can sort by power or value, which compares each piece of gear with the one you are wearing
- Travelling merchants are scattered around the world: walk up to their stall and interact to sell the items you don't use and to buy potions (healing, mana and stamina), Cataclysm runes and rare gear you won't find in chests (dragon sword, plate armor, wind boots, archmage amulet, inferno ring, meteor and vigor tomes, elixirs)
- Long mountain ranges and deep ravines cut across the land: mountains can't be crossed, ravines can swallow you, but a running jump and a couple of air dashes can carry you over the narrow ones. Caves open in the mountain walls
- Interact with a cave entrance to explore a dark underground of tunnels and caverns: find the passage down in the cave walls on each level (2 to 5 levels) and face the Cave Guardian, a tough boss that grows with your level, in its arena on the last one: it never leaves the arena and, from a distance, it charges up and hurls fans of magic bolts. Beat it for gold, a Cataclysm rune and special items you can't find anywhere else
- The game saves automatically every 5 minutes and whenever you enter a cave, waiting until no enemies are nearby (the enemies around, the boss included, are saved too, right where they were and with the health they had left); you can also save from the pause menu at any time, even on the move, as long as no enemies are nearby. Three save slots, side by side: each one shows your level, where you are, health and damage, gold and potions, enemies defeated, play time and when it was saved. Pick one when you start a new game (an occupied slot asks for confirmation) and the game is saved there right away; Continue on the title screen picks up your most recent save straight away
- The game locks on to the nearest enemy you can see by itself (never one behind a wall): a red ring circles its feet, it glows red, you face it, your strikes and fireballs go its way and the camera keeps it in view. Press R3 (or C) for a manual lock that keeps that target while it lives and stays close, and again to switch to the nearest one
- Tall walls, mountains and cliffs that hide your character turn fully transparent around you, showing the ground behind them, so you always see what is happening. When you close a menu with A or B, the button doesn't also make you jump, dodge or open the chest next to you
- Stone totems stand in the middle of wide open arenas: interact with one to start a 30-second survival challenge with waves of enemies matched to your level, and earn experience and a potion
- Earn experience to level up: the first ten levels come quickly, then each one takes a little longer. Every level raises your base damage and lets you choose an upgrade: one more combo hit, one more chained power strike, one more chained dodge, one more jump, one more health point (only now and then), a faster shield recharge (5%), a faster run (5%), more stamina (10%), more mana, a stronger spell, one more potion of each kind carried (healing, mana and stamina), stronger healing potions, stronger mana potions (5%), one more Cataclysm rune carried, more Frenzy strikes (+2) or one more card to choose from at the next level-ups: three of them (more with that upgrade), picked at random, are offered on cards with icons. Your skill levels are always shown on screen, and the active power-ups are shown as small icons in the bottom-right corner

- Play with the mouse too: left click to attack and right click for a power strike toward the cursor, middle click to walk to the cursor (hold it to keep following)
- Every control can be remapped from Options (title screen or pause menu): keyboard, mouse and controller, each with its own column, saved for next time and reset to defaults with one button

CONTROLS (defaults: change them in Options)
- Move: left stick / WASD / on-screen stick / middle click (walk to the cursor)
- Attack (combo; hold to keep attacking): R1 / J / left click
- Power strike (ends the combo; hold to charge, uses mana; keep holding to chain): L2 / L / right click
- Parry (hold): L1 / K
- Dodge (press again to chain; cancels any action): B / Space
- Jump (cancels any action): A / F
- Run on/off (dodge while running = slide): tap L3 / Shift
- Torch on/off: hold L3 / Shift
- Focus (hold: dims the world, highlights you, items, chests and passages): R2 / V
- Fireball: X / U
- Shield: Y / R
- Potion: D-pad left / Q
- Mana potion: D-pad right / T
- Stamina potion: D-pad down / G
- Interact (chests, merchants, totems, caves, stairs): A / E
- Inventory: D-pad up / I (R3 / C to sort)
- Map: Select / M
- Manual lock on the nearest enemy you can see (press again to switch; without it the lock is automatic): R3 / C
- Frenzy special attack (full Frenzy bar): parry + attack together, L1 + R1 / K + J
- Pause menu (save, controls, tutorial, options, quit to title with confirmation): Start / Esc
- Special attacks: power strike right after a combo = mixed combo with bonus damage; charged first power strike = stronger chained power strikes; attack in mid-air = aerial slashes; power strike in mid-air = smash a Cataclysm rune (hold to float and widen the blast); power strike during an air dash = dash strike

Play with a controller (Steam Deck and MSI Claw built-in controls included), keyboard and mouse or touch screen. The full list of controls and a 13-page illustrated tutorial are in the main menu (and in the pause menu), and you can remap them in Options. English only for now.

PLATFORMS
Windows (handheld gaming PCs like the MSI Claw 8 included), Linux and SteamOS (Steam Deck). Capped at a steady 60 FPS. On Linux it renders with Vulkan, falling back to OpenGL 3.3 when Vulkan is not available.
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
