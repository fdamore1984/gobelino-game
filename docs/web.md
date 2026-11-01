# Versione web (sito ufotizio.com)

Il gioco si esporta anche per il browser (preset **Web** di
`export_presets.cfg`), per pubblicarlo su **ufotizio.com** insieme agli altri
giochi del sito. La CI fa l'export a ogni PR e lo lascia come artefatto `web`
scaricabile dalla pagina della run (non va su itch.io); sul sito lo si carica
nel bucket R2 con `tools/carica-giochi.sh` del repo ufotizio-site, che carica
anche la pagina itch.io (`store/itch/`) mostrata sotto il gioco.

## Export

- Renderer Compatibility (WebGL 2), come le altre versioni.
- **Senza thread** (`variant/thread_support=false`): non servono gli header
  COOP/COEP sul server, funziona dentro un iframe e su Safari. L'audio usa la
  riproduzione a campioni del browser (i suoni sono generati da `scripts/sfx.gd`
  come sul PC).
- Il risultato è una cartella (`build/web/`): `index.html`, `index.js`,
  `index.wasm`, `index.pck` e qualche icona. Si serve così com'è, da un
  qualsiasi hosting statico; il server deve mandare `index.wasm` come
  `application/wasm` (lo fanno tutti gli hosting moderni).
- I testi usano Fredoka (`assets/fonts/fredoka_*.ttf`, il font del sito, vedi
  `UiStyle`). Nel browser non ci sono i font del sistema: le frecce della
  croce e pochi altri simboli che Fredoka non ha vengono da
  `assets/fonts/symbols.otf` (sottoinsieme di Inter). Licenza OFL di tutti e
  due in `assets/fonts/OFL.txt`, inclusa nell'export.

## Prestazioni sui telefoni

- Il terreno di ogni pezzo di mappa e ogni blocco tra i personaggi si
  disegnano come una mesh sola (`scripts/mesh_canvas.gd`, usata da
  `World.ChunkView` e `World.TerrainBlock`) invece che poligono per poligono:
  nel browser ogni chiamata di disegno costa molto, e così in partita sono
  poche centinaia per frame invece di qualche migliaio.
- Sui dispositivi touch (`pointer: coarse`) lo script in `html/head_include`
  limita `devicePixelRatio`, così la tela del gioco ha al più circa 540 pixel
  sul lato corto invece di tutti quelli dello schermo (2-3 volte tanti per
  lato sui telefoni): molti meno pixel da disegnare, con testi ancora
  leggibili. Su PC non cambia nulla.
- Le orde di non morti sono più piccole su telefoni e tablet, anche nel
  browser (`count_mobile` in `data/world.json`, vedi `Platform.is_mobile`).

## Cosa cambia nel browser

- **Lingua**: è quella del sito (`ufotizioCloud.language()`, vedi sotto),
  anche se nel browser ne era salvata un'altra; cambiandola dalle Opzioni
  del gioco cambia anche quella del sito (`setLanguage`).
- `Platform.is_web` è vero: nel menù iniziale non c'è **Esci** (il gioco si
  chiude chiudendo la pagina).
- **Comandi**: tastiera e mouse come sul PC; controller con l'API Gamepad del
  browser (Chrome, Edge, Firefox; il controller si "sveglia" premendo un tasto
  dopo aver aperto la pagina); touch con i controlli a schermo
  in Modalità Touch (vedi sotto).
- I clic emulati dai tocchi non premono le azioni del mouse (vedi
  `Keybinds._apply`): toccare la levetta non attacca.
- Il browser fa partire l'audio solo dopo il primo clic, tocco o tasto.
- A schermo intero il primo **Esc** lo prende il browser per uscire dallo
  schermo intero. La pagina del sito può evitarlo con la Keyboard Lock API
  (vedi sotto); la pausa resta comunque su Start del controller e sul pulsante
  Menu del touch.

## Modalità Touch (solo nel browser)

All'avvio della versione web `Platform._detect_touch_only` guarda se c'è un
controller o la coppia tastiera e mouse (`(pointer: fine)` e
`(hover: hover)` del browser): se non c'è nessuno dei due (telefoni e
tablet, `web_android` / `web_ios` sempre) parte la **Modalità Touch**
(`Platform.touch_mode`). Nelle versioni per PC (Windows, Linux / SteamOS)
la Modalità Touch non esiste: niente controlli a schermo né automazioni.

- **Controlli a schermo** (`scripts/touch_controls.gd`): in alto a sinistra,
  sotto lo stato, Menù, Zaino e Mappa; in basso a sinistra la levetta; in
  basso a destra Attacco (tasto unico) e Schivata, più i tasti colorati
  Runa e Frenesia, che compaiono solo quando si possono usare, e il tasto verde
  Interagisci, solo vicino a qualcosa con cui interagire (il suggerimento
  sopra l'oggetto dice solo "Interagisci", senza tasto). Nessun altro tasto.
- **Automazioni** (`scripts/touch_assist.gd`, chiamato da
  `Player._physics_process`; preme e rilascia le azioni dell'Input Map):
  salto davanti ai dislivelli superabili con i salti rimasti; pozioni di mana e vigore bevute da sole
  quando mana o vigore finiscono (a vita zero, in `Player.receive_hit`, si
  consuma subito una pozione della vita); scudo alzato appena è carico; torcia accesa e
  spenta secondo il buio (`DayNight.darkness`).
- **Combattimento**: Attacco tenuto premuto fa da solo combo normale →
  colpo potente → salto e slam, finché regge il vigore; da lontano
  la palla di fuoco, mai con un nemico vicino. La parata è automatica (in
  `Player.receive_hit`, non perfetta) tranne mentre si tiene Attacco.
- **Pannelli**: inventario, mappa, negozio, pausa, opzioni, tutorial e
  slot hanno un pulsante da toccare per uscire (Chiudi, Indietro,
  Riprendi): quando sono aperti coprono i tasti a schermo.
- **Menù e tutorial**: il pulsante Comandi sparisce (menù iniziale e di
  pausa); il tutorial ha un percorso a parte (`TutorialPanel.TOUCH_PAGES`)
  che spiega controlli e automazioni.

## Scatti nel browser

Nel browser (senza thread) tutto quello che si prepara la prima volta pesa
sul frame in cui succede. Per questo: la regione successiva del terreno si
genera in sottofondo poco per volta, i blocchi e gli ostacoli dei pezzi
nuovi si aggiungono pochi per frame, i nemici compaiono al più due alla
volta e durante la prima schermata di caricamento si preparano gli shader
usati solo in certi momenti (vedi README, *Prestazioni*).

## Salvataggi sull'account (`scripts/cloud.gd`)

I file del giocatore in `user://` (nel browser stanno in IndexedDB) sono:

| File | Contenuto |
|---|---|
| `savegame_1.json` … `savegame_3.json` | i tre slot |
| `settings.json` | lingua |
| `keybinds.json` | comandi personalizzati |

L'autoload `Cloud` li tiene allineati con l'account del sito, **se la pagina
che ospita il gioco offre l'oggetto JavaScript `window.ufotizioCloud`**. Il
gioco non sa niente del servizio usato dal sito (Supabase, Firebase, un
server proprio): parla solo con questo oggetto. Se il gioco è dentro un
`<iframe>` della stessa origine, prende l'oggetto della pagina che lo contiene
(script in `html/head_include` del preset Web).

All'apertura del menù il gioco chiede all'account i suoi file e, per ognuno,
vince la versione più recente: quella dell'account si scrive nel browser,
quella del browser si carica sull'account. Finché non ha finito (al massimo 12
secondi) i pulsanti del menù sono disattivati. Poi ogni salvataggio, cambio
di comandi si carica subito, e ogni cancellazione (slot
eliminato, comandi predefiniti) si segna sull'account, così un file cancellato
su un dispositivo non torna da un altro. In basso a sinistra nel menù si legge
se i salvataggi sono sull'account, solo nel browser o se l'account non
risponde. Senza `ufotizioCloud`, o senza accesso fatto, tutto resta nel browser
come nelle altre versioni.

### Contratto di `window.ufotizioCloud`

L'oggetto lo scrive il sito (per esempio in `/account/cloud.js`), con il
servizio che preferisce. `game` è il nome del gioco (`"gobelino"` per
questo gioco, `"ciccio-massacro"` per Ciccio Massacro), `name` il nome del file, `updatedAt`
i secondi Unix della modifica.

```js
window.ufotizioCloud = {
  // true se il giocatore ha fatto l'accesso al sito.
  signedIn() { return true; },
  // Nome da mostrare nel menù del gioco.
  userName() { return "Mario"; },
  // Lingua del sito ("it" o "en"): il gioco la usa al posto di quella
  // salvata (facoltativo: senza, vale quella salvata).
  language() { return "it"; },
  // Il giocatore ha cambiato lingua dalle Opzioni del gioco: il sito passa
  // alla stessa lingua (facoltativo).
  setLanguage(code) { /* ... */ },
  // Promise di un TESTO JSON: { "<name>": { "text": "...", "updated_at": 1730000000, "deleted": false }, ... }
  loadFiles(game) { /* ... */ },
  // Salva (o sostituisce) un file; Promise.
  saveFile(game, name, text, updatedAt) { /* ... */ },
  // Segna il file come cancellato (deleted: true, updated_at); Promise.
  removeFile(game, name, updatedAt) { /* ... */ },
};
```

Le Promise di `saveFile` e `removeFile` non devono mai fallire senza gestire
l'errore: se la rete manca, il sito può riprovare più tardi; alla prossima
apertura il gioco ricarica comunque i file più recenti.

### Esempio con Supabase (da completare insieme alla pubblicazione)

Tabella, con le regole di accesso (Row Level Security) che fanno leggere e
scrivere a ognuno solo i propri file:

```sql
create table public.saves (
  user_id uuid not null references auth.users on delete cascade default auth.uid(),
  game text not null,
  name text not null,
  text text,
  updated_at bigint not null,
  deleted boolean not null default false,
  primary key (user_id, game, name)
);
alter table public.saves enable row level security;
create policy "solo i propri salvataggi" on public.saves
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

E l'oggetto per il gioco (`supabase` è il client già creato dalla pagina, con
l'accesso fatto):

```js
let session = (await supabase.auth.getSession()).data.session;
supabase.auth.onAuthStateChange((_event, s) => { session = s; });
window.ufotizioCloud = {
  signedIn: () => session != null,
  userName: () => session?.user?.user_metadata?.name || session?.user?.email || "",
  async loadFiles(game) {
    const { data, error } = await supabase.from("saves").select("name,text,updated_at,deleted").eq("game", game);
    if (error) throw error;
    return JSON.stringify(Object.fromEntries(data.map((r) => [r.name, r])));
  },
  async saveFile(game, name, text, updatedAt) {
    await supabase.from("saves").upsert({ user_id: session.user.id, game, name, text, updated_at: updatedAt, deleted: false });
  },
  async removeFile(game, name, updatedAt) {
    await supabase.from("saves").upsert({ user_id: session.user.id, game, name, text: null, updated_at: updatedAt, deleted: true });
  },
};
```

## Pagina del gioco sul sito

Il gioco si può aprire direttamente (`/gobelino/index.html`) o, meglio,
dentro una pagina del sito con intestazione e accesso all'account:

```html
<iframe src="/gobelino/index.html" allow="gamepad; fullscreen; autoplay"
        style="width: 100%; aspect-ratio: 16 / 9; border: 0"></iframe>
```

Per lo schermo intero conviene un pulsante della pagina che chiama
`iframe.requestFullscreen()` e poi `navigator.keyboard?.lock(["Escape"])`
(Chrome ed Edge): così Esc arriva al gioco e per uscire dallo schermo intero si
tiene premuto Esc.

## Prova in locale

```bash
godot --headless --export-release "Web"
cd build/web && python3 -m http.server 8000
# poi http://localhost:8000/ nel browser
```

Per provare i salvataggi sull'account basta una pagina che definisce un
`window.ufotizioCloud` finto (per esempio con i file in `localStorage`) e
apre il gioco in un iframe.
