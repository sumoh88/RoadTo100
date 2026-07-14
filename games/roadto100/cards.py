"""Card definitions and deck construction for RoadTo100."""

from __future__ import annotations

from enum import Enum
from typing import Union

from simulator.domain.card import Card

from .card_database import (
    CARD_89_COPIES,
    GOLD_VALUES,
    IMBROGLIO_COPIES,
    INCREMENT_COPIES_PER_VALUE,
    INCREMENT_VALUES,
    JOLLY_COPIES,
    PLUS11_COPIES,
    make_89_card,
    make_gold_card,
    make_imbroglio_card,
    make_increment_card,
    make_jolly_card,
    make_plus11_card,
)
from .config import CARD_COLORS


class CardType(str, Enum):
    """High-level card categories used by RoadTo100."""

    INCREMENT = "increment"
    JOLLY = "jolly"
    GOLD = "gold"
    IMBROGLIO = "imbroglio"
    SPECIAL = "special"


def build_card(card_id: str, name: str, value: int = None, card_type: Union[CardType, str] = CardType.INCREMENT, color: str = None) -> Card:
    """Create a generic card for RoadTo100."""
    if isinstance(card_type, CardType):
        resolved_type = card_type.value
        resolved_color = color or CARD_COLORS.get(card_type.value, "orange")
    else:
        resolved_type = card_type
        resolved_color = color or CARD_COLORS.get(card_type, "orange")

    return Card(
        card_id=card_id,
        name=name,
        value=value,
        color=resolved_color,
        metadata={"card_type": resolved_type},
    )


def build_deck() -> list:
    """Build the full 60-card deck for RoadTo100."""
    cards = []
    for value in INCREMENT_VALUES:
        for copy_index in range(INCREMENT_COPIES_PER_VALUE):
            cards.append(make_increment_card(value, copy_index))
    for copy_index in range(JOLLY_COPIES):
        cards.append(make_jolly_card(copy_index))
    for value in GOLD_VALUES:
        cards.append(make_gold_card(value))
    for copy_index in range(CARD_89_COPIES):
        cards.append(make_89_card(copy_index))
    for copy_index in range(PLUS11_COPIES):
        cards.append(make_plus11_card(copy_index))
    for copy_index in range(IMBROGLIO_COPIES):
        cards.append(make_imbroglio_card(copy_index))
    return cards
