"""RuleSet skeleton for RoadTo100."""

from __future__ import annotations

import random
from typing import List, Optional

from simulator.domain.action import Action
from simulator.domain.card import Card
from simulator.domain.game import Game, GamePhase
from simulator.domain.player import Player
from simulator.domain.ruleset import RuleSet

from .actions import CHANGE_CARD_ACTION, PLAY_CARD_ACTION, RESET_HAND_ACTION, RoadTo100Action
from .config import INITIAL_HAND_SIZE, TARGET_SCORE


class RoadTo100RuleSet(RuleSet):
    """RuleSet for RoadTo100 implementing increment cards and Jolly cards."""

    # +11 Gold chain: the value a +11 assumes when played after a Gold card.
    GOLD_CHAIN: dict[int, int] = {12: 23, 23: 34, 34: 45, 45: 56, 56: 67, 67: 78, 78: 89}

    @staticmethod
    def _is_increment_card(card: Card) -> bool:
        """Return whether the provided card is an increment card (orange, numeric +1..+10)."""
        return str(card.metadata.get("card_type", "")).lower() == "increment"

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

    @staticmethod
    def _is_blocked_type(card: Card, blocked_type: str) -> bool:
        """Return whether the provided card belongs to the blocked type during Safe Round.

        Per GAME_RULES.md Giro Sicuro rules:
        - "Incremento" blocks normal Incremento cards AND +11 (which belongs to Incremento type)
        - "Gold" blocks normal Gold cards AND 89 (special Gold card)
        - "Imbroglio" blocks Imbroglio cards
        """
        bt = str(blocked_type).lower()
        if bt == "incremento":
            # Blocks increment, jolly, AND +11 (per rules: +11 belongs to Incremento type)
            return (
                RoadTo100RuleSet._is_increment_card(card)
                or RoadTo100RuleSet._is_jolly_card(card)
                or RoadTo100RuleSet._is_plus11_card(card)
            )
        elif bt == "gold":
            # Blocks normal Gold cards AND 89 (special Gold card, per rules: 89 is Carta Gold Speciale)
            return RoadTo100RuleSet._is_gold_card(card) or RoadTo100RuleSet._is_special_89_card(card)
        elif bt == "imbroglio":
            return RoadTo100RuleSet._is_imbroglio_card(card)
        return False

    @staticmethod
    def _reshuffle_discard_into_deck(game: Game) -> None:
        """Move discard cards (except the last) back to deck, then shuffle.

        Gold cards on the plateau are never in the discard pile, so no
        special filtering is needed here.

        If only one card remains in the discard, it is moved to deck too
        so the game does not stall.
        """
        if not game.discard_pile:
            return
        if len(game.discard_pile) == 1:
            cards = list(game.discard_pile)
            game.discard_pile.clear()
            game.deck.add_cards(cards)
        else:
            last = game.discard_pile.pop()
            cards = list(game.discard_pile)
            game.discard_pile.clear()
            game.discard_pile.append(last)
            game.deck.add_cards(cards)
        game.deck.shuffle()

    @staticmethod
    def _draw_cards(game: Game, count: int) -> List[Card]:
        """Draw up to ``count`` cards, reconstituting deck from discard if needed.

        If the deck has some cards, they are drawn first.  Only when the deck
        cannot supply all requested cards are the discard cards (except the
        last played one) shuffled back in to complete the draw.
        """
        drawn: List[Card] = []

        # 1. Draw any cards already in the deck
        while not game.deck.is_empty() and len(drawn) < count:
            card = game.deck.draw()
            if card is not None:
                drawn.append(card)

        # 2. Reconstitute from discard if more cards are needed
        if len(drawn) < count:
            RoadTo100RuleSet._reshuffle_discard_into_deck(game)
            while not game.deck.is_empty() and len(drawn) < count:
                card = game.deck.draw()
                if card is not None:
                    drawn.append(card)

        return drawn

    @staticmethod
    def _draw_or_reshuffle(game: Game) -> Optional[Card]:
        """Draw a card, reshuffling discard into deck if the deck is empty."""
        drawn = RoadTo100RuleSet._draw_cards(game, 1)
        return drawn[0] if drawn else None

    def initialize_game(self, game: Game) -> None:
        """Initialize the game state for a new match."""
        game.phase = GamePhase.PLAYING
        game.winner = None
        game.turn_number = 0
        game.discard_pile.clear()
        game.metadata["piatto"] = 0
        game.metadata["plateau_cards"] = []
        game.metadata["special_round_active"] = False
        game.metadata["special_round_player_id"] = None
        game.metadata["special_round_type"] = "advantage"
        game.metadata["blocked_type"] = ""
        game.metadata["target_score"] = TARGET_SCORE
        game.metadata["turn_phase"] = "start"

        for player in game.players:
            player.clear_hand()
            player.metadata["score"] = 0

        if game.players:
            game.deck.shuffle()
            game.current_player_index = random.randrange(len(game.players))
            game.set_current_player(game.players[game.current_player_index])
            for _ in range(INITIAL_HAND_SIZE):
                for player in game.players:
                    card = game.deck.draw()
                    if card is not None:
                        player.receive_card(card)
        else:
            game.set_current_player(None)

    def get_available_actions(self, game: Game) -> List[Action]:
        """Return available play actions for the current player."""
        current_player = game.current_player()
        if current_player is None:
            return []

        actions: List[Action] = []

        special_round_active = bool(game.metadata.get("special_round_active", False))
        special_round_player_id = game.metadata.get("special_round_player_id")
        is_special_round_active = (
            special_round_active
            and special_round_player_id is not None
            and current_player.player_id == special_round_player_id
        )

        # Special Round playability:
        # - Safe Round: non-activators cannot play the blocked card type.
        # - Advantage Round (GdV): only Orange cards and +11 can be played.
        sr_type = str(game.metadata.get("special_round_type", "advantage"))
        blocked_type = ""
        if special_round_active and not is_special_round_active and sr_type == "safe":
            blocked_type = str(game.metadata.get("blocked_type", ""))

        def card_playable(card: Card) -> bool:
            if blocked_type and self._is_blocked_type(card, blocked_type):
                return False
            if special_round_active and sr_type == "advantage":
                if not (self._is_increment_card(card) or self._is_jolly_card(card) or self._is_plus11_card(card)):
                    return False
            return True

        # During Special Round: non-activator players with no playable cards
        # get RESET_HAND; Cambio Carta remains available in all cases.
        if special_round_active and not is_special_round_active and current_player.hand.cards:
            if not any(card_playable(c) for c in current_player.hand.cards):
                actions.append(RoadTo100Action(action_type=RESET_HAND_ACTION))
                for card in current_player.hand.cards:
                    actions.append(RoadTo100Action(action_type=CHANGE_CARD_ACTION, parameters={"card": card}))
                return actions

        # Safety net: if the player has no cards at all, offer RESET_HAND
        if not current_player.hand.cards:
            actions.append(RoadTo100Action(action_type=RESET_HAND_ACTION))
            return actions

        # Card play actions
        for card in current_player.hand.cards:
            if special_round_active and not card_playable(card):
                continue

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

        # CHANGE_CARD is always available for every card in hand
        for card in current_player.hand.cards:
            actions.append(
                RoadTo100Action(action_type=CHANGE_CARD_ACTION, parameters={"card": card})
            )

        return actions

    def validate_action(self, game: Game, action: Action) -> bool:
        """Validate an action against the current game state."""
        if not isinstance(action, RoadTo100Action):
            return False

        current_player = game.current_player()
        if current_player is None:
            return False

        card = action.parameters.get("card")
        if action.action_type != RESET_HAND_ACTION:
            if not isinstance(card, Card) or not current_player.has_card(card):
                return False

        special_round_active = bool(game.metadata.get("special_round_active", False))
        special_round_player_id = game.metadata.get("special_round_player_id")
        is_special_round_player = (
            special_round_active
            and special_round_player_id is not None
            and current_player.player_id == special_round_player_id
        )

        if action.action_type == RESET_HAND_ACTION:
            # Always valid when the player has no cards (safety net)
            if not current_player.hand.cards:
                return True
            # During Special Round: valid for non-activator players
            return special_round_active and not is_special_round_player

        if action.action_type == CHANGE_CARD_ACTION:
            return isinstance(card, Card) and current_player.has_card(card)

        sr_type = str(game.metadata.get("special_round_type", "advantage"))

        # Card play actions during Safe Round: non-activators have blocked card types
        if special_round_active and not is_special_round_player and sr_type == "safe":
            blocked_type = str(game.metadata.get("blocked_type", ""))
            if blocked_type and self._is_blocked_type(card, blocked_type):
                return False

        # Card play actions during Advantage Round (GdV only): only Orange and +11 allowed
        if special_round_active and sr_type == "advantage":
            if not (self._is_increment_card(card) or self._is_jolly_card(card) or self._is_plus11_card(card)):
                return False

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
        if action.action_type != RESET_HAND_ACTION:
            if not isinstance(card, Card):
                return

        if action.action_type == RESET_HAND_ACTION:
            cards_to_reset = list(current_player.hand.cards)
            current_player.clear_hand()
            for card in cards_to_reset:
                game.deck.add_card(card)
            game.deck.shuffle()
            for card in self._draw_cards(game, 3):
                current_player.receive_card(card)
            game.metadata["turn_phase"] = "action"
            return

        if action.action_type == CHANGE_CARD_ACTION:
            current_player.play_card(card)
            game.deck.add_card(card)
            game.deck.shuffle()
            drawn_card = self._draw_or_reshuffle(game)
            if drawn_card is not None:
                current_player.receive_card(drawn_card)
            game.metadata["turn_phase"] = "action"
            return

        current_player.play_card(card)

        if not self._is_gold_card(card) and not self._is_special_89_card(card):
            game.discard_pile.append(card)

        if self._is_jolly_card(card):
            chosen_value = int(action.parameters.get("selected_value", 1))
            increment = chosen_value
        elif self._is_imbroglio_card(card):
            increment = int(action.parameters.get("selected_value", 0))
        elif self._is_special_89_card(card):
            increment = 89
            # F7: 89 activates GdV, replacing any active Safe Round; the stale
            # blocked_type must not leak into the GdV.
            game.metadata["special_round_active"] = True
            game.metadata["special_round_player_id"] = current_player.player_id
            game.metadata["special_round_type"] = "advantage"
            game.metadata["_activator_has_played_next"] = False
            game.metadata["blocked_type"] = ""
        elif self._is_plus11_card(card):
            # Check Gold chain: only when the card played immediately before is a
            # normal Gold (12..78), the +11 assumes the next Gold value and
            # activates the matching Special Round. Otherwise it just adds 11
            # and leaves any active Special Round untouched.
            plateau_cards = game.metadata.get("plateau_cards", [])
            gold_chain_value: Optional[int] = None
            if plateau_cards:
                last_card = plateau_cards[-1]
                if self._is_gold_card(last_card):
                    gold_chain_value = self.GOLD_CHAIN.get(int(last_card.value or 0))

            if gold_chain_value is not None:
                increment = gold_chain_value
                game.metadata["special_round_active"] = True
                game.metadata["special_round_player_id"] = current_player.player_id
                game.metadata["_activator_has_played_next"] = False
                if increment == 89:
                    game.metadata["special_round_type"] = "advantage"
                    game.metadata["blocked_type"] = ""
                else:
                    # +11 from Gold chain resolves as a normal Gold: Safe Round,
                    # with the blocked_type chosen in this same play_card action.
                    game.metadata["special_round_type"] = "safe"
                    game.metadata["blocked_type"] = str(action.parameters.get("blocked_type", "") or "")
                game.metadata["_plus11_gold_chain"] = True
            else:
                increment = 11
        elif self._is_gold_card(card):
            increment = int(card.value or 0)
            game.metadata["plateau_value"] = increment
            game.metadata["gold_cards"] = game.metadata.get("gold_cards", []) + [card]
            # F2: Normal Gold (12-78) activates Safe Round.
            # F7: the blocked_type choice is part of this same play_card action
            # and stays unchanged until the Safe Round ends or is replaced.
            game.metadata["special_round_active"] = True
            game.metadata["special_round_player_id"] = current_player.player_id
            game.metadata["special_round_type"] = "safe"
            game.metadata["_activator_has_played_next"] = False
            game.metadata["blocked_type"] = str(action.parameters.get("blocked_type", "") or "")
        else:
            increment = int(card.value or 0)

        plateau = int(game.metadata.get("piatto", 0))
        if self._is_gold_card(card) or self._is_special_89_card(card) or game.metadata.pop("_plus11_gold_chain", False):
            plateau = increment
        else:
            plateau += increment

        # Determine raw_total for bounce/victory logic (for non-Gold/89/+11-gold-chain cards).
        # Gold/89/Gold-chain cards set plateau directly, no bounce.
        raw_total = None
        if not self._is_gold_card(card) and not self._is_special_89_card(card):
            raw_total = plateau  # plateau already has increment added

        sr_active = bool(game.metadata.get("special_round_active", False))
        sr_pid = game.metadata.get("special_round_player_id")
        is_adv_player = sr_pid is not None and current_player.player_id == sr_pid
        is_plus11 = self._is_plus11_card(card)
        sr_type = str(game.metadata.get("special_round_type", "advantage"))
        # F7: only a Giro di Vantaggio grants no-bounce / >=100 victory to the
        # activator. A Safe Round activator plays under the universal rules.
        is_gdv_player = is_adv_player and sr_active and sr_type == "advantage"

        # --- Plateau value computation (bounce / GdV cap) ---
        if raw_total is not None:
            # GdV advantage player and +11 never bounce.
            if is_gdv_player or is_plus11:
                pass  # plateau stays as computed
            elif sr_active:
                if sr_type == "advantage":
                    # GdV: non-activator gets the cap (100→99, no win).
                    if raw_total == TARGET_SCORE:
                        plateau = TARGET_SCORE - 1  # 100 → 99, no win
                    elif raw_total > TARGET_SCORE:
                        plateau = (2 * TARGET_SCORE) - raw_total  # bounce: 200 - raw_total
                else:
                    # Safe Round: everyone (activator included) bounces normally.
                    if raw_total > TARGET_SCORE:
                        plateau = (2 * TARGET_SCORE) - raw_total  # bounce: 200 - raw_total
            else:
                # Outside SR: universal bounce for raw_total > 100.
                if raw_total > TARGET_SCORE:
                    plateau = (2 * TARGET_SCORE) - raw_total  # bounce: 200 - raw_total

        game.metadata.setdefault("plateau_cards", []).append(card)

        # Victory check: +11 wins at Piatto >= 100 (ignores bounce and GdV restriction).
        # GdV advantage player wins at >= 100. Safe Round: normal victory at 100.
        if is_plus11 and plateau >= TARGET_SCORE:
            game.winner = current_player
        elif is_gdv_player and plateau >= TARGET_SCORE:
            game.winner = current_player
        elif sr_active and sr_type == "safe":
            if plateau == TARGET_SCORE or plateau > TARGET_SCORE:
                plateau = TARGET_SCORE
                game.winner = current_player
        elif not sr_active and (plateau == TARGET_SCORE or plateau > TARGET_SCORE):
            plateau = TARGET_SCORE
            game.winner = current_player

        # Store capped plateau value (advantage wins may show raw value for display).
        game.metadata["piatto"] = min(plateau, TARGET_SCORE) if not is_adv_player else plateau

        game.metadata["turn_phase"] = "action"
        drawn_card = self._draw_or_reshuffle(game)
        if drawn_card is not None:
            current_player.receive_card(drawn_card)

    def advance_turn(self, game: Game) -> None:
        """Advance the game flow after an action has been processed."""
        if not game.players:
            return

        previous_player_index = game.current_player_index

        if game.current_player_index is None:
            game.current_player_index = 0
        else:
            game.current_player_index = (game.current_player_index + 1) % len(game.players)

        game.set_current_player(game.players[game.current_player_index])
        game.metadata["turn_phase"] = "start"
        game.turn_number += 1

        # Special Round ends when the activator player completes their NEXT turn
        special_round_active = bool(game.metadata.get("special_round_active", False))
        special_round_player_id = game.metadata.get("special_round_player_id")
        if special_round_active and special_round_player_id is not None:
            prev_player = game.players[previous_player_index]
            if prev_player.player_id == special_round_player_id:
                if game.metadata.get("_activator_has_played_next", False):
                    game.metadata["special_round_active"] = False
                    game.metadata["special_round_player_id"] = None
                    game.metadata["_activator_has_played_next"] = False
                    # F7: blocked_type lives exactly as long as the Safe Round.
                    game.metadata["blocked_type"] = ""
                else:
                    game.metadata["_activator_has_played_next"] = True

    def is_game_over(self, game: Game) -> bool:
        """Return whether the game has reached a terminal state."""
        return game.winner is not None

    def get_winner(self, game: Game) -> Optional[Player]:
        """Return the winning player, if any."""
        return game.winner
