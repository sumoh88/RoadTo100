"""Setup helpers for the sample game."""

from __future__ import annotations

from typing import Tuple

from simulator.domain.game import Game
from simulator.domain.player import Player
from simulator.engine.simulator import Simulator

from .cards import build_numeric_cards
from .config import PLAYER_COUNT, TARGET_SCORE
from .rules import SampleActionController, SampleRuleSet


def build_game() -> Game:
    """Create a minimal two-player game state."""
    players = [Player(player_id=f"player_{index + 1}", name=f"Player {index + 1}") for index in range(PLAYER_COUNT)]
    game = Game(players=players)
    game.deck.add_cards(build_numeric_cards())
    game.deck.shuffle()
    game.metadata["target_score"] = TARGET_SCORE
    return game


def run_sample() -> Tuple[Game, Simulator]:
    """Create and run the sample game through the public engine API."""
    game = build_game()
    ruleset = SampleRuleSet()
    controller = SampleActionController()
    simulator = Simulator(ruleset, controller)
    simulator.run(game, max_turns=50)
    return game, simulator
