# RoadTo100 — Stato Progetto

> Aggiornato al: 15 luglio 2026
> Scopo: documento di avvio per future sessioni di sviluppo.

---

## Stato attuale

Il progetto è composto da due codebase separati:

| Componente | Stato |
|---|---|
| Simulatore Python | **Completato e congelato** |
| Client Godot | **Da sviluppare** (solo `project.godot` iniziale) |

---

## Componenti completati

- **Simulatore Python** (`games/roadto100/`): implementa tutte le regole di `GAME_RULES.md`
  - Mazzo 60 carte, 5 tipologie
  - Giro di Vantaggio (attivazione, durata, restrizioni carte)
  - Catena Gold della carta +11 (12→23…78→89)
  - Cambio Carta, Gold Reveal, RESET_HAND
  - Ricostituzione del Mazzo dagli Scarti
  - Vittoria a 100, limiti Imbroglio
- **Test**: 13 test mirati (`test_roadto100_rules.py`) — tutti OK
- **Strumenti**: `run_simulations.py` (batch di partite)
- **Validazione**: 50.000+ partite simulate con 2/3/4 giocatori, zero errori

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
├── games/roadto100/        # Logica di gioco Python (attiva)
│   ├── rules.py            # RoadTo100RuleSet
│   ├── actions.py          # RoadTo100Action, ActionController
│   ├── cards.py            # Costruzione mazzo
│   ├── card_database.py    # Definizioni carte
│   ├── config.py           # Costanti
│   ├── setup.py            # build_initial_game()
│   └── helpers.py          # Utilità (plateau clamping — inutilizzato)
├── simulator/
│   ├── domain/             # Tipi generici (congelato)
│   ├── engine/             # Loop simulazione (congelato)
│   └── ai/                 # Bot base (placeholder per fasi future)
├── project.godot           # Config Godot 3.4.4 (1280×720)
├── GAME_RULES.md           # Regolamento ufficiale
├── CARD_DATABASE.md        # Dati carte
├── run_simulations.py      # Batch runner
└── test_roadto100_rules.py # Test regole
```

---

## File fondamentali

| File | Ruolo |
|---|---|
| `GAME_RULES.md` | Regolamento ufficiale — fonte di verità |
| `games/roadto100/rules.py` | `RoadTo100RuleSet` — tutte le meccaniche |
| `games/roadto100/actions.py` | Tipi azione e `RoadTo100ActionController` (selezione casuale) |
| `games/roadto100/cards.py` | `build_deck()` — costruzione mazzo 60 carte |
| `games/roadto100/setup.py` | `build_initial_game()` — setup partita |
| `run_simulations.py` | Esecuzione batch: `python3 run_simulations.py <g2|g3|g4> <N>` |
| `project.godot` | Punto di partenza per il client Godot |

---

## TODO rimasti

- [ ] **Client Godot**: sviluppare partita completa giocabile
  - Board (Piatto, Mazzo, Scarti)
  - Mano del giocatore (3 carte)
  - Selezione e giocata carte
  - Turni e avversari (locale o hot-seat)
  - Animazioni ed effetti carte
- [ ] **AI** (`simulator/ai/bot.py`): scheletro vuoto — opzionale, fase futura
- [ ] **Multiplayer**: non iniziato

---

## Prossima fase

**Sviluppare una partita completa e giocabile in Godot 3.4.4.**

Il simulatore Python funge da reference: per qualsiasi dubbio sul comportamento di una carta o di una meccanica, eseguire il simulatore è più rapido e affidabile che rileggere il regolamento.

Flusso di lavoro consigliato:
1. Implementare una feature in Godot
2. Verificare che il comportamento corrisponda al simulatore (stesse carte → stesso risultato)
3. In caso di discrepanza, il simulatore ha ragione — correggere Godot
