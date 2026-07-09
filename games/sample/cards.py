"""Numeric cards used by the sample game."""

from simulator.domain.card import Card


def build_numeric_cards() -> list[Card]:
    """Create a small deck of numeric cards."""
    cards: list[Card] = []
    for value in range(1, 10):
        cards.append(Card(card_id=f"card_{value}", name=str(value), value=value, color="number"))
    return cards
