# RoadTo100 — QWEN.md

## Project Overview

**RoadTo100** is a fast-paced multiplayer competitive card game built with **Godot 3.4.4** (engine) and **Python 3.8+** (simulation/testing framework). The game features simple rules with deep strategic choices, aiming for matches lasting 4-8 minutes. The project also includes a reusable card-game simulation framework (`simulator/`) designed to be game-agnostic.

### Key Technologies

| Layer | Technology | Path |
|---|---|---|
| Game client | Godot 3.4.4 (GDScript) | `project.godot` + `.gd` files |
| Simulation framework | Python 3.8+ | `simulator/` |
| Game-specific rules | Python 3.8+ | `games/roadto100/` |
| Card-game AI | Python 3.8+ | `simulator/ai/` |

---

## Architecture

### Repository Structure

```
/media/sumaka/Giochi/GodotProjects/roadTo100/
├── project.godot          # Godot engine project config (1280×720, "Road To 100")
├── a.gd                   # Empty GDScript placeholder
├── default_env.tres       # Godot default environment
├── icon.png / .import     # Game icon (auto-imported by Godot)
├── CARD_DATABASE.md       # Official card database v1.0
├── GAME_DESIGN.md         # Game design document
├── GAME_RULES.md          # Official game rules v1.0 (source of truth)
├── ENGINE_API.md          # Framework API reference (frozen contract)
├── TODO.md                # Development roadmap
├── regole.md              # Italian-language rules summary (informal)
├── .vscode/settings.json  # VSCode IDE config
├── memories/              # Project context memory files
│   └── repo/framework-guardrails.md
├── simulator/             # ** Python card-game simulation framework **
│   ├── domain/            # Generic domain types (frozen)
│   │   ├── game.py        # Game state (players, deck, phase, winner)
│   │   ├── card.py        # Generic Card dataclass
│   │   ├── deck.py        # Deck management (draw, shuffle)
│   │   ├── hand.py        # Player hand management
│   │   ├── player.py      # Player identity + hand
│   │   ├── action.py      # Abstract Action dataclass
│   │   ├── ruleset.py     # RuleSet ABC (contract for game rules)
│   │   └── ...
│   ├── engine/            # Simulation orchestration (frozen)
│   │   ├── simulator.py   # Main Simulator loop + SimulationResult
│   │   └── action_controller.py  # ActionController ABC (strategy pattern)
│   ├── ai/                # Bot agents
│   │   └── bot.py         # Bot base class (empty)
│   └── games/             # Game-specific implementations
│       └── roadto100/     # RoadTo100 concrete game
│           ├── rules.py             # (empty placeholder)
│           ├── card_database.py     # (empty placeholder)
│           └── deck_definition.py   # (empty placeholder)
├── games/                 # ** Python game definition modules **
│   ├── roadto100/         # RoadTo100 game implementation (in progress)
│   │   ├── __init__.py
│   │   ├── config.py      # Static game parameters
│   │   ├── cards.py       # Card definitions (per CARD_DATABASE.md)
│   │   ├── actions.py     # Action models (play_card, change_card, reveal_gold, etc.)
│   │   ├── rules.py       # RoadTo100Rules (RuleSet implementation)
│   │   ├── setup.py       # Initial game state construction
│   │   ├── helpers.py     # Shared utility functions
│   │   └── README.md      # Architecture proposal document
│   └── sample/            # Sample game (reference/template)
│       ├── __init__.py
│       ├── cards.py
│       ├── config.py
│       ├── rules.py
│       ├── setup.py
│       └── README.md
└── simulator.{zip,7z,tar} # Packaged simulator archives
```

### Two Codebases

1. **Godot client** (`project.godot`, `.gd`): The visual game — board, hand, animations, multiplayer (not yet implemented).
2. **Python simulator** (`simulator/` + `games/`): Headless simulation for balance testing, meta-analysis, and AI development.

---

## Framework Guardrails (Critical)

The following files are **frozen** (do not modify):

- `simulator/domain/` — All domain types (Game, Card, Player, Deck, Hand, Action, RuleSet, GamePhase)
- `simulator/engine/` — Simulator loop, SimulationResult, ActionController contract
- `ENGINE_API.md` — The official framework contract

**Rules:**
1. All new game logic must go under `games/`.
2. Never modify `domain` or `engine` unless fixing a real bug exposed by a concrete implemented game.
3. Never modify the framework for theoretical improvements.
4. If a game reveals a framework limitation, describe the limitation precisely and propose the minimal change; do not apply it automatically.
5. Any future framework change must be motivated by at least one concrete case from an implemented game.

---

## Game Rules Summary (RoadTo100)

### Objective
Be the player who brings the **Plate** (shared score) to **100 or more**.

### Deck Composition (60 cards)
| Card Type | Color | Count | Effect |
|---|---|---|---|
| Increment (+1 to +10) | Orange | 30 (3× each) | Add value to Plate |
| Jolly (+1 to +10 variable) | Orange | 10 | Player chooses value to add |
| Gold (12,23,34,45,56,67,78) | Gold | 7 | Set Plate to that value (stays on Plate) |
| 89 | Purple | 3 | Set Plate to 89 + start Advantage Round |
| +11 | Red | 5 | Add 11; wins instantly during Advantage Round |
| Imbroglio (-15 to +15, ≠0) | Green | 5 | Player chooses value (keeps Plate 0-99) |

### Game Flow
- Each player starts with 3 cards.
- **Per turn:** Play a card → resolve effect → draw 1 card. OR: return a card to deck → shuffle → draw 1.
- **Advantage Round:** Starts when 89 is played. Only the Advantage player can win; all players can only play Orange and Red cards.
- **Win conditions:** Reach 100+ normally (Imbroglio excluded). +11 during Advantage Round wins instantly.
- **Deck exhaustion:** Shuffle all discard pile cards (except the last one) back into the deck. Gold cards remain on the Plate permanently.

---

## Running the Project

### Godot Client
Open `project.godot` in **Godot Engine 3.4.4**.

### Python Simulator
```bash
# Prerequisites: Python 3.8+
python3 -c "from simulator.domain.game import Game; print('OK')"
```

No specific runner/entry point exists yet. The simulator is invoked programmatically:
```python
from simulator.domain.game import Game
from simulator.engine.simulator import Simulator
from games.roadto100.rules import RoadTo100Rules  # (to be implemented)
```

---

## Development Conventions

### Python Code Style
- **Python 3.8+** with `from __future__ import annotations` everywhere.
- **Dataclasses** with `slots=True` for value/domain objects.
- **ABCs** (via `abc.ABC`) for contracts (RuleSet, ActionController).
- **Enums** for closed sets of values (GamePhase, SimulationTerminationReason).
- Minimal dependencies — no external packages required for the simulator.
- Typing: use `Optional[T]`, `dict[str, Any]`, `list[T]` from the standard library.

### Godot Conventions
- Godot 3.4.4 (GDScript, not Godot 4).
- Window resolution: 1280×720.
- Visual design inspired by UNO, MTG Arena layout, and Poker clarity.

### Testing
- No test framework is configured yet (inferred from absence of test files).
- TODO: Add tests using Python's `unittest` or `pytest`.

### Documentation Hierarchy
- **`GAME_RULES.md`** is the authoritative source for game rules (overrides code).
- **`CARD_DATABASE.md`** is the authoritative source for card data.
- **`ENGINE_API.md`** is the frozen framework contract.
- Rules are never duplicated across documents.

---

## Current Development Status

| Component | Status |
|---|---|
| Domain (CardData, Deck, Hand, etc.) | ✅ Completed |
| Rules (RoadTo100Rules GDScript) | ✅ Completed and approved |
| Provider (GameStateProvider + LocalGameEngine) | ✅ Completed |
| Presenter/UI (Board, Hand, Turn, CardFace) | ✅ Completed and verified |
| GameController (8 states, input, popup, animation) | ✅ Completed (Steps 1–7) |
| CardAnimator (FIFO queue, tween, headless fallback) | ✅ Implemented |
| DebugDemo (Auto demo, integrated with GC) | ✅ Functional |
| Python Simulator | ✅ Complete and frozen |
| Multiplayer | ❌ Not started |
| AI (bot.py) | ❌ Not started |

See `PROJECT_STATE.md` and `ROADMAP.md` for the full roadmap and detailed status.

---

## Key Architecture Patterns

### Simulation Loop (Simulator + RuleSet + ActionController)
```
1. RuleSet.initialize_game(game)
2. Loop:
   a. RuleSet.get_available_actions(game)
   b. ActionController.select_action(game, actions)
   c. RuleSet.validate_action(game, action)
   d. RuleSet.apply_action(game, action)
   e. RuleSet.advance_turn(game)
   f. RuleSet.is_game_over(game) → break if done
```

### Game Module Structure (per `games/roadto100/README.md`)
```
config.py   → static constants
cards.py    → Card instances
actions.py  → Action instances
rules.py    → RuleSet implementation
setup.py    → initial Game state
helpers.py  → pure utility functions
```

---

## Memory Files

- `memories/repo/framework-guardrails.md` — Permanent framework change restrictions (rules above).
- `memories/` — Other project memories stored here for cross-session context.
