# Gobelino — Game Design Document

Documento vivo: da compilare e aggiornare. Le sezioni vuote sono da definire.

## 1. Visione

- **Titolo provvisorio**: Gobelino
- **Genere**: RPG fantasy medievale 2D, visuale isometrica, combattimento in tempo reale
- **Piattaforme target**: Windows, Linux, SteamOS (Steam Deck) e Android. Steam per desktop e Deck, Google Play per Android
- **Pitch in una frase**: Un goblin solitario, muto e senza passato, che vive in una tana come un animale selvatico, esplora il mondo attorno a sé, diventa più forte e incontra chi gli apre nuove strade.
- **Pubblico**: _da definire_
- **Durata stimata**: _da definire (consigliato 5-10 ore per il primo titolo)_

## 2. Ambientazione e tono

- **Mondo**: si parte dai dintorni della tana del goblin e ci si allarga al mondo circostante, fino alle città. Dettagli da definire
- **Epoca e atmosfera**: medievale fantasy
- **Tono** (serio, ironico, cupo...): _da definire_
- **Riferimenti e ispirazioni**: _da definire_

## 3. Protagonista e personaggi

- **Protagonista**: un goblin che vive in una tana tutta sua. Non parla, non ha un passato, è completamente solo e si comporta come un animale selvatico. Nome: _da definire_
- **Personaggi chiave**: personaggi incontrati nel mondo che introducono nuove quest. Elenco _da definire_
- **Fazioni**: _da definire_

## 4. Loop di gioco

Cosa fa il giocatore minuto per minuto, ora per ora:

- **Esplorazione**: partire dai dintorni della tana, poi scoprire il mondo e le città
- **Combattimento**: in tempo reale. Dettagli (attacco, schivata, stamina, armi) _da definire_
- **Progressione**: diventare più forte, trovare nuove armi e nuovo equipaggiamento. Sistema _da definire (livelli, abilità)_
- **Quest**: assegnate da personaggi incontrati lungo il cammino
- **Looting**: sia drop dai nemici sia forzieri e oggetti fissi nel mondo. Tabelle di drop e rarità _da definire_
- **Economia**: _da definire_

## 5. Sistemi principali

Priorità di design indicata: il cuore del gioco sono sistema di gioco, inventario e looting. Vanno definiti prima dei contenuti.

| Sistema | Descrizione | Stato |
|---|---|---|
| Movimento | Isometrico, 8 direzioni; tastiera, gamepad e touch | da fare |
| Combattimento | Tempo reale | da fare |
| Inventario | A slot con limite di peso. Dettagli (numero slot, pesi, deposito nella tana) _da definire_ | da fare |
| Dialoghi | _da definire_ | da fare |
| Quest | _da definire_ | da fare |
| Salvataggi | _da definire_ | da fare |

## 6. Storia

- **Premessa**: _da definire_
- **Struttura** (atti, finali): _da definire_

## 7. Arte e audio

- **Stile grafico**: 2D isometrico (pixel art, disegnato a mano...): _da definire_
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
- **Isometrico**: `TileMapLayer` con forma tile isometrica, ordinamento per profondità con Y-sort, movimento convertito dagli assi di input agli assi isometrici
- **Input**: tastiera, gamepad e touch tramite Input Map; UI utilizzabile anche solo con controller
- **Dati**: contenuti di gioco in `data/` (JSON o risorse), separati dal codice
- **Repository**: ramo unico `main`, CI su GitHub Actions
