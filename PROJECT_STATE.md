# RoadTo100 — Stato Progetto

> Aggiornato al: 14 settembre 2026
> Scopo: documento di avvio per future sessioni di sviluppo.

---

## Stato attuale

Il progetto è composto da due codebase separati:

| Componente | Stato |
|---|---|
| Simulatore Python | **Completato e congelato** |
| Client Godot — Passaggio A→F | **Completo e verificato** (A→F chiusi) |
| Modalità manuale 1 umano + 3 CPU | **Funzionante** (ManualGame.gd, pulsante "Inizia Partita", selezione carte corretta) |
| Regola `allow89` | ✅ Implementata (carta 89 bloccata fino a Piatto ≥ 20) |
| Mazzo aggiornato | ✅ 6 Imbrogli / 4 +11 (totale 60: 40 Incrementi+Jolly, 7 Gold, 3×89, 4 +11, 6 Imbrogli) |
| +11 Gold chain | ✅ Rappresentazione corretta: crea nuova Gold nel Piatto senza consumare l'originale |
| **AI player_2 (bilanciata)** | ✅ RoadTo100AI — score-based strategic AI |
| **AI player_3 (aggressiva)** | ✅ RoadTo100AI con pesi aggressivi (preferisce incrementi alti, accetta più rischio) |
| **AI player_4 (tattica/prudente)** | ✅ RoadTo100AI con pesi tattici (preferisce controllo, evita rimbalzi) |
| **Ordine giocatori corretto** | ✅ P1→P2(Left)→P3(Top)→P4(Right) — turni logici e UI allineati |
| **Single-player core gameplay** | ✅ **Completato e funzionante** |
| **MainMenu** | ✅ **Implementata e ridisegnata** — scena principale (`run/main_scene`); pulsanti Gioca / Come si gioca (tutorial) / Esci |
| **AudioManager (singleton)** | ✅ **Musica dinamica funzionante** — 5 stem (Beat/Piano/Cello/Violin/Trumpet), autoloader globale |
| **GlobalsUtilities (singleton)** | ✅ **Stato condiviso** — plateValue, sr_active, selected_value, gameStarted, soglie musica |
| **spe100.png** | ✅ Piatto ≥ 100 usa texture speciale senza numero sovrapposto |
| **Valore Jolly/Imbroglio sugli Scarti** | ✅ `GlobalsUtilities.selected_value` + `ResolvedValueLabel` — visibile per tutti i giocatori (inclusa CPU) |
| **Ombre morbide e pile appoggiate a mano** | ✅ `ShadowFactory.gd` (ombre sagomate, SDF rettangolare) + ventaglio carte CPU + jitter pile Piatto/Scarti (±7px, rotazione ~±2.5°) + stack scarti dinamico |
| **Compatibilità Android / APK** | ✅ Preset di export "Android" (`export_presets.cfg`), cartella `android/`, APK `RT100.apk` funzionante |
| **Caricamento musicale su Android** | ✅ Canzone casuale scelta da **elenco esplicito** (necessario perché il listing su `res://` non funziona in APK) — attualmente solo `CardTrickLoop` |
| **SplashScreen** | ✅ Animazione logo al primo avvio (fade-in 0.7s / display 1.5s / fade-out 0.7s), saltabile con un tasto, poi → MainMenu |
| **Modalità Tutorial (1A + 1B)** | ✅ Modalità guidata "Come si gioca": popup con overlay bloccante, navigazione Prosegui/Fine, demo deterministica per step (scripted scenario, rewind, popup reali di scelta) |

---

## Flusso Menu → Partita

```
App avvio → SplashScreen.tscn (solo al primo avvio, se !GlobalsUtilities.splash_shown)
  ├─ Logo: fade-in 0.7s → display 1.5s → fade-out 0.7s (saltabile con un tasto)
  └─ → MainMenu.tscn (run/main_scene)

MainMenu.tscn
  ├─ _ready() → AudioManager.set_menu_music() (tutti e 5 stem a stemsVolume=0.7)
  ├─ [Gioca] pulsante
  │    └─ GlobalsUtilities.gameStarted=true, tutorialStarted=false → change_scene(Main.tscn)
  │         └─ Main.gd._ready() → $StartGameButton.emit_signal("pressed")
  │              └─ ManualGame.start_game(4) → partita 1 umano + 3 CPU
  ├─ [Come si gioca] pulsante
  │    └─ GlobalsUtilities.tutorialStarted=true → change_scene(Main.tscn)
  │         └─ Main.gd._ready() → TutorialController.start_tutorial() → modalità tutorial
  └─ [Esci] pulsante → get_tree().quit()

Durante la partita:
  ├─ BoardPresenter.apply_snapshot() aggiorna:
  │    ├─ GlobalsUtilities.plateValue = piatto
  │    ├─ GlobalsUtilities.sr_active = special_round_active
  │    └─ AudioManager.set_plate_value(plate_value) [ridondante: AudioManager lo fa da solo in _process]
  ├─ TurnPresenter.apply_snapshot() resetta:
  │    └─ GlobalsUtilities.selected_value = ""
  ├─ GameController._on_value_chosen():
  │    └─ GlobalsUtilities.selected_value = str(value) [solo per Jolly/Imbroglio del giocatore locale]
  └─ BoardPresenter mostra ResolvedValueLabel con il valore (+N o -N) sugli Scarti

Torna al Menu:
  └─ [Torna al Menu] pulsante (BackMenuButton in ActionPanel)
       └─ Main.gd._on_BackMenuButton_pressed()
            ├─ get_tree().change_scene("res://MainMenu.tscn")
            └─ GlobalsUtilities.gameStarted = false
```

### Note sul flusso
- `Main.tscn` è la scena di destinazione sia per la partita sia per il tutorial. `Main.gd._ready()` decide il ramo in base ai flag: se `tutorialStarted` → avvia `TutorialController.start_tutorial()`; altrimenti emette il segnale del pulsante StartGameButton (partita).
- `SplashScreen.tscn` appare solo al primo avvio (`GlobalsUtilities.splash_shown == false`); imposta il flag a `true` e non torna più.
- `AudioManager` è un **singleton autoloader** (`[autoload] AudioManager="*res://AudioManager.tscn"` in `project.godot`): sempre disponibile globalmente come `AudioManager`.
- `GlobalsUtilities` è un **singleton autoloader** per lo stato condiviso tra scene (`gameStarted`, `demoStarted`, `tutorialStarted`, `splash_shown`, `plateValue`, `sr_active`, `selected_value`).

---

## AudioManager — Musica Dinamica

### Architettura
- **File**: `AudioManager.gd` + `AudioManager.tscn`
- **Tipo**: Autoloader/singleton globale (registrato in `project.godot`)
- **5 stem musicali** (tutti `AudioStreamPlayer`, figli di `MusicPlayer`):
  - `Beat`, `Piano`, `Cello`, `Violin`, `Trumpet`
- **SFXPlayer**: AudioStreamPlayer con effetti posizionali (Select, ShuffleDeal, Draw, PlayCard, Victory)
- **Cartelle canzoni**: `res://sound/<nome_canzone>/`, ciascuna con i 5 file stem (`beat/piano/cello/violin/trumpet.mp3`). La canzone da caricare NON viene rilevata a runtime ma scelta da un **elenco esplicito** in `_load_random_song()`.

### Comportamento
1. **Avvio** (`_ready()`): sceglie una canzone casuale dall'elenco esplicito `song_folders` (attualmente `["CardTrickLoop"]`), carica i 5 stem con `load()`, avvia tutti in loop simultaneamente.
   - **Nota Android**: il caricamento usa un elenco esplicito invece del listing di directory perché l'enumerazione su `res://` non è affidabile quando le risorse sono impacchettate nell'APK. Per aggiungere una canzone basta: creare la cartella `sound/<Nome>/` con i 5 mp3 e aggiungere `<Nome>` all'array `song_folders`.
2. **Menu**: `set_menu_music()` → tutti e 5 gli stem a `stemsVolume` (0.7).
3. **Partita**: `set_game_music(piatto, sr_active)` → dinamica per soglie del Piatto.
4. **Ogni frame** (`_process()`): legge `GlobalsUtilities.plateValue` e `GlobalsUtilities.sr_active` e aggiorna i volumi con fade (0.7s).
5. **Nessun stop/play**: durante menu/partita gli stem non si fermano mai; l'ingresso/uscita avviene SOLO tramite volume_db con tween.

### Soglie musica (da `GlobalsUtilities`)

| Piatto | Beat | Piano | Cello | Violin | Trumpet |
|---|---|---|---|---|---|
| 0–29 | ✅ 0.7 | 0 | 0 | 0 | 0 (o 0.7 se SR) |
| 30–59 | ✅ 0.7 | ✅ 0.7 | 0 | 0 | 0 (o 0.7 se SR) |
| 60–88 | ✅ 0.7 | ✅ 0.7 | ✅ 0.7 | 0 | 0 (o 0.7 se SR) |
| 89–99 | ✅ 0.7 | ✅ 0.7 | ✅ 0.7 | ✅ 0.7 | 0 (o 0.7 se SR) |

- **Trumpet** si aggiunge indipendentemente quando `GlobalsUtilities.sr_active == true` (GS o GdV).
- `stemsVolume` è un export(float) configurabile (default 0.7).

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

## AI e personalizzazione giocatori

Tutti e tre i giocatori CPU utilizzano il sistema `RoadTo100AI` con configurazioni di pesi diverse per produrre personalità distinte:

| Giocatore | Personalità | Strategia | Pesi chiave diversi da default |
|---|---|---|---|
| **P2** | Bilanciata | Ottimizzazione bilanciata tra progresso e rischio | Default (W_INCREMENT_HIGH=3, W_PLATEAU_DANGER=25) |
| **P3** | Aggressiva | Preferisce incrementi alti, accetta più rischio sul Piatto | W_INCREMENT_HIGH=8, W_PLATEAU_DANGER=6, W_JOLLY_FLEXIBILITY=25, W_PLUS11_HOLD_BACK=-50 |
| **P4** | Tattica/Prudente | Preferisce controllo Piatto, usa il rimbalzo in modo difensivo, Imbroglio per il controllo | W_INCREMENT_HIGH=2, W_PLATEAU_DANGER=40, W_IMBROGLIO_STRATEGIC=50, W_PLUS11_HOLD_BACK=-100 |

Il sistema di scoring è comune; solo i pesi variano. **Nota**: non esiste più `W_BOUNCE_PENALTY` (penalità piatta sul rimbalzo). Al suo posto il modello usa `W_PLATEAU_DANGER`: penalità/bonus per ogni punto oltre 92 lasciati al giocatore successivo (zona di rischio), calcolata sul Piatto finale reale post-azione. Questo consente di aggiungere nuove personalità modificando solo la configurazione, non il codice base dell'AI.

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
| **Debug / Automazione** | | |
| DebugDemo | `scripts/DebugDemo.gd` | ✅ Integrato con GC (E6), esclusione reciproca |
| ManualGame | `scripts/ManualGame.gd` | ✅ 1 umano + 3 CPU, pausa turno umano, esclusione reciproca |
| StartGameButton | In `Main.tscn` | ✅ "Inizia Partita" → ManualGame.start_game(4), auto-emesso da Main.gd._ready() |
| BackMenuButton | In `Main.tscn` | ✅ "Torna al Menu" → Main.gd._on_BackMenuButton_pressed() → MainMenu.tscn |
| **Singleton / Autoloaders** | | |
| MainMenu | `MainMenu.tscn` + `MainMenu.gd` | ✅ Menu ridisegnata: Gioca / Come si gioca (tutorial) / Esci + gate splash |
| SplashScreen | `SplashScreen.tscn` + `SplashScreen.gd` | ✅ Animazione logo al primo avvio (saltabile) → MainMenu |
| AudioManager | `AudioManager.tscn` + `AudioManager.gd` | ✅ Singleton musica dinamica (5 stem) + SFX |
| GlobalsUtilities | `GlobalsUtilities.gd` | ✅ Singleton stato condiviso (plateValue, sr_active, selected_value, gameStarted, demoStarted, tutorialStarted, splash_shown, soglie) |
| Main.gd | `Main.gd` | ✅ Routing partita/tutorial in `_ready()`, BackMenuButton handler |
| **Tutorial** | | |
| TutorialController | `scripts/TutorialController.gd` + `.tscn` | ✅ Modalità guidata "Come si gioca" (popup, navigazione, input bloccato, demo) |

### Architettura finale

```
┌─────────────────────────────────────────────────────────────┐
│              AUTLOADERS (globali, sempre attivi)              │
│  AudioManager  — musica dinamica 5 stem + SFX               │
│  GlobalsUtilities — stato condiviso (piatto, SR, valori)    │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│              UI Layer (MainMenu.tscn → Main.tscn)            │
│  MainMenu: Gioca / Come si gioca (tutorial) / Esci          │
│  Main: BoardPresenter  HandPresenter  TurnPresenter          │
│        CardAnimator  CardFace  popup  TutorialController     │
│  Non conoscono le regole                                     │
└─────────────────────┬───────────────────────────────────────┘
                      │ snapshot / events / segnali
┌─────────────────────▼───────────────────────────────────────┐
│              GameController.gd                               │
│  Stati: WAITING → READY → CARD_SELECTED →                    │
│         WAITING_CHOICE → ACTION_PENDING →                    │
│         ANIMATING → GAME_OVER                                │
│  Public API: start_game(), perform_action()                  │
│  Signal: action_applied(result)                              │
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
| Domain | `tests/domain_test.gd` | 55+ | ✅ All PASS (60 carte, 4 +11, 6 Imbroglio) |
| Rules | `tests/rules_test.gd` | 214 | ✅ 0 FAIL (fix F7: in GS non si offre RESET_HAND, solo GdV) |
| Provider | `tests/provider_test.gd` | 93 | ✅ 0 FAIL |
| Presenter | `tests/presenter_test.gd` | 86 | ✅ 0 FAIL |
| Board | `tests/board_test.gd` | 41 | ✅ 0 FAIL (pile entro limiti jitter ±7px/~±2.5°) |
| Shadow / Pile Presentation | `tests/shadow_integration_test.gd/.tscn` | 20 | ✅ 0 FAIL (ombra non circolare, 1/pila, jitter pile, ombre CPU) |
| Fan Geometry (CPU) | `tests/fan_geometry_test.gd/.tscn` | 7 | ✅ 0 FAIL (ventaglio carte CPU) |
| GameController | `tests/game_controller_test.gd` | 238 | ✅ 0 FAIL (incl. GdV blocking, popup re-open, race condition) |
| Card Selection | `tests/card_selection_test.gd` | 27 | ✅ 0 FAIL (fix HUDLayer.mouse_filter) |
| CardAnimator | `tests/card_animator_test.gd` | 5 | ✅ 0 FAIL |
| CardAnimator Multi-Player | `tests/card_animator_test2.gd` | 20 | ✅ 0 FAIL |
| Demo Integrazione | `tests/demo_integration_test.gd` | 5 | ⚠️ flaky (partite casuali; occasionalmente >200 turni senza vincitore — preesistente) |
| Demo Verifica Eventi | `tests/demo_verification_test.gd` | 9 | ✅ 0 FAIL |
| Manual Game (1H+3C) | `tests/manual_game_test.gd` | 26 | ✅ 0 FAIL |
| Manual Game Smoke | `tests/manual_game_smoke.tscn` | — | ✅ PASS |
| +11 Gold Transformation | `tests/plus11_gold_transformation_test.gd` | 3 | ✅ 0 FAIL (Gold chain crea nuova Gold) |
| AI Decisioni Base | `tests/ai_test.gd` | 3 | ✅ 0 FAIL (preferenza alta, Gold, Gold chain) |
| AI Avanzate | `tests/ai_advanced_test.gd` | 7 | ✅ 0 FAIL (vittoria, Jolly strategico, bounce, Imbroglio, hold-back +11) |
| Reset Hand Rule | `tests/reset_hand_rule_test.gd` | 3 | ✅ 0 FAIL (GS vietato, GdV una volta) |
| Tutorial Mode (1A) | `tests/tutorial_test.gd` | 71 | ✅ 0 FAIL (routing, input bloccato, navigazione, demo deterministica) |
| Scripted Demo (1B) | `tests/scripted_demo_test.gd` | 26 | ✅ 0 FAIL (stato iniziale, sequenze step, rewind, popup reali, riproducibilità) |

**Test Python:** 93 test totali — 87 in `test_roadto100_rules.py` + 6 in `test_roadto100_ai.py` — tutti OK.

---

## TODO rimasti

- [x] ~~**Fix selezione carte nel turno umano**~~ — **RISOLTO** (HUDLayer.mouse_filter=IGNORE, test card_selection_test)
- [x] ~~**AI avversaria** (`player_2`)~~ — **IMPLEMENTATA** (score-based strategic AI in Python/GDScript, integrata in ManualGame)
- [x] ~~**AI personalità multiple**~~ — **COMPLETATO** (P3 aggressiva, P4 tattica/prudente, stessa base RoadTo100AI con pesi diversi)
- [ ] **Multiplayer**: non iniziato.

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

**Stato attuale:** ✅ Passaggio F chiuso — Step F1–F8 tutti completati e verificati (F8 il 19 agosto 2026). Prossimo lavoro: flusso 1 umano vs 3 CPU.

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
- [x] **F8:** Regressione finale, correzione bug funzionali residui e chiusura del Passaggio F. ✅ Completato e verificato (19 agosto 2026).

**Prossimo step da implementare:** Flusso 1 umano vs 3 CPU (primo lavoro post-F)

**File coinvolti in F8:** `engine/LocalGameEngine.gd`, `scripts/GameController.gd`, `tests/rules_test.gd`, `tests/provider_test.gd`, `tests/game_controller_test.gd`, `tests/demo_verification_test.gd`.

---

### F8 — Regressione finale e chiusura (19 agosto 2026, completato)

Ultimo step del Passaggio F: verifica completa dei bug funzionali segnalati e correzioni mirate.

**Bug #4 — Vittoria a Piatto 107 con +10 fuori da Giri Speciali:** analizzato e confermato **legittimo** quando il +10 è l'advantage player durante il GdV (il Vantaggio ignora la Regola del Rimbalzo e vince a >= 100; il valore raw interno 107 è corretto per la risoluzione). Il difetto reale era la UI che mostrava 107 → risolto con il bug #5. Test documentativo: `_test_f8_gdv_advantage_97_plus_10_wins_raw` (rules_test).

**Bug #5 — Piatto mai > 100 in UI:** `LocalGameEngine.gd` cappa il display del Piatto a 100 sia nello snapshot (`display_piatto`) che nello stack visivo (`_build_plateau_visual_stack`). Il metadata interno conserva il valore raw per la risoluzione delle regole. Test: `_test_f8_gdv_win_snapshot_piatto_capped` (provider_test, GdV 97+10=107 → snapshot 100, stack clean).

**Bug #3 — Popup Jolly/Imbroglio:** il GameController non usava più range hardcoded, ma legge i `choices` da `available_actions` dello snapshot (valori già filtrati dalle regole: Jolly 1-10, Imbroglio -15..+15 escluso 0 e coerente con il Piatto corrente). Nuovo helper `_play_values_for_selected_card()`. Test F8.1/F8.2/F8.3 in game_controller_test (imbroglio filtrato dal Piatto, valore non consentito bloccato, Jolly dallo snapshot).

**Bug #1/#2 — Gestione popup/WAITING_FOR_CHOICE e blocked_type una sola volta:** verificati con i test esistenti F7 (6 GC + flusso provider) — nessuna regressione: il popup appare per ogni scelta richiesta e blocca correttamente; la scelta `blocked_type` avviene una sola volta all'attivazione del GS.

**Bug pre-esistenti corretti durante F8:**
- `mini()` → `min()` in LocalGameEngine.gd (sintassi Godot 4 invalida su 3.4, causava parse error e timeout silent).
- `not in` → `not (...) in` in game_controller_test.gd (GDScript 3 non supporta l'operatore infix, causava hang della suite).
- Bug semicolon one-line in `demo_verification_test.gd`: `else: failed += 1; print(...)` stampava "FAIL" anche sui test verdi — convertito alla forma multi-line.

**Stato test finale F8 (regressione completa, 19 agosto 2026):**
- Python: 74/74 OK
- rules_test: 60 test / 191 assert / 0 FAIL
- provider_test: 97/0
- game_controller_test: 175/0
- presenter_test: 84/0
- board_test: 44/0
- domain_test: All PASS
- card_animator_test: 5/0
- card_animator_test2: 20/0
- demo_integration_test: 5/5 partite / 0 FAIL
- demo_verification_test: 9/0

**Passaggio F chiuso.** Il client Godot implementa ora l'intero gameplay (A→F). Prossimo lavoro consigliato: flusso 1 umano vs 3 CPU.

---

## ULTIMA SESSIONE (21 agosto 2026) — Fix popup UI post-F8

Correzioni mirate dei bug di comportamento popup rilevati in-game, senza modifiche alle regole.

### Fix applicati

- **Jolly/Imbroglio popup:** mostra sempre tutte le opzioni teoriche; solo i valori presenti nelle `choices` dell'engine sono abilitati; se `choices` è vuoto tutte le opzioni restano disabilitate (nessun'invenzione di validità lato UI).
- **Carte bloccate GS:** HandPresenter scurisce e disabilita il click sulle carte della tipologia bloccata durante Giro Sicuro.
- **GoldRevealPopup:** lifecycle corretto — aperto solo quando l'engine offre `reveal_gold`, chiuso da Sì/No o `perform_action` diretto.
- **HandResetPopup:** limitato ESCLUSIVAMENTE al Giro di Vantaggio, solo per il giocatore locale non-in-Vantaggio senza Incrementi giocabili. Durante GS non esiste cambio completo mano (resta disponibile Cambio Carta).
- **reset_hand non termina il turno:** `LocalGameEngine.send_action()` salta `advance_turn()` per `reset_hand`; il giocatore continua con le nuove carte.
- **Segnalino SR badge:** indicatore su `special_round_player_id` finché `special_round_active` (BoardPresenter).
- **Animazione carta vincente:** GAME_OVER impostato solo dopo il completamento dell'animazione (non prima).
- **Interferenze popup eliminate:** nessun popup sopprime o apre erroneamente un altro per effetto di uno stato `WAITING_FOR_CHOICE` generico.
- **demo_integration_test:** gestisce `reset_hand` nello stato WAITING_FOR_CHOICE; 5/5 partite senza hang.

### File modificati (solo UI/engine, non regole)

- `scripts/GameController.gd` — `_open_value_choice()` all/valid split, `_full_value_range()`, `_check_reset_hand()` con check GdV+local+non-advantage
- `scripts/HandPresenter.gd` — darkening + click-blocking per GS blocked cards
- `scripts/BoardPresenter.gd` — SR badges
- `engine/LocalGameEngine.gd` — `advance_turn()` saltato per reset_hand
- `tests/game_controller_test.gd` — aggiornati Fix4 tests + 5 nuovi HR scope tests (197 totali)
- `tests/provider_test.gd` — aggiornato test reset_hand order (no turn_changed)
- `tests/demo_integration_test.gd` — gestione reset_hand in state 3

### Modalità manuale 1 umano + 3 CPU (implementata)

Nuovo nodo `scripts/ManualGame.gd` che avvia una partita 1 umano + 3 CPU reusing DebugDemo/GameController/engine senza duplicare regole:

- **Pulsante "Inizia Partita"** in `Main.tscn` → `ManualGame.start_game(4)`.
- **CPU automatiche:** scelgono azioni da `available_actions` (stesso pattern di DebugDemo).
- **Automazione si ferma al turno umano:** `_is_local_turn()` verifica; se è il turno del giocatore locale, ManualGame non invia azioni e lascia la UI interattiva.
- **Ripresa dopo l'azione umana:** il timer continua a girare; quando il turno passa alle CPU, riparte l'automazione.
- **Esclusione reciproca:** `ManualGame.start_game()` e `DebugDemo.start_demo()` chiamano `_stop_sibling_automation()`, fermando l'altro nodo. Solo una automazione può guidare il gioco alla volta.

### Bug fix modalità manuale (21 agosto 2026)

- **Bug 1 — Primo turno umano auto-eseguito:** causa: ManualGame e DebugDemo entrambi attivi guidavano lo stesso GameController; DebugDemo non rispettava il turno umano. Fix: `_stop_sibling_automation()` in entrambi i nodi → esclusione reciproca.
- **Bug 2 — Input umano bloccato dal secondo turno:** causa: `OverlayLayer` (Control full-screen, z-order sopra GameArea) con `mouse_filter=PASS` (1) intercettava tutti i click via `mouse_pick`. Fix: `mouse_filter=IGNORE` (2) in `Main.tscn`. I popup (PopupPanel/Window) sono immuni perché gestiscono il proprio input via focus finestra.
- **Pulsanti Gioca/Cambia** ora ricevono correttamente i click durante il turno umano.

### Problema aperto — Prossimo step

~~Durante il turno umano **le carte della mano non risultano selezionabili**: cliccando una carta non accade nulla.~~ **RISOLTO** (26 agosto 2026): causa era `HUDLayer.mouse_filter=PASS` che intercettava i click. Fix: `mouse_filter=IGNORE`. Test: `card_selection_test.gd`.

### Nota non bloccante

Warning preesistente nel CardAnimator: `Only non-negative delay values allowed in Tweens` (`PLAY_ANIM_DURATION 0.35 − FADE_DURATION 0.75 = -0.40`). Non correlato ai bug sopra, non blocca il gioco (le animazioni completano comunque). Da correggere separatamente.

### Stato test finale (21 agosto 2026)

Tutte le suite verdi: GC 197, Provider 97, Presenter 84, Board 44, Rules 191, manual_game_test **25/0**, manual_game_smoke **PASS**, demo_integration 5/5.

### Prossimo passo consigliato (alternative post-F)

1. ~~**Fix selezione carte nel turno umano**~~ — **RISOLTO** (sessione 26 agosto 2026)
2. **AI per simulatore Python** (`simulator/ai/bot.py`): prossima implementazione per player_2.
3. **Migliorie UI/UX** — Texture carte definitive, effetti sonori, schermata di vittoria, animazioni più ricche.
4. **Multiplayer** (`RemoteGameAdapter`): architettura definita, implementazione futura.

---

## ULTIMA SESSIONE (26 agosto 2026)

### Single-player core gameplay completato

Chiusura della fase single-player con tutte le correzioni e miglioramenti finali:

#### Fix selezione carte (RISOLTO)

**Causa:** `HUDLayer` (Control full-screen) aveva `mouse_filter = 1` (PASS), che intercettava i click destinati alle carte della mano. I pulsanti d'azione funzionavano perché sono figli di HUDLayer.

**Soluzione:** `HUDLayer.mouse_filter = 2` (IGNORE) — trasparente ai click sulle carte sottostanti.

**Test:** `tests/card_selection_test.gd` — verifica strutturale del fix + catena completa click → CardFace.clicked → HandPresenter.card_selected → GameController selection.

#### Regola `allow89`

**Implementazione:** Carta 89 non giocabile fino a Piatto ≥ 20 permanentemente.

- **Python** (`games/roadto100/rules.py`): `game.metadata["allow89"] = False` → True quando plateau ≥ 20
- **GDScript** (`engine/RoadTo100Rules.gd`): stessa logica
- **Provider** (`engine/LocalGameEngine.gd`): `"allow89"` nello snapshot
- **UI** (`scripts/HandPresenter.gd`): carta 89 dimmed quando `allow89=false`
- **GameController** (`scripts/GameController.gd`): guardia `_is_selected_card_89_not_allowed()`

**Test Python:** `TestAllow89` — 8 test, tutti OK.

#### Mazzo aggiornato (6 Imbrogli / 4 +11)

- **Python:** `games/roadto100/card_database.py` — `PLUS11_COPIES=4`, `IMBROGLIO_COPIES=6`
- **GDScript:** `engine/CardDatabase.gd` — `range(4)` / `range(6)`
- **Test:** `tests/domain_test.gd` aggiornati (7 special, 6 imbroglio)

#### +11 Gold chain — rappresentazione corretta

**Problema:** La +11 giocata dopo una Gold via Gold chain appariva come carta generica sul Piatto invece che come la Gold risultante.

**Soluzione minima in `RoadTo100Rules.gd`:**
- Quando `gold_chain_value != null`, si crea una nuova `CardData` con `card_id="transformed_gold_<val>"` e `card_type="gold"`
- Questa viene aggiunta a `plateau_cards` invece della +11 originale
- La +11 segue i normali flussi (scarto)

**Test:** `tests/plus11_gold_transformation_test.gd` — verifica:
- Gold 45 → +11 → plateau contiene Gold 56 trasformata (ID unico)
- Gold originale non consumata (ID diverso dalla trasformata)

#### Popup/GS/GdV fixes

- **Popup modality:** popup non si chiudono più con click esterno durante WAITING_FOR_CHOICE (re-open via `popup_hide` signal + `call_deferred`)
- **GdV visual dimming:** carte non-Incremento oscurate durante Giro di Vantaggio (`_card_blocked_by_gdv`)

#### Stato test finale

| Suite | Esito |
|---|---|
| Python (test_roadto100_rules.py) | 87/87 OK |
| domain_test | ✅ PASS |
| rules_test | ✅ PASS (62 test, 191 assert) |
| provider_test | ✅ PASS |
| game_controller_test | ✅ PASS (211 assert) |
| card_selection_test | ✅ PASS |
| plus11_gold_transformation_test | ✅ PASS |
| Tutte le altre suite | ✅ PASS |

**Totale: ~750+ GDScript assertions + 87 Python tests — tutti verdi.**

---

## ULTIMA SESSIONE (28 agosto 2026)

### Prima AI strategica di player_2 — Completata

Implementazione completa della prima AI non-casuale per `player_2`, sia in Python che in GDScript, con equivalenza funzionale tra le due implementazioni.

#### Architettura AI

Score-based: ogni azione disponibile viene valutata con un punteggio euristico, la più alta viene scelta (con jitter casuale minimo per rompere i pari). L'AI usa solo informazioni legittimamente disponibili (snapshot pubblico, proprie carte, stato Piatto/SR).

#### Capacità implementate

| Capacità | Dettaglio |
|---|---|
| Vittoria immediata | Rileva quando `piatto + valore >= 100` e gioca per vincere (priorità massima: `W_IMMEDIATE_WIN = 10000`) |
| Valutazione Piatto/distanza | Score proporzionale all'avanzamento verso 100 (`W_ADVANCE = 100 × valore / 10`) |
| Scelta Jolly strategica | Valuta ogni valore 1–10, sceglie quello che massimizza progresso senza rimbalzo; vince se possibile |
| Scelta Imbroglio strategica | Scegli il valore positivo più alto per massimizzare il Piatto (vincolato a max 99) |
| Hold-back +11 | `W_PLUS11_HOLD_BACK = -75` — conserva la +11 salvo vittoria, Gold chain, o GdV |
| Gold chain | `W_PLUS11_GOLD_CHAIN = 70` — priorità alta per +11 dopo Gold |
| GdV | Bonus per attivatore +11 e incrementi alti durante Giro di Vantaggio |
| Gestione rischio Piatto | `W_PLATEAU_DANGER` (default 25) — bonus/penalità per i punti >92 lasciati al giocatore successivo; valuta il Piatto finale reale (post-bounce) invece di una penalità piatta sul rimbalzo |
| Gold/GS | `W_GOLD_ACTIVATE_SR = 60` — valore strategico dell'attivazione Safe Round |
| Cambio Carta | `W_CHANGE_CARD = -10` — ultima risorsa |

#### File creati/modificati

| File | Ruolo |
|---|---|
| `games/roadto100/ai.py` | AI Python (class `RoadTo100Bot`) — usa reali `available_actions` da `RoadTo100RuleSet` |
| `engine/RoadTo100AI.gd` | AI GDScript (class `RoadTo100AI`) — interfaccia `select_action(available_actions, snapshot)` |
| `scripts/ManualGame.gd` | Integrata AI per `player_2`, supporto `selected_value` per Jolly/Imbroglio |
| `tests/ai_test.gd/.tscn` | 3 test base (preferenza alta, Gold, Gold chain) |
| `tests/ai_advanced_test.gd/.tscn` | 7 test avanzati (vittoria, Jolly vincente, bounce, Imbroglio, hold-back +11, +11 vittoria, Jolly anti-bounce) |
| `test_roadto100_ai.py` | 6 test Python con integrazione reale available_actions |

#### Pesi euristiche (costanti configurabili)

```python
# Pesi default attuali (engine/RoadTo100AI.gd)
W_IMMEDIATE_WIN = 10000      # Vittoria immediata
W_ADVANCE = 100              # Progresso verso 100
W_PLATEAU_DANGER = 25        # Rischio: penalità/bonus per punto >92 lasciato al prossimo (replaced W_BOUNCE_PENALTY)
W_INCREMENT_HIGH = 3         # Bonus incrementi alti (8-10)
W_INCREMENT_MED = 2          # Incrementi medi (5-7)
W_INCREMENT_LOW = 1          # Incrementi bassi (1-4)
W_JOLLY_FLEXIBILITY = 15     # Flessibilità Jolly
W_GOLD_ACTIVATE_SR = 60      # Attivazione GS
W_PLUS11_GOLD_CHAIN = 70     # Gold chain
W_PLUS11_NORMAL = 40         # +11 normale
W_PLUS11_HOLD_BACK = -75     # Hold-back +11
W_IMBROGLIO_STRATEGIC = 25   # Imbroglio
W_GDV_BONUS = 30             # Bonus GdV
W_CHANGE_CARD = -10          # Cambio carta
TIE_BREAKER_JITTER = 5       # Random jitter per anti-predictability
```

#### Stato test finale (28 agosto 2026)

| Suite | Esito |
|---|---|
| Python (93 test: rules + AI) | ✅ 93/93 OK |
| ai_test | ✅ 3/0 |
| ai_advanced_test | ✅ 7/0 |
| manual_game_test | ✅ 26/0 |
| domain_test | ✅ PASS |
| Tutte le altre suite | ✅ PASS |

### Fix reset_hand durante GS (sessione precedente, verificato)

`reset_hand` è consentito **solo** durante GdV (`special_round_type == "advantage"`), mai durante Giro Sicuro. Flag `_reset_hand_used_this_turn` previene uso ripetuto nello stesso turno. Test: `tests/reset_hand_rule_test.gd`.

### Prossimo step

1. **Multiplayer** (`RemoteGameAdapter`): architettura definita, implementazione futura.
2. **AI personalità multiple**: varianti aggressive/difensive bilanciando i pesi esistenti.
3. **Migliorie UI/UX**: texture definitive, effetti sonori, animazioni più ricche.

---

## ULTIMA SESSIONE (11 settembre 2026) — Ombre/pile grafiche e caricamento audio su Android

### Resa grafica: ombre morbide e pile "appoggiate a mano"

Implementata la resa visiva di ombre e pile sul tavolo, **solo presentazione** (nessuna modifica a regole, input o animazioni).

- **`scripts/ShadowFactory.gd`** (nuovo) — helper puramente visivi per le ombre:
  - Ombra **sagomata** a rettangolo arrotondato con bordi morbidi (SDF signed-distance in shader `canvas_item` su un `ColorRect`), leggermente più grande dell'elemento, offset verso basso/destra.
  - Una sola ombra sotto l'intera pila per **Mazzo / Piatto / Scarti**; una per ogni **carta coperta CPU**. Nessuna ombra sulla mano P1.
  - Nota tecnica: usato un shader (e non `ImageTexture` procedurale né `z_index`) perché in questo build Godot 3.4.4 `Image.create()` e la scrittura di `z_index` su `ColorRect` non funzionano; l'ordine di rendering è gestito con l'ordinamento dei fratelli (`move_child`).
- **`scripts/BoardPresenter.gd`**:
  - `_setup_pile_shadows()` — ombra unica per Mazzo/Piatto/Scarti in `_ready()`.
  - **Ventaglio CPU** (P2/P3/P4): carte coperte disposte a ventaglio ordinato (centrale dritta, laterali ruotate in verso opposto).
  - **Jitter pile** (`_pile_jit`, tabella deterministica): ogni carta di **Piatto** (`PL/SV`) e degli **Scarti** riceve offset ±7px e rotazione ~±2.5° stabile (base allo 0,0). Mazzo con sola rotazione complessiva minima (1.5°), senza jitter per carta.
  - **Stack Scarti dinamico** (`_update_discard`): renderizza le ultime carte scartate come pila con jitter dietro `TopCard`.

### Caricamento musicale via elenco esplicito (necessario per Android)

- **`AudioManager.gd` → `_load_random_song()`**: la canzone NON viene più rilevata a runtime dalle sottocartelle, ma scelta **casualmente da un elenco esplicito** `song_folders`. Attualmente l'elenco contiene solo `"CardTrickLoop"` (unica cartella presente in `res://sound/`).
- **Motivo**: sull'APK le risorse `res://` sono impacchettate e il listing di directory non è affidabile → si usa un elenco esplicito + `load()`.
- Per aggiungere una canzone: creare `res://sound/<Nome>/` con i 5 mp3 e aggiungere `<Nome>` all'array.

### Stato Android

- Preset di export **"Android"** in `export_presets.cfg` (output `./RT100.apk`) + cartella `android/`; APK funzionante (commit "Aggiunta compatibilità Android e APK funzionante").
- La musica carica correttamente su Android grazie all'elenco esplicito.

### Test di verifica

| Suite | Esito |
|---|---|
| `tests/shadow_integration_test.gd/.tscn` | ✅ 20/0 — ombra non circolare (SDF), 1 ombra/pila, jitter Piatto/Scarti entro limiti, ombre CPU 1-per-carta |
| `tests/fan_geometry_test.gd/.tscn` | ✅ 7/7 — geometria ventaglio CPU |
| `tests/board_test.gd` | ✅ 41/0 (verifica jitter pile entro limiti) |
| `tests/game_controller_test.gd` | ✅ 211/0 (partite reali con nuovo rendering) |
| `tests/provider_test.gd` | ✅ 93/0 (snapshot incl. `discard_stack`) |
| `tests/manual_game_smoke.tscn` | ✅ SMOKE PASS |

---

## ULTIMA SESSIONE (13 settembre 2026) — Fix race condition, plate back, logica GdV reset_hand/change_card

Tre modifiche indipendenti, tutte verificate con i test. Nessuna modifica al framework Python congelato; solo client Godot + regole GdV.

### 1. Race condition "Nuova partita" durante animazione deal

**Problema:** premendo "Nuova partita" durante l'animazione di deal, la logica dell'antica partita poteva ancora completare operazioni asincrone (yield di animazione, timer CPU) e corrompere lo stato della nuova partita.

**Soluzione — sistema di Game Generation ID:**
- `GameController.gd`: contatore `_game_generation`; `get_game_generation()`; `start_game()` incrementa il contatore, cancella `CardAnimator`, resetta flag asincroni.
- `_animate_initial_deal()`: dopo ogni `yield`, verifica che la generazione non sia cambiata → se cambiato, interrompe e ritorna.
- `_on_animation_finished()`: usa flag `_expecting_animation_finish` (non più `is_animating()`, perché il CardAnimator reale setta `_busy=false` PRIMA di emettere il segnale).
- `CardAnimator.gd`: nuovo metodo `cancel()` — uccide la tween, svuota la coda, libera i cloni (`_active_clones`).
- `ManualGame.gd` e `DebugDemo.gd`: variabile `_game_gen` impostata all'avvio; `_on_timer_timeout()` verifica la generazione corrente → se cambiate, ritorna (timer stalescatti ignorati).

### 2. Plate back durante l'animazione di deal

**Modifica:** durante il deal iniziale si mostra `cardbackplate.png` al posto del `plate.png` con valore 0; alla fine del deal (inizio primo turno) si torna al plate normale.
- `BoardPresenter.gd`: nuovi metodi `show_plate_back()` / `hide_plate_back()`.
- `GameController._animate_initial_deal()`: chiama `show_plate_back()` all'inizio, `hide_plate_back()` alla fine.

### 3. Logica GdV: reset_hand + change_card (regressione corretta)

**Problema originale (deadlock P4):** durante il GdV, un giocatore con mano `[gold_34, imbroglio_3, imbroglio_4]` e nessuna carta arancione/rossa giocabile si bloccava: `available_actions` vuoto → nessun'azione possibile.

**Evoluzione della specifica (3 versioni, la 3 è quella finale):**
1. ~~reset_hand per tutti; change_card solo dopo rifiuto~~ — implementata poi rifiutata dall'utente.
2. ~~change_card disponibile normalmente durante GdV~~ — rifiutata.
3. **FINALE:** quando un giocatore non ha carte giocabili, **ENTRO** `reset_hand` E `change_card` sono disponibili **simultaneamente**. Nessun meccanismo di rifiuto. Il giocatore sceglie liberamente.

**Logica finale implementata in `RoadTo100Rules.gd`:**
```gdscript
# Durante GdV: TUTTI i giocatori senza carte giocabili ricevono RESET_HAND + CHANGE_CARD.
var is_gdv = advantage_turn and sr_type == "advantage"
if is_gdv and not current_player.hand.cards.empty():
    var has_playable = false
    for c in current_player.hand.cards:
        if _card_playable_sr(c, advantage_turn, sr_type, blocked_type):
            has_playable = true
            break
    if not has_playable:
        var reset_used = game.metadata.get("_reset_hand_used_this_turn", false)
        if not reset_used:
            actions.append({"action_type": RESET_HAND_ACTION})
        # change_card sempre disponibile come alternativa per ogni carta in mano
        for card in current_player.hand.cards:
            actions.append({"action_type": CHANGE_CARD_ACTION, "card": card})
        return actions
```

- `reset_hand` disponibile **una volta per turno** (flag `_reset_hand_used_this_turn`).
- `change_card` sempre disponibile per tutte le carte in mano.
- Dopo un `reset_hand` che non produce carte giocabili, `change_card` resta disponibile.
- Stesso comportamento per il giocatore in Vantaggio e per i giocatori normali.
- `advance_turn()` resetta SOLO il flag `_reset_hand_used_this_turn`.

**Nota:** `LocalGameEngine.set_reset_hand_refused()` e lo stub nel mock provider sono stati mantenuti ma **non più usati** dalla logica (nessun meccanismo di rifiuto nella versione finale). Sono residui della versione 2, inoffensivi.

### File principali modificati

| File | Ruolo |
|---|---|
| `engine/RoadTo100Rules.gd` | Logica GdV: reset_hand + change_card simultanei quando nessuna carta giocabile |
| `scripts/GameController.gd` | Generation ID, `_expecting_animation_finish`, plate back, reset_hand/change_card flow |
| `scripts/CardAnimator.gd` | Metodo `cancel()` per invalidare animazioni stalescate |
| `scripts/ManualGame.gd` | `_game_gen` + check generazione nel timer |
| `scripts/DebugDemo.gd` | `_game_gen` + check generazione nel timer |
| `scripts/BoardPresenter.gd` | `show_plate_back()` / `hide_plate_back()` |
| `engine/LocalGameEngine.gd` | `set_reset_hand_refused()` (residuo, inattivo) |
| `tests/rules_test.gd` | Test GdV reset_hand/change_card aggiornati + 4 nuovi test |
| `tests/game_controller_test.gd` | 5 nuovi test race condition (generation ID) |
| `tests/mock_provider.gd` | Stub `set_reset_hand_refused()` (inattivo) |

### Test eseguiti e risultati (verificati il 13 settembre 2026)

| Suite | Assert | Esito |
|---|---|---|
| rules_test | **214** | ✅ 0 FAIL |
| game_controller_test | **238** | ✅ 0 FAIL (incl. 5 nuovi test race condition) |
| Python (rules + AI) | 93 test | ✅ OK |

### Test aggiunti nella sessione

- **game_controller_test.gd** — 5 test race condition: "New game during deal", "Generation increments", "Deal gen check", "CA cancel on restart", "Stale anim ignored", "ManualGame gen check".
- **rules_test.gd** — 4 nuovi test GdV:
  - `_test_gdv_no_playable_both_available` — reset_hand + change_card entrambi offerti
  - `_test_gdv_reset_still_no_playable_change_available` — dopo reset, change_card resta disponibile
  - `_test_gdv_advantage_player_same_behavior` — stesso comportamento per il giocatore in Vantaggio
  - `_test_gdv_has_playable_normal_actions` — con carte giocabili, azioni normali (no reset/change)

### Problemi aperti / punti da verificare

- **Residuo inattivo:** `set_reset_hand_refused()` in LocalGameEngine e mock è codice morto dalla versione 3 della logica. Può essere rimosso in una pulizia futura (non bloccante).
- **Warning preesistente:** `ObjectDB instances leaked at exit` nei test game_controller_test — già noto, non correlato alle modifiche di questa sessione, non blocca i test (exit code 0).

### Prossimo passo consigliato

1. **Multiplayer** (`RemoteGameAdapter`): architettura definita, implementazione futura.
2. **AI personalità multiple**: varianti aggressive/difensive bilanciando i pesi esistenti (già implementate P3 aggressiva / P4 tattica — vedi sezione AI).
3. **Migliorie UI/UX**: texture definitive, effetti sonori, animazioni più ricche, schermata di vittoria.
4. **Pulizia codice**: rimuovere `set_reset_hand_refused()` inattivo se si conferma che il meccanismo di rifiuto non tornerà.

---

## ULTIMA SESSIONE (14 settembre 2026) — SplashScreen, MainMenu ridisegnata e Modalità Tutorial

Lavoro sul flusso di avvio e sulla modalità guidata "Come si gioca". Nessuna modifica alle regole di gioco: la logica resta in `RoadTo100Rules.gd`; preparazione stato e rewind della demo appartengono al sistema demo/engine, non alle regole.

### 1. SplashScreen (nuova)

- **File:** `SplashScreen.tscn` + `SplashScreen.gd`.
- Mostrata **solo al primo avvio** (`GlobalsUtilities.splash_shown == false`); poi il flag è `true` e non torna.
- Animazione logo: fade-in 0.7s → display 1.5s → fade-out 0.7s (tween su `modulate:a`). **Saltabile** premendo un tasto (`is_any_key_pressed()`).
- Alla fine → `MainMenu.tscn` (via `call_deferred("change_scene", ...)`).

### 2. MainMenu ridisegnata

- **File:** `MainMenu.tscn` + `MainMenu.gd`; icone/font nuovi in `imgs/` e `fonts/` (`playIcon`, `tutorialIcon`, `onlineIcon`, `optionIcon`, `shopIcon`, `statsIcon`, `popupTutorial.png`, `btnFont.tres`, `popupFont.tres`).
- **Pulsanti funzionali (connessi):**
  - **Gioca** → `_on_Play_pressed()`: `gameStarted=true`, `tutorialStarted=false` → `Main.tscn`.
  - **Come si gioca** → `_on_Tutorial_pressed()`: `tutorialStarted=true` → `Main.tscn` (apre il tutorial).
  - **Esci** → `_on_ExitGame_pressed()`: `get_tree().quit()`.
- **Nota:** le icone Online/Opzioni/Shop/Statistiche sono presenti come asset ma i relativi pulsanti **non sono ancora cablati** (placeholder per funzioni future).

### 3. Routing in Main.gd

- `Main.tscn` è la scena di destinazione sia per la partita sia per il tutorial.
- `Main.gd._ready()`: se `GlobalsUtilities.tutorialStarted` → ottiene/crea `TutorialController` e chiama `start_tutorial()`; altrimenti emette `StartGameButton.pressed` (partita 1 umano + 3 CPU).

### 4. Modalità Tutorial — Fase 1A (framework popup)

- **File:** `scripts/TutorialController.gd` + `scripts/TutorialController.tscn`.
- **Responsabilità:** possiede il **contenuto** del tutorial (array `steps`), la UI del popup (struttura/aspect nel `.tscn`, stile tipo choice_value con immagine a sinistra), il **blocco dell'input** (overlay full-screen trasparente che assorbe i click), e le demo "Mostra".
- **Comportamento:**
  - `start_tutorial()` → attiva la modalità, blocca l'input, mostra il primo step.
  - Navigazione: **Prosegui** avanza; sull'ultimo step diventa **Fine** (emette `tutorial_finished`, la scena naviga al menu).
  - "Mostra" nasconde il popup e lancia la demo; a fine demo **ritorna sempre allo stesso step/popup**.
- **Test:** `tests/tutorial_test.gd` + `.tscn`.

### 5. Modalità Tutorial — Fase 1B (demo scriptate deterministiche) — **questa sessione**

Ogni pressione di "Mostra" esegue **solo lo step corrente**, con una demo **completamente deterministica** (identica a ogni ripetizione), P1 sempre il giocatore mostrato, popup reali di scelta aperti durante la demo, e rewind che ripristina esattamente lo stato preparato.

- **Preparazione scenario (`LocalGameEngine.start_scenario(spec)`):** costruisce uno stato di gioco completamente specificato (mani fisse, mazzo pesca con l'ultima carta = prossima pesca, Piatto e metadata overrides) **senza RNG**. Ri-chiamarlo con la stessa spec = **rewind**.
- **`GameController.start_scenario()`:** wrapper che incrementa la generation (invalida async), azzera animazioni/flag e delega al provider.
- **`DebugDemo` (scripted mode):** `start_scripted_demo(scenario)` percorre i segmenti; per ogni azione pilota il flusso UI reale (`_on_card_selected` → `_on_play_pressed` → `_on_value_chosen` / `_on_safe_round_choice_chosen`) così che i popup reali si aprano. Tra un segmento e l'altro applica il rewind (`_next_segment()`).
- **Content (`TutorialController._build_steps()`):** 7 step (0–6). Step 0 = demo breve seeded esistente; step 1–6 usano scenari scriptati:
  - **Step 1 (Incrementi):** P1 con +4/+7/Jolly → demo 1 gioca +7 (Piatto 7), rewind, demo 2 gioca Jolly=5 con popup reale (Piatto 5).
  - **Step 2 (Imbroglio):** gioca Imbroglio, popup reale, valore −7 (15→8).
  - **Step 3 (Gold):** gioca Gold 34 → Piatto 34 + attivazione Giro Sicuro con scelta reale del tipo bloccato.
  - **Step 4 (89/GdV):** gioca 89 → Piatto 89 + Giro di Vantaggio; un CPU mostra la restrizione (solo Incrementi/+11).
  - **Step 5 (+11):** tre casi con rewind tra loro: 1) +11 in GdV → vittoria; 2) +11 su Piatto normale; 3) +11 dopo Gold → trasformazione nella Gold successiva.
  - **Step 6 (Consigli/combo):** sequenza didattica costruita per mostrare combo verso 100 e vittoria esatta con Jolly.
- **Test:** `tests/scripted_demo_test.gd` + `.tscn` (stato iniziale, sequenza per step, rewind, popup reali, riproducibilità).

### File nuovi/modificati (solo UI/engine/demo, non regole)

| File | Ruolo |
|---|---|
| `SplashScreen.tscn` / `SplashScreen.gd` | Animazione logo al primo avvio |
| `MainMenu.tscn` / `MainMenu.gd` | Menu ridisegnato (Gioca/Come si gioca/Esci), gate splash |
| `Main.gd` | Routing tutorial vs partita in `_ready()` |
| `GlobalsUtilities.gd` | Nuovi flag: `splash_shown`, `demoStarted`, `tutorialStarted` |
| `scripts/TutorialController.gd` / `.tscn` | Framework popup + contenuto + demo (Fase 1A+1B) |
| `engine/LocalGameEngine.gd` | `start_scenario(spec)` — preparazione stato deterministica (rewind) |
| `scripts/GameController.gd` | `start_scenario()`; `start_game(player_count, rng=null)` per demo deterministiche |
| `scripts/DebugDemo.gd` | Scripted mode: segmenti, rewind, pilotaggio popup reali |
| `tests/tutorial_test.gd` / `.tscn` | Test modalità tutorial (Fase 1A) |
| `tests/scripted_demo_test.gd` / `.tscn` | Test demo scriptate (Fase 1B) |

### Test eseguiti e risultati (14 settembre 2026)

| Suite | Assert | Esito |
|---|---|---|
| `tests/tutorial_test.gd` | **71** | ✅ 0 FAIL |
| `tests/scripted_demo_test.gd` | **26** | ✅ 0 FAIL (verificato ×10 run) |
| rules_test | 214 | ✅ 0 FAIL |
| provider_test | 93 | ✅ 0 FAIL |
| game_controller_test | 238 | ✅ 0 FAIL |
| demo_verification_test | 9 | ✅ 0 FAIL |

### Problemi aperti / note

- **`demo_integration_test` flaky (preesistente, non da questo lavoro):** esegue partite *casuali* e richiede un vincitore entro 200 turni a partita; con il meccanismo di rimbalzo una partita può occasionalmente superarli. Verificato: codice HEAD e working-tree hanno la stessa frequenza di fallimento (~2/4). Non correlato alle modifiche della sessione (questo test non usa DebugDemo né `start_scenario`). Da sistemare separatamente (es. determinismo o `max_turns_per_game` più alto) se si vuole verde stabile.
- **Tutorial 1C NON implementato:** l'utente ha chiesto di non procedere senza conferma esplicita.
- **Pulsanti Online/Opzioni/Shop/Statistiche** presenti come icone ma non cablati (funzionalità future).

