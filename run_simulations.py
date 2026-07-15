#!/usr/bin/env python3
"""Minimal script to run multiple RoadTo100 simulations."""

from __future__ import annotations

import sys
from collections import Counter
from statistics import mean

from games.roadto100.setup import build_initial_game
from games.roadto100.actions import RoadTo100ActionController
from games.roadto100.rules import RoadTo100RuleSet
from simulator.engine.simulator import Simulator


def main() -> None:
    if len(sys.argv) != 3:
        print("Usage: python3 run_simulations.py <g2|g3|g4> <num_games>")
        sys.exit(1)

    player_arg = sys.argv[1]
    if player_arg == "g2":
        player_count = 2
    elif player_arg == "g3":
        player_count = 3
    elif player_arg == "g4":
        player_count = 4
    else:
        print("Invalid player count. Use g2, g3, or g4.")
        sys.exit(1)

    try:
        num_games = int(sys.argv[2])
    except ValueError:
        print("Invalid number of games.")
        sys.exit(1)

    ruleset = RoadTo100RuleSet()
    controller = RoadTo100ActionController()

    total = 0
    completed = 0
    not_completed = 0
    wins: Counter[str] = Counter()
    turns: list[int] = []
    reasons: Counter[str] = Counter()
    plateaus: list[int] = []

    for _ in range(num_games):
        game = build_initial_game(player_count=player_count)
        sim = Simulator(ruleset, controller)
        result = sim.run(game)

        total += 1
        turns.append(result.turns_completed)
        plateaus.append(result.game.metadata.get("piatto", 0))

        if result.completed:
            completed += 1
        else:
            not_completed += 1

        reasons[result.termination_reason.value] += 1

        if result.winner is not None:
            wins[result.winner.name] += 1

    print("--- RoadTo100 Simulation Report ---")
    print(f"Giocatori:          {player_count}")
    print(f"Partite totali:     {total}")
    print(f"Completate:         {completed}")
    print(f"Non completate:     {not_completed}")
    print()
    print("Vittorie per giocatore:")
    for player_name, count in wins.most_common():
        print(f"  {player_name}: {count} ({100.0 * count / total:.1f}%)")
    print()
    print(f"Turni:              media={mean(turns):.1f}  min={min(turns)}  max={max(turns)}")
    print(f"Piatto finale medio: {mean(plateaus):.1f}")
    print()
    print("Motivi di terminazione:")
    for reason, count in reasons.most_common():
        print(f"  {reason}: {count} ({100.0 * count / total:.1f}%)")


if __name__ == "__main__":
    main()
