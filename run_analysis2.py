#!/usr/bin/env python3
"""Analisi utilizzo carte e azioni."""

from __future__ import annotations

import sys
from typing import Optional

from games.roadto100.setup import build_initial_game
from games.roadto100.actions import RoadTo100ActionController, PLAY_CARD_ACTION, CHANGE_CARD_ACTION, REVEAL_GOLD_ACTION
from games.roadto100.rules import RoadTo100RuleSet


def run(num_games: int, player_count: int) -> None:
    ruleset = RoadTo100RuleSet()
    controller = RoadTo100ActionController()

    inc = jolly = gold = c89 = p11_norm = p11_chain = imbroglio = 0
    change = reveal = 0
    total_cards = 0

    for _ in range(num_games):
        game = build_initial_game(player_count=player_count)
        ruleset.initialize_game(game)

        while not ruleset.is_game_over(game):
            actions = ruleset.get_available_actions(game)
            if not actions:
                break
            action = controller.select_action(game, actions)
            if not ruleset.validate_action(game, action):
                break

            if action.action_type == CHANGE_CARD_ACTION:
                change += 1
                total_cards += 1
            elif action.action_type == REVEAL_GOLD_ACTION:
                reveal += 1
                total_cards += 1
            elif action.action_type == PLAY_CARD_ACTION:
                card = action.parameters.get("card")
                if card is not None:
                    total_cards += 1
                    ct = str(card.metadata.get("card_type", "")).lower()
                    if ct == "increment":
                        inc += 1
                    elif ct == "jolly":
                        jolly += 1
                    elif ct == "gold":
                        gold += 1
                    elif ct == "imbroglio":
                        imbroglio += 1
                    elif ct == "special" and card.name == "89":
                        c89 += 1
                    elif ct == "special" and card.name == "+11":
                        # Distinguish normal +11 from gold-chain +11
                        pc = game.metadata.get("plateau_cards", [])
                        last = pc[-1] if pc else None
                        if last is not None and ruleset._is_gold_card(last):
                            p11_chain += 1
                        else:
                            p11_norm += 1

            ruleset.apply_action(game, action)
            ruleset.advance_turn(game)

    n = num_games
    label = f"g{player_count}"
    print(f"\n=== {label} — {n} partite ===")
    rows = [
        ("Carte Incremento", inc),
        ("Jolly", jolly),
        ("Gold", gold),
        ("Carte 89", c89),
        ("+11 normale", p11_norm),
        ("+11 catena Gold", p11_chain),
        ("Imbroglio", imbroglio),
        ("Cambio Carta", change),
        ("Gold Reveal", reveal),
    ]
    label_w = max(len(r[0]) for r in rows)
    print(f"{'Azione'.ljust(label_w)}  {'Totale':>8}  {'Media/partita':>14}  {'% su carte giocate':>18}")
    print("-" * (label_w + 44))
    for name, count in rows:
        avg = count / n
        pct = 100.0 * count / total_cards if total_cards else 0.0
        print(f"{name.ljust(label_w)}  {count:>8}  {avg:>14.2f}  {pct:>17.1f}%")
    print(f"\n  Totale carte/azioni giocate: {total_cards}")
    print(f"  Media azioni per partita:    {total_cards / n:.1f}")


def main() -> None:
    for arg in [("g2", 10000), ("g3", 10000), ("g4", 10000)]:
        run(arg[1], int(arg[0][1]))


if __name__ == "__main__":
    main()
