"""Generic simulator engine for card-game domains.

The simulator coordinates a game session by delegating all gameplay decisions
and state transitions to a game-specific RuleSet implementation. It does not
implement any specific card-game rules and remains completely generic.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Optional

from simulator.domain.action import Action
from simulator.domain.game import Game
from simulator.domain.player import Player
from simulator.domain.ruleset import RuleSet
from .action_controller import ActionController


class SimulationTerminationReason(Enum):
    """Reason why a simulation stopped."""

    VICTORY = "victory"
    MAX_TURNS = "max_turns"
    NO_ACTIONS = "no_actions"
    INVALID_ACTION = "invalid_action"
    ERROR = "error"


@dataclass(slots=True)
class SimulationResult:
    """Represents the outcome of a completed simulation.

    Attributes:
        game: The final state of the simulated game.
        winner: The winning player, if one was determined.
        completed: Whether the simulation reached a terminal state.
        termination_reason: Why the simulation stopped.
        turns_completed: The number of turns processed.
        metadata: Additional extensible data for simulation consumers.
    """

    game: Game
    winner: Optional[Player]
    completed: bool
    termination_reason: SimulationTerminationReason
    turns_completed: int
    metadata: dict[str, Any] = field(default_factory=dict)


class Simulator:
    """Generic engine that runs a card-game simulation through a RuleSet."""

    def __init__(self, ruleset: RuleSet, action_controller: ActionController) -> None:
        """Initialize the simulator with a rule set and an action controller.

        Args:
            ruleset: The rule-set implementation that controls the game flow.
            action_controller: The component that chooses an action from the
                available ones.
        """
        self.ruleset = ruleset
        self.action_controller = action_controller

    def run(self, game: Game, *, max_turns: int = 1000) -> SimulationResult:
        """Run a complete simulation for the provided game state.

        Args:
            game: The game state to simulate.
            max_turns: Maximum number of turns before stopping.

        Returns:
            A result object containing the final state of the simulation.
        """
        self.ruleset.initialize_game(game)

        turns_completed = 0
        completed = False
        winner: Optional[Player] = None
        termination_reason = SimulationTerminationReason.ERROR

        try:
            while turns_completed < max_turns:
                if self.ruleset.is_game_over(game):
                    completed = True
                    termination_reason = SimulationTerminationReason.VICTORY
                    winner = self.ruleset.get_winner(game)
                    break

                actions = self.ruleset.get_available_actions(game)
                if not actions:
                    completed = True
                    termination_reason = SimulationTerminationReason.NO_ACTIONS
                    winner = self.ruleset.get_winner(game)
                    break

                action = self.action_controller.select_action(game, actions)
                if not self.ruleset.validate_action(game, action):
                    completed = False
                    termination_reason = SimulationTerminationReason.INVALID_ACTION
                    break

                self.ruleset.apply_action(game, action)
                self.ruleset.advance_turn(game)
                turns_completed += 1

                if self.ruleset.is_game_over(game):
                    completed = True
                    termination_reason = SimulationTerminationReason.VICTORY
                    winner = self.ruleset.get_winner(game)
                    break

            else:
                completed = True
                termination_reason = SimulationTerminationReason.MAX_TURNS
        except Exception:
            completed = False
            termination_reason = SimulationTerminationReason.ERROR

        return SimulationResult(
            game=game,
            winner=winner,
            completed=completed,
            termination_reason=termination_reason,
            turns_completed=turns_completed,
        )
