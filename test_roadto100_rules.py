#!/usr/bin/env python3
"""Targeted tests for RoadTo100 game rules per GAME_RULES.md."""

from __future__ import annotations

import unittest
from typing import List

from simulator.domain.card import Card
from simulator.domain.deck import Deck
from simulator.domain.game import Game, GamePhase
from simulator.domain.hand import Hand
from simulator.domain.player import Player

from games.roadto100.actions import (
    CHANGE_CARD_ACTION,
    PLAY_CARD_ACTION,
    RESET_HAND_ACTION,
    RoadTo100Action,
)
from games.roadto100.config import TARGET_SCORE
from games.roadto100.rules import RoadTo100RuleSet

# ---------------------------------------------------------------------------
# Helper factories
# ---------------------------------------------------------------------------

GOLD_CHAIN: dict[int, int] = {12: 23, 23: 34, 34: 45, 45: 56, 56: 67, 67: 78, 78: 89}


def gold_card(value: int) -> Card:
    return Card(
        card_id=f"gold_{value}",
        name=str(value),
        value=value,
        color="Gold",
        metadata={"card_type": "gold", "category": "gold", "destination": "plate"},
    )


def plus11_card(copy: int = 0) -> Card:
    return Card(
        card_id=f"+11_{copy}",
        name="+11",
        value=11,
        color="Red",
        metadata={"card_type": "special", "category": "normal", "destination": "discard"},
    )


def card89(copy: int = 0) -> Card:
    return Card(
        card_id=f"89_{copy}",
        name="89",
        value=89,
        color="Purple",
        metadata={"card_type": "special", "category": "normal", "destination": "plate"},
    )


def increment_card(value: int, copy: int = 0) -> Card:
    return Card(
        card_id=f"+{value}_{copy}",
        name=f"+{value}",
        value=value,
        color="Orange",
        metadata={"card_type": "increment", "category": "normal", "destination": "discard"},
    )


def jolly_card(copy: int = 0) -> Card:
    return Card(
        card_id=f"jolly_{copy}",
        name="Jolly",
        value=None,
        color="Orange",
        metadata={"card_type": "jolly", "category": "normal", "destination": "discard"},
    )


def imbroglio_card(copy: int = 0) -> Card:
    return Card(
        card_id=f"imbroglio_{copy}",
        name="Imbroglio",
        value=0,
        color="Green",
        metadata={"card_type": "imbroglio", "category": "normal", "destination": "discard"},
    )


def make_game(*, players: List[Player], deck_cards: List[Card],
              discard: List[Card] | None = None,
              metadata: dict | None = None) -> Game:
    g = Game(
        players=players,
        deck=Deck(cards=list(deck_cards)),
        discard_pile=list(discard) if discard is not None else [],
        current_player_index=0,
        turn_number=0,
        phase=GamePhase.PLAYING,
        metadata=dict(metadata) if metadata is not None else {},
    )
    g.set_current_player(players[0])
    return g


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestGoldChain(unittest.TestCase):
    """+11 played immediately after a Gold card assumes the next Gold value."""

    def _run_chain(self, gold_value: int, expected: int) -> None:
        rules = RoadTo100RuleSet()
        p = Player("p1", "Player 1", Hand())
        game = make_game(
            players=[p],
            deck_cards=[increment_card(1)],
            metadata={
                "piatto": gold_value,
                "plateau_cards": [gold_card(gold_value)],
                "special_round_active": False,
                "special_round_player_id": None,
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        card = plus11_card()
        p.receive_card(card)

        action = RoadTo100Action(action_type=PLAY_CARD_ACTION, parameters={"card": card})
        rules.apply_action(game, action)

        self.assertEqual(game.metadata["piatto"], expected)

    def test_12_to_23(self) -> None:
        self._run_chain(12, 23)

    def test_23_to_34(self) -> None:
        self._run_chain(23, 34)

    def test_34_to_45(self) -> None:
        self._run_chain(34, 45)

    def test_45_to_56(self) -> None:
        self._run_chain(45, 56)

    def test_56_to_67(self) -> None:
        self._run_chain(56, 67)

    def test_67_to_78(self) -> None:
        self._run_chain(67, 78)

    def test_78_to_89_triggers_gdv(self) -> None:
        """+11 after 78 sets plateau=89 AND activates the Advantage Round."""
        rules = RoadTo100RuleSet()
        p = Player("p1", "Player 1", Hand())
        game = make_game(
            players=[p],
            deck_cards=[increment_card(1)],
            metadata={
                "piatto": 78,
                "plateau_cards": [gold_card(78)],
                "special_round_active": False,
                "special_round_player_id": None,
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        card = plus11_card()
        p.receive_card(card)

        action = RoadTo100Action(action_type=PLAY_CARD_ACTION, parameters={"card": card})
        rules.apply_action(game, action)

        self.assertEqual(game.metadata["piatto"], 89)
        self.assertTrue(game.metadata.get("special_round_active"))
        self.assertEqual(game.metadata.get("special_round_player_id"), "p1")


class TestGdvLifecycle(unittest.TestCase):
    """Advantage Round: active, persists, ends at the right moment."""

    def test_gdv_ends_after_advantage_player_next_turn(self) -> None:
        """GdV stays active through other players, until advantage player
        finishes their NEXT turn."""
        rules = RoadTo100RuleSet()
        p1 = Player("p1", "P1", Hand([increment_card(1)]))
        p2 = Player("p2", "P2", Hand([increment_card(2)]))

        game = make_game(
            players=[p1, p2],
            deck_cards=[increment_card(3)],
            metadata={
                "piatto": 89,
                "plateau_cards": [card89()],
                "special_round_active": True,
                "special_round_player_id": "p1",
                "turn_phase": "action",
                "target_score": TARGET_SCORE,
            },
        )

        # Step 1: P1 just played 89. advance_turn → P2.
        rules.advance_turn(game)
        self.assertTrue(game.metadata["special_round_active"],
                        "GdV should stay active after P1's 89 turn ends")
        self.assertEqual(game.current_player().player_id, "p2")

        # Step 2: P2's turn ends → back to P1 (NEXT turn for P1).
        rules.advance_turn(game)
        self.assertTrue(game.metadata["special_round_active"],
                        "GdV should be active during P1's NEXT turn")
        self.assertEqual(game.current_player().player_id, "p1")

        # Step 3: P1's NEXT turn ends → GdV must end.
        rules.advance_turn(game)
        self.assertFalse(game.metadata.get("special_round_active"),
                         "GdV should end after P1's NEXT turn completes")
        self.assertEqual(game.current_player().player_id, "p2")


class TestCard89NotPlayableDuringGdv(unittest.TestCase):
    """89 card cannot be played during an active Advantage Round."""

    def test_89_not_in_available_actions_during_gdv(self) -> None:
        rules = RoadTo100RuleSet()
        c89 = card89()
        p = Player("p1", "P1", Hand([c89, increment_card(1)]))
        game = make_game(
            players=[p],
            deck_cards=[increment_card(2)],
            metadata={
                "piatto": 50,
                "plateau_cards": [],
                "special_round_active": True,
                "special_round_player_id": "p2",
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )

        actions = rules.get_available_actions(game)

        for a in actions:
            if a.action_type != PLAY_CARD_ACTION:
                continue
            played = a.parameters.get("card")
            if played is c89:
                self.fail("89 card should NOT be playable during GdV")

        # 89 should still be changeable
        change_89 = [a for a in actions
                     if a.action_type == CHANGE_CARD_ACTION
                     and a.parameters.get("card") is c89]
        self.assertTrue(change_89, "89 card should be changeable during GdV")


class TestPlus11DuringGdv(unittest.TestCase):
    """+11 can be played as Orange during GdV and wins instantly."""

    def test_plus11_playable_and_wins_during_gdv(self) -> None:
        rules = RoadTo100RuleSet()
        c11 = plus11_card()
        p = Player("p1", "P1", Hand([c11]))
        game = make_game(
            players=[p],
            deck_cards=[increment_card(1)],
            metadata={
                "piatto": 50,
                "plateau_cards": [],
                "special_round_active": True,
                "special_round_player_id": "p1",
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )

        # Verify +11 appears in available actions
        actions = rules.get_available_actions(game)
        plus11_play = [a for a in actions
                       if a.action_type == PLAY_CARD_ACTION
                       and a.parameters.get("card") is c11]
        self.assertTrue(plus11_play,
                        "+11 must be playable during GdV")

        # Apply — should win immediately
        action = plus11_play[0]
        rules.apply_action(game, action)
        self.assertIs(game.winner, p,
                      "+11 must grant immediate victory during GdV")


class TestCard89SetsPiatto(unittest.TestCase):
    """89 must SET the piatto to 89, not add 89 to current value."""

    def _run_89_asserts(self, piatto_before: int) -> None:
        rules = RoadTo100RuleSet()
        c89 = card89()
        p = Player("p1", "P1", Hand([c89]))
        game = make_game(
            players=[p],
            deck_cards=[increment_card(1)],
            metadata={
                "piatto": piatto_before,
                "plateau_cards": [],
                "special_round_active": False,
                "special_round_player_id": None,
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )

        action = RoadTo100Action(action_type=PLAY_CARD_ACTION, parameters={"card": c89})
        rules.apply_action(game, action)

        self.assertEqual(game.metadata["piatto"], 89,
                         f"89 from piatto={piatto_before} must set piatto to 89")
        self.assertTrue(game.metadata.get("special_round_active"),
                        "advantage_turn must be set after 89")
        self.assertEqual(game.metadata.get("special_round_player_id"), "p1",
                         "advantage_player_id must be the player who played 89")
        self.assertIsNone(game.winner,
                          "89 must not trigger an immediate win")

    def test_89_from_piatto_0(self) -> None:
        """Piatto 0 + 89 → piatto=89, GdV active, no winner."""
        self._run_89_asserts(0)

    def test_89_from_piatto_11(self) -> None:
        """Piatto 11 + 89 → piatto=89 (NOT 100), GdV active, no winner."""
        self._run_89_asserts(11)

    def test_89_from_piatto_50(self) -> None:
        """Piatto 50 + 89 → piatto=89 (NOT 100/139), GdV active, no winner."""
        self._run_89_asserts(50)


class TestDeckReconstitution(unittest.TestCase):
    """Draw logic with partial deck and discard reshuffle."""

    def test_draw_cards_reconstitutes_from_discard(self) -> None:
        """_draw_cards draws existing deck cards first, then reshuffles
        discard (except last) to complete the draw."""
        rules = RoadTo100RuleSet()
        d1 = increment_card(1)
        d2 = increment_card(2)
        deck = Deck(cards=[d1])  # only 1 card in deck
        discard = [increment_card(3), increment_card(4), increment_card(5)]
        p = Player("p1", "P1", Hand())
        game = make_game(
            players=[p],
            deck_cards=[d1],
            discard=[increment_card(3), increment_card(4), increment_card(5)],
            metadata={"target_score": TARGET_SCORE},
        )

        drawn = RoadTo100RuleSet._draw_cards(game, 3)

        self.assertEqual(len(drawn), 3,
                         "must draw 3 cards total")
        self.assertEqual(drawn[0], d1,
                         "first card must come from the deck")
        # discard should have kept exactly 1 card (the last one)
        self.assertEqual(len(game.discard_pile), 1,
                         "discard must contain exactly 1 card after reconstitution")
        self.assertEqual(game.deck.cards, [],
                         "deck must be empty after drawing all requested cards")

    def test_change_card_with_insufficient_deck(self) -> None:
        """CHANGE_CARD with fewer deck cards than needed: draws existing
        cards, reconstitutes from discard, then draws the rest.
        Final hand must contain 3 cards."""
        rules = RoadTo100RuleSet()

        # Player has 3 cards, deck has 0
        h1, h2, h3 = increment_card(1), increment_card(2), increment_card(3)
        p = Player("p1", "P1", Hand([h1, h2, h3]))

        # Discard has some cards
        s1, s2 = increment_card(4), increment_card(5)

        game = make_game(
            players=[p],
            deck_cards=[],  # empty deck
            discard=[s1, s2],
            metadata={
                "piatto": 10,
                "plateau_cards": [],
                "special_round_active": False,
                "special_round_player_id": None,
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )

        initial_count = len(p.hand.cards)

        # Perform CHANGE_CARD on h1
        action = RoadTo100Action(action_type=CHANGE_CARD_ACTION,
                                 parameters={"card": h1})
        rules.apply_action(game, action)

        self.assertEqual(len(p.hand.cards), initial_count,
                         "hand must have the same number of cards after CHANGE_CARD")

    def test_reset_hand_reconstitutes_deck(self) -> None:
        """RESET_HAND with only 1 hand card + empty deck: returns the card,
        needs 3 draws, reconstitutes from discard, ends with 3 cards."""
        rules = RoadTo100RuleSet()

        # Player has 1 card
        h1 = increment_card(1)
        p = Player("p1", "P1", Hand([h1]))

        # Discard has 4 cards (3 will be needed to complete the draw)
        s1, s2, s3, s4 = (increment_card(4), increment_card(5),
                          increment_card(6), increment_card(7))

        p2 = Player("p2", "P2", Hand())
        game = make_game(
            players=[p, p2],
            deck_cards=[],  # empty deck
            discard=[s1, s2, s3, s4],
            metadata={
                "piatto": 50,
                "plateau_cards": [],
                "special_round_active": True,
                "special_round_player_id": "p2",
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        game.set_current_player(p)

        action = RoadTo100Action(action_type=RESET_HAND_ACTION)
        rules.apply_action(game, action)

        self.assertEqual(len(p.hand.cards), 3,
                         "hand must have 3 cards after RESET_HAND")


class TestGdvBounce(unittest.TestCase):
    """Bounce rule during GdV: non-advantage players bounce at 100."""

    def _make_gdv_game(self, piatto: int, card: Card, advantage_player: str = "p1",
                       current_player: str = "p2") -> tuple[RoadTo100RuleSet, Player, Game]:
        rules = RoadTo100RuleSet()
        p1 = Player("p1", "P1", Hand())
        p2 = Player(current_player, f"P{current_player[-1]}", Hand([card]))
        p2id = p2.player_id
        deck_cards = [increment_card(3)]
        game = make_game(
            players=[p1, p2],
            deck_cards=deck_cards,
            metadata={
                "piatto": piatto,
                "plateau_cards": [],
                "special_round_active": True,
                "special_round_player_id": advantage_player,
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        game.set_current_player(p2)
        return rules, p2, game

    def test_bounce_99_plus_1(self) -> None:
        """Non-advantage: piatto 99 +1 → 100 esatto, Piatto=99, no win."""
        rules, player, game = self._make_gdv_game(99, increment_card(1))
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": player.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 99)
        self.assertIsNone(game.winner)

    def test_bounce_99_plus_5(self) -> None:
        """Non-advantage: piatto 99 +5 → 104, bounce (200-104=96)."""
        rules, player, game = self._make_gdv_game(99, increment_card(5))
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": player.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 96)
        self.assertIsNone(game.winner)

    def test_bounce_90_plus_10(self) -> None:
        """Non-advantage: piatto 90 +10 → 100 esatto, Piatto=99, no win."""
        rules, player, game = self._make_gdv_game(90, increment_card(10))
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": player.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 99)
        self.assertIsNone(game.winner)

    def test_bounce_97_plus_8(self) -> None:
        """Non-advantage: piatto 97 +8 → 105, bounce (200-105=95)."""
        rules, player, game = self._make_gdv_game(97, increment_card(8))
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": player.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 95)
        self.assertIsNone(game.winner)

    def test_bounce_70_plus_10_no_bounce(self) -> None:
        """Non-advantage: piatto 70 +10=80 (<100), no bounce."""
        rules, player, game = self._make_gdv_game(70, increment_card(10))
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": player.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 80)
        self.assertIsNone(game.winner)

    def test_no_bounce_advantage_player(self) -> None:
        """Advantage player: piatto 95 +10 → 105, wins (no bounce)."""
        rules = RoadTo100RuleSet()
        p1 = Player("p1", "P1", Hand([increment_card(10)]))  # advantage player
        p2 = Player("p2", "P2", Hand())
        game = make_game(
            players=[p1, p2],
            deck_cards=[increment_card(3)],
            metadata={
                "piatto": 95,
                "plateau_cards": [],
                "special_round_active": True,
                "special_round_player_id": "p1",
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        game.set_current_player(p1)
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": p1.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 105)
        self.assertIs(game.winner, p1)

    def test_no_bounce_plus11_non_advantage(self) -> None:
        """Non-advantage: +11 during GdV → wins instantly, no bounce."""
        rules = RoadTo100RuleSet()
        p1 = Player("p1", "P1", Hand())
        c11 = plus11_card()
        p2 = Player("p2", "P2", Hand([c11]))
        game = make_game(
            players=[p1, p2],
            deck_cards=[increment_card(3)],
            metadata={
                "piatto": 99,
                "plateau_cards": [],
                "special_round_active": True,
                "special_round_player_id": "p1",
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        game.set_current_player(p2)
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": c11})
        rules.apply_action(game, action)
        self.assertIs(game.winner, p2, "+11 must win for non-advantage player during GdV")
        # Piatto can be anything, but should NOT be bounced (game already won)


class TestBounceFormula(unittest.TestCase):
    """F5: Universal bounce formula 200 - raw_total outside SR."""

    def test_normal_99_plus_1(self) -> None:
        """Normal play: 99+1=100 → victory."""
        rules = RoadTo100RuleSet()
        p = Player("p1", "P1", Hand([increment_card(1)]))
        game = make_game(
            players=[p],
            deck_cards=[],
            metadata={
                "piatto": 99,
                "plateau_cards": [],
                "special_round_active": False,
                "special_round_player_id": None,
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": p.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 100)
        self.assertIs(game.winner, p)

    def test_normal_99_plus_2(self) -> None:
        """Normal play: 99+2=101 → bounce (200-101=99)."""
        rules = RoadTo100RuleSet()
        p = Player("p1", "P1", Hand([increment_card(2)]))
        game = make_game(
            players=[p],
            deck_cards=[],
            metadata={
                "piatto": 99,
                "plateau_cards": [],
                "special_round_active": False,
                "special_round_player_id": None,
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": p.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 99)
        self.assertIsNone(game.winner)

    def test_normal_99_plus_5(self) -> None:
        """Normal play: 99+5=104 → bounce (200-104=96)."""
        rules = RoadTo100RuleSet()
        p = Player("p1", "P1", Hand([increment_card(5)]))
        game = make_game(
            players=[p],
            deck_cards=[],
            metadata={
                "piatto": 99,
                "plateau_cards": [],
                "special_round_active": False,
                "special_round_player_id": None,
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": p.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 96)
        self.assertIsNone(game.winner)

    def test_normal_97_plus_8(self) -> None:
        """Normal play: 97+8=105 → bounce (200-105=95)."""
        rules = RoadTo100RuleSet()
        p = Player("p1", "P1", Hand([increment_card(8)]))
        game = make_game(
            players=[p],
            deck_cards=[],
            metadata={
                "piatto": 97,
                "plateau_cards": [],
                "special_round_active": False,
                "special_round_player_id": None,
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": p.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 95)
        self.assertIsNone(game.winner)

    def test_normal_95_plus_8(self) -> None:
        """Normal play: 95+8=103 → bounce (200-103=97)."""
        rules = RoadTo100RuleSet()
        p = Player("p1", "P1", Hand([increment_card(8)]))
        game = make_game(
            players=[p],
            deck_cards=[],
            metadata={
                "piatto": 95,
                "plateau_cards": [],
                "special_round_active": False,
                "special_round_player_id": None,
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": p.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 97)
        self.assertIsNone(game.winner)


class TestGdvNonAdvantageExact100(unittest.TestCase):
    """F5: During GdV, non-advantage player bringing plateau to exactly 100 → Piatto=99."""

    def test_gdv_99_plus_1(self) -> None:
        """GdV non-Vantaggio: 99+1=100 → Piatto=99, no win."""
        rules = RoadTo100RuleSet()
        p1 = Player("p1", "P1", Hand())
        p2 = Player("p2", "P2", Hand([increment_card(1)]))
        game = make_game(
            players=[p1, p2],
            deck_cards=[],
            metadata={
                "piatto": 99,
                "plateau_cards": [],
                "special_round_active": True,
                "special_round_player_id": "p1",
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        game.set_current_player(p2)
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": p2.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 99)
        self.assertIsNone(game.winner)

    def test_gdv_98_plus_2(self) -> None:
        """GdV non-Vantaggio: 98+2=100 → Piatto=99, no win."""
        rules = RoadTo100RuleSet()
        p1 = Player("p1", "P1", Hand())
        p2 = Player("p2", "P2", Hand([increment_card(2)]))
        game = make_game(
            players=[p1, p2],
            deck_cards=[],
            metadata={
                "piatto": 98,
                "plateau_cards": [],
                "special_round_active": True,
                "special_round_player_id": "p1",
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        game.set_current_player(p2)
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": p2.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 99)
        self.assertIsNone(game.winner)

    def test_gdv_97_plus_3(self) -> None:
        """GdV non-Vantaggio: 97+3=100 → Piatto=99, no win."""
        rules = RoadTo100RuleSet()
        p1 = Player("p1", "P1", Hand())
        p2 = Player("p2", "P2", Hand([increment_card(3)]))
        game = make_game(
            players=[p1, p2],
            deck_cards=[],
            metadata={
                "piatto": 97,
                "plateau_cards": [],
                "special_round_active": True,
                "special_round_player_id": "p1",
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        game.set_current_player(p2)
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": p2.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 99)
        self.assertIsNone(game.winner)


class TestGdvAdvantagePlayerNoBounce(unittest.TestCase):
    """F5: During GdV, advantage player ignores bounce and wins at 100+."""

    def test_gdv_advantage_97_plus_8(self) -> None:
        """GdV Vantaggio: 97+8=105 → 105, immediate win (no bounce)."""
        rules = RoadTo100RuleSet()
        p1 = Player("p1", "P1", Hand([increment_card(8)]))
        p2 = Player("p2", "P2", Hand())
        game = make_game(
            players=[p1, p2],
            deck_cards=[],
            metadata={
                "piatto": 97,
                "plateau_cards": [],
                "special_round_active": True,
                "special_round_player_id": "p1",
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        game.set_current_player(p1)
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": p1.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 105)
        self.assertIs(game.winner, p1)

    def test_gdv_advantage_95_plus_5(self) -> None:
        """GdV Vantaggio: 95+5=100 → 100, immediate win."""
        rules = RoadTo100RuleSet()
        p1 = Player("p1", "P1", Hand([increment_card(5)]))
        p2 = Player("p2", "P2", Hand())
        game = make_game(
            players=[p1, p2],
            deck_cards=[],
            metadata={
                "piatto": 95,
                "plateau_cards": [],
                "special_round_active": True,
                "special_round_player_id": "p1",
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        game.set_current_player(p1)
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": p1.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 100)
        self.assertIs(game.winner, p1)


class TestSafeRoundVictory(unittest.TestCase):
    """F5: Safe Round does not affect normal victory at 100."""

    def test_safe_round_99_plus_1(self) -> None:
        """Safe Round: 99+1=100 → vittoria normale (il giocatore che ha giocato la carta vince)."""
        rules = RoadTo100RuleSet()
        p1 = Player("p1", "P1", Hand([increment_card(1)]))
        game = make_game(
            players=[p1],
            deck_cards=[],
            metadata={
                "piatto": 99,
                "plateau_cards": [],
                "special_round_active": True,
                "special_round_player_id": "p1",
                "special_round_type": "safe",
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": p1.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 100)
        self.assertIs(game.winner, p1)


class TestSafeRoundLifecycle(unittest.TestCase):
    """F6: Safe Round lifecycle — ends after activator's NEXT turn."""

    def test_safe_round_ends_after_activator_next_turn(self) -> None:
        """Safe Round stays active through other players' turns, until activator
        finishes their NEXT turn."""
        rules = RoadTo100RuleSet()
        p1 = Player("p1", "P1", Hand([increment_card(1)]))
        p2 = Player("p2", "P2", Hand([increment_card(2)]))

        # Simulate: P1 just played Gold 12 → Safe Round for P1
        game = make_game(
            players=[p1, p2],
            deck_cards=[increment_card(3)],
            metadata={
                "piatto": 12,
                "plateau_cards": [gold_card(12)],
                "special_round_active": True,
                "special_round_player_id": "p1",
                "special_round_type": "safe",
                "turn_phase": "action",
                "target_score": TARGET_SCORE,
            },
        )

        # advance_turn → P2
        rules.advance_turn(game)
        self.assertTrue(game.metadata["special_round_active"],
                        "Safe Round should stay active after P1's Gold turn ends")
        self.assertEqual(game.current_player().player_id, "p2")

        # advance_turn → P1 (NEXT turn for P1)
        rules.advance_turn(game)
        self.assertTrue(game.metadata["special_round_active"],
                        "Safe Round should be active during P1's NEXT turn")
        self.assertEqual(game.current_player().player_id, "p1")

        # advance_turn → P2 (P1's NEXT turn ends)
        rules.advance_turn(game)
        self.assertFalse(game.metadata.get("special_round_active"),
                         "Safe Round should end after P1's NEXT turn completes")


class TestSafeRoundNonActivatorPlay(unittest.TestCase):
    """F6: During Safe Round, non-activators play normally (no GdV cap)."""

    def test_safe_round_non_adv_99_plus_1(self) -> None:
        """Safe Round non-activator: 99+1=100 → wins normally."""
        rules = RoadTo100RuleSet()
        p1 = Player("p1", "P1", Hand())  # activator
        p2 = Player("p2", "P2", Hand([increment_card(1)]))  # non-activator playing
        game = make_game(
            players=[p1, p2],
            deck_cards=[],
            metadata={
                "piatto": 99,
                "plateau_cards": [],
                "special_round_active": True,
                "special_round_player_id": "p1",
                "special_round_type": "safe",
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        game.set_current_player(p2)
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": p2.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 100)
        self.assertIs(game.winner, p2, "non-activator should win at 100 during Safe Round")

    def test_safe_round_non_adv_97_plus_8(self) -> None:
        """Safe Round non-activator: 97+8=105 → normal bounce (200-105=95)."""
        rules = RoadTo100RuleSet()
        p1 = Player("p1", "P1", Hand())  # activator
        p2 = Player("p2", "P2", Hand([increment_card(8)]))  # non-activator playing
        game = make_game(
            players=[p1, p2],
            deck_cards=[],
            metadata={
                "piatto": 97,
                "plateau_cards": [],
                "special_round_active": True,
                "special_round_player_id": "p1",
                "special_round_type": "safe",
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        game.set_current_player(p2)
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": p2.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 95)
        self.assertIsNone(game.winner)

    def test_safe_round_non_adv_99_plus_5(self) -> None:
        """Safe Round non-activator: 99+5=104 → normal bounce (200-104=96)."""
        rules = RoadTo100RuleSet()
        p1 = Player("p1", "P1", Hand())
        p2 = Player("p2", "P2", Hand([increment_card(5)]))
        game = make_game(
            players=[p1, p2],
            deck_cards=[],
            metadata={
                "piatto": 99,
                "plateau_cards": [],
                "special_round_active": True,
                "special_round_player_id": "p1",
                "special_round_type": "safe",
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        game.set_current_player(p2)
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": p2.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 96)
        self.assertIsNone(game.winner)


class TestAdvantageNonActivatorExact100(unittest.TestCase):
    """F6: During GdV (advantage), non-activator brings plateau to exactly 100 → Piatto=99."""

    def test_gdv_non_adv_99_plus_1(self) -> None:
        """GdV non-in-Vantaggio: 99+1=100 → Piatto=99, no win."""
        rules = RoadTo100RuleSet()
        p1 = Player("p1", "P1", Hand())
        p2 = Player("p2", "P2", Hand([increment_card(1)]))
        game = make_game(
            players=[p1, p2],
            deck_cards=[],
            metadata={
                "piatto": 99,
                "plateau_cards": [],
                "special_round_active": True,
                "special_round_player_id": "p1",
                "special_round_type": "advantage",
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        game.set_current_player(p2)
        action = RoadTo100Action(action_type=PLAY_CARD_ACTION,
                                 parameters={"card": p2.hand.cards[0]})
        rules.apply_action(game, action)
        self.assertEqual(game.metadata["piatto"], 99)
        self.assertIsNone(game.winner)


class TestSafeRoundActivation(unittest.TestCase):
    """F2: Normal Gold cards activate Safe Round, +11 from Gold chain activates Safe/Advantage."""

    def test_gold_12_activates_safe_round(self) -> None:
        """Normal Gold 12 sets piatto=12 and activates Safe Round (type=safe)."""
        rules = RoadTo100RuleSet()
        p = Player("p1", "P1", Hand([gold_card(12)]))
        game = make_game(
            players=[p],
            deck_cards=[increment_card(1)],
            metadata={
                "piatto": 0,
                "plateau_cards": [],
                "special_round_active": False,
                "special_round_player_id": None,
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )

        action = RoadTo100Action(action_type=PLAY_CARD_ACTION, parameters={"card": p.hand.cards[0]})
        rules.apply_action(game, action)

        self.assertEqual(game.metadata["piatto"], 12, "Gold 12 sets piatto to 12")
        self.assertTrue(game.metadata.get("special_round_active"), "Safe Round activates after Gold")
        self.assertEqual(game.metadata.get("special_round_player_id"), "p1", "P1 is activator")
        self.assertEqual(game.metadata.get("special_round_type"), "safe", "Type is safe")

    def test_gold_78_activates_safe_round(self) -> None:
        """Normal Gold 78 sets piatto=78 and activates Safe Round (type=safe)."""
        rules = RoadTo100RuleSet()
        p = Player("p1", "P1", Hand([gold_card(78)]))
        game = make_game(
            players=[p],
            deck_cards=[increment_card(1)],
            metadata={
                "piatto": 0,
                "plateau_cards": [],
                "special_round_active": False,
                "special_round_player_id": None,
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )

        action = RoadTo100Action(action_type=PLAY_CARD_ACTION, parameters={"card": p.hand.cards[0]})
        rules.apply_action(game, action)

        self.assertEqual(game.metadata["piatto"], 78, "Gold 78 sets piatto to 78")
        self.assertTrue(game.metadata.get("special_round_active"), "Safe Round activates after Gold")
        self.assertEqual(game.metadata.get("special_round_type"), "safe", "Type is safe")

    def test_plus11_from_78_gold_chain_activates_advantage(self) -> None:
        """+11 after 78 Gold → plateau=89, activates Advantage Round (type=advantage)."""
        rules = RoadTo100RuleSet()
        p = Player("p1", "P1", Hand([plus11_card()]))
        game = make_game(
            players=[p],
            deck_cards=[increment_card(1)],
            metadata={
                "piatto": 78,
                "plateau_cards": [gold_card(78)],
                "special_round_active": False,
                "special_round_player_id": None,
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )

        action = RoadTo100Action(action_type=PLAY_CARD_ACTION, parameters={"card": p.hand.cards[0]})
        rules.apply_action(game, action)

        self.assertEqual(game.metadata["piatto"], 89, "+11 from 78 chain sets plateau to 89")
        self.assertTrue(game.metadata.get("special_round_active"), "Special Round activates")
        self.assertEqual(game.metadata.get("special_round_type"), "advantage", "Type is advantage")

    def test_plus11_from_67_gold_chain_activates_safe_round(self) -> None:
        """+11 after 67 Gold → plateau=78, activates Safe Round (type=safe)."""
        rules = RoadTo100RuleSet()
        p = Player("p1", "P1", Hand([plus11_card()]))
        game = make_game(
            players=[p],
            deck_cards=[increment_card(1)],
            metadata={
                "piatto": 67,
                "plateau_cards": [gold_card(67)],
                "special_round_active": False,
                "special_round_player_id": None,
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )

        action = RoadTo100Action(action_type=PLAY_CARD_ACTION, parameters={"card": p.hand.cards[0]})
        rules.apply_action(game, action)

        self.assertEqual(game.metadata["piatto"], 78, "+11 from 67 chain sets plateau to 78")
        self.assertTrue(game.metadata.get("special_round_active"), "Safe Round activates")
        self.assertEqual(game.metadata.get("special_round_type"), "safe", "Type is safe")

    def test_new_safe_round_overwrites_previous(self) -> None:
        """New Safe Round immediately replaces previous Special Round."""
        rules = RoadTo100RuleSet()
        p1 = Player("p1", "P1", Hand([gold_card(12)]))
        p2 = Player("p2", "P2", Hand([gold_card(34)]))

        # Start: P1 plays Gold 12 → Safe Round for P1
        game = make_game(
            players=[p1, p2],
            deck_cards=[increment_card(1)],
            metadata={
                "piatto": 0,
                "plateau_cards": [],
                "special_round_active": False,
                "special_round_player_id": None,
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )

        action1 = RoadTo100Action(action_type=PLAY_CARD_ACTION, parameters={"card": p1.hand.cards[0]})
        rules.apply_action(game, action1)
        self.assertEqual(game.metadata["special_round_player_id"], "p1")
        self.assertEqual(game.metadata["piatto"], 12)

        # Advance turn to P2, P2 plays Gold 34 → Safe Round replaces for P2
        game.current_player_index = 1
        game.set_current_player(p2)
        game.metadata["turn_phase"] = "start"
        game.turn_number += 1

        action2 = RoadTo100Action(action_type=PLAY_CARD_ACTION, parameters={"card": p2.hand.cards[0]})
        rules.apply_action(game, action2)
        self.assertEqual(game.metadata["special_round_player_id"], "p2", "P2 becomes new activator")
        self.assertEqual(game.metadata["piatto"], 34, "Piatto set to 34 by Gold 34")


class TestSafeRoundBlockedType(unittest.TestCase):
    """F4: Safe Round card type blocking in get_available_actions and validate_action."""

    def _make_safe_round_game(self, p1, p2, deck_cards, blocked_type, current_player_idx=0):
        """Create a 2-player game with Safe Round active for p1 and blocked_type set."""
        rules = RoadTo100RuleSet()

        # Set up Safe Round for p1 (activator)
        game = make_game(
            players=[p1, p2],
            deck_cards=deck_cards,
            metadata={
                "piatto": 50,
                "plateau_cards": [],
                "special_round_active": True,
                "special_round_player_id": "p1",
                "special_round_type": "safe",
                "blocked_type": blocked_type,
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        game.set_current_player([p1, p2][current_player_idx])
        return rules, p1, p2, game

    def test_blocked_incremento_blocks_normal_increment(self) -> None:
        """Incremento blocked: normal increment card NOT playable by non-activator."""
        p1 = Player("p1", "P1", Hand())
        p2 = Player("p2", "P2", Hand())
        rules, p1, p2, game = self._make_safe_round_game(
            p1, p2, [increment_card(1)], "Incremento", current_player_idx=1
        )
        p2.receive_card(increment_card(5, 0))

        actions = rules.get_available_actions(game)
        play_actions = [a for a in actions if a.action_type == PLAY_CARD_ACTION]
        for a in play_actions:
            self.assertNotEqual(a.parameters.get("card"), p2.hand.cards[0],
                                "Increment card should NOT be playable when Incremento is blocked")

    def test_blocked_incremento_blocks_plus11(self) -> None:
        """Incremento blocked: +11 (belongs to Incremento type) NOT playable by non-activator."""
        p1 = Player("p1", "P1", Hand())
        p2 = Player("p2", "P2", Hand())
        rules, p1, p2, game = self._make_safe_round_game(
            p1, p2, [increment_card(1)], "Incremento", current_player_idx=1
        )
        c11 = plus11_card()
        p2.receive_card(c11)

        actions = rules.get_available_actions(game)
        play_actions = [a for a in actions if a.action_type == PLAY_CARD_ACTION]
        for a in play_actions:
            self.assertNotEqual(a.parameters.get("card"), c11,
                                "+11 should NOT be playable when Incremento is blocked")

    def test_blocked_gold_blocks_normal_gold(self) -> None:
        """Gold blocked: normal Gold card NOT playable by non-activator."""
        p1 = Player("p1", "P1", Hand())
        p2 = Player("p2", "P2", Hand())
        rules, p1, p2, game = self._make_safe_round_game(
            p1, p2, [increment_card(1)], "Gold", current_player_idx=1
        )
        c_gold = gold_card(23)
        p2.receive_card(c_gold)

        actions = rules.get_available_actions(game)
        play_actions = [a for a in actions if a.action_type == PLAY_CARD_ACTION]
        for a in play_actions:
            self.assertNotEqual(a.parameters.get("card"), c_gold,
                                "Gold card should NOT be playable when Gold is blocked")

    def test_blocked_gold_blocks_89(self) -> None:
        """Gold blocked: 89 (special Gold card) NOT playable by non-activator."""
        p1 = Player("p1", "P1", Hand())
        p2 = Player("p2", "P2", Hand())
        rules, p1, p2, game = self._make_safe_round_game(
            p1, p2, [increment_card(1)], "Gold", current_player_idx=1
        )
        c89 = card89()
        p2.receive_card(c89)

        actions = rules.get_available_actions(game)
        play_actions = [a for a in actions if a.action_type == PLAY_CARD_ACTION]
        for a in play_actions:
            self.assertNotEqual(a.parameters.get("card"), c89,
                                "89 should NOT be playable when Gold is blocked")

    def test_blocked_gold_allows_plus11(self) -> None:
        """Gold blocked: +11 (belongs to Incremento type) IS playable by non-activator."""
        p1 = Player("p1", "P1", Hand())
        p2 = Player("p2", "P2", Hand())
        rules, p1, p2, game = self._make_safe_round_game(
            p1, p2, [increment_card(1)], "Gold", current_player_idx=1
        )
        c11 = plus11_card()
        p2.receive_card(c11)

        actions = rules.get_available_actions(game)
        play_actions = [a for a in actions if a.action_type == PLAY_CARD_ACTION]
        plus11_actions = [a for a in play_actions if a.parameters.get("card") is c11]
        self.assertTrue(plus11_actions, "+11 should be playable when Gold is blocked")

    def test_blocked_imbroglio_blocks_imbroglio(self) -> None:
        """Imbroglio blocked: Imbroglio card NOT playable by non-activator."""
        p1 = Player("p1", "P1", Hand())
        p2 = Player("p2", "P2", Hand())
        rules, p1, p2, game = self._make_safe_round_game(
            p1, p2, [increment_card(1)], "Imbroglio", current_player_idx=1
        )
        imb = imbroglio_card()
        p2.receive_card(imb)

        actions = rules.get_available_actions(game)
        play_actions = [a for a in actions if a.action_type == PLAY_CARD_ACTION]
        for a in play_actions:
            self.assertNotEqual(a.parameters.get("card"), imb,
                                "Imbroglio card should NOT be playable when Imbroglio is blocked")

    def test_change_card_always_available_during_safe_round(self) -> None:
        """Cambio Carta is always available during Safe Round, even for non-activators."""
        p1 = Player("p1", "P1", Hand())
        p2 = Player("p2", "P2", Hand())
        rules, p1, p2, game = self._make_safe_round_game(
            p1, p2, [increment_card(1)], "Incremento", current_player_idx=1
        )
        c = increment_card(5, 0)
        p2.receive_card(c)

        actions = rules.get_available_actions(game)
        change_actions = [a for a in actions if a.action_type == CHANGE_CARD_ACTION]
        change_c = [a for a in change_actions if a.parameters.get("card") is c]
        self.assertTrue(change_c, "Change card should be available for all cards during Safe Round")

    def test_validate_action_blocks_incremento_card(self) -> None:
        """validate_action rejects a blocked Incremento card for non-activator."""
        p1 = Player("p1", "P1", Hand())
        p2 = Player("p2", "P2", Hand())
        rules, p1, p2, game = self._make_safe_round_game(
            p1, p2, [increment_card(1)], "Incremento", current_player_idx=1
        )
        c = increment_card(5, 0)
        p2.receive_card(c)

        action = RoadTo100Action(action_type=PLAY_CARD_ACTION, parameters={"card": c})
        self.assertFalse(rules.validate_action(game, action),
                         "validate_action should reject blocked Incremento card")

    def test_validate_action_allows_plus11_when_gold_blocked(self) -> None:
        """validate_action accepts +11 when Gold is blocked (it's Incremento type)."""
        p1 = Player("p1", "P1", Hand())
        p2 = Player("p2", "P2", Hand())
        rules, p1, p2, game = self._make_safe_round_game(
            p1, p2, [increment_card(1)], "Gold", current_player_idx=1
        )
        c11 = plus11_card()
        p2.receive_card(c11)

        action = RoadTo100Action(action_type=PLAY_CARD_ACTION, parameters={"card": c11})
        self.assertTrue(rules.validate_action(game, action),
                        "validate_action should accept +11 when Gold is blocked")

    def test_validate_action_blocks_89_when_gold_blocked(self) -> None:
        """validate_action rejects 89 when Gold is blocked (it's a special Gold card)."""
        p1 = Player("p1", "P1", Hand())
        p2 = Player("p2", "P2", Hand())
        rules, p1, p2, game = self._make_safe_round_game(
            p1, p2, [increment_card(1)], "Gold", current_player_idx=1
        )
        c89 = card89()
        p2.receive_card(c89)

        action = RoadTo100Action(action_type=PLAY_CARD_ACTION, parameters={"card": c89})
        self.assertFalse(rules.validate_action(game, action),
                         "validate_action should reject 89 when Gold is blocked")


if __name__ == "__main__":
    unittest.main()
