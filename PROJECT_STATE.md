# RoadTo100 — Stato Progetto

> Aggiornato al: 20 luglio 2026
> Scopo: documento di avvio per future sessioni di sviluppo.

---

## Stato attuale

Il progetto è composto da due codebase separati:

| Componente | Stato |
|---|---|
| Simulatore Python | **Completato e congelato** |
| Client Godot — Passaggio E, Step 7 | **Completato e verificato** |

---

## Client Godot — Stato di avanzamento

Il porting delle regole e della UI in Godot è suddiviso in passaggi progressivi.

### Passaggio A — Domain (✅ Completato)
Port delle strutture dati fondamentali: `CardData`, `Deck`, `Hand`, `PlayerData`, `GameState`, `GameConstants`, `CardDatabase`. 8 file in `engine/`. Test headless funzionanti.

### Passaggio B — Rules (✅ Completato e approvato)
Port del motore di gioco `RoadTo100Rules.gd` (426 righe), fedele alla reference Python. 17 test GDScript, 48 assert, 0 FAIL.

### Passaggio C — Provider (✅ Completato)
`GameStateProvider` (contratto astratto) + `LocalGameEngine` (implementazione concreta locale). Produce snapshot ed eventi serializzabili (nessun oggetto Reference). `RemoteGameAdapter` previsto per il futuro multiplayer.

### Passaggio D — Presenter/UI (✅ Completato e verificato)
Tutta la UI del tavolo da gioco. BoardPresenter, HandPresenter, TurnPresenter, CardFace, CardAnimator (scheletro), TextureResolver, DebugDemo, Main.tscn. Bug risolti: mani avversarie non centrate, carte non Gold duplicate sul Piatto, Gold coperta, duplicazione valore Piatto, carta 89, nome vincitore oltre Player 1.

### Passaggio E — GameController (✅ Completato, 7 step)

| Step | Descrizione | Stato |
|---|---|---|
| 1 | Scheletro e macchina a stati (8 stati: WAITING_FOR_STATE → GAME_OVER) | ✅ |
| 2 | Selezione carte: CardFace → HandPresenter → GameController | ✅ |
| 3 | Bottoni azione: PlayButton/ChangeButton/CancelButton → GameController | ✅ |
| 4 | Popup e scelte speciali: Jolly, Imbroglio, Gold Reveal | ✅ |
| 5 | CardAnimator: coda FIFO, animazione card_played, segnali start/finish, headless fallback | ✅ |
| 6 | Integrazione DebugDemo con GameController | ✅ |
| 7 | Flusso input GUI reale, punto unico `perform_action()` | ✅ |

**Flusso completo realizzato:**
```
CardFace._gui_input(click)
  → clicked(card_id)
  → HandPresenter._on_card_face_clicked()
  → card_selected(card_id)
  → GameController._on_card_selected()
  → stato CARD_SELECTED

PlayButton.pressed
  → TurnPresenter._on_play()
  → play_pressed
  → GameController._on_play_pressed()
  → GameController.perform_action(action_dict)
  → Provider.send_action()
  → action_completed({snapshot, events})
  → GameController._apply_snapshot() (presenter aggiornati)
  → CardAnimator.play_events() + stato ANIMATING
  → animation_finished → _finish_post_action()
  → READY_FOR_INPUT
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
| CardAnimator | `scripts/CardAnimator.gd` | ✅ Implementato (E5) |
| TextureResolver | `engine/TextureResolver.gd` | ✅ |
| **GameController** | `scripts/GameController.gd` | ✅ Implementato (E1–E7) |
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
| Rules | `tests/rules_test.gd` | 48 | ✅ 0 FAIL |
| Provider | `tests/provider_test.gd` | 104 | ✅ 0 FAIL |
| Presenter | `tests/presenter_test.gd` | 84 | ✅ 0 FAIL |
| Board | `tests/board_test.gd` | 42 | ✅ 0 FAIL (bug `_a()` risolto) |
| GameController | `tests/game_controller_test.gd` | 145 | ✅ 0 FAIL, nessun memory leak |
| CardAnimator | `tests/card_animator_test.gd` | 5 | ✅ 0 FAIL |
| Demo Automatica | — | — | ✅ Funzionante, ~4+ turni in 9s |

---

## TODO rimasti

- [ ] **Passaggio E — Step 8** (prossimo)
  - Da definire.
- [ ] **AI** (`simulator/ai/bot.py`): scheletro vuoto — opzionale, fase futura
- [ ] **Multiplayer**: non iniziato

---

## ULTIMA SESSIONE (20 luglio 2026)

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

### Prossimo lavoro

**Passaggio E, Step 8** — da definire. Consultare `ROADMAP.md` e la roadmap aggiornata per la prossima milestone.
