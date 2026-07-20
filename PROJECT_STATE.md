# RoadTo100 — Stato Progetto

> Aggiornato al: 20 luglio 2026
> Scopo: documento di avvio per future sessioni di sviluppo.

---

## Stato attuale

Il progetto è composto da due codebase separati:

| Componente | Stato |
|---|---|
| Simulatore Python | **Completato e congelato** |
| Client Godot — Passaggio D | **Completato e verificato** |

---

## Client Godot — Stato di avanzamento

Il porting delle regole e della UI in Godot è suddiviso in 5 passaggi progressivi.

### Passaggio A — Domain (✅ Completato)
Port delle strutture dati fondamentali: `CardData`, `Deck`, `Hand`, `PlayerData`, `GameState`, `GameConstants`, `CardDatabase`. 8 file in `engine/`. Test headless funzionanti.

### Passaggio B — Rules (✅ Completato e approvato)
Port del motore di gioco `RoadTo100Rules.gd` (426 righe), fedele alla reference Python. 14 test GDScript equivalenti ai test Python. 33 assertion, 0 FAIL.

### Passaggio C — Provider (✅ Completato)
`GameStateProvider` (contratto astratto) + `LocalGameEngine` (implementazione concreta locale). Produce snapshot ed eventi serializzabili (nessun oggetto Reference). `RemoteGameAdapter` previsto per il futuro multiplayer.

### Passaggio D — Presenter/UI (✅ Completato e verificato)
Tutta la UI del tavolo da gioco:

| Componente | Descrizione |
|---|---|
| `BoardPresenter` | Piatto, mazzo, scarti, carte permanenti (Gold/89), mani avversarie |
| `HandPresenter` | Mano del giocatore locale |
| `TurnPresenter` | Label turno, istruzioni, pulsanti, popup Game Over |
| `CardFace` | Carta visuale riutilizzabile (fronte/retro) |
| `CardAnimator` | Scheletro per future animazioni |
| `TextureResolver` | Mapping texture `{prefisso}{valore}.png` centralizzato |
| `DebugDemo` | Demo automatica 4 giocatori (avvio manuale: F10 o pulsante) |
| `Main.tscn` | Layout definitivo 1920×1080 (non modificare) |

#### Bug risolti durante il Passaggio D
1. **Mani avversarie non centrate** — pivot ricalcolato a runtime, bounding box carte visibili
2. **Carte non Gold duplicate sul Piatto** — `plateau_visual_stack` distingue Gold/89 (card face) da non-Gold (carta Piatto)
3. **Gold coperta dalla carta Piatto** — Step 3 di `_build_plateau_visual_stack()` non aggiunge plate dopo Gold/89
4. **Gold coperta dal PlateauValueCard statico** — nodo fratello nascosto in `_ready()`
5. **Duplicazione valore del Piatto** — `ValueLayer` statico nascosto (sostituito dai Label dinamici)
6. **Carta 89 non impostava il Piatto** — 89 trattata come incremento invece di set; corretto aggiungendo `_is_special_89_card()` al condizionale plateau. Test aggiunti per Piatto 0/11/50 → 89.

#### Bug verificati e chiusi (Passaggio D)
1. **Giro di Vantaggio / carta 89** — Causa: 89 trattata come incremento (`plateau += 89`) invece di set (`plateau = 89`). Corretto in GDScript e Python. Test aggiunti per Piatto 0/11/50 → 89. Tutte le suite passano.
2. **Schermata di vittoria — nome non trovato oltre Player 1** — Il loop `for p in s.get("players", [])` in `TurnPresenter.apply_snapshot()` non trovava il vincitore per giocatori oltre l'indice 0 nello snapshot reale. Causa: comportamento anomalo del `for-in` con dizionari complessi (contenenti array `hand`). Sostituito con accesso indicizzato `for i in range(players.size())`. Test di regressione per tutti e 4 i giocatori aggiunto in `presenter_test.gd`. Verificato con 10+ Demo automatiche.

#### Visual stack del Piatto
La pila visiva è costruita dal Provider (`_build_plateau_visual_stack()`) e renderizzata dal Presenter (`_update_plateau()`):
- Sequenza corretta: carta Piatto iniziale → Gold → carta Piatto aggiornata → Gold → ...
- Gold: visibile in cima dopo la giocata (~1 secondo con demo a 1000ms)
- Non-Gold dopo Gold: nuova carta Piatto sopra la Gold
- Carte non Gold mai nella pila del Piatto

#### Bug aperti (Passaggio D)
Nessuno. Il Passaggio D è completato e verificato.

### Passaggio E — Input/Animazioni (⬜ Non iniziato)
GameController + input giocatore + popup scelta valore + blocco input + animazioni + fine partita.

---

## Componenti completati

- **Simulatore Python** (`games/roadto100/`): implementa tutte le regole di `GAME_RULES.md`
  - Mazzo 60 carte, 5 tipologie
  - Giro di Vantaggio (attivazione, durata, restrizioni carte)
  - Catena Gold della carta +11 (12→23…78→89)
  - Cambio Carta, Gold Reveal, RESET_HAND
  - Ricostituzione del Mazzo dagli Scarti
  - Vittoria a 100, limiti Imbroglio
- **Test**: 16 test mirati (`test_roadto100_rules.py`) — tutti OK
- **Strumenti**: `run_simulations.py` (batch di partite)
- **Validazione**: 50.000+ partite simulate con 2/3/4 giocatori, zero errori
- **Client Godot** (Passaggi A–D completati):
  - Engine: CardData, Deck, Hand, PlayerData, GameState, GameConstants, CardDatabase
  - Regole: RoadTo100Rules.gd (porting fedele)
  - Provider: GameStateProvider + LocalGameEngine (snapshot/eventi)
  - Presenter/UI: BoardPresenter, HandPresenter, TurnPresenter, CardFace, TextureResolver
  - Debug: Demo automatica 4 giocatori funzionante
  - Test GDScript: tutte le suite superate (domain, rules, provider, presenter, board)

---

## Componenti congelati

**Nessuna modifica al simulatore** (`games/roadto100/`, `simulator/`) salvo:

1. Bug reale
2. Modifica di `GAME_RULES.md`
3. Incompatibilità Python

Il simulatore è la **fonte ufficiale** del regolamento. Ogni differenza tra Godot e simulatore è un bug del client o una modifica esplicita del regolamento.

---

## Regole progettuali importanti

- `GAME_RULES.md` prevale su qualsiasi codice
- Il client Godot deve implementare fedelmente il comportamento del simulatore
- Le regole non sono duplicate tra documenti
- Framework `simulator/domain/` e `simulator/engine/` sono congelati
- Nuova logica va in `games/` (Python) o in `.gd` (Godot)
- Compatibilità Python 3.8 mantenuta
- Zero dipendenze esterne per il simulatore

---

## Architettura attuale

```
roadTo100/
├── games/roadto100/        # Logica di gioco Python (attiva, congelata)
│   ├── rules.py            # RoadTo100RuleSet
│   ├── actions.py          # RoadTo100Action, ActionController
│   ├── cards.py            # Costruzione mazzo
│   ├── card_database.py    # Definizioni carte
│   ├── config.py           # Costanti
│   ├── setup.py            # build_initial_game()
│   └── helpers.py          # Utilità
├── simulator/
│   ├── domain/             # Tipi generici (congelato)
│   ├── engine/             # Loop simulazione (congelato)
│   └── ai/                 # Bot base (placeholder)
├── engine/                 # Godot — logica di gioco (completato A–C)
│   ├── CardData.gd
│   ├── Deck.gd / Hand.gd / PlayerData.gd
│   ├── GameState.gd / GameConstants.gd
│   ├── CardDatabase.gd / TextureResolver.gd
│   ├── RoadTo100Rules.gd
│   ├── GameStateProvider.gd / LocalGameEngine.gd
├── scripts/                # Godot — presenter e UI (completato D)
│   ├── BoardPresenter.gd / HandPresenter.gd / TurnPresenter.gd
│   ├── CardFace.gd / CardAnimator.gd
│   └── DebugDemo.gd
├── scenes/
│   └── CardFace.tscn
├── tests/                  # Godot — test headless
│   ├── domain_test, rules_test, provider_test
│   ├── presenter_test, board_test
├── Main.tscn               # Scena principale (layout definitivo)
├── project.godot           # Config Godot 3.4.4
├── GAME_RULES.md           # Regolamento ufficiale
├── CARD_DATABASE.md        # Dati carte
├── ROADMAP.md              # Roadmap e stato passaggi
└── test_roadto100_rules.py # Test regole Python
```

---

## File fondamentali

| File | Ruolo |
|---|---|
| `GAME_RULES.md` | Regolamento ufficiale — fonte di verità |
| `ROADMAP.md` | Roadmap e stato dei passaggi — leggere all'inizio di ogni sessione |
| `games/roadto100/rules.py` | `RoadTo100RuleSet` — tutte le meccaniche |
| `games/roadto100/actions.py` | Tipi azione e `RoadTo100ActionController` (selezione casuale) |
| `games/roadto100/cards.py` | `build_deck()` — costruzione mazzo 60 carte |
| `games/roadto100/setup.py` | `build_initial_game()` — setup partita |
| `run_simulations.py` | Esecuzione batch: `python3 run_simulations.py <g2|g3|g4> <N>` |
| `engine/RoadTo100Rules.gd` | Porting GDScript fedele delle regole |
| `engine/LocalGameEngine.gd` | Provider concreto locale (snapshot/eventi) |
| `scripts/BoardPresenter.gd` | Presenter del tavolo (piatto, mani, carte permanenti) |
| `Main.tscn` | Scena principale Godot (layout definitivo) |
| `project.godot` | Config Godot 3.4.4 |

---

## TODO rimasti

- [ ] **Passaggio E — GameController + Input + Animazioni** (prossimo)
  - GameController: stati interfaccia (WAITING_FOR_STATE, READY_FOR_INPUT, CARD_SELECTED, ecc.)
  - Raccolta input giocatore (clic carte, pulsanti)
  - Popup scelta valore (Jolly, Imbroglio)
  - Popup Gold Reveal
  - Animazioni carte (CardAnimator)
  - Blocco input durante animazioni
  - Fine partita e Game Over
  - Integrazione Demo Automatica con GameController
  - Test end-to-end
- [ ] **AI** (`simulator/ai/bot.py`): scheletro vuoto — opzionale, fase futura
- [ ] **Multiplayer**: non iniziato

---

## Prossima fase

**Passaggio E — GameController + Input + Animazioni.**

Il tavolo da gioco è completo (mazzo, mani, piatto, scarti, carte permanenti, avversari). Manca il GameController che collega l'input del giocatore al Provider e gestisce gli stati dell'interfaccia.

Il simulatore Python funge da reference: per qualsiasi dubbio sul comportamento di una carta o di una meccanica, eseguire il simulatore è più rapido e affidabile che rileggere il regolamento.

Flusso di lavoro consigliato:
1. Implementare una feature in Godot
2. Verificare che il comportamento corrisponda al simulatore (stesse carte → stesso risultato)
3. In caso di discrepanza, il simulatore ha ragione — correggere Godot

---

## ULTIMA SESSIONE (20 luglio 2026)

### Bug carta 89 — risolto

È stato individuato un bug condiviso tra Godot e simulatore Python: la carta 89 **aggiungeva** 89 al Piatto (`plateau += 89`) invece di **impostarlo** a 89 (`plateau = 89`), come da `GAME_RULES.md` ("il Piatto diventa 89"). Quando il Piatto era ≥ 12, l'incremento portava a 100 e il giocatore vinceva immediatamente invece di attivare il Giro di Vantaggio.

**Correzione:** in `RoadTo100Rules.gd` e `rules.py`, aggiunto `_is_special_89_card(card)` al condizionale che determina `plateau = increment`.

**Test:** aggiunti 3 test per Piatto 0, 11, 50 → sempre 89. Tutte le suite passano.

### Bug nome vincitore — risolto

Il testo di vittoria mostrava solo `" vince!"` (senza nome) per Player 2, 3 e 4. Il bug è stato risolto modificando la ricerca del giocatore vincitore all'interno dello snapshot: il ciclo originario è stato sostituito con una ricerca indicizzata. La modifica elimina il problema che impediva la corretta risoluzione del nome per i giocatori oltre il primo.

**Nota:** la UI rimane completamente statica — Player 1 = Bottom (locale), Player 2 = Top, Player 3 = Left, Player 4 = Right. Con 2 giocatori si nascondono Left e Right; con 3 si nasconde Right. L'online cambierà solo i nomi visualizzati nei PlayerData.

**Test:** test di regressione `_test_winner_all_players()` in `presenter_test.gd` — verifica il nome risolto per tutti e 4 i giocatori.

### Stato test

- **Python:** 16 test, tutti OK
- **Godot rules_test.gd:** 17 test, 48 assert, 0 FAIL
- **Godot presenter_test.gd:** 9 test, 62 assert, 0 FAIL
- **Godot provider_test.gd:** 20 test, 92 assert, 0 FAIL
- **Godot board_test.gd:** 7 test, 0 FAIL
- **Godot domain_test.gd:** All PASS

Un eventuale miglioramento futuro della copertura test è opzionale e NON rappresenta un bug aperto.

### Pulizia

Rimossi: logging diagnostico `[DIAG-T]`, flag `AUTO_DEMO`, file temporanei (`test_forin_bug.*`, `tests/MockLabel.gd`).

### Stato attuale

Il Passaggio D è concluso. Entrambi i bug principali sono risolti e verificati.

Il prossimo lavoro dovrà partire dal **Passaggio E** della roadmap.

Non riaprire le diagnosi della carta 89 o del nome del vincitore salvo la comparsa di nuovi bug reali.

