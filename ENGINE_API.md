# ENGINE API - riferimento interno del framework

Questo documento descrive l'API attuale del framework di simulazione card-game, con focus su domain ed engine.

Obiettivo:
- fornire un riferimento stabile per le parti considerate congelate;
- mantenere la separazione tra stato, regole, scelta delle azioni e orchestrazione;
- evitare che lo sviluppo dei giochi introduca dipendenze o responsabilità nella parte generica.

## 1. Domain

Il package domain contiene concetti generici, riusabili fra giochi diversi. Non implementa regole di gioco specifiche e non contiene logica di simulazione.

### 1.1 Game

Responsabilità
- rappresentare lo stato corrente di una partita;
- contenere i giocatori, il mazzo, la pila di scarto e il turno attivo;
- tenere traccia di fase e vincitore.

Dati contenuti
- players: lista di Player;
- deck: Deck;
- discard_pile: lista di Card;
- current_player_index: indice del giocatore attivo, se presente;
- turn_number: numero del turno corrente;
- phase: valore di GamePhase;
- winner: Player vincitore, se presente;
- metadata: stato estensibile per future esigenze.

Cosa può modificare
- aggiungere giocatori;
- impostare il giocatore corrente;
- impostare il vincitore;
- cambiare la fase di gioco.

Cosa non deve conoscere
- regole di gioco specifiche;
- validazione di azioni;
- applicazione di effetti;
- criterio di fine partita oltre al semplice stato contenuto.

### 1.2 Player

Responsabilità
- rappresentare un giocatore in una partita generica;
- contenere l'identità del giocatore e le carte attualmente in suo possesso.

Dati contenuti
- player_id: identificatore univoco;
- name: nome visualizzato;
- hand: Hand;
- metadata: stato aggiuntivo estensibile.

Cosa può modificare
- ricevere carte nella mano;
- rimuovere carte dalla mano;
- verificare se possiede una carta;
- pulire la mano.

Cosa non deve conoscere
- il turno della partita;
- la logica delle regole del gioco;
- la scelta dell'azione da compiere.

### 1.3 Card

Responsabilità
- rappresentare una singola carta in modo generico.

Dati contenuti
- card_id: identificatore della carta;
- name: nome leggibile;
- value: valore numerico opzionale;
- color: categoria o colore opzionale;
- metadata: dati aggiuntivi arbitrari.

Cosa può modificare
- il proprio stato interno tramite i suoi attributi;
- eventualmente estendere metadata.

Cosa non deve conoscere
- le regole del gioco;
- il contesto di partita;
- il comportamento di gioco specifico.

### 1.4 Deck

Responsabilità
- contenere e gestire un mazzo di carte in modo generico.

Dati contenuti
- cards: lista di Card.

Cosa può modificare
- aggiungere carte;
- pescare una carta o più carte;
- mescolare;
- svuotare il mazzo.

Cosa non deve conoscere
- il significato semantico di una carta;
- le regole di distribuzione o di utilizzo del mazzo.

### 1.5 Hand

Responsabilità
- contenere le carte attualmente in mano a un giocatore.

Dati contenuti
- cards: lista di Card.

Cosa può modificare
- aggiungere carte;
- rimuovere una carta specifica;
- verificare presenza;
- pulire la mano.

Cosa non deve conoscere
- il significato delle carte;
- l'eventuale vincolo di utilizzo delle carte;
- il flusso di gioco.

### 1.6 Action

Responsabilità
- rappresentare una azione astratta che un giocatore può compiere.

Dati contenuti
- action_type: identificatore generico del tipo di azione;
- parameters: dati arbitrari specifici per l'azione.

Cosa può modificare
- essere creata e interpretata dal livello di gioco specifico.

Cosa non deve conoscere
- come eseguire la propria logica;
- lo stato del gioco completo;
- le regole di validazione.

### 1.7 GamePhase

Responsabilità
- definire gli stati di ciclo di vita di una partita.

Dati contenuti
- valori enumerati: setup, playing, finished.

Cosa può modificare
- essere usato per rappresentare il progresso del gioco.

Cosa non deve conoscere
- logica di transizione complessa;
- regole specifiche del gioco.

## 2. Engine

Il package engine contiene l'orchestrazione del ciclo di simulazione. Non contiene logica di gioco specifica.

### 2.1 Simulator

Ruolo
- eseguire il ciclo di simulazione di una partita tramite un RuleSet e un ActionController;
- coordinare l'ordine delle operazioni senza implementare le regole del gioco.

Dipendenze consentite
- RuleSet;
- ActionController;
- Game, Action, Player;
- eventuali tipi di dominio necessari per il flusso generico.

Dipendenze vietate
- implementare regole di gioco specifiche all'interno del simulatore;
- scegliere l'azione in modo interno senza delegare all'ActionController;
- dipendere da moduli concreti di un gioco specifico.

### 2.2 RuleSet

Ruolo
- definire il contratto delle regole di un gioco specifico;
- esporsi come interfaccia per inizializzazione, azioni disponibili, validazione, applicazione, avanzamento e fine partita.

Dipendenze consentite
- Game;
- Action;
- Player;
- eventuali tipi di dominio specifici del gioco implementato.

Dipendenze vietate
- dipendere direttamente dal Simulator per orchestrare il flusso;
- utilizzare l'ActionController per prendere decisioni di gioco;
- introdurre logica generica nel package engine invece che nel modulo del gioco.

### 2.3 ActionController

Ruolo
- scegliere quale azione eseguire tra quelle offerte dal RuleSet.

Dipendenze consentite
- Game;
- Action;
- elenco delle azioni disponibili.

Dipendenze vietate
- modificare direttamente lo stato di gioco in modo da sostituire la logica di RuleSet;
- implementare meccaniche di gioco specifiche come se fosse una regola del sistema;
- assumere responsabilità di simulazione o avanzamento turno.

### 2.4 SimulationResult

Ruolo
- raccogliere il risultato di una simulazione completata o interrotta.

Dipendenze consentite
- Game;
- Player;
- metadati estensibili.

Dipendenze vietate
- alterare il flusso di gioco;
- sostituire RuleSet o ActionController;
- introdurre nuove regole o observability non richieste dal contratto attuale.

## 3. Flusso di esecuzione

Il ciclo di simulazione attuale è il seguente:

1. Inizializzazione
   - il Simulator invoca RuleSet.initialize_game(game);
   - il gioco viene posto in uno stato pronto per la simulazione.

2. Azioni disponibili
   - il Simulator richiede RuleSet.get_available_actions(game);
   - il risultato è l'insieme delle azioni ammissibili per il turno corrente.

3. Scelta azione
   - il Simulator delega la scelta all'ActionController;
   - l'ActionController seleziona un'azione tra quelle disponibili.

4. Validazione
   - il Simulator richiede RuleSet.validate_action(game, action);
   - se l'azione non è valida, la simulazione termina con motivo di errore o invalid action.

5. Applicazione
   - il Simulator invoca RuleSet.apply_action(game, action);
   - le modifiche di stato vengono applicate dal RuleSet.

6. Avanzamento turno
   - il Simulator invoca RuleSet.advance_turn(game);
   - il flusso di gioco passa al turno successivo.

7. Verifica conclusione
   - il Simulator controlla RuleSet.is_game_over(game);
   - se la partita è terminata, recupera il vincitore tramite RuleSet.get_winner(game).

Il ciclo termina quando:
- la partita raggiunge una condizione di vittoria;
- non ci sono azioni disponibili;
- il numero massimo di turni viene raggiunto;
- un'azione non è valida;
- si verifica un errore di esecuzione.

## 4. Regole di estensione

Le regole di estensione del framework sono le seguenti:

- nuovi giochi devono essere implementati fuori da domain ed engine;
  - il punto di estensione è il modulo specifico del gioco, non il core generico.

- nuove carte e nuove meccaniche appartengono al modulo del gioco;
  - non vanno integrate nel dominio generico salvo estensioni esplicitamente compatibili con il contratto attuale.

- nuove strategie appartengono agli ActionController;
  - la scelta dell'azione è una responsabilità separata dalle regole di gioco.

- domain ed engine devono rimanere astratti e indipendenti da specifiche meccaniche di gioco;
  - ogni gioco concreto deve fornire il proprio RuleSet e, se necessario, i propri ActionController.
