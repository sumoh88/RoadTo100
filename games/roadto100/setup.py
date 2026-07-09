"""Initial game setup helpers for RoadTo100."""

from __future__ import annotations

from simulator.domain.game import Game
from simulator.domain.player import Player

from .cards import build_deck
from .config import DEFAULT_PLAYER_COUNT
from .rules import RoadTo100RuleSet


def build_initial_game(player_count: int = DEFAULT_PLAYER_COUNT) -> Game:
    """Create an initial game state for RoadTo100."""
    players = [Player(player_id=f"player_{index + 1}", name=f"Player {index + 1}") for index in range(player_count)]
    game = Game(players=players)
    game.deck.add_cards(build_deck())
    ruleset = RoadTo100RuleSet()
    ruleset.initialize_game(game)
    return game
