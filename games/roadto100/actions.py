"""Action definitions for the RoadTo100 game skeleton."""

from simulator.domain.action import Action
from simulator.domain.game import Game
from simulator.engine.action_controller import ActionController


class RoadTo100Action(Action):
    """Concrete action wrapper for RoadTo100."""

    pass


PLAY_CARD_ACTION = "play_card"
CHANGE_CARD_ACTION = "change_card"
REVEAL_GOLD_ACTION = "reveal_gold"
RESET_HAND_ACTION = "reset_hand"


class RoadTo100ActionController(ActionController):
    """Choose the first available increment-card action."""

    def select_action(self, game: Game, available_actions: list[Action]) -> Action:
        if not available_actions:
            return RoadTo100Action(action_type=PLAY_CARD_ACTION)
        return available_actions[0]
