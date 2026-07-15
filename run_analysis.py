#!/usr/bin/env python3
"""Analyse 20 000 RoadTo100 games, classifying every win by category."""

from __future__ import annotations

import sys
from collections import Counter
from typing import Any

from games.roadto100.setup import build_initial_game
from games.roadto100.actions import RoadTo100ActionController, PLAY_CARD_ACTION
from games.roadto100.rules import RoadTo100RuleSet
from simulator.engine.simulator import Simulator


def classify_win(
    action: Any,
    prev_piatto: int,
    gdv_active: bool,
    gdv_start_piatto: int,
    gdv_adv_player: str | None,
    non_adv_orange_played: bool,
    current_player_id: str | None,
) -> str:
    """Classify a win into one of the six categories (priority order)."""
    card = action.parameters.get("card")
    if card is None:
        return "altri_casi"

    is_plus11 = card.name == "+11"
    card_type = str(card.metadata.get("card_type", "")).lower()
    is_orange = card_type in ("increment", "jolly")

    # Priority 5: non-advantage player wins with +11 during GdV
    if gdv_active and is_plus11 and gdv_adv_player is not None and current_player_id != gdv_adv_player:
        return "plus11_gdv_giocatore_non_in_vantaggio"

    # Priority 1: GdV started from 89 → +11 wins during same GdV
    if gdv_active and is_plus11 and gdv_start_piatto == 89:
        return "89_poi_plus11"

    # Priority 3: +11 played when plateau was 89 (not in above categories)
    if is_plus11 and prev_piatto == 89:
        return "piatto_89_poi_plus11"

    # Priority 2: GdV started from 89, non-adv played orange during it,
    #             advantage player wins with orange card
    if gdv_active and is_orange and gdv_start_piatto == 89 and non_adv_orange_played:
        if gdv_adv_player is not None and current_player_id == gdv_adv_player:
            return "89_poi_arancione"

    # Priority 4: orange card wins from plateau 90-99 (not in above categories)
    if is_orange and 90 <= prev_piatto <= 99:
        return "piatto_90_o_piu_poi_arancione"

    return "altri_casi"


def main() -> None:
    num_games = 20000
    player_count = 4

    ruleset = RoadTo100RuleSet()
    controller = RoadTo100ActionController()

    wins: Counter[str] = Counter()
    gdv_activated_by_89 = 0
    gdv_activated_by_chain = 0
    gdv_ended_without_win = 0

    # Per-simulation tracking
    gdv_active = False
    gdv_adv_player: str | None = None
    gdv_start_piatto = 0
    non_adv_orange_played = False

    for game_idx in range(num_games):
        game = build_initial_game(player_count=player_count)
        ruleset.initialize_game(game)

        # Reset per-game tracking
        gdv_active = False
        gdv_adv_player = None
        gdv_start_piatto = 0
        non_adv_orange_played = False
        prev_winner = None

        while not ruleset.is_game_over(game):
            # --- Detect fresh GdV activation ---
            gdv_now = bool(game.metadata.get("advantage_turn", False))
            if gdv_now and not gdv_active:
                gdv_active = True
                gdv_adv_player = game.metadata.get("advantage_player_id")
                gdv_start_piatto = game.metadata.get("piatto", 0)
                non_adv_orange_played = False

                pc = game.metadata.get("plateau_cards", [])
                if pc:
                    last = pc[-1]
                    if last is not None and last.name == "89":
                        gdv_activated_by_89 += 1
                    elif last is not None and last.name == "+11":
                        gdv_activated_by_chain += 1

            # --- Simulator step ---
            actions = ruleset.get_available_actions(game)
            if not actions:
                break

            action = controller.select_action(game, actions)
            if not ruleset.validate_action(game, action):
                break

            # Capture state BEFORE the action
            prev_piatto = game.metadata.get("piatto", 0)
            current = game.current_player()
            current_id = current.player_id if current is not None else None

            ruleset.apply_action(game, action)

            # --- Detect win ---
            if game.winner is not None and (prev_winner is None or game.winner is not prev_winner):
                cat = classify_win(
                    action,
                    prev_piatto,
                    gdv_active,
                    gdv_start_piatto,
                    gdv_adv_player,
                    non_adv_orange_played,
                    current_id,
                )
                wins[cat] += 1

            # --- Track non-advantage orange plays during GdV ---
            if gdv_active and current_id is not None and current_id != gdv_adv_player:
                card = action.parameters.get("card")
                if card is not None:
                    ct = str(card.metadata.get("card_type", "")).lower()
                    if ct in ("increment", "jolly"):
                        new_piatto = game.metadata.get("piatto", 0)
                        if new_piatto > prev_piatto:
                            non_adv_orange_played = True

            ruleset.advance_turn(game)

            # --- Detect GdV ending ---
            if gdv_active and not bool(game.metadata.get("advantage_turn", False)):
                if game.winner is None or game.winner is prev_winner:
                    gdv_ended_without_win += 1
                gdv_active = False
                gdv_adv_player = None

            prev_winner = game.winner

    # --- Report ---
    total = sum(wins.values())
    print("=== RoadTo100 — Analisi 20 000 partite (4 giocatori) ===\n")
    print("Vittorie per categoria:")
    order = [
        "89_poi_plus11",
        "89_poi_arancione",
        "piatto_89_poi_plus11",
        "piatto_90_o_piu_poi_arancione",
        "plus11_gdv_giocatore_non_in_vantaggio",
        "altri_casi",
    ]
    for cat in order:
        c = wins.get(cat, 0)
        print(f"  {cat}: {c} ({100.0 * c / total:.1f}%)")
    print()
    print(f"  totale: {total}")
    print()
    print("Contatori secondari:")
    print(f"  GdV attivato da carta 89:              {gdv_activated_by_89}")
    print(f"  GdV attivato da sequenza Gold 78→+11:  {gdv_activated_by_chain}")
    print(f"  GdV terminato senza vittoria:          {gdv_ended_without_win}")

    assert total == num_games, f"SOMMA SBAGLIATA: {total} != {num_games}"


if __name__ == "__main__":
    main()
