# RoadTo100 — Roadmap e Stato del Progetto

## Stato del progetto

### Architettura attuale

```
┌─────────────────────────────────────────────────┐
│              UI Layer (Main.tscn)                 │
│  BoardPresenter  HandPresenter  TurnPresenter     │
│  CardAnimator (queue + tween)  CardFace  popup    │
│  DemoButton (Debug)                               │
│  Non conoscono le regole                          │
└─────────────────────┬───────────────────────────┘
                      │ snapshot / events / segnali
┌─────────────────────▼───────────────────────────┐
│              GameController.gd                    │
│  8 stati interfaccia (implementati)              │
│  Public: start_game(), perform_action()          │
│  Signal: action_applied(result)                  │
│  Passaggio E — completato (Step 1–7)             │
└─────────────────────┬───────────────────────────┘
                      │ perform_action() / start_game()
                      ▼
┌─────────────────────────────────────────────────┐
│         GameStateProvider (contratto)            │
│  signal game_started(snapshot)                   │
│  signal action_completed({snapshot, events})    │
│  signal action_rejected(msg)                    │
│  func start_game(n) / send_action(dict)         │
├──────────────────────┬──────────────────────────┤
│   LocalGameEngine    │ RemoteGameAdapter         │
│  (implementato)      │ (futuro — rete)          │
└──────────┬───────────┴──────────────────────────┘
           │
┌──────────▼──────────┐
│  RoadTo100Rules     │
│  CardData / Deck    │
│  Hand / PlayerData  │
│  GameState          │
│  CardDatabase       │
│  TextureResolver    │
└─────────────────────┘
```

### Componenti implementati

| Componente | File | Stato |
|---|---|---|
| **Domain (engine/)** | | |
| CardData | `engine/CardData.gd` | ✅ Completato (A) |
| Deck | `engine/Deck.gd` | ✅ Completato (A) |
| Hand | `engine/Hand.gd` | ✅ Completato (A) |
| PlayerData | `engine/PlayerData.gd` | ✅ Completato (A) |
| GameState | `engine/GameState.gd` | ✅ Completato (A) |
| GameConstants | `engine/GameConstants.gd` | ✅ Completato (A) |
| CardDatabase | `engine/CardDatabase.gd` | ✅ Completato (A) |
| TextureResolver | `engine/TextureResolver.gd` | ✅ Completato (D) |
| **Regole** | | |
| RoadTo100Rules | `engine/RoadTo100Rules.gd` | ✅ Completato (B) |
| **Provider** | | |
| GameStateProvider | `engine/GameStateProvider.gd` | ✅ Completato (C) |
| LocalGameEngine | `engine/LocalGameEngine.gd` | ✅ Completato (C) |
| **UI/Presenter** | | |
| CardFace | `scenes/CardFace.tscn` + `scripts/CardFace.gd` | ✅ Scaffold |
| BoardPresenter | `scripts/BoardPresenter.gd` | ✅ Scaffold |
| HandPresenter | `scripts/HandPresenter.gd` | ✅ Scaffold |
| TurnPresenter | `scripts/TurnPresenter.gd` | ✅ Scaffold |
| CardAnimator | `scripts/CardAnimator.gd` | ✅ Implementato (E5) |
| **Debug** | | |
| DebugDemo | `scripts/DebugDemo.gd` | ✅ Integrato con GC (E6) |
| DemoButton | In `Main.tscn` | ✅ Funzionante |
| **GameController** | `scripts/GameController.gd` | ✅ Implementato (E1–E7) |

### Stato passaggi

| Passaggio | Stato | Note |
|---|---|---|
| A — Domain port | ✅ Completato | 8 file engine, test diagnostico funzionante |
| B — Rules port | ✅ Completato | RoadTo100Rules.gd, 14 test Python equivalenti |
| C — Provider | ✅ Completato | GameStateProvider, LocalGameEngine, snapshot, eventi |
| D — Presenter/UI | ✅ **Completato e verificato** | Bug risolti (incluse schermata vittoria e carta 89). Test verificati con 10+ Demo. |
| E — Input/Animazioni | ✅ **Completato (Step 1–7)** | GameController, card selection, bottoni, popup Jolly/Imbroglio/Gold Reveal, CardAnimator, DebugDemo integrato, perform_action(). Test: 145 assert GC, 0 FAIL. |

---

## Decisioni architetturali definitive

Queste decisioni NON devono essere rimesse in discussione:

1. **Simulatore Python = reference implementation.** Il comportamento corretto del gioco è definito dal codice Python in `games/roadto100/`. Il GDScript è un porting fedele.
2. **Engine / Provider / Presenter / UI** — quattro strati separati. I presenter non conoscono le regole. Il provider è l'unica fonte di stato autorevole.
3. **GameStateProvider è un contratto astratto.** `LocalGameEngine` lo implementa oggi; `RemoteGameAdapter` lo implementerà in futuro. Presenter e UI non sanno quale implementazione è in uso.
4. **Snapshot ed eventi sono Dictionaries puri.** Nessun oggetto `Reference` (CardData, PlayerData) nei dati pubblici. Le carte sono identificate da `card_id` stringhe.
5. **Eventi con ordine per tipo azione.** L'ordine degli eventi non è determinato da confronto before/after, ma segue l'esatto ordine di esecuzione del Python `apply_action()` per ogni tipo di carta/azione.
6. **TextureResolver centralizzato.** Il mapping `{prefisso}{valore}.png` è l'unico modo per risolvere le texture. Nessuna mappatura manuale carta per carta.
7. **CardFace è puramente visuale.** Non contiene regole, logica di mano, networking o stato di gioco. Emette solo `clicked(card_id)`.
8. **`update()` non può essere usato come nome metodo** in classi che estendono Node/Control perché confligge con `CanvasItem.update()`. Usare `apply_snapshot()`.
9. **La Demo non parte automaticamente.** Solo tramite pulsante o F10.
10. **Main.tscn è il layout definitivo.** Non modificare posizione, dimensioni, font, margini, proporzioni o asset grafici esistenti.
11. **a.gd** è stato eliminato. Non ricrearlo.

---

## File modificati

### Engine (completato, non modificare)

| File | Motivo | Stato |
|---|---|---|
| `engine/CardData.gd` | Domain port da Python | ✅ |
| `engine/Deck.gd` | Domain port da Python | ✅ |
| `engine/Hand.gd` | Domain port da Python | ✅ |
| `engine/PlayerData.gd` | Domain port da Python | ✅ |
| `engine/GameState.gd` | Domain port da Python | ✅ |
| `engine/GameConstants.gd` | Domain port da Python | ✅ |
| `engine/CardDatabase.gd` | Domain port da Python | ✅ |
| `engine/RoadTo100Rules.gd` | Rules port da Python | ✅ |
| `engine/GameStateProvider.gd` | Contratto astratto provider | ✅ |
| `engine/LocalGameEngine.gd` | Provider concreto locale | ✅ |
| `engine/TextureResolver.gd` | Risoluzione texture centralizzata | ✅ |

### Script UI

| File | Motivo | Stato |
|---|---|---|
| `scripts/BoardPresenter.gd` | Aggiorna piatto, mazzo, scarti, carte permanenti, avversari | ✅ Scaffold |
| `scripts/HandPresenter.gd` | Gestisce mano giocatore locale | ✅ Scaffold |
| `scripts/TurnPresenter.gd` | Label, bottoni, popup | ✅ Scaffold |
| `scripts/CardAnimator.gd` | Coda animazioni FIFO, card_played tween, headless fallback (Passaggio E, Step 5) | ✅ Implementato |
| `scripts/CardFace.gd` | Carta visuale riutilizzabile | ✅ Scaffold |
| `scripts/DebugDemo.gd` | Demo automatica 4 giocatori — integrata con GameController (Passaggio E, Step 6) | ✅ Integrata |
| `scripts/GameController.gd` | Orchestratore centrale: 8 stati, input, popup, animazioni, perform_action() (Passaggio E, Step 1–7) | ✅ Implementato |

### Scene

| File | Motivo | Stato |
|---|---|---|
| `scenes/CardFace.tscn` | Carta visuale riutilizzabile | ✅ |
| `Main.tscn` | Script assegnati, ext_resource aggiunti | ✅ Invariata graficamente |

### Altro

| File | Motivo | Stato |
|---|---|---|
| `a.gd` | Eliminato | ✅ |

---

## Test

| Suite | File | Cosa verifica | Stato |
|---|---|---|---|
| **Domain** | `tests/domain_test.gd` + `.tscn` | Deck 60 carte, card_id univoci, Deck/Hand/Player/GameState operazioni | ✅ 60 card, 0 FAIL |
| **Rules** | `tests/rules_test.gd` + `.tscn` | 14 test: Gold chain, GdV lifecycle, 89/+11, deck reconstitution, reset hand | ✅ 48 assert, 0 FAIL |
| **Provider** | `tests/provider_test.gd` + `.tscn` | start_game 2/3/4p, snapshot, card_id, event order, plateau visual stack (4 sequenze) | ✅ 104 assert, 0 FAIL |
| **Presenter** | `tests/presenter_test.gd` + `.tscn` | Texture resolution, fallback, CardFace, Board/Hand/Turn presenter, button signals, selection, no rules, no auto-start | ✅ 84 assert, 0 FAIL |
| **Board** | `tests/board_test.gd` + `.tscn` | Plateau visual stack, gold/non-gold separation, opponent centering, rotation setup, chronological order | ✅ 42 assert, 0 FAIL |
| **GameController** | `tests/game_controller_test.gd` + `.tscn` | Stati, card selection, bottoni, popup, animazioni, integrazione Demo, input GUI reale | ✅ 145 assert, 0 FAIL |
| **CardAnimator** | `tests/card_animator_test.gd` + `.tscn` | FIFO, segnali start/finish, headless fallback, busy guard | ✅ 5 assert, 0 FAIL |

---

## Bug risolti (Passaggio D)

Tutti e tre i bug del Passaggio D sono stati risolti e verificati.

### Bug 1 — Mani avversarie non centrate

**Causa (primo tentativo):** `sx = max(0, (tw - total) / 2)` impediva la centratura quando le carte superavano la larghezza del contenitore.

**Causa reale (completa):** Due problemi distinti:
1. `max(0, ...)` azzerava l'offset sx, impedendo la centratura delle mani con overflow.
2. `rect_pivot_offset = rect_size / 2` veniva calcolato in `_ready()`, quando `rect_size` poteva essere ancora (0,0) perché il layout di Godot 3 non era stato finalizzato. Un pivot errato causa la rotazione attorno al punto sbagliato, spostando le mani Left/Right nonostante il calcolo matematico fosse corretto.

**Soluzione:**
1. Rimosso `max(0, ...)` da sx.
2. Rimosso il setup di pivot e rotazione da `_ready()`.
3. In `_update_opponents()`, per ogni aggiornamento:
   a. Si ricalcola `rect_pivot_offset = rect_size / 2` (usando la `rect_size` corretta a runtime).
   b. Si riapplica `rect_rotation`.
   c. Si piazzano le carte a (0,0) con la spaziatura corretta.
   d. Si calcola il bounding box effettivo delle carte visibili (solo figli con nome "OP*").
   e. Si applica l'offset di centratura a TUTTE le carte, calcolato come `(layer_center - bb_center)`.
4. `_opp_seats` ora memorizza `{layer, rotation_deg}` invece del solo nodo, per preservare l'angolo di rotazione tra aggiornamenti.

**File modificati:** `scripts/BoardPresenter.gd`

### Bug 2 — Le carte non Gold non vengono più duplicate sul Piatto

**Causa:** `game_state.metadata["plateau_cards"]` (gestito da `RoadTo100Rules`) contiene TUTTE le carte giocate in ordine cronologico, incluse quelle non Gold. Il `BoardPresenter._update_plateau()` creava una `CardFace` per ogni carta in questo array, mostrando quindi anche le carte non Gold come carte permanenti sul Piatto.

**Soluzione:** Suddivisa la responsabilità in due livelli:

1. **Provider** (`LocalGameEngine._build_snapshot()`): nuovo metodo `_build_plateau_visual_stack()` che ricostruisce la pila visiva cronologica, distinguendo tra:
   - Carte Gold/89 → mostrate come `CardFace` (carte permanenti)
   - Carte non Gold → aggiornano il valore corrente del Piatto, rappresentato da una "carta Piatto" (`TextureRect` con `plate.png` + etichetta valore)
   
   Il risultato è un array `plateau_visual_stack` nel snapshot, con item di tipo `{"type":"plate","value":N}` e `{"type":"card","card":{...}}`.

2. **Presenter** (`BoardPresenter._update_plateau()`): ora consuma `plateau_visual_stack` invece di `plateau_cards`, creando il nodo appropriato per ogni item.

**File modificati:** `engine/LocalGameEngine.gd`, `scripts/BoardPresenter.gd`

### Bug 3 — Ordine cronologico della pila del Piatto (e Gold coperta)

**Causa originale:** Stessa causa del Bug 2. Tutte le carte erano mostrate come carte permanenti, senza distinzione tra Gold/89 e carte non Gold.

**Causa dopo la prima correzione:** La nuova `_build_plateau_visual_stack()` produceva una sequenza come `[plate(0), goldCard, plate(23)]` subito dopo una Gold. Lo Step 3 finale dello stack aggiungeva una carta Piatto sopra OGNI Gold/89, coprendola immediatamente:

```gdscript
# Step 3 (vecchio):
if visual[visual.size() - 1]["type"] == "card":
    visual.append({"type": "plate", "value": current_piatto})
```

**Soluzione finale:** Lo Step 3 ora controlla l'ULTIMA CARTA GIOCATA (non l'ultimo elemento visivo). Se è una Gold/89, non aggiunge la carta Piatto finale — la Gold rimane in cima:

```gdscript
# Step 3 (corretto):
if visual.size() > 0 and segments.size() > 0:
    var last_seg_is_gold = segments[segments.size() - 1]["is_gold_or_89"]
    if not last_seg_is_gold:
        # Last card was non-Gold: ensure a final plate
        ...
    # Last card was Gold/89: card face remains top element — no plate added.
```

Comportamento risultante:
- Subito dopo una Gold → `[..., plate(prec), gold]` — la Gold è visibile in cima
- Dopo non-Gold successivo → `[..., gold, plate(nuovo_valore)]` — nuova carta Piatto sopra la Gold
- Dopo altra Gold → `[..., plate, gold]` — Gold torna in cima

**File modificati:** `engine/LocalGameEngine.gd`

### Test aggiunti/aggiornati

| Test | File | Verifica |
|---|---|---|
| Plateau visual stack — Seq A | `tests/provider_test.gd` | non-Gold + Gold: stack = [plate(0), card(gold)] |
| Plateau visual stack — Seq B | `tests/provider_test.gd` | non-Gold + Gold + non-Gold: [plate, card, plate] |
| Plateau visual stack — Seq C | `tests/provider_test.gd` | non-Gold + Gold + non-Gold + Gold: gold in cima |
| Plateau visual stack — Seq D | `tests/provider_test.gd` | Sequenza completa 5 carte, valori intermedi corretti |

### Bug 4 — Gold coperta dal PlateauValueCard statico

**Causa:** Il nodo `PlateauValueCard` (TextureRect con `plate.png`) in `Main.tscn` è un fratello di `PermanentCardsLayer` dichiarato DOPO nel file. Godot 3 renderizza i fratelli in ordine di dichiarazione — l'ultimo va sopra. Quindi `PlateauValueCard` copriva sempre tutto il contenuto dinamico di `PermanentCardsLayer`, incluse le CardFace delle Gold.

La correzione dello Step 3 di `_build_plateau_visual_stack()` produceva il visual stack corretto (Gold era l'ultimo elemento), ma il `PlateauValueCard` statico veniva renderizzato SOPRA la Gold, nascondendola.

**Soluzione:** In `BoardPresenter._ready()`, il `PlateauValueCard` statico viene trovato e nascosto (`visible = false`). Le carte Piatto dinamiche dentro `_permanent_layer` lo sostituiscono.

**File modificati:** `scripts/BoardPresenter.gd`

### Bug 5 — Duplicazione valore del Piatto

**Causa:** Tre fonti del numero del Piatto venivano renderizzate simultaneamente:
1. `ValueLabel` statico in `ValueLayer` (fratello di `PermanentCardsLayer`, sempre visibile, aggiornato da `apply_snapshot()`)
2. Label dinamico dentro ogni carta Piatto creata da `_update_plateau()`
3. Texture delle Gold (il valore è già stampato nell'immagine, es. `gold23.png`)

Il `ValueLabel` statico veniva renderizzato SOPRA tutto, causando:
- Carte Piatto: due numeri sovrapposti (Label dinamico + ValueLabel statico)
- Gold: numero della texture + numero del ValueLabel sovrapposto

**Soluzione:** In `BoardPresenter._ready()`, il `ValueLayer` statico viene nascosto (`visible = false`). Il numero del Piatto è ora mostrato esclusivamente dai Label dinamici dentro le carte Piatto e dalle texture delle Gold.

**File modificati:** `scripts/BoardPresenter.gd`

### Posizioni seat definitive

Le posizioni manuali corrette nella scena (da `Main.tscn`) sono:

| Nodo | margin_top |
|---|---|
| TopSeat | 110 |
| LeftSeat | 500 |
| RightSeat | 500 |

Queste posizioni NON devono essere modificate dal codice runtime. `BoardPresenter` non sovrascrive più `rect_pivot_offset` o `rect_rotation` in `_ready()`, quindi le posizioni della scena vengono preservate.

### Verifica finale

✅ **Passaggio D completato e verificato.** La Demo Automatica completa una partita senza errori runtime. Verifica visiva superata:
- Mani avversarie centrate
- Gold visibile in cima al Piatto dopo la giocata
- Carte non Gold solo negli Scarti
- Carte Piatto dinamiche con valore corretto (nessuna duplicazione numerica)
- Sequenza 89→100 con carta Piatto 100 in cima
- Nessun crash o errore runtime

Bug risolti:
1. **Giro di Vantaggio / carta 89** — Causa: 89 trattata come incremento (`plateau += 89`) invece di set (`plateau = 89`). Corretto in GDScript e Python. Test aggiunti per Piatto 0/11/50 → 89. Tutte le suite passano.
2. **Schermata di vittoria — nome non trovato oltre Player 1** — Il loop `for p in s.get("players", [])` in `TurnPresenter.apply_snapshot()` non trovava il vincitore per giocatori oltre l'indice 0 nello snapshot reale, causando `" vince!"` senza nome. Sostituito con accesso indicizzato `for i in range(players.size())`. Test di regressione per tutti e 4 i giocatori in `presenter_test.gd`.

---

## Vincoli permanenti

1. **GAME_RULES.md** è la fonte autorevole delle regole.
2. **PROJECT_STATE.md** riflette lo stato del progetto — consultare prima di ogni modifica.
3. **Non modificare il motore di gioco** (`RoadTo100Rules.gd`) per correggere bug grafici.
4. **Non modificare l'architettura** Engine / Provider / Presenter.
5. **Non ridisegnare** `Main.tscn` — non spostare, ridimensionare, o modificare nodi esistenti.
6. **Non introdurre workaround** che mascherino bug del Provider o del Presenter.
7. **Non modificare il simulatore Python.**
8. **Solo sintassi Godot 3.4.4** — niente `await`, `@export`, `@onready`, API Godot 4.
9. **Compatibilità con CLI** (`--no-window`) per test headless.
10. **Segnali e yield** per comunicazione asincrona, non chiamate dirette.

---

## Prossimo lavoro

Passaggio E completato (Step 1–7). Prossime attività in ordine:

1. **Passaggio E, Step 8** — da definire.

2. **Miglioria game design — Giro di Vantaggio** (da implementare dopo il Passaggio E):
   Quando il GdV è attivo, i giocatori diversi dal giocatore in vantaggio non possono portare il Piatto a 100 (massimo 99). Eccezioni: carte +11 e il giocatore in vantaggio, che può regolarmente raggiungere 100 e vincere.

---

## Come riprendere il lavoro

Apri una nuova chat, chiedi di leggere `PROJECT_STATE.md` e `ROADMAP.md`. Inizia dalla sezione **"ULTIMA SESSIONE"** in `PROJECT_STATE.md` per il contesto delle ultime correzioni, poi continua dal **Passaggio E, Step 8** senza ripetere il lavoro già completato.

Tutte le suite di test sono verdi. Eseguire i test dopo ogni modifica:

```bash
/home/sumaka/bin/Godot3 --path /media/sumaka/Giochi/GodotProjects/roadTo100 tests/<suite>.tscn --no-window
```

Suite disponibili: `game_controller_test`, `presenter_test`, `board_test`, `provider_test`, `rules_test`, `domain_test`, `card_animator_test`.
