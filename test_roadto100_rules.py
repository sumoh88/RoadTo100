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
                "advantage_turn": False,
                "advantage_player_id": None,
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
                "advantage_turn": False,
                "advantage_player_id": None,
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        card = plus11_card()
        p.receive_card(card)

        action = RoadTo100Action(action_type=PLAY_CARD_ACTION, parameters={"card": card})
        rules.apply_action(game, action)

        self.assertEqual(game.metadata["piatto"], 89)
        self.assertTrue(game.metadata.get("advantage_turn"))
        self.assertEqual(game.metadata.get("advantage_player_id"), "p1")


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
                "advantage_turn": True,
                "advantage_player_id": "p1",
                "turn_phase": "action",
                "target_score": TARGET_SCORE,
            },
        )

        # Step 1: P1 just played 89. advance_turn → P2.
        rules.advance_turn(game)
        self.assertTrue(game.metadata["advantage_turn"],
                        "GdV should stay active after P1's 89 turn ends")
        self.assertEqual(game.current_player().player_id, "p2")

        # Step 2: P2's turn ends → back to P1 (NEXT turn for P1).
        rules.advance_turn(game)
        self.assertTrue(game.metadata["advantage_turn"],
                        "GdV should be active during P1's NEXT turn")
        self.assertEqual(game.current_player().player_id, "p1")

        # Step 3: P1's NEXT turn ends → GdV must end.
        rules.advance_turn(game)
        self.assertFalse(game.metadata.get("advantage_turn"),
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
                "advantage_turn": True,
                "advantage_player_id": "p2",
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
                "advantage_turn": True,
                "advantage_player_id": "p1",
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
                "advantage_turn": False,
                "advantage_player_id": None,
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
                "advantage_turn": True,
                "advantage_player_id": "p2",
                "turn_phase": "start",
                "target_score": TARGET_SCORE,
            },
        )
        game.set_current_player(p)

        action = RoadTo100Action(action_type=RESET_HAND_ACTION)
        rules.apply_action(game, action)

        self.assertEqual(len(p.hand.cards), 3,
                         "hand must have 3 cards after RESET_HAND")


if __name__ == "__main__":
    unittest.main()
