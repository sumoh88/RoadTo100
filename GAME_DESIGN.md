# GAME_DESIGN.md

# RoadTo100

## Game Design Document (GDD)

Versione collegata a:

- GAME_RULES.md v1.0

---

# Visione

RoadTo100 è un gioco di carte multiplayer competitivo, veloce e altamente rigiocabile.

L'obiettivo del progetto è creare partite da circa 4-8 minuti, con regole semplici ma decisioni strategiche continue.

Il gioco è pensato principalmente per il multiplayer online.

---

# Filosofia di Design

Il gioco segue alcuni principi fondamentali.

## Regole semplici

Ogni carta deve essere leggibile in pochi secondi.

Le regole devono poter essere spiegate in pochi minuti.

---

## Alta profondità

Le decisioni devono derivare dall'interazione tra:

- valore del Piatto;
- gestione della mano;
- gestione del Mazzo;
- utilizzo delle Carte Gold;
- utilizzo delle Carte Speciali;
- utilizzo del Giro di Vantaggio.

---

## Partite veloci

Le partite devono avere una durata media di circa:

- 2-4 minuti (2 giocatori)
- 4-6 minuti (3 giocatori)
- 6-8 minuti (4 giocatori)

Il gioco è progettato per accelerare naturalmente verso la conclusione grazie al consumo permanente delle Carte Gold.

---

# Identità visiva

Le carte sono suddivise in categorie cromatiche.

## Arancione

Carte Normali

- Carte Incremento
- Carte Jolly

---

## Dorato

Carte Gold

---

## Viola

Carta 89

---

## Rosso

Carta +11

---

## Verde

Carta Imbroglio

---

## Blu

Carte Piatto (virtuali)

---

# Board

La Board contiene esclusivamente tre pile di carte.

1. Piatto
2. Mazzo
3. Scarti

Il Mazzo è l'elemento centrale dell'interfaccia, alla sua sinistra c'è il Piatto, mentre alla destra del Mazzo c'è la pila Scarti

---

# Mano

Ogni giocatore mantiene sempre tre carte.

Le uniche eccezioni sono gestite dalle regole ufficiali.

---

# Flusso della partita

Una partita segue sempre questo ciclo.

1. Inizio partita
2. Turni dei giocatori
3. Gestione del Piatto
4. Gestione del Mazzo
5. Vittoria

Le regole dettagliate sono definite esclusivamente in GAME_RULES.md.

---

# Multiplayer

Versione iniziale:

- Multiplayer online
- Matchmaking automatico
- Bot utilizzati solo se necessario per ridurre i tempi di attesa

Versione finale:

- Solo giocatori reali
- Nessun bot

---

# IA

I bot devono simulare un giocatore reale.

Sono utilizzati esclusivamente per:

- test;
- simulazioni;
- riempimento lobby.

---

# Simulatore

Il progetto comprenderà un simulatore indipendente.

Scopo:

- testare il bilanciamento;
- verificare la durata media;
- analizzare il meta;
- valutare la distribuzione delle vittorie;
- confrontare modifiche alle regole.

Il simulatore non contiene grafica.

---

# Interfaccia

L'interfaccia deve essere minimale.

Priorità:

- leggibilità;
- rapidità;
- chiarezza.

Ispirazioni:

- UNO 
- MTG Arena (layout, non complessità)
- Poker (pulizia grafica)

---

# Obiettivo dello sviluppo

Realizzare un framework riutilizzabile che permetta in futuro di sviluppare facilmente altri giochi di carte online semplicemente sostituendo:

- regole;
- carte;
- effetti.