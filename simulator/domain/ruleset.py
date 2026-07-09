"""Abstract rule-set contract for card-game implementations.

This module defines the generic interface that game-specific rule implementations
must satisfy. It contains no concrete logic and is intentionally reusable for
any card game.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Optional

from .action import Action
from .game import Game
from .player import Player


class RuleSet(ABC):
    """Abstract contract for game-specific rule handling.

    Implementations are responsible for initializing the game, exposing the
    available actions, validating and applying actions, advancing the game
    flow, and determining whether the game is over and who has won.
    """

    @abstractmethod
    def initialize_game(self, game: Game) -> None:
        """Initialize the game state before the main simulation loop begins."""

    @abstractmethod
    def get_available_actions(self, game: Game) -> list[Action]:
        """Return the actions currently available to the active player."""

    @abstractmethod
    def validate_action(self, game: Game, action: Action) -> bool:
        """Return whether the provided action is valid in the given game state."""

    @abstractmethod
    def apply_action(self, game: Game, action: Action) -> None:
        """Apply the effects of a validated action to the game state."""

    @abstractmethod
    def advance_turn(self, game: Game) -> None:
        """Advance the game flow after an action has been processed."""

    @abstractmethod
    def is_game_over(self, game: Game) -> bool:
        """Return whether the game has reached a terminal state."""

    @abstractmethod
    def get_winner(self, game: Game) -> Optional[Player]:
        """Return the winning player, if any."""
