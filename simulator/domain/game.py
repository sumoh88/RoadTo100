"""Generic game-state abstraction for card-game domains.

This module represents the mutable state of a game session. It contains no
rules, no validation logic, and no game-specific behavior.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Optional

from .card import Card
from .deck import Deck
from .player import Player


class GamePhase(Enum):
    """Generic lifecycle phases for a card-game session."""

    SETUP = "setup"
    PLAYING = "playing"
    FINISHED = "finished"


@dataclass(slots=True)
class Game:
    """Represents the current state of a card-game session.

    Attributes:
        players: The players participating in the game.
        deck: The shared deck available to the game.
        discard_pile: The cards that have been discarded or otherwise removed
            from active play.
        current_player_index: Index of the active player, if any.
        turn_number: Current turn counter.
        phase: Current phase of the game.
        winner: The winning player, if any.
        metadata: Additional arbitrary state for future extensibility.
    """

    players: list[Player] = field(default_factory=list)
    deck: Deck = field(default_factory=Deck)
    discard_pile: list[Card] = field(default_factory=list)
    current_player_index: Optional[int] = None
    turn_number: int = 0
    phase: GamePhase = GamePhase.SETUP
    winner: Optional[Player] = None
    metadata: dict[str, Any] = field(default_factory=dict)

    def add_player(self, player: Player) -> None:
        """Add a player to the game state.

        Args:
            player: The player to add.
        """
        self.players.append(player)

    def add_players(self, players: list[Player]) -> None:
        """Add multiple players to the game state.

        Args:
            players: The players to add.
        """
        self.players.extend(players)

    def current_player(self) -> Optional[Player]:
        """Return the currently active player, if one exists."""
        if self.current_player_index is None:
            return None
        if not 0 <= self.current_player_index < len(self.players):
            return None
        return self.players[self.current_player_index]

    def set_current_player(self, player: Optional[Player]) -> None:
        """Set the current active player by object reference.

        Args:
            player: The player to mark as current, or ``None`` to clear it.
        """
        if player is None:
            self.current_player_index = None
            return
        for index, existing_player in enumerate(self.players):
            if existing_player.player_id == player.player_id:
                self.current_player_index = index
                return

    def set_winner(self, player: Optional[Player]) -> None:
        """Set the winner of the game.

        Args:
            player: The winning player, or ``None`` to clear the winner.
        """
        self.winner = player

    def set_phase(self, phase: GamePhase) -> None:
        """Set the current phase of the game.

        Args:
            phase: The new phase value.
        """
        self.phase = phase
