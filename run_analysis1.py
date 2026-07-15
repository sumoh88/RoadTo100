#!/usr/bin/env python3
"""Analisi vittorie speciali — categorie prioritarie."""

from __future__ import annotations

import sys
from collections import Counter
from typing import Optional

from games.roadto100.setup import build_initial_game
from games.roadto100.actions import RoadTo100ActionController
from games.roadto100.rules import RoadTo100RuleSet


def classify(action, prev_piatto, gdv_active, gdv_start, gdv_adv, non_adv_orange, cur_id):
    card = action.parameters.get("card")
    if card is None:
        return "altri_casi"
    is_plus11 = card.name == "+11"
    ct = str(card.metadata.get("card_type", "")).lower()
    is_orange = ct in ("increment", "jolly")

    if gdv_active and is_plus11 and gdv_adv is not None and cur_id != gdv_adv:
        return "plus11_gdv_giocatore_non_in_vantaggio"
    if gdv_active and is_plus11 and gdv_start == 89:
        return "89_poi_plus11"
    if is_plus11 and prev_piatto == 89:
        return "piatto_89_poi_plus11"
    if gdv_active and is_orange and gdv_start == 89 and non_adv_orange and gdv_adv is not None and cur_id == gdv_adv:
        return "89_poi_arancione"
    if is_orange and 90 <= prev_piatto <= 99:
        return "piatto_90_o_piu_poi_arancione"
    return "altri_casi"


def run(num_games: int, player_count: int) -> None:
    ruleset = RoadTo100RuleSet()
    controller = RoadTo100ActionController()

    wins: Counter[str] = Counter()
    gdv89 = gdvchain = gdvnowin = 0

    for _ in range(num_games):
        game = build_initial_game(player_count=player_count)
        ruleset.initialize_game(game)
        gdv_active = gdv_adv = gdv_start = False  # type: ignore[assignment]
        non_adv_orange = False
        prev_winner = None

        while not ruleset.is_game_over(game):
            gdv_now = bool(game.metadata.get("advantage_turn", False))
            if gdv_now and not gdv_active:
                gdv_active = True
                gdv_adv = game.metadata.get("advantage_player_id")
                gdv_start = game.metadata.get("piatto", 0)
                non_adv_orange = False
                pc = game.metadata.get("plateau_cards", [])
                if pc:
                    last = pc[-1]
                    if last is not None and last.name == "89":
                        gdv89 += 1
                    elif last is not None and last.name == "+11":
                        gdvchain += 1

            actions = ruleset.get_available_actions(game)
            if not actions:
                break
            action = controller.select_action(game, actions)
            if not ruleset.validate_action(game, action):
                break

            prev_piatto = game.metadata.get("piatto", 0)
            cur = game.current_player()
            cur_id = cur.player_id if cur is not None else None

            ruleset.apply_action(game, action)

            if game.winner is not None and (prev_winner is None or game.winner is not prev_winner):
                cat = classify(action, prev_piatto, gdv_active, gdv_start, gdv_adv, non_adv_orange, cur_id)
                wins[cat] += 1

            if gdv_active and cur_id is not None and cur_id != gdv_adv:
                c = action.parameters.get("card")
                if c is not None and str(c.metadata.get("card_type", "")).lower() in ("increment", "jolly"):
                    if game.metadata.get("piatto", 0) > prev_piatto:
                        non_adv_orange = True

            ruleset.advance_turn(game)

            if gdv_active and not bool(game.metadata.get("advantage_turn", False)):
                if game.winner is None or game.winner is prev_winner:
                    gdvnowin += 1
                gdv_active = False
                gdv_adv = None

            prev_winner = game.winner

    total = sum(wins.values())
    label = f"g{player_count}"
    print(f"\n=== {label} — {num_games} partite ===")
    order = ["89_poi_plus11", "89_poi_arancione", "piatto_89_poi_plus11",
             "piatto_90_o_piu_poi_arancione", "plus11_gdv_giocatore_non_in_vantaggio", "altri_casi"]
    for cat in order:
        c = wins.get(cat, 0)
        print(f"  {cat}: {c} ({100*c/total:.1f}%)")
    print(f"  totale: {total}")
    print(f"  GdV da 89: {gdv89}  |  GdV da catena: {gdvchain}  |  GdV senza vittoria: {gdvnowin}")


def main() -> None:
    for arg, games in [("g2", 10000), ("g3", 10000)]:
        run(games, int(arg[1]))


if __name__ == "__main__":
    main()
