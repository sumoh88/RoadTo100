# RoadTo100 architecture proposal

Questa proposta definisce la struttura modulare del gioco RoadTo100 usando esclusivamente le API pubbliche di domain ed engine.

## Principio generale

Tutto il codice di RoadTo100 resta sotto games/roadto100. Il framework non viene toccato.

## Moduli proposti

### 1. config.py
Responsabilità
- contenere i parametri statici del gioco: numero di giocatori supportati, soglia di vittoria, dimensione del mazzo, valori di configurazione del turno.

Dipendenze consentite
- nessuna dipendenza dal framework oltre ai tipi standard di Python.

Dati gestiti
- costanti di gioco, valori limite, liste di carte base.

Logica contenuta
- nessuna logica di gioco; solo configurazione.

### 2. cards.py
Responsabilità
- definire le carte del gioco e il loro contenuto semantico.

Dipendenze consentite
- simulator.domain.card.Card.

Dati gestiti
- descrizione delle carte: id, nome, valore, colore, metadata.

Logica contenuta
- costruzione delle carte del mazzo di RoadTo100;
- eventuale classificazione delle carte per tipo.

### 3. actions.py
Responsabilità
- definire il modello delle azioni del gioco in modo esplicito.

Dipendenze consentite
- simulator.domain.action.Action.

Dati gestiti
- azioni come play_card, change_card, reveal_gold, pass, ecc.

Logica contenuta
- nessuna esecuzione; solo rappresentazione delle azioni possibili.

### 4. rules.py
Responsabilità
- contenere il RuleSet concreto di RoadTo100.

Dipendenze consentite
- simulator.domain.action.Action;
- simulator.domain.game.Game;
- simulator.domain.player.Player;
- simulator.domain.ruleset.RuleSet;
- eventuali tipi di supporto locali del gioco.

Dati gestiti
- stato di gioco specifico: piatto, mano dei giocatori, giro di vantaggio, carte gold sul piatto, mazzo e scarti.

Logica contenuta
- inizializzazione della partita;
- elenco delle azioni disponibili;
- validazione delle azioni;
- applicazione delle azioni;
- avanzamento del turno;
- controllo di vittoria.

### 5. setup.py
Responsabilità
- costruire lo stato iniziale della partita.

Dipendenze consentite
- simulator.domain.game.Game;
- simulator.domain.player.Player;
- simulator.domain.deck.Deck;
- simulator.domain.card.Card;
- i moduli locali del gioco come cards.py e config.py.

Dati gestiti
- giocatori, mazzo iniziale, stato iniziale del gioco.

Logica contenuta
- creazione dei giocatori;
- distribuzione iniziale delle carte;
- preparazione del mazzo e del gioco.

### 6. helpers.py
Responsabilità
- raccogliere funzioni di supporto usate da più parti del gioco.

Dipendenze consentite
- simulator.domain.* solo se strettamente necessarie;
- moduli locali del gioco.

Dati gestiti
- funzioni pure di utilità per il gioco.

Logica contenuta
- operazioni di supporto come reset del mazzo, rimescolamento, gestione del piatto, ordinamento di carte, calcolo di valori possibili.

### 7. __init__.py
Responsabilità
- esporre i punti di ingresso principali del modulo roadto100.

Dipendenze consentite
- moduli locali del gioco.

Dati gestiti
- nessuno.

Logica contenuta
- nessuna; solo import pubblici.

## Separazione suggerita

- config.py: dati statici e costanti;
- cards.py: definizione del mazzo e delle carte;
- actions.py: modello delle azioni;
- rules.py: regole e comportamento del gioco;
- setup.py: stato iniziale della partita;
- helpers.py: funzioni ausiliarie condivise.

## Verifica finale

Ogni responsabilità proposta appartiene al gioco RoadTo100 e non al framework core. Non viene introdotta alcuna logica nel framework, e non viene usato alcun meccanismo non previsto dall’API pubblica di domain ed engine.
