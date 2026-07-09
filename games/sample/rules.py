"""Rules and action selection for the sample game."""

from __future__ import annotations

from simulator.domain.action import Action
from simulator.domain.game import Game, GamePhase
from simulator.domain.ruleset import RuleSet
from simulator.engine.action_controller import ActionController

from .config import TARGET_SCORE


class SampleRuleSet(RuleSet):
    """A minimal rule set for a two-player score race."""

    def initialize_game(self, game: Game) -> None:
        for player in game.players:
            player.metadata["score"] = 0

        game.metadata["target_score"] = TARGET_SCORE
        game.turn_number = 0
        game.phase = GamePhase.PLAYING
        game.winner = None
        game.discard_pile.clear()

        if game.players:
            game.set_current_player(game.players[0])
        else:
            game.set_current_player(None)

    def get_available_actions(self, game: Game) -> list[Action]:
        if game.phase is not GamePhase.PLAYING or game.current_player() is None:
            return []
        return [Action(action_type="draw_and_play")]

    def validate_action(self, game: Game, action: Action) -> bool:
        return action.action_type == "draw_and_play" and game.current_player() is not None

    def apply_action(self, game: Game, action: Action) -> None:
        current_player = game.current_player()
        if current_player is None:
            return

        card = game.deck.draw()
        if card is None:
            return

        game.discard_pile.append(card)
        score = int(current_player.metadata.get("score", 0))
        if card.value is not None:
            score += card.value
        current_player.metadata["score"] = score

    def advance_turn(self, game: Game) -> None:
        if not game.players:
            return

        if game.current_player_index is None:
            game.current_player_index = 0
        else:
            game.current_player_index = (game.current_player_index + 1) % len(game.players)

        game.set_current_player(game.players[game.current_player_index])

    def is_game_over(self, game: Game) -> bool:
        for player in game.players:
            score = int(player.metadata.get("score", 0))
            if score >= int(game.metadata.get("target_score", TARGET_SCORE)):
                return True
        return False

    def get_winner(self, game: Game):
        for player in game.players:
            score = int(player.metadata.get("score", 0))
            if score >= int(game.metadata.get("target_score", TARGET_SCORE)):
                return player
        return None


class SampleActionController(ActionController):
    """Always choose the only action available in the sample game."""

    def select_action(self, game: Game, available_actions: list[Action]) -> Action:
        if not available_actions:
            return Action(action_type="draw_and_play")
        return available_actions[0]
