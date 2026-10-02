# RoadTo100 --- Stato Progetto

> Stato compatto per future sessioni di sviluppo.\
> Le regole di gioco sono definite in `GAME_RULES.md`; questo file
> descrive lo stato tecnico corrente.

------------------------------------------------------------------------

## 1. Ambiente

-   Engine: **Godot 3.4.4**
-   Progetto: `roadTo100`
-   Main scene: `res://MainMenu.tscn`
-   Scena partita/tutorial: `res://Main.tscn`
-   Font principale: `res://fonts/Dyuthi.ttf`
-   Simulatore Python: completato e congelato; il client Godot è la
    codebase attiva.
-   Android: export funzionante; APK testato su Android 14.
-   Godot 3.4.4 + Android target 36: APK costruito con SDK Android
    locale e Gradle/AGP aggiornati manualmente.

### Fonti autoritative

1.  `GAME_RULES.md` --- regole di gioco.
2.  `PROJECT_STATE.md` --- stato tecnico corrente.
3.  Codice reale --- fonte primaria quando la documentazione non
    coincide con il comportamento.

### Vincoli di sviluppo

-   Prima di modificare codice verificare il codice reale.
-   Patch minima.
-   Nessun refactoring non richiesto.
-   Non modificare regole/AI/architettura per risolvere problemi
    puramente UI.
-   Aggiungere solo i test strettamente necessari.
-   Aggiornare la documentazione solo quando richiesto o quando serve a
    mantenere lo stato corrente.
-   Per Qwen/Continue usare prompt brevi e mirati; una
    modifica/investigazione alla volta.

------------------------------------------------------------------------

## 2. Architettura corrente

### Domain / engine

-   `engine/GameConstants.gd`
-   `engine/CardData.gd`
-   `engine/Deck.gd`
-   `engine/Hand.gd`
-   `engine/PlayerData.gd`
-   `engine/GameState.gd`
-   `engine/CardDatabase.gd`
-   `engine/RoadTo100Rules.gd`
-   `engine/LocalGameEngine.gd`
-   `engine/RoadTo100AI.gd`

### Controller / presentation

-   `scripts/GameController.gd`
-   `scripts/BoardPresenter.gd`
-   `scripts/HandPresenter.gd`
-   `scripts/TurnPresenter.gd`
-   `scripts/CardAnimator.gd`
-   `scripts/ManualGame.gd`
-   `scripts/DebugDemo.gd`
-   `scripts/TutorialController.gd`
-   `scripts/ShadowFactory.gd`

### Singleton

-   `GlobalsUtilities.gd`
-   `AudioManager.gd`

`AudioManager` e `GlobalsUtilities` sono autoload.

------------------------------------------------------------------------

## 3. Gameplay corrente

### Modalità

-   Single-player: **1 umano + 3 CPU**, funzionante.
-   CPU: player_2 bilanciata, player_3 aggressiva, player_4
    tattica/prudente.
-   Multiplayer: non implementato.
-   RemoteGameAdapter: architettura futura.

### Regole principali

Le regole complete sono in `GAME_RULES.md`. Non duplicarle qui.

Stato importante: - mazzo: 60 carte; - `allow89`: 89 bloccata fino a
Piatto ≥ 30; - +11 / Gold chain / 89 / GdV / GS implementati; - reset
mano disponibile solo nel GdV quando non ci sono carte giocabili; -
`reset_hand` utilizzabile una volta per turno; - **stato corrente
richiesto:** durante GdV il `change_card` deve essere disabilitato;
`reset_hand` resta disponibile; - bounce e vittoria seguono
`GAME_RULES.md`; - Jolly/Imbroglio usano le `choices` provenienti
dall'engine.

### AI

`RoadTo100AI.gd` è score-based e usa le azioni realmente disponibili.

Pesi correnti documentati nel codice: - vittoria immediata: 10000 -
avanzamento: 100 - rischio Piatto: 25 - Jolly: 15 - Gold/GS: 60 - Gold
chain +11: 70 - +11 normale: 40 - hold-back +11: -75 - Imbroglio: 25 -
GdV: 30 - cambio carta: -10 - tie-break jitter: 5

Non modificare questi pesi senza una richiesta specifica.

------------------------------------------------------------------------

## 4. UI e flusso principale

### MainMenu

`MainMenu.tscn` è il menu principale.

Funzionali: - Gioca - Come si gioca - Opzioni - Statistiche - Esci

Non ancora implementati: - Online - Negozio

### SplashScreen

`res://SplashScreen.tscn`.

-   Mostrata solo al primo avvio tramite
    `GlobalsUtilities.splash_shown`.
-   Logo con fade-in/display/fade-out.
-   Dopo lo splash → MainMenu.
-   Non modificare il main scene/root hierarchy senza necessità.

### Main

`Main.tscn` viene usata sia per la partita sia per il tutorial.

`Main.gd` decide il flusso tramite: - `tutorialStarted` - `gameStarted`

Il pulsante Nuova Partita può riutilizzare la stessa istanza di
`BoardPresenter`; questo è importante per il lifecycle del jitter del
DrawPile.

------------------------------------------------------------------------

## 5. Tutorial

Framework e demo deterministiche già implementati.

-   `TutorialController.tscn/.gd`
-   overlay bloccante;
-   popup con navigazione;
-   `Mostra` esegue solo lo step corrente;
-   demo deterministiche con rewind;
-   popup reali per le scelte;
-   test tutorial e scripted demo presenti.

Step già implementati nel framework: - Incrementi/Jolly - Imbroglio -
Gold / Giro Sicuro - 89 / Giro di Vantaggio - +11 - combo/consigli

**Tutorial 1C: NON procedere senza approvazione esplicita dell'utente.**

Contenuti tutorial da localizzare/raffinare possono ancora richiedere
lavoro.

------------------------------------------------------------------------

## 6. Statistiche, traguardi e post-partita

Completati:

-   `Stats.tscn` / `Stats.gd`
-   statistiche persistenti;
-   23 traguardi;
-   notifiche unlock FIFO;
-   Game Over popup;
-   serie corrente/migliore;
-   vittorie;
-   Giri Sicuri/Vantaggio;
-   salvataggio tramite `ConfigFile`.

Fonte unica dei traguardi: array `achievements` in `Stats.gd`.

I nomi/descrizioni attuali sono quelli presenti nel codice; non
ripristinare le vecchie liste storiche.

------------------------------------------------------------------------

## 7. Localizzazione

Sistema IT/EN completato e verificato.

-   `TranslationServer`
-   `translations/test.csv`
-   risorse `.translation`
-   cambio lingua senza riavvio;
-   lingua persistente;
-   63 chiavi attualmente verificate;
-   vecchi `.po` eliminati.

Da tenere presente: - alcuni contenuti tutorial successivi possono
ancora essere hardcoded; - nomi/descrizioni dei traguardi sono dati
nell'array di `Stats.gd`, non tradotti automaticamente.

------------------------------------------------------------------------

## 8. Salvataggio / Opzioni

`OptionMenu.tscn/.gd`.

Persistono: - lingua; - fullscreen; - volume musica; - volume SFX; -
statistiche; - traguardi.

`GlobalsUtilities.SaveData()` / `LoadSavedData()` usano `ConfigFile`.

Problema storico "delete data" da non considerare risolto
automaticamente: se viene nuovamente investigato, verificare il
comportamento reale dopo riavvio dell'app.

------------------------------------------------------------------------

## 9. Audio

`AudioManager.gd/.tscn`.

Stem: - Beat - Piano - Cello - Violin - Trumpet

SFX: - Select - ShuffleDeal - Draw - PlayCard - Victory

### Android

Il caricamento delle canzoni **non deve usare runtime directory
scanning**.

`_load_random_song()` usa un elenco esplicito `song_folders` e
`load("res://...")`.

Attualmente: - `CardTrickLoop` è la canzone disponibile. - Per
aggiungere una canzone: nuova cartella con i 5 stem + nome nell'elenco
esplicito.

Questo approccio è necessario perché l'enumerazione delle risorse
`res://` impacchettate nell'APK non è affidabile in questo contesto.

------------------------------------------------------------------------

## 10. Rendering: ombre, pile e fan CPU

### ShadowFactory

`ShadowFactory.gd` usa un `ColorRect` con shader SDF per un'ombra
rettangolare arrotondata.

-   una sola ombra per Mazzo;
-   una sola ombra per Piatto;
-   una sola ombra per Scarti;
-   una per ogni carta coperta CPU;
-   nessuna ombra sulla mano P1.

### BoardPresenter

-   Piatto e Scarti hanno jitter leggero e ordinato;
-   fan CPU con carta centrale dritta e laterali ruotate;
-   Scarti renderizzati come stack;
-   DrawPile deve rimanere ordinato e con jitter molto leggero.

### DrawPile --- stato attuale

L'utente ha modificato manualmente il jitter delle carte coperte in:

``` gdscript
cb.rect_rotation = rand_range(-1.0, 1.0)
cb.rect_position = Vector2(
    rand_range(-2.0, 2.0),
    rand_range(-2.0, 2.0)
)
```

Questa modifica funziona quando si entra da MainMenu → Gioca.

Problema ancora in lavorazione: - premendo Nuova Partita da `Main.tscn`,
il DrawPile non viene randomizzato nuovamente; - le righe sono
attualmente chiamate da `_ready()` di `BoardPresenter.gd`; - serve
rigenerare il jitter a ogni nuova partita senza ricreare inutilmente il
presenter.

------------------------------------------------------------------------

## 11. Animazione dealing --- lavoro corrente

Qwen ha già implementato una prima versione in `GameController.gd`.

Stato della prima implementazione: - animazione cardback dal DrawPile; -
uso dell'architettura `CardAnimationLayer`; - fallback headless; -
durata iniziale circa 4 s; - problema: troppo lenta; - problema: le mani
non mostrano progressivamente le carte durante il deal.

### Comportamento desiderato

-   tutte le mani partono graficamente da 0;
-   il primo giocatore animato è **sempre il giocatore attualmente di
    turno**, non necessariamente P1;
-   il deal visivo può essere organizzato a blocchi per giocatore: 3
    carte una alla volta al giocatore corrente, poi al successivo, ecc.;
-   dopo ogni carta la mano grafica deve passare progressivamente
    0→1→2→3;
-   l'ordine/contenuto reale del deal non deve cambiare;
-   animazione breve ma chiaramente visibile;
-   al termine la UI deve coincidere con lo snapshot reale;
-   mantenere il fallback headless e le protezioni contro Nuova Partita
    durante un'animazione.

Non modificare le regole del deal per ottenere questo effetto.

------------------------------------------------------------------------

## 12. Protezione Nuova Partita / animazioni

È presente un sistema di Game Generation ID.

-   `GameController` incrementa `_game_generation` a ogni nuova partita;
-   le operazioni asincrone verificano la generazione dopo i `yield`;
-   `CardAnimator.cancel()` invalida animazioni obsolete;
-   `ManualGame` e `DebugDemo` ignorano timer appartenenti a una
    generazione precedente;
-   esiste protezione contro una vecchia animazione/deal che modifica la
    nuova partita.

Non rimuovere questa protezione.

------------------------------------------------------------------------

## 13. Test attuali rilevanti

Ultimi valori verificati nel lavoro recente:

  -----------------------------------------------------------------------
  Suite                                                             Esito
  ------------------------------ ----------------------------------------
  Python rules + AI                                                 93/93

  `rules_test`                       214 assert, 0 FAIL prima dell'ultima
                                   modifica GdV; dopo l'aggiunta del test
                                   change-card la suite va verificata nel
                                                          nuovo conteggio

  `provider_test`                                              93, 0 FAIL

  `presenter_test`                                             86, 0 FAIL

  `board_test`                                                 41, 0 FAIL

  `game_controller_test`                                      238, 0 FAIL

  `shadow_integration_test`                                    20, 0 FAIL

  `fan_geometry_test`                                           7, 0 FAIL

  `tutorial_test`                 verificato durante la fase tutorial, da
                                     riallineare se il contenuto tutorial
                                                                   cambia

  `scripted_demo_test`            verificato durante la fase tutorial, da
                                     riallineare se il contenuto tutorial
                                                                   cambia

  `manual_game_test`                                **26 assert, 0 FAIL**

  `manual_game_smoke`                                                PASS
  -----------------------------------------------------------------------

Nota: i conteggi devono essere aggiornati quando una suite viene
modificata; non usare vecchi totali storici come stato corrente.

------------------------------------------------------------------------

## 14. Problemi / attività aperte

### Priorità attuale

1.  **Completare/correggere il dealing iniziale**
    -   mani grafiche da 0;
    -   carte che compaiono progressivamente;
    -   primo giocatore = giocatore di turno;
    -   animazione più rapida.
2.  **Correggere il reset del jitter DrawPile**
    -   randomizzazione a ogni nuova partita;
    -   deve funzionare anche con Nuova Partita dalla stessa
        `Main.tscn`;
    -   non ricreare il presenter.
3.  **Tutorial**
    -   non procedere a Tutorial 1C senza approvazione;
    -   rifinire/localizzare i contenuti quando richiesto.
4.  **Release / UX**
    -   verifiche finali;
    -   eventuali miglioramenti grafici/audio;
    -   Online e Negozio restano futuri.

### Pulizia non urgente

-   `set_reset_hand_refused()` in `LocalGameEngine.gd` e mock è residuo
    inattivo della vecchia logica GdV. Rimuoverlo solo con richiesta
    esplicita o durante una pulizia dedicata.
-   Warning `ObjectDB instances leaked at exit` nei test: noto, non
    blocca le suite.
-   Warning storico CardAnimator sui delay negativi: non considerarlo
    una priorità finché non viene verificato sul codice corrente.

------------------------------------------------------------------------

## 15. Regole operative per future sessioni

Quando si apre una nuova sessione Qwen:

1.  leggere `PROJECT_STATE.md`;
2.  leggere `GAME_RULES.md` se la modifica coinvolge il gameplay;
3.  verificare il codice reale prima di proporre una soluzione;
4.  modificare solo ciò che è richiesto;
5.  mantenere compatibilità Godot 3.4.4;
6.  eseguire solo i test pertinenti;
7.  riportare file modificati, test e incongruenze;
8.  fermarsi.

Non trasformare problemi UI in modifiche al domain/engine se non
necessario.
