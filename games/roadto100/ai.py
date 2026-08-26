"""RoadTo100 AI Bot Implementation.

A heuristic-based bot that makes strategic decisions using visible information only.
Design: score each available action, pick the highest with small random tie-breaking.
"""

from __future__ import annotations

import random
from typing import List, Optional

from simulator.domain.game import Game
from games.roadto100.rules import RoadTo100RuleSet


class RoadTo100Bot:
    """AI bot for RoadTo100 using scoring heuristics.

    Uses only public information (available_actions, current player's hand,
    plateau_cards, special round state). No hidden info or cheating.

    Parameters are exposed as class attributes to allow future personality
    variations without rewriting the core logic.
    """

    # --- Tunable weights (for future difficulty/personality profiles) ---
    W_IMMEDIATE_WIN = 10000       # Score for winning immediately
    W_ADVANCE = 100               # Base score per point of progress toward 100
    W_BOUNCE_PENALTY = -50        # Penalty for actions that cause bounce
    W_INCREMENT_HIGH = 3          # Bonus for high-value increment cards (8-10)
    W_INCREMENT_MED = 2           # Bonus for medium increment (5-7)
    W_INCREMENT_LOW = 1           # Base score for low increment (1-4)
    W_JOLLY_FLEXIBILITY = 15      # Jolly is flexible, add bonus
    W_GOLD_ACTIVATE_SR = 60       # Gold activates Safe Round - strategic value
    W_PLUS11_GOLD_CHAIN = 70      # +11 after Gold creates transformed Gold
    W_PLUS11_NORMAL = 40          # +11 just adds 11 points
    W_PLUS11_HOLD_BACK = -150     # Penalty for using +11 when not strategic (must exceed max advancement 110)
    W_IMBROGLIO_STRATEGIC = 25    # Imbroglio can be used strategically
    W_GDV_BONUS = 30              # Bonus during GdV for +11 or high increments
    W_CHANGE_CARD = -10           # Cambio Carta is last resort (negative score)
    TIE_BREAKER_JITTER = 5        # Max random jitter for tie-breaking

    GOLD_CHAIN = {12: 23, 23: 34, 34: 45, 45: 56, 56: 67, 67: 78, 78: 89}

    def __init__(self):
        self._rules = RoadTo100RuleSet()

    def select_action(self, game: Game) -> dict:
        """Select the best action from available actions.

        Args:
            game: The current game state

        Returns:
            Dictionary representing the selected action with keys:
            - action_type: "play_card", "change_card", or "reset_hand"
            - card_id: The card ID (for play/change)
            - selected_value: Value for Jolly/Imbroglio (if applicable)
        """
        raw_actions = self._rules.get_available_actions(game)

        if not raw_actions:
            return {"action_type": "reset_hand"}

        best_score = float('-inf')
        best_result = None

        for action in raw_actions:
            score = self._score_action(game, action)

            # For Jolly/Imbroglio, select the best value from choices
            chosen_value = -1
            selected_value = action.parameters.get("selected_value")
            if selected_value is not None:
                chosen_value = int(selected_value)

            # Add small random jitter to avoid predictable patterns
            jitter = random.randint(-self.TIE_BREAKER_JITTER, self.TIE_BREAKER_JITTER)
            final_score = score + jitter

            if final_score > best_score:
                best_score = final_score
                card = action.parameters.get("card")
                result = {"action_type": action.action_type}
                if card is not None:
                    result["card_id"] = card.card_id
                if chosen_value >= 0:
                    result["selected_value"] = chosen_value
                best_result = result

        return best_result if best_result else {"action_type": "reset_hand"}

    def _score_action(self, game: Game, action) -> float:
        """Score a single action based on heuristics."""
        action_type = action.action_type
        card = action.parameters.get("card")

        # Get game state info
        plateau = int(game.metadata.get("piatto", 0))
        target_score = int(game.metadata.get("target_score", 100))
        plateau_cards = game.metadata.get("plateau_cards", [])
        last_plateau_card = plateau_cards[-1] if plateau_cards else None
        special_round_active = bool(game.metadata.get("special_round_active", False))
        special_round_player_id = game.metadata.get("special_round_player_id")
        special_round_type = str(game.metadata.get("special_round_type", "advantage"))
        current_player = game.current_player()

        is_activator = (
            special_round_active
            and special_round_player_id is not None
            and current_player is not None
            and current_player.player_id == special_round_player_id
        )

        # --- RESET_HAND scoring ---
        if action_type == "reset_hand":
            return 0.0

        # --- CHANGE_CARD scoring (last resort) ---
        if action_type == "change_card":
            return float(self.W_CHANGE_CARD)

        # --- PLAY_CARD scoring ---
        if action_type != "play_card" or card is None:
            return 0.0

        selected_value = action.parameters.get("selected_value")
        effective_value = self._get_effective_value(card, last_plateau_card, selected_value)

        # --- Immediate win detection ---
        if self._would_win(plateau, card, effective_value, last_plateau_card,
                           special_round_active, special_round_type, is_activator):
            return float(self.W_IMMEDIATE_WIN)

        score = 0.0

        # Calculate bounce potential and advancement toward 100
        card_type_check = str(card.metadata.get("card_type", "")).lower()
        card_name_check = card.name or ""
        is_gold_check = self._is_gold_card(card)
        is_89_check = (card_type_check == "special" and card_name_check == "89")
        is_plus11_check = (card_type_check == "special" and card_name_check == "+11")
        is_gold_chain = is_plus11_check and last_plateau_card and self._is_gold_card(last_plateau_card)

        if is_gold_check or is_89_check or is_gold_chain:
            # Gold/89/Gold-chain set plateau directly, no bounce possible
            score += (effective_value * self.W_ADVANCE) / 10.0
        else:
            raw_new_plateau = plateau + effective_value
            no_bounce = is_plus11_check or (special_round_active and special_round_type == "advantage" and is_activator)
            if raw_new_plateau > target_score and not no_bounce:
                # Bounce will occur - penalize heavily
                score += float(self.W_BOUNCE_PENALTY)
            else:
                # No bounce or bounce exempt - reward advancement
                score += (effective_value * self.W_ADVANCE) / 10.0

        # Card-specific scoring
        card_type = str(card.metadata.get("card_type", "")).lower()
        card_name = card.name or ""

        if card_type == "increment":
            value = card.value or 0
            if value >= 8:
                score += float(self.W_INCREMENT_HIGH)
            elif value >= 5:
                score += float(self.W_INCREMENT_MED)
            else:
                score += float(self.W_INCREMENT_LOW)

        elif card_type == "jolly":
            score += float(self.W_JOLLY_FLEXIBILITY)

        elif card_type == "gold":
            score += float(self.W_GOLD_ACTIVATE_SR)

        elif card_type == "imbroglio":
            score += float(self.W_IMBROGLIO_STRATEGIC)

        elif card_type == "special":
            if card_name == "+11":
                # Check if this +11 would trigger Gold chain (strategic use)
                if last_plateau_card and self._is_gold_card(last_plateau_card):
                    score += float(self.W_PLUS11_GOLD_CHAIN)
                elif special_round_active and special_round_type == "advantage" and is_activator:
                    # +11 during GdV as activator is strategic
                    score += float(self.W_PLUS11_NORMAL + self.W_GDV_BONUS)
                else:
                    # Normal +11 use - apply hold-back penalty unless near win
                    if not self._would_win(plateau, card, effective_value, last_plateau_card,
                                           special_round_active, special_round_type, is_activator):
                        score += float(self.W_PLUS11_HOLD_BACK)
                    else:
                        score += float(self.W_PLUS11_NORMAL)

            elif card_name == "89":
                # 89 is high value but risky (starts GdV)
                score += 50.0  # Strategic value of starting GdV

        # Special Round bonuses
        if special_round_active and special_round_type == "advantage" and is_activator:
            if card_type == "special" and card_name == "+11":
                score += float(self.W_GDV_BONUS)
            elif card_type == "increment" and (card.value or 0) >= 8:
                score += self.W_GDV_BONUS / 2.0

        return score

    def _get_effective_value(self, card, last_plateau_card, selected_value) -> int:
        """Get the effective numeric value a card will contribute."""
        # If value is already selected (Jolly/Imbroglio), use it
        if selected_value is not None:
            return int(selected_value)

        card_type = str(card.metadata.get("card_type", "")).lower()

        if card_type == "jolly":
            return 5  # Default estimate for scoring purposes

        if card_type == "imbroglio":
            return 0  # Conservative estimate (could be positive or negative)

        # For +11 with Gold chain, calculate transformed value
        if card_type == "special" and card.name == "+11":
            if last_plateau_card and self._is_gold_card(last_plateau_card):
                gold_value = int(last_plateau_card.value or 0)
                return self.GOLD_CHAIN.get(gold_value, 11)

        # Default: use card's value
        return card.value or 0

    def _would_win(self, plateau: int, card, effective_value: int, last_plateau_card,
                   sr_active: bool, sr_type: str, is_activator: bool) -> bool:
        """Check if playing this card would win immediately."""
        target = 100
        card_type = str(card.metadata.get("card_type", "")).lower()
        card_name = card.name or ""

        is_gold = self._is_gold_card(card)
        is_89 = (card_type == "special" and card_name == "89")
        is_plus11 = (card_type == "special" and card_name == "+11")

        # Gold, 89, and +11 with Gold chain never win directly
        if is_gold or is_89:
            return False

        if is_plus11 and last_plateau_card and self._is_gold_card(last_plateau_card):
            # Gold chain sets plateau to transformed value (23-89), never wins
            return False

        # Normal cards: compute new plateau
        new_plateau = plateau + effective_value

        if is_plus11:
            # +11 wins at >= 100 regardless of bounce/GdV
            return new_plateau >= target

        # Check SR state for normal cards
        if sr_active and sr_type == "advantage":
            if is_activator:
                # GdV activator: no bounce, wins at >= 100
                return new_plateau >= target
            else:
                # GdV non-activator: capped to 99, never wins
                return False

        # Safe Round or no SR: win at exactly 100 (bounce prevents >100 from winning)
        if sr_active and sr_type == "safe":
            return new_plateau == target

        # No SR: win at exactly 100 (bounce for >100)
        return new_plateau == target

    def _calculate_new_plateau(self, plateau: int, card, effective_value: int,
                                last_plateau_card, sr_active: bool, sr_type: str,
                                is_activator: bool) -> int:
        """Calculate the resulting plateau value after playing this card."""
        target = 100
        card_type = str(card.metadata.get("card_type", "")).lower()
        card_name = card.name or ""

        is_gold = self._is_gold_card(card)
        is_89 = (card_type == "special" and card_name == "89")
        is_plus11 = (card_type == "special" and card_name == "+11")

        # Gold/89 set plateau directly
        if is_gold or is_89:
            return card.value or 0

        # +11 with Gold chain sets plateau to transformed value
        if is_plus11 and last_plateau_card and self._is_gold_card(last_plateau_card):
            gold_value = int(last_plateau_card.value or 0)
            return self.GOLD_CHAIN.get(gold_value, 11)

        # Normal: add to plateau
        new_plateau = plateau + effective_value

        # Apply bounce logic
        if is_plus11 or (sr_active and sr_type == "advantage" and is_activator):
            return new_plateau  # No bounce for +11 or GdV activator

        if sr_active and sr_type == "advantage":
            # GdV non-activator: cap to 99, bounce for >100
            if new_plateau == target:
                return target - 1
            elif new_plateau > target:
                return (2 * target) - new_plateau

        # GS or no SR: normal bounce
        if new_plateau > target:
            return (2 * target) - new_plateau

        return new_plateau

    def _is_gold_card(self, card) -> bool:
        """Check if a card is a Gold card."""
        if card is None:
            return False
        ct = str(card.metadata.get("card_type", "")).lower()
        return ct == "gold" or (card.name and card.name.lower() in {"12", "23", "34", "45", "56", "67", "78"})
