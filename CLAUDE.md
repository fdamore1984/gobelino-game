# Regole di lavoro per Gobelino

- **Lingua**: per ora tutto ciò che vede il giocatore è solo in inglese.
  I testi del gioco stanno in `data/translations.csv` (colonna `en`)
  e nel codice si usano con `tr("CHIAVE")`; mai testi scritti nel codice.
  Anche la pagina itch.io è solo in inglese. Documentazione interna, commenti e
  commit restano in italiano.
- **Pagina itch.io sempre aggiornata**: a ogni modifica che cambia ciò che il
  gioco fa o mostra, aggiorna `store/itch/README.md` (descrizione, comandi,
  tag) e rigenera copertina e screenshot con `tools/store_capture.tscn`
  (istruzioni nel README della cartella). itch.io non ha API per la pagina:
  segnala all'utente cosa ricaricare a mano.
- **Contenuti nei dati**: caratteristiche di nemici e simili in `data/`
  (per esempio `data/enemies.json`), separate dal codice.
- **Input**: solo azioni dell'Input Map; tutto deve funzionare con tastiera,
  gamepad (menù compresi) e touch.
- **Asset provvisori**: grafica geometrica disegnata in codice e suoni
  sintetizzati in `scripts/sfx.gd`, finché non arrivano gli asset definitivi.
- **Verifica prima di pubblicare**: import e avvio senza errori né warning
  con Godot 4.4.1, test delle meccaniche toccate, screenshot di controllo.
- **Merge automatico**: ogni modifica passa da una Pull Request verso `main`;
  quando la CI della PR è verde (export Linux: per ora si pubblica solo per Linux / SteamOS) si fa il
  merge senza chiedere conferma, poi si verifica il caricamento su itch.io
  del build su `main`. Se la CI è rossa, niente merge: si corregge prima.
