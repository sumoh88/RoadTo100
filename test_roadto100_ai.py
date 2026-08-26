"""Tests for RoadTo100 AI Bot.

Verifies that the Python AI makes correct strategic decisions using
real available_actions from the rules engine.
"""

import sys
import unittest
from simulator.domain.game import Game, GamePhase
from simulator.domain.player import Player
from simulator.domain.card import Card
from games.roadto100.ai import RoadTo100Bot
from games.roadto100.rules import RoadTo100RuleSet


def make_card(card_id, name, value, color, card_type):
    return Card(
        card_id=card_id,
        name=name,
        value=value,
        color=color,
        metadata={"card_type": card_type},
    )


class TestRoadTo100AI(unittest.TestCase):
    """Test the AI bot with real game states."""

    def _make_game(self, num_players=4):
        player_list = [Player(f"p{i+1}", f"P{i+1}") for i in range(num_players)]
        game = Game(players=player_list)
        return game

    def _setup_bot_turn(self, game, hand_cards, piatto=0, plateau_cards=None):
        """Setup game state for a bot turn."""
        game.phase = GamePhase.PLAYING
        game.metadata["piatto"] = piatto
        game.metadata["plateau_cards"] = plateau_cards or []
        game.metadata["special_round_active"] = False
        game.metadata["special_round_player_id"] = None
        game.metadata["special_round_type"] = "advantage"
        game.metadata["blocked_type"] = ""
        game.metadata["target_score"] = 100
        game.metadata["allow89"] = False

        # Set current player to p2 (index 1)
        game.current_player_index = 1
        game.set_current_player(game.players[1])

        # Setup current player's hand
        cp = game.current_player()
        if cp is None:
            return
        cp.clear_hand()
        for card in hand_cards:
            cp.receive_card(card)

    def test_immediate_win_detection(self):
        """AI should play +5 when plateau is 95 (reaches exactly 100)."""
        game = self._make_game(4)
        self._setup_bot_turn(
            game,
            hand_cards=[
                make_card("+5_win", "+5", 5, "Orange", "increment"),
                make_card("+3_safe", "+3", 3, "Orange", "increment"),
            ],
            piatto=95,
        )

        bot = RoadTo100Bot()
        action = bot.select_action(game)

        self.assertEqual(action["action_type"], "play_card")
        self.assertEqual(action["card_id"], "+5_win",
                         f"AI should play +5 to win at 100, got: {action}")

    def test_jolly_winning_value(self):
        """AI should pick Jolly value 10 when plateau is 90 (reaches 100)."""
        game = self._make_game(4)
        self._setup_bot_turn(
            game,
            hand_cards=[
                make_card("jolly_test", "Jolly", 0, "Orange", "jolly"),
            ],
            piatto=90,
        )

        bot = RoadTo100Bot()
        action = bot.select_action(game)

        self.assertEqual(action["action_type"], "play_card")
        self.assertEqual(action.get("selected_value"), 10,
                         f"AI should pick Jolly value 10 to win, got: {action}")

    def test_avoid_bounce(self):
        """AI should prefer +3 over +6 at plateau 95 (avoids bounce)."""
        game = self._make_game(4)
        self._setup_bot_turn(
            game,
            hand_cards=[
                make_card("+6_bounce", "+6", 6, "Orange", "increment"),
                make_card("+3_safe", "+3", 3, "Orange", "increment"),
            ],
            piatto=95,
        )

        bot = RoadTo100Bot()
        action = bot.select_action(game)

        self.assertEqual(action["card_id"], "+3_safe",
                         f"AI should avoid bouncing +6, got: {action}")

    def test_hold_back_plus11(self):
        """AI should hold back +11 when not strategic (plateau 50)."""
        game = self._make_game(4)
        self._setup_bot_turn(
            game,
            hand_cards=[
                make_card("+11_hold", "+11", 11, "Red", "special"),
                make_card("+7_play", "+7", 7, "Orange", "increment"),
            ],
            piatto=50,
        )

        bot = RoadTo100Bot()
        action = bot.select_action(game)

        self.assertEqual(action["card_id"], "+7_play",
                         f"AI should hold back +11 at plateau 50, got: {action}")

    def test_plus11_win(self):
        """AI should play +11 when it wins (plateau 90, 90+11=101>=100)."""
        game = self._make_game(4)
        self._setup_bot_turn(
            game,
            hand_cards=[
                make_card("+11_win", "+11", 11, "Red", "special"),
                make_card("+2_low", "+2", 2, "Orange", "increment"),
            ],
            piatto=90,
        )

        bot = RoadTo100Bot()
        action = bot.select_action(game)

        self.assertEqual(action["card_id"], "+11_win",
                         f"AI should play +11 to win at plateau 90, got: {action}")

    def test_imbroglio_maximize_progress(self):
        """AI should pick high positive Imbroglio value to maximize progress."""
        game = self._make_game(4)
        self._setup_bot_turn(
            game,
            hand_cards=[
                make_card("imb_test", "Imbroglio", 0, "Green", "imbroglio"),
            ],
            piatto=85,
        )

        bot = RoadTo100Bot()
        action = bot.select_action(game)

        self.assertEqual(action["action_type"], "play_card")
        selected_val = action.get("selected_value", 0)
        # At plateau 85, max valid is +14 (reaches 99)
        self.assertGreaterEqual(selected_val, 10,
                                f"AI should pick high Imbroglio value, got: {action}")


if __name__ == "__main__":
    unittest.main()
