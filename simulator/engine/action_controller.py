"""Action selection abstraction for the simulator engine.

This module defines the interface for components that choose which action to
execute from the set of actions offered by a RuleSet.
"""

from __future__ import annotations

from abc import ABC, abstractmethod

from simulator.domain.action import Action
from simulator.domain.game import Game


class ActionController(ABC):
    """Abstract component responsible for selecting an action for a turn."""

    @abstractmethod
    def select_action(self, game: Game, available_actions: list[Action]) -> Action:
        """Select one action from the list of available actions.

        Args:
            game: The current game state.
            available_actions: The actions currently available to the controller.

        Returns:
            The action to execute.
        """
