# Gobelino — Game Design Document

Documento vivo: da compilare e aggiornare. Le sezioni vuote sono da definire.

## 1. Visione

- **Titolo provvisorio**: Gobelino
- **Genere**: RPG fantasy medievale 2D
- **Piattaforme target**: Windows, Linux, SteamOS (Steam Deck) e Android. Steam per desktop e Deck, Google Play per Android
- **Pitch in una frase**: _da definire_
- **Pubblico**: _da definire_
- **Durata stimata**: _da definire (consigliato 5-10 ore per il primo titolo)_

## 2. Ambientazione e tono

- **Mondo**: _da definire_
- **Epoca e atmosfera**: medievale fantasy
- **Tono** (serio, ironico, cupo...): _da definire_
- **Riferimenti e ispirazioni**: _da definire_

## 3. Protagonista e personaggi

- **Protagonista**: _da definire_
- **Personaggi chiave**: _da definire_
- **Fazioni**: _da definire_

## 4. Loop di gioco

Cosa fa il giocatore minuto per minuto, ora per ora:

- **Esplorazione**: _da definire_
- **Combattimento**: _da definire (a turni, in tempo reale, ibrido)_
- **Progressione**: _da definire (livelli, equipaggiamento, abilità)_
- **Economia**: _da definire_

## 5. Sistemi principali

| Sistema | Descrizione | Stato |
|---|---|---|
| Movimento | _da definire_ | da fare |
| Combattimento | _da definire_ | da fare |
| Inventario | _da definire_ | da fare |
| Dialoghi | _da definire_ | da fare |
| Quest | _da definire_ | da fare |
| Salvataggi | _da definire_ | da fare |

## 6. Storia

- **Premessa**: _da definire_
- **Struttura** (atti, finali): _da definire_

## 7. Arte e audio

- **Stile grafico**: 2D (pixel art, disegnato a mano...): _da definire_
- **Risoluzione base**: 1280x720 (impostata nel progetto, modificabile)
- **Musica e suoni**: _da definire_

## 8. Scope e roadmap

1. **Prototipo**: personaggio che si muove, un nemico, un combattimento
2. **Vertical slice**: un'area completa e giocabile
3. **Contenuti**: aree, quest, nemici, oggetti
4. **Rifinitura**: bilanciamento, UI, audio, bug fixing
5. **Steam**: pagina store, build beta su branch privato, lancio

## 9. Decisioni tecniche

- **Motore**: Godot 4.4, GDScript, renderer Compatibility
- **Input**: tastiera, gamepad e touch tramite Input Map; UI utilizzabile anche solo con controller
- **Dati**: contenuti di gioco in `data/` (JSON o risorse), separati dal codice
- **Repository**: ramo unico `main`, CI su GitHub Actions
