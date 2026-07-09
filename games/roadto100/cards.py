"""Card definitions and deck construction for RoadTo100."""

from __future__ import annotations

from enum import Enum

from simulator.domain.card import Card

from .config import CARD_COLORS


class CardType(str, Enum):
    """High-level card categories used by RoadTo100."""

    INCREMENT = "increment"
    JOLLY = "jolly"
    GOLD = "gold"
    IMBROGLIO = "imbroglio"
    SPECIAL = "special"


def build_card(card_id: str, name: str, value: int | None = None, card_type: CardType | str = CardType.INCREMENT, color: str | None = None) -> Card:
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


def build_deck() -> list[Card]:
    """Create a deck with increment cards and Jolly cards for the base flow."""
    cards: list[Card] = []
    for value in range(1, 11):
        for copy_index in range(3):
            cards.append(
                build_card(
                    card_id=f"increment_{value}_{copy_index}",
                    name=f"+{value}",
                    value=value,
                    card_type=CardType.INCREMENT,
                    color="orange",
                )
            )

    cards.append(
        build_card(
            card_id="jolly_1",
            name="Jolly",
            value=None,
            card_type=CardType.JOLLY,
            color="orange",
        )
    )

    for gold_value in [12, 23, 34, 45, 56, 67, 78]:
        cards.append(
            build_card(
                card_id=f"gold_{gold_value}",
                name=str(gold_value),
                value=gold_value,
                card_type=CardType.GOLD,
                color="gold",
            )
        )

    cards.append(
        build_card(
            card_id="imbroglio_1",
            name="Imbroglio",
            value=None,
            card_type=CardType.IMBROGLIO,
            color="green",
        )
    )

    cards.append(
        build_card(
            card_id="special_89",
            name="89",
            value=89,
            card_type=CardType.SPECIAL,
            color="purple",
        )
    )

    cards.append(
        build_card(
            card_id="special_plus11",
            name="+11",
            value=11,
            card_type=CardType.SPECIAL,
            color="red",
        )
    )

    return cards
