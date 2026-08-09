# RoadTo100 — Stato Progetto

> Aggiornato al: 24 luglio 2026
> Scopo: documento di avvio per future sessioni di sviluppo.

---

## Stato attuale

Il progetto è composto da due codebase separati:

| Componente | Stato |
|---|---|
| Simulatore Python | **Completato e congelato** |
| Client Godot — Passaggio E, Step 8 | **Completato e verificato** |

---

## Client Godot — Stato di avanzamento

Il porting delle regole e della UI in Godot è suddiviso in passaggi progressivi.

### Passaggio A — Domain (✅ Completato)
Port delle strutture dati fondamentali: `CardData`, `Deck`, `Hand`, `PlayerData`, `GameState`, `GameConstants`, `CardDatabase`. 8 file in `engine/`. Test headless funzionanti.

### Passaggio B — Rules (✅ Completato e approvato)
Port del motore di gioco `RoadTo100Rules.gd` (444+ righe), fedele alla reference Python. 24 test GDScript, 68 assert, 0 FAIL.
Include regola del rimbalzo GdV (allineata al simulatore Python).

### Passaggio C — Provider (✅ Completato)
`GameStateProvider` (contratto astratto) + `LocalGameEngine` (implementazione concreta locale). Produce snapshot ed eventi serializzabili (nessun oggetto Reference). `RemoteGameAdapter` previsto per il futuro multiplayer.

### Passaggio D — Presenter/UI (✅ Completato e verificato)
Tutta la UI del tavolo da gioco. BoardPresenter, HandPresenter, TurnPresenter, CardFace, CardAnimator (scheletro), TextureResolver, DebugDemo, Main.tscn. Bug risolti: mani avversarie non centrate, carte non Gold duplicate sul Piatto, Gold coperta, duplicazione valore Piatto, carta 89, nome vincitore oltre Player 1.

### Passaggio E — GameController (✅ Completato, 8 step)

| Step | Descrizione | Stato |
|---|---|---|
| 1 | Scheletro e macchina a stati (8 stati: WAITING_FOR_STATE → GAME_OVER) | ✅ |
| 2 | Selezione carte: CardFace → HandPresenter → GameController | ✅ |
| 3 | Bottoni azione: PlayButton/ChangeButton/CancelButton → GameController | ✅ |
| 4 | Popup e scelte speciali: Jolly, Imbroglio, Gold Reveal | ✅ |
| 5 | CardAnimator: coda FIFO, animazione card_played, segnali start/finish, headless fallback | ✅ |
| 6 | Integrazione DebugDemo con GameController | ✅ |
| 7 | Flusso input GUI reale, punto unico `perform_action()` | ✅ |
| 8 | **Animazioni multi-player e validazione**: correzione animazioni non visibili (bug doppio: `has_method` errato + snapshot prima di animazione), ricerca carte per `player_id` (locale e avversari), animazione pesca da `DrawPile`, coordinate globali, nascondi originale prima dello snapshot, 20 test, 5 partite complete, verifica 4 giocatori | ✅ |

**Flusso completo animazioni (multi-player):**
```
PlayButton.pressed
  → TurnPresenter._on_play()
  → play_pressed
  → GameController._on_play_pressed()
  → GameController.perform_action(action_dict)
  → Provider.send_action()
  → action_completed({snapshot, events})
  → GameController._on_action_completed():
      │
      ├─ CardAnimator.play_events([card_played, card_drawn, ...])
      │   ├─ card_played: _find_card_node(player_id, card_id)
      │   │   ├─ P1: HandPresenter/CardsLayer (locale)
      │   │   ├─ P2/P3/P4: OpponentsLayer/{Top,Left,Right}Seat
      │   │   ├─ clone = TextureRect(texture, rect_size, rect_global_position)
      │   │   ├─ original.visible = false
      │   │   └─ tween: posizione → destinazione (0.7s, fade ultimi 0.15s)
      │   │
      │   ├─ [yield] → _apply_snapshot(snapshot)
      │   ├─ hide_drawn_cards(events)  ← nasconde carte pescate (antiflicker)
      │   │
      │   ├─ card_drawn: _find_card_node(player_id, card_id)
      │   │   ├─ clone(cardback) = TextureRect(start_pos=DrawPile)
      │   │   ├─ target.visible = false
      │   │   ├─ tween: DrawPile → mano (0.6s, senza fade)
      │   │   └─ target.visible = true
      │   │
      │   └─ animation_finished
      │
      └─ _finish_post_action() → READY_FOR_INPUT
```

Tutte le azioni transitano esclusivamente per `GameController.perform_action(action_dict)`.

---

## Componenti completati

### Simulatore Python
- `games/roadto100/`: implementa tutte le regole di `GAME_RULES.md`
  - Mazzo 60 carte, 5 tipologie
  - Giro di Vantaggio (attivazione, durata, restrizioni carte)
  - Catena Gold della carta +11 (12→23…78→89)
  - Cambio Carta, Gold Reveal, RESET_HAND
  - Ricostituzione del Mazzo dagli Scarti
  - Vittoria a 100, limiti Imbroglio
- **Test**: 16 test mirati (`test_roadto100_rules.py`) — tutti OK
- **Strumenti**: `run_simulations.py` (batch di partite)
- **Validazione**: 50.000+ partite simulate con 2/3/4 giocatori, zero errori
- **Congelato**: non modificare salvo bug reale, modifica regolamento o incompatibilità Python

### Client Godot

| Componente | File | Stato |
|---|---|---|
| **Domain (engine/)** | | ✅ Passaggio A |
| CardData | `engine/CardData.gd` | ✅ |
| Deck | `engine/Deck.gd` | ✅ |
| Hand | `engine/Hand.gd` | ✅ |
| PlayerData | `engine/PlayerData.gd` | ✅ |
| GameState | `engine/GameState.gd` | ✅ |
| GameConstants | `engine/GameConstants.gd` | ✅ |
| CardDatabase | `engine/CardDatabase.gd` | ✅ |
| **Regole** | `engine/RoadTo100Rules.gd` | ✅ Passaggio B |
| **Provider** | | ✅ Passaggio C |
| GameStateProvider | `engine/GameStateProvider.gd` | ✅ Contratto |
| LocalGameEngine | `engine/LocalGameEngine.gd` | ✅ Concreto |
| **Presenter/UI** | | ✅ Passaggio D |
| BoardPresenter | `scripts/BoardPresenter.gd` | ✅ |
| HandPresenter | `scripts/HandPresenter.gd` | ✅ |
| TurnPresenter | `scripts/TurnPresenter.gd` | ✅ |
| CardFace | `scenes/CardFace.tscn` + `scripts/CardFace.gd` | ✅ |
| CardAnimator | `scripts/CardAnimator.gd` | ✅ FIFO, multi-player, giocata+p esca, 0.7s/0.6s |
| TextureResolver | `engine/TextureResolver.gd` | ✅ |
| **GameController** | `scripts/GameController.gd` | ✅ Implementato (E1–E8) |
| **Debug** | | |
| DebugDemo | `scripts/DebugDemo.gd` | ✅ Integrato con GC (E6) |
| DemoButton | In `Main.tscn` | ✅ F10/pulsante |

### Architettura finale

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
│  Stati: WAITING → READY → CARD_SELECTED →        │
│         WAITING_CHOICE → ACTION_PENDING →        │
│         ANIMATING → GAME_OVER                    │
│  Public API: start_game(), perform_action()      │
│  Signal: action_applied(result)                  │
└─────────────────────┬───────────────────────────┘
                      │ perform_action(action_dict)
                      │ start_game(player_count)
                      ▼
┌─────────────────────────────────────────────────┐
│         GameStateProvider (contratto)            │
│  LocalGameEngine (concreto)                      │
│  RemoteGameAdapter (futuro — rete)               │
└─────────────────────┬───────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────┐
│  RoadTo100Rules  •  CardData/Deck               │
│  Hand/PlayerData  •  GameState  •  CardDatabase  │
│  TextureResolver                                 │
└─────────────────────────────────────────────────┘
```

---

## Test

| Suite | File | Assert | Esito |
|---|---|---|---|
| Domain | `tests/domain_test.gd` | 55+ | ✅ All PASS |
| Rules | `tests/rules_test.gd` | 68 | ✅ 0 FAIL (24 test, include rimbalzo GdV) |
| Provider | `tests/provider_test.gd` | 104 | ✅ 0 FAIL |
| Presenter | `tests/presenter_test.gd` | 84 | ✅ 0 FAIL |
| Board | `tests/board_test.gd` | 42 | ✅ 0 FAIL |
| GameController | `tests/game_controller_test.gd` | 145 | ✅ 0 FAIL, nessun memory leak |
| CardAnimator | `tests/card_animator_test.gd` | 5 | ✅ 0 FAIL |
| CardAnimator Multi-Player | `tests/card_animator_test2.gd` | 20 | ✅ 0 FAIL |
| Demo Integrazione | `tests/demo_integration_test.gd` | 5 | ✅ 5/5 partite complete |
| Demo Verifica Eventi | `tests/demo_verification_test.gd` | 9 | ✅ 0 FAIL — 4 giocatori verificati |
| Demo Automatica | — | — | ✅ Funzionante via GC

---

## TODO rimasti

- [ ] **AI** (`simulator/ai/bot.py`): scheletro vuoto — opzionale, fase futura
- [ ] **Multiplayer**: non iniziato

---

## ULTIMA SESSIONE (21 luglio 2026)

### Regola del rimbalzo GdV

Implementata la regola del rimbalzo nel Giro di Vantaggio, allineata perfettamente tra simulatore Python e client Godot:

- Durante il GdV, i giocatori **non in Vantaggio** che giocano carte Arancioni con `piatto + incremento >= 100` attivano il rimbalzo: il nuovo piatto diventa `199 - (piatto + incremento)`.
- Il **giocatore in Vantaggio** non usa il rimbalzo e vince normalmente a 100.
- La carta **+11** non usa il rimbalzo e mantiene il comportamento speciale (vittoria istantanea in GdV).
- Se `piatto + incremento < 100`, il piatto aumenta normalmente.

**File modificati:**
- `games/roadto100/rules.py` — Aggiunta logica rimbalzo in `apply_action()`
- `engine/RoadTo100Rules.gd` — Aggiunta logica rimbalzo in `apply_action()`
- `test_roadto100_rules.py` — Aggiunta classe `TestGdvBounce` (7 test)
- `tests/rules_test.gd` — Aggiunti 7 test GdVBounce, 24 test totali / 68 assert
- `PROJECT_STATE.md` — Stato aggiornato

**Test Python:** 23/23 OK (7 nuovi)
**Test Godot:** rules_test 68 assert 0 FAIL, tutte le altre suite verdi (104+84+42+145+5+55+)

Simulatore e client implementano la stessa regola del rimbalzo.

### Passaggio E completato (Step 1–7)

Il GameController è stato implementato in 7 step progressivi:

1. **Step 1** — Scheletro e macchina a stati. `GameController.gd` creato con 8 stati di interfaccia, connessione al provider (LocalGameEngine), applicazione snapshot ai presenter.
2. **Step 2** — Selezione carte. `HandPresenter` esteso con segnale `card_selected`, metodi `set_selected`/`clear_selection`, evidenziazione per spostamento verticale. `GameController` gestisce selezione/deselezione/cambio carta.
3. **Step 3** — Bottoni azione. `TurnPresenter` esteso con segnali `play_pressed`/`change_pressed`/`cancel_pressed` e connessione pulsanti. `GameController` gestisce Play/Change/Cancel con transizioni di stato.
4. **Step 4** — Popup Jolly/Imbroglio/Gold Reveal. `GameController` apre `ValueChoicePopup` e `GoldRevealPopup`, convalida valori. Aggiunta UI minima ai popup in `Main.tscn`.
5. **Step 5** — `CardAnimator` implementato con coda FIFO, animazione `card_played` (tween), segnali `animation_started`/`animation_finished`, headless fallback. `GameController` integra animazioni nel flusso `action_completed`.
6. **Step 6** — `DebugDemo` integrato con `GameController`. Non crea più engine proprio, usa `GC.start_game()` e `GC.perform_action()`. Aggiunto `signal action_applied` e metodo pubblico `perform_action()` a `GameController`.
7. **Step 7** — Consolidamento: rimosso `_send_action()`, tutte le azioni passano per `perform_action()`. Singolo punto di ingresso. Test di integrazione `_test_real_click_to_action`: CardFace._gui_input → HandPresenter → GC → perform_action → provider.

### Bug risolti durante la sessione

- `board_test.gd`: bug `_a()` con semicolonne causava falsi `FAIL`. Centramento Left seat: formula hardcoded `3*60+2*6` invece di usare `hand_count=2`. Entrambi corretti.
- `tests/mock_animator.gd`: da auto-asincrono (yield) a controllabile (`play_events` senza emissione, `finish_animation()` manuale).
- `tests/presenter_test.gd`: `_test_no_auto_start` usava `dd.engine` (rimosso in Step 6).
- `tests/game_controller_test.gd`: leak Control node in `_test_real_click_to_action` — `layer.free()` mancante.
- `scripts/DebugDemo.gd`: mancava `_schedule_next_step()` dopo `_gc.start_game(4)` — timer non partiva, Turns=0.

### Stato test finale

| Suite | Assert | Esito |
|---|---|---|
| `tests/domain_test.gd` | 55+ | ✅ All PASS |
| `tests/rules_test.gd` | 48 | ✅ 0 FAIL |
| `tests/provider_test.gd` | 104 | ✅ 0 FAIL |
| `tests/presenter_test.gd` | 84 | ✅ 0 FAIL |
| `tests/board_test.gd` | 42 | ✅ 0 FAIL (bug `_a()` risolto) |
| `tests/game_controller_test.gd` | 145 | ✅ 0 FAIL, NO memory leak |
| `tests/card_animator_test.gd` | 5 | ✅ 0 FAIL |
| Demo Automatica | — | ✅ Funzionante via GC |

Tutte le suite superate. Nessun memory leak nei test.

---

## ULTIMA SESSIONE (24–25 luglio 2026)

### Animazioni multi-player complete

Completato il Passaggio E (Step 8) con animazioni multi-player funzionanti per tutti e 4 i giocatori.

#### Problemi risolti

**1. Animazioni non visibili** (24 luglio)
- CardAnimator: `c.has_method("get_card_id")` cercava un metodo inesistente (variabile membro, non metodo) → nessuna carta veniva mai clonata.
- GameController: snapshot applicato prima della clonazione → carta già sparita dalla mano al momento del clone.
- Fix: ordinamento invertito (`play_events` prima di snapshot), rimossa condizione `has_method`.

**2. Animazioni solo per Player 1**
- `_create_card_clone()` cercava solo in `LocalPlayerArea/PlayerHand/CardsLayer`.
- Fix: nuova funzione `_find_card_node(player_id, card_id)`:
  - player_1 → `HandPresenter/CardsLayer` (match per card_id)
  - player_2/3/4 → `OpponentsLayer/{TopSeat,LeftSeat,RightSeat}/CardsLayer` (carta più a destra)

**3. Nessuna animazione di pesca**
- Fix: nuovo metodo `_animate_card_drawn(event)`: clona dorso da `_get_draw_pile_pos()` (DrawPile center), anima alla posizione post-snapshot della carta pescata.

**4. Animazioni invisibili dopo giocata** (25 luglio)
- Durata troppo breve (0.25s/0.2s) + posizione pesca confusa con scarti.
- Fix: costanti configurabili `PLAY_ANIM_DURATION=0.7s`, `DRAW_ANIM_DURATION=0.6s`, `FADE_DURATION=0.15s`.
- Fade ritardato di 0.55s, visibile solo alla fine della giocata.
- Clone di pesca indipendente con `stretch_mode`, `rect_min_size`, posizione impostata prima di `add_child`.
- `_get_draw_pile_pos()` con name check esplicito (`dp.name != "DrawPile"`).

#### Verifiche eseguite

| Suite | Assert | Esito |
|---|---|---|
| `card_animator_test` (originale) | 5 | ✅ 0 FAIL |
| `card_animator_test2` (multi-player) | 20 | ✅ 0 FAIL |
| `game_controller_test` | 145 | ✅ 0 FAIL |
| `demo_integration_test` | 5 | ✅ 5/5 partite complete |
| `demo_verification_test` | 9 | ✅ 0 FAIL — tutti e 4 i giocatori |
| Test Python | 23 | ✅ OK |

#### File creati
- `tests/card_animator_test2.gd` + `.tscn` — 20 test: find_card per player, opponent, clone, dest, hide_drawn, event routing
- `tests/demo_verification_test.gd` + `.tscn` — verifica eventi 4 giocatori in partita reale

### Prossimo passo: Passaggio F — Special Round (Giro Sicuro)

**Stato:** 📋 Pianificato, non ancora implementato.

**Obiettivo:** Generalizzare il Giro di Vantaggio esistente in un sistema comune `Special Round`, aggiungendo il Giro Sicuro.

**Decisioni chiave:**
- Gold 12–78 → attiva Special Round di tipo `"safe"` (Giro Sicuro); il giocatore sceglie la tipologia da bloccare (`Incremento` / `Gold` / `Imbroglio`) via popup UI riutilizzando `WAITING_FOR_CHOICE`. La scelta è parte della stessa azione `play_card` (nessuno stato persistente con `blocked_type == null`).
- 89 → attiva Special Round di tipo `"advantage"` (Giro di Vantaggio, comportamento esistente).
- +11 giocata immediatamente dopo una Gold assume la Gold successiva: se 23–78 → Safe Round; se 89 → Advantage Round.
- Safe Round e Advantage Round condividono lo stesso lifecycle: terminano alla fine del successivo turno dell'attivatore. Un nuovo Special Round sostituisce immediatamente quello precedente.
- Il giocatore in Vantaggio ignora il rimbalzo e vince se porta il Piatto a 100 o più. Durante GdV, i giocatori normali non possono vincere a 100 (il Piatto va a 99). Fuori da GdV, il giocatore normale che porta il Piatto esattamente a 100 vince; se supera 100, si applica la Regola del Rimbalzo universale.
- **Correzione formula rimbalzo:** Il regolamento usa `200 − (piatto + incremento)`, non `199 − (piatto + incremento)` come nel codice attuale. Correzione necessaria in entrambe le codebase.

**Step pianificati (F1–F8):**
- **F1:** Rinomina metadata (`advantage_turn` → `special_round_active`, `advantage_player_id` → `special_round_player_id`, nuova chiave `special_round_type`).
- **F2:** Attivazione Safe Round da Gold normale e logica +11 da catena Gold.
- **F3:** UI popup Safe Round choice riutilizzando `_open_value_choice` esistente; passaggio `blocked_type` in `send_action`.
- **F4:** Branch Safe Round in `get_available_actions` e `validate_action` (blocco tipo carta per i non-attivatori).
- **F5:** Correzione formula rimbalzo (`200 − raw_total`), condizione biforcata `>`/`>=` (fuori SR: `> 100`; durante GdV normali: `>= 100` → forza 99; durante GdV vantaggio: ignora).
- **F6–F8:** Test Python/Godot + regressione.

**File coinvolti:** `games/roadto100/rules.py`, `engine/RoadTo100Rules.gd`, `engine/LocalGameEngine.gd`, `scripts/GameController.gd`, `scripts/TurnPresenter.gd`, `test_roadto100_rules.py`, `tests/rules_test.gd`.

**Pronto per:** `Implementa F1`

---

### Prossimo passo consigliato (alternative post-F)

**Migliorie UI/UX** — Texture carte definitive, effetti sonori, schermata di vittoria, animazioni più ricche. Dopo Passaggio F l'infrastruttura di gameplay del client Godot sarà completa (Passaggio A→F), manca la rifinitura visiva per un'esperienza giocabile.

Alternative:
- **AI per simulatore Python** (`simulator/ai/bot.py`): scheletro vuoto, strategie di gioco.
- **Multiplayer** (`RemoteGameAdapter`): architettura definita, implementazione futura.
