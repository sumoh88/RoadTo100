"""RuleSet skeleton for RoadTo100."""

from __future__ import annotations

from typing import Optional

from simulator.domain.action import Action
from simulator.domain.card import Card
from simulator.domain.game import Game, GamePhase
from simulator.domain.player import Player
from simulator.domain.ruleset import RuleSet

from .actions import CHANGE_CARD_ACTION, PLAY_CARD_ACTION, RESET_HAND_ACTION, REVEAL_GOLD_ACTION, RoadTo100Action
from .config import INITIAL_HAND_SIZE, TARGET_SCORE


class RoadTo100RuleSet(RuleSet):
    """RuleSet for RoadTo100 implementing increment cards and Jolly cards."""

    @staticmethod
    def _is_jolly_card(card: Card) -> bool:
        """Return whether the provided card is a Jolly card."""
        return str(card.metadata.get("card_type", "")).lower() == "jolly" or card.name.lower() == "jolly"

    @staticmethod
    def _is_gold_card(card: Card) -> bool:
        """Return whether the provided card is a Gold card."""
        return str(card.metadata.get("card_type", "")).lower() == "gold" or card.name.lower() in {"12", "23", "34", "45", "56", "67", "78"}

    @staticmethod
    def _is_imbroglio_card(card: Card) -> bool:
        """Return whether the provided card is an Imbroglio card."""
        return str(card.metadata.get("card_type", "")).lower() == "imbroglio" or card.name.lower() == "imbroglio"

    @staticmethod
    def _is_special_89_card(card: Card) -> bool:
        """Return whether the provided card is the 89 special card."""
        return str(card.metadata.get("card_type", "")).lower() == "special" and card.name == "89"

    @staticmethod
    def _is_plus11_card(card: Card) -> bool:
        """Return whether the provided card is the +11 special card."""
        return str(card.metadata.get("card_type", "")).lower() == "special" and card.name == "+11"

    def _matching_gold_card(self, player: Player, plateau_value: int) -> Optional[Card]:
        """Return a matching Gold card from the player's hand, if present."""
        for card in player.hand.cards:
            if self._is_gold_card(card) and card.value == plateau_value:
                return card
        return None

    def initialize_game(self, game: Game) -> None:
        """Initialize the game state for a new match."""
        game.phase = GamePhase.PLAYING
        game.winner = None
        game.turn_number = 0
        game.discard_pile.clear()
        game.metadata["piatto"] = 0
        game.metadata["plateau_cards"] = []
        game.metadata["advantage_turn"] = False
        game.metadata["advantage_player_id"] = None
        game.metadata["target_score"] = TARGET_SCORE
        game.metadata["turn_phase"] = "start"

        for player in game.players:
            player.clear_hand()
            player.metadata["score"] = 0

        if game.players:
            game.current_player_index = 0
            game.set_current_player(game.players[0])
            for _ in range(INITIAL_HAND_SIZE):
                for player in game.players:
                    card = game.deck.draw()
                    if card is not None:
                        player.receive_card(card)
        else:
            game.set_current_player(None)

    def get_available_actions(self, game: Game) -> list[Action]:
        """Return available play actions for increment cards and Jolly cards."""
        current_player = game.current_player()
        if current_player is None:
            return []

        if bool(game.metadata.get("advantage_turn", False)):
            advantage_player_id = game.metadata.get("advantage_player_id")
            if advantage_player_id is not None and current_player.player_id != advantage_player_id:
                return []

        actions: list[Action] = []
        if bool(game.metadata.get("advantage_turn", False)):
            advantage_player_id = game.metadata.get("advantage_player_id")
            if advantage_player_id is not None and current_player.player_id != advantage_player_id:
                if not current_player.hand.cards:
                    actions.append(RoadTo100Action(action_type=RESET_HAND_ACTION))
                else:
                    actions.append(RoadTo100Action(action_type=RESET_HAND_ACTION))
        elif game.metadata.get("turn_phase") == "start":
            plateau_value = int(game.metadata.get("piatto", 0))
            matching_gold = self._matching_gold_card(current_player, plateau_value)
            if matching_gold is not None:
                actions.append(
                    RoadTo100Action(action_type=REVEAL_GOLD_ACTION, parameters={"card": matching_gold})
                )

        if bool(game.metadata.get("advantage_turn", False)):
            advantage_player_id = game.metadata.get("advantage_player_id")
            if advantage_player_id is not None and current_player.player_id != advantage_player_id:
                return actions

        for card in current_player.hand.cards:
            if self._is_jolly_card(card):
                for chosen_value in range(1, 11):
                    actions.append(
                        RoadTo100Action(
                            action_type=PLAY_CARD_ACTION,
                            parameters={"card": card, "selected_value": chosen_value},
                        )
                    )
            elif self._is_imbroglio_card(card):
                plateau_value = int(game.metadata.get("piatto", 0))
                for chosen_value in range(-15, 16):
                    if chosen_value == 0:
                        continue
                    candidate = plateau_value + chosen_value
                    if 0 <= candidate <= TARGET_SCORE - 1:
                        actions.append(
                            RoadTo100Action(
                                action_type=PLAY_CARD_ACTION,
                                parameters={"card": card, "selected_value": chosen_value},
                            )
                        )
            elif self._is_special_89_card(card):
                actions.append(RoadTo100Action(action_type=PLAY_CARD_ACTION, parameters={"card": card}))
            elif self._is_plus11_card(card):
                actions.append(RoadTo100Action(action_type=PLAY_CARD_ACTION, parameters={"card": card}))
            elif self._is_gold_card(card):
                actions.append(RoadTo100Action(action_type=PLAY_CARD_ACTION, parameters={"card": card}))
            elif card.value is not None:
                actions.append(RoadTo100Action(action_type=PLAY_CARD_ACTION, parameters={"card": card}))
        return actions

    def validate_action(self, game: Game, action: Action) -> bool:
        """Validate an action against the current game state."""
        if not isinstance(action, RoadTo100Action):
            return False

        current_player = game.current_player()
        if current_player is None:
            return False

        card = action.parameters.get("card")
        if not isinstance(card, Card) or not current_player.has_card(card):
            return False

        if bool(game.metadata.get("advantage_turn", False)):
            advantage_player_id = game.metadata.get("advantage_player_id")
            if advantage_player_id is not None and current_player.player_id != advantage_player_id:
                return False

        if action.action_type == RESET_HAND_ACTION:
            return bool(game.metadata.get("advantage_turn", False)) and current_player.player_id != game.metadata.get("advantage_player_id")

        if action.action_type == REVEAL_GOLD_ACTION:
            plateau_value = int(game.metadata.get("piatto", 0))
            return isinstance(card, Card) and current_player.has_card(card) and self._is_gold_card(card) and card.value == plateau_value

        if self._is_jolly_card(card):
            selected_value = action.parameters.get("selected_value")
            return isinstance(selected_value, int) and 1 <= selected_value <= 10

        if self._is_imbroglio_card(card):
            selected_value = action.parameters.get("selected_value")
            if not isinstance(selected_value, int) or selected_value == 0:
                return False
            plateau_value = int(game.metadata.get("piatto", 0))
            candidate = plateau_value + selected_value
            return 0 <= candidate <= TARGET_SCORE - 1

        if self._is_special_89_card(card):
            return card.value is not None

        if self._is_plus11_card(card):
            return card.value is not None

        if self._is_gold_card(card):
            return card.value is not None

        return card.value is not None

    def apply_action(self, game: Game, action: Action) -> None:
        """Apply a validated action to the game state."""
        current_player = game.current_player()
        if current_player is None:
            return

        card = action.parameters.get("card")
        if not isinstance(card, Card):
            return

        if action.action_type == RESET_HAND_ACTION:
            cards_to_reset = list(current_player.hand.cards)
            current_player.clear_hand()
            for card in cards_to_reset:
                game.deck.add_card(card)
            game.deck.shuffle()
            for _ in range(3):
                drawn_card = game.deck.draw()
                if drawn_card is not None:
                    current_player.receive_card(drawn_card)
            game.metadata["turn_phase"] = "action"
            return

        if action.action_type == REVEAL_GOLD_ACTION:
            current_player.play_card(card)
            game.deck.add_card(card)
            game.deck.shuffle()
            drawn_card = game.deck.draw()
            if drawn_card is not None:
                current_player.receive_card(drawn_card)
            game.metadata["turn_phase"] = "action"
            return

        current_player.play_card(card)

        if self._is_jolly_card(card):
            chosen_value = int(action.parameters.get("selected_value", 1))
            increment = chosen_value
        elif self._is_imbroglio_card(card):
            increment = int(action.parameters.get("selected_value", 0))
        elif self._is_special_89_card(card):
            increment = 89
            game.metadata["advantage_turn"] = True
            game.metadata["advantage_player_id"] = current_player.player_id
        elif self._is_plus11_card(card):
            increment = 11
            if bool(game.metadata.get("advantage_turn", False)):
                game.winner = current_player
        elif self._is_gold_card(card):
            increment = int(card.value or 0)
            game.metadata["plateau_value"] = increment
            game.metadata["gold_cards"] = game.metadata.get("gold_cards", []) + [card]
        else:
            increment = int(card.value or 0)

        plateau = int(game.metadata.get("piatto", 0))
        if self._is_gold_card(card):
            plateau = increment
        else:
            plateau += increment
        game.metadata["piatto"] = min(plateau, TARGET_SCORE)
        game.metadata.setdefault("plateau_cards", []).append(card)

        current_player.metadata["score"] = int(current_player.metadata.get("score", 0)) + increment
        if int(game.metadata.get("piatto", 0)) >= TARGET_SCORE:
            game.winner = current_player

        game.metadata["turn_phase"] = "action"
        drawn_card = game.deck.draw()
        if drawn_card is not None:
            current_player.receive_card(drawn_card)

    def advance_turn(self, game: Game) -> None:
        """Advance the game flow after an action has been processed."""
        if not game.players:
            return

        if game.current_player_index is None:
            game.current_player_index = 0
        else:
            game.current_player_index = (game.current_player_index + 1) % len(game.players)

        game.set_current_player(game.players[game.current_player_index])
        game.metadata["turn_phase"] = "start"
        game.metadata["advantage_turn"] = False
        game.metadata["advantage_player_id"] = None
        game.turn_number += 1

    def is_game_over(self, game: Game) -> bool:
        """Return whether the game has reached a terminal state."""
        return int(game.metadata.get("piatto", 0)) >= TARGET_SCORE

    def get_winner(self, game: Game) -> Optional[Player]:
        """Return the winning player, if any."""
        if game.winner is not None:
            return game.winner
        if self.is_game_over(game):
            current_player = game.current_player()
            if current_player is not None:
                return current_player
        return None
