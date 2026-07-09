# TODO.md

# RoadTo100

Roadmap ufficiale del progetto.

---

# Fase 0 — Preparazione

- [ ] Creazione repository Git
- [ ] Configurazione Godot 3.4.4
- [ ] Configurazione VSCode
- [ ] Configurazione Continue
- [ ] Struttura cartelle progetto

---

# Fase 1 — Motore di gioco

## Carte

- [ ] Classe Card
- [ ] Enumerazione tipi carta
- [ ] Sistema effetti
- [ ] Sistema colori

---

## Mazzo

- [ ] Deck
- [ ] Shuffle
- [ ] Draw
- [ ] Discard
- [ ] Gestione esaurimento Mazzo

---

## Piatto

- [ ] Valore corrente
- [ ] Gestione Carte Gold
- [ ] Gestione Carta 89
- [ ] Gestione Carte Piatto
- [ ] Storico del Piatto

---

## Mano

- [ ] Mano giocatore
- [ ] Pesca
- [ ] Giocata
- [ ] Cambio carta
- [ ] Controllo Gold duplicate del Piatto

---

## Regole

Implementare tutte le regole presenti in GAME_RULES.md.

Nessuna regola deve essere duplicata in altri documenti.

---

# Fase 2 — Multiplayer

- [ ] Server
- [ ] Lobby
- [ ] Matchmaking
- [ ] Sincronizzazione stato
- [ ] Gestione turni
- [ ] Validazione mosse lato server

---

# Fase 3 — Interfaccia

## Board

- [ ] Piatto
- [ ] Mazzo
- [ ] Scarti

---

## Mano

- [ ] Carte
- [ ] Hover
- [ ] Click
- [ ] Drag

---

## Giocatori

- [ ] Avatar
- [ ] Nome
- [ ] Numero carte

---

## Animazioni

- [ ] Pesca
- [ ] Giocata
- [ ] Cambio carta
- [ ] Vittoria

---

# Fase 4 — Simulatore

Creare un simulatore completamente separato dal gioco.

Statistiche da raccogliere:

- [ ] Durata media partita
- [ ] Numero medio turni
- [ ] Vittorie con 89
- [ ] Vittorie con +11
- [ ] Vittorie normali
- [ ] Utilizzo Carte Gold
- [ ] Utilizzo Imbroglio
- [ ] Utilizzo Cambio Carta
- [ ] Frequenza rimescolamento Mazzo

Simulare:

- [ ] 2 giocatori
- [ ] 3 giocatori
- [ ] 4 giocatori

---

# Fase 5 — IA

Bot per:

- [ ] simulazioni
- [ ] test automatici
- [ ] riempimento lobby

Livelli IA:

- [ ] casuale
- [ ] base
- [ ] avanzata

---

# Fase 6 — Rifinitura

- [ ] Effetti sonori
- [ ] Musica
- [ ] Opzioni
- [ ] Profilo giocatore
- [ ] Statistiche
- [ ] Leaderboard
- [ ] Match history

---

# Versione 1.0

Obiettivo:

Una versione completa e stabile del gioco multiplayer online con tutte le regole presenti in GAME_RULES.md.