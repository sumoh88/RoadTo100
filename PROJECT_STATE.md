# RoadTo100 — Stato Progetto

> Aggiornato al: 18 agosto 2026
> Scopo: documento di avvio per future sessioni di sviluppo.

---

## Stato attuale

Il progetto è composto da due codebase separati:

| Componente | Stato |
|---|---|
| Simulatore Python | **Completato e congelato** |
| Client Godot — Passaggio F, Step 1–7 | **F1–F7 completati e verificati** (prossimo: F8, ultimo step) |

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
| Rules | `tests/rules_test.gd` | 188 | ✅ 0 FAIL (59 test, include F7 GS/GdV end-to-end: 14 nuovi) |
| Provider | `tests/provider_test.gd` | 92 | ✅ 0 FAIL (include snapshot `blocked_type` F7) |
| Presenter | `tests/presenter_test.gd` | 84 | ✅ 0 FAIL |
| Board | `tests/board_test.gd` | 44 | ✅ 0 FAIL |
| GameController | `tests/game_controller_test.gd` | 165 | ✅ 0 FAIL, nessun memory leak (include 6 test F7 popup GS pre-azione) |
| CardAnimator | `tests/card_animator_test.gd` | 5 | ✅ 0 FAIL |
| CardAnimator Multi-Player | `tests/card_animator_test2.gd` | 20 | ✅ 0 FAIL |
| Demo Integrazione | `tests/demo_integration_test.gd` | 5 | ✅ 5/5 partite complete × 3 run consecutive, nessun hang |
| Demo Verifica Eventi | `tests/demo_verification_test.gd` | 9 | ✅ 0 FAIL — 4 giocatori verificati |
| Demo Automatica | — | — | ✅ Funzionante via GC |

**Test Python:** `test_roadto100_rules.py` — 74 test, 0 FAIL (incl. F7: 14 nuovi su persistenza `blocked_type`, +11 durante GS, replacement lifecycle, rimbalzo/vittoria GS/GdV, playability).

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

### Passaggio F — Special Round (Giro Sicuro)

**Stato attuale:** Step F1–F7 completati e verificati; prossimo step F8 (ultimo del Passaggio F).

#### F1 — Rinomina metadata (completato)
- `advantage_turn` → `special_round_active`
- `advantage_player_id` → `special_round_player_id`
- Aggiunta chiave `special_round_type` (`"advantage"` / `"safe"`)
- File: Python `rules.py`, Godot `RoadTo100Rules.gd`, `LocalGameEngine.gd`

#### F2 — Attivazione Safe Round da Gold e +11 chain (completato)
- **Normal Gold (12–78)** → attiva Safe Round (`special_round_type="safe"`)
- **+11 da catena Gold**: 23–78 → Safe Round; 89 → Advantage Round
- File: Python `rules.py`, Godot `RoadTo100Rules.gd`
- **Test Python:** `TestSafeRoundActivation` — 5 test (`test_gold_12_activates_safe_round`, `test_gold_78_activates_safe_round`, `test_plus11_from_78_gold_chain_activates_advantage`, `test_plus11_from_67_gold_chain_activates_safe_round`, `test_new_safe_round_overwrites_previous`)
- **Test Godot:** 5 test specchiati in `tests/rules_test.gd`

#### F3 — UI popup Safe Round choice e blocked_type passthrough (completato)
- **Popup UI:** riutilizzo `ValueChoicePopup` con `_open_safe_round_choice()`, tre pulsanti (`"Incremento"`, `"Gold"`, `"Imbroglio"`)
- **blocked_type:** passato tramite `send_action` → `LocalGameEngine.send_action()` → rules layer
- **snapshot:** `special_round_type` incluso nell'output di `_build_snapshot()`
- **integrazione:** `_check_safe_round_choice()` chiamato in `_finish_post_action()` dopo ogni azione
- **Test Godot:** `_test_safe_round_blocked_type_flow` in `tests/provider_test.gd` — verifica flusso end-to-end Gold→Safe Round popup→blocked_type
- **Bug fix test:** connessione mancante `action_completed` signal aggiunta a `_test_safe_round_blocked_type_flow`

**File coinvolti in F1–F3:**
- `games/roadto100/rules.py` — metadata rename, Safe Round activation
- `engine/RoadTo100Rules.gd` — stesso logica mirroring Python
- `engine/LocalGameEngine.gd` — blocked_type passthrough, snapshot special_round_type
- `scripts/GameController.gd` — popup UI Safe Round choice, integrazione `_check_safe_round_choice`
- `test_roadto100_rules.py` — 5 nuovi test F2
- `tests/rules_test.gd` — 5 nuovi test Godot F2
- `tests/provider_test.gd` — 1 nuovo test Godot F3

**Stato test dopo F1–F3:**
- Python: 28/28 OK
- Godot rules_test: 73 assert (29 test), 0 FAIL
- Godot provider_test: 104 assert, 0 FAIL
- Tutte le altre suite invariate e verdi

#### F4 — Branch Safe Round in `get_available_actions` e `validate_action` (completato)
- **Helper `_is_blocked_type(card, blocked_type)`:** mappa `blocked_type` a tipologie carte:
  - `"Incremento"` → blocca increment, jolly E +11 (per regolamento: +11 appartiene a Incremento tipo)
  - `"Gold"` → blocca Gold normali E 89 (Carta Gold Speciale)
  - `"Imbroglio"` → blocca Imbroglio
- **`get_available_actions`:** durante Safe Round, non-attivatori hanno carte del tipo bloccato filtrate PRIMA del filtro Orange/+11
- **`validate_action`:** stessa logica — rifiuta carte di tipo bloccato per non-attivatori
- **Cambio Carta:** rimane disponibile per tutte le carte durante Safe Round
- File: Python `rules.py`, Godot `RoadTo100Rules.gd`
- **Test Python:** `TestSafeRoundBlockedType` — 10 test
  - `test_blocked_incremento_blocks_normal_increment`
  - `test_blocked_incremento_blocks_plus11`
  - `test_blocked_gold_blocks_normal_gold`
  - `test_blocked_gold_blocks_89`
  - `test_blocked_gold_allows_plus11`
  - `test_blocked_imbroglio_blocks_imbroglio`
  - `test_change_card_always_available_during_safe_round`
  - `test_validate_action_blocks_incremento_card`
  - `test_validate_action_allows_plus11_when_gold_blocked`
  - `test_validate_action_blocks_89_when_gold_blocked`
- **Test Godot:** 10 test specchiati in `tests/rules_test.gd`, helper `_make_safe_round_game`

**Stato test dopo F6:**
- Python: 60/60 OK (incl. regressioni +11, 89, Gold chain)
- Godot rules_test: 131 assert, 0 FAIL
- Godot provider_test: 92 assert, 0 FAIL (verificato ×5 run consecutive)
- Godot board_test: 44 assert, 0 FAIL
- Tutte le altre suite verdi

#### F7 — Integrazione end-to-end Giro Sicuro / Giro di Vantaggio (completato)
Correzione dei bug G1–G7 e dei bug rilevati in-game: integrazione completa GS/GdV tra regole, provider, controller e UI.

- **`blocked_type` persistito:** scelto una sola volta all'attivazione del GS (stessa azione `play_card`) e invariato fino a fine/sostituzione del Giro; incluso nello snapshot (`_build_snapshot()`) e pulito quando il GS termina o è sostituito da 89.
- **Popup GS pre-azione:** la scelta della tipologia bloccata avviene PRIMA dell'invio della carta attivante (Gold normale, o +11 con chain 23–78); una sola `play_card` porta `card_id` + `blocked_type`. Rimosso il vecchio popup post-azione F3.
- **Lifecycle GS/GdV:** reset di `_activator_has_played_next` ad ogni attivazione/sostituzione; 89 sostituisce un GS attivo e pulisce il `blocked_type` residuo; +11 durante GS non interrompe né sostituisce il GS, salvo Gold chain valida (carta precedente nel Piatto normale).
- **Distinzione GS/GdV per rimbalzo e vittoria:** solo il GdV concede no-bounce e vittoria a >= 100 all'attivatore; l'attivatore del GS gioca con le regole universali (bounce > 100, vittoria a 100 esatti).
- **Cambio Carta** resta disponibile durante GS quando non esistono carte giocabili (RESET_HAND + Cambio).
- **UI:** indicatore superiore corretto `GIRO SICURO`/`GIRO DI VANTAGGIO` per `special_round_type`; `Turno di Player X` non viene più sostituito dal Giro Speciale.
- **DebugDemo / demo_integration_test / demo_verification_test** aggiornati al nuovo flusso (`blocked_type` sulle carte che attivano GS; fix flake pre-esistente su `selected_value` Jolly/Imbroglio). Rimossi i print `[DBG]` residui in `LocalGameEngine.gd` e `provider_test.gd`.
- File: `games/roadto100/rules.py`, `engine/RoadTo100Rules.gd`, `engine/LocalGameEngine.gd`, `scripts/GameController.gd`, `scripts/TurnPresenter.gd`, `scripts/DebugDemo.gd`, `test_roadto100_rules.py`, `tests/rules_test.gd`, `tests/game_controller_test.gd`, `tests/provider_test.gd`, `tests/demo_integration_test.gd`, `tests/demo_verification_test.gd`.

**Stato test dopo F7:**
- Python: 74/74 OK (14 nuovi F7)
- Godot rules_test: 188 assert, 0 FAIL (59 test, incl. 14 F7)
- Godot game_controller_test: 165 assert, 0 FAIL (6 nuovi F7 sul flusso popup pre-azione)
- Godot provider_test: 92 assert, 0 FAIL (`blocked_type` nel formato snapshot + flusso GS)
- demo_integration_test: 5/5 partite complete × 3 run consecutive, nessun hang
- Tutte le altre suite verdi (domain, presenter 84, board 44, card_animator 5+20, demo_verification)

**Prossimo step: F8** — ultimo step del Passaggio F (da definire).

---

#### Passaggio F — Piano completo F1–F8

**Obiettivo:** Generalizzare il Giro di Vantaggio esistente in un sistema comune `Special Round`, aggiungendo il Giro Sicuro.

**Decisioni chiave:**
- Gold 12–78 → attiva Special Round di tipo `"safe"` (Giro Sicuro); il giocatore sceglie la tipologia da bloccare (`Incremento` / `Gold` / `Imbroglio`) via popup UI riutilizzando `WAITING_FOR_CHOICE`. La scelta è parte della stessa azione `play_card` (nessuno stato persistente con `blocked_type == null`).
- 89 → attiva Special Round di tipo `"advantage"` (Giro di Vantaggio, comportamento esistente).
- +11 giocata immediatamente dopo una Gold assume la Gold successiva: se 23–78 → Safe Round; se 89 → Advantage Round.
- Safe Round e Advantage Round condividono lo stesso lifecycle: terminano alla fine del successivo turno dell'attivatore. Un nuovo Special Round sostituisce immediatamente quello precedente.
- Il giocatore in Vantaggio ignora il rimbalzo e vince se porta il Piatto a 100 o più. Durante GdV, i giocatori normali non possono vincere a 100 (il Piatto va a 99). Fuori da GdV, il giocatore normale che porta il Piatto esattamente a 100 vince; se supera 100, si applica la Regola del Rimbalzo universale.
- **Correzione formula rimbalzo:** Il regolamento usa `200 − (piatto + incremento)`, non `199 − (piatto + incremento)` come nel codice attuale. Correzione necessaria in entrambe le codebase.

**Step pianificati (F1–F8):**
- [x] **F1:** Rinomina metadata (`advantage_turn` → `special_round_active`, `advantage_player_id` → `special_round_player_id`, nuova chiave `special_round_type`). ✅ Completato e verificato.
- [x] **F2:** Attivazione Safe Round da Gold normale e logica +11 da catena Gold. ✅ Completato e verificato (6 test Python + 5 Godot).
- [x] **F3:** UI popup Safe Round choice riutilizzando `_open_value_choice` esistente; passaggio `blocked_type` in `send_action`. ✅ Completato e verificato (1 test provider).
- [x] **F4:** Branch Safe Round in `get_available_actions` e `validate_action` (blocco tipo carta per i non-attivatori). ✅ Completato e verificato (10 test Python + 10 Godot).
- [x] **F5:** Correzione formula rimbalzo (`200 − raw_total`), condizione biforcata `>`/`>=` (fuori SR: `> 100`; durante GdV normali: `>= 100` → forza 99; durante GdV vantaggio: ignora). ✅ Completato e verificato.
- [x] **F6:** Test Python/Godot + regressione. ✅ Completato e verificato (60 test Python, rules_test 131/0, provider_test 92/0 ×5 run, board_test 44/0).
  - Bug fix: plateau cap e victory condition per Safe Round non-activators (distinguere type="advantage" da type="safe").
  - Bug fix: logica +11 secondo GAME_RULES.md — eliminato trigger generico `+11 = vittoria`; la +11 ora verifica sempre la gold chain, ignora Rimbalzo, e durante GdV ignora la restrizione del solo-Vantaggio. La vittoria deriva dal Piatto risultante (>= 100).
  - Fix: non-deterministicità provider_test (`_playable_card_id` skip choices, `sr_pid` dynamic).
- [x] **F7:** Integrazione end-to-end GS/GdV: persistenza + snapshot `blocked_type`, popup pre-azione con una sola `play_card`, lifecycle `_activator_has_played_next`, distinzione GS/GdV per rimbalzo/vittoria, Cambio Carta durante GS senza carte giocabili, UI `GIRO SICURO`/`GIRO DI VANTAGGIO` + turno sempre visibile, rimozione `[DBG]`. ✅ Completato e verificato (14 test Python, 14 rules Godot, 6 GC, provider snapshot; demo_integration 5/5 ×3 run).
- [ ] **F8:** (da definire) — ultimo step del Passaggio F.

**Prossimo step da implementare:** F8 (ultimo step del Passaggio F, da definire)

**File coinvolti:** `games/roadto100/rules.py`, `engine/RoadTo100Rules.gd`, `engine/LocalGameEngine.gd`, `scripts/GameController.gd`, `scripts/TurnPresenter.gd`, `test_roadto100_rules.py`, `tests/rules_test.gd`.

**Pronto per:** Definire e implementare F8

---

### Prossimo passo consigliato (alternative post-F)

**Migliorie UI/UX** — Texture carte definitive, effetti sonori, schermata di vittoria, animazioni più ricche. Dopo Passaggio F l'infrastruttura di gameplay del client Godot sarà completa (Passaggio A→F), manca la rifinitura visiva per un'esperienza giocabile.

Alternative:
- **AI per simulatore Python** (`simulator/ai/bot.py`): scheletro vuoto, strategie di gioco.
- **Multiplayer** (`RemoteGameAdapter`): architettura definita, implementazione futura.
