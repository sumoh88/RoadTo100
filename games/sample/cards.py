"""Numeric cards used by the sample game."""

from __future__ import annotations

from typing import List

from simulator.domain.card import Card


def build_numeric_cards() -> List[Card]:
    """Create a small deck of numeric cards."""
    cards: List[Card] = []
    for value in range(1, 10):
        cards.append(Card(card_id=f"card_{value}", name=str(value), value=value, color="number"))
    return cards
