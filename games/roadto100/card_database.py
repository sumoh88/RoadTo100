"""Card database for RoadTo100.

Static description of every card type defined in ``CARD_DATABASE.md``.
It relies exclusively on the generic :class:`simulator.domain.card.Card`
abstraction and contains **no game logic** (no effects, rules or state
transitions). The actual 60-card deck is assembled in ``deck_definition.py``.
"""

from __future__ import annotations

from simulator.domain.card import Card

# ---------------------------------------------------------------------------
# Categories (field "Tipo" in CARD_DATABASE.md)
# ---------------------------------------------------------------------------
CATEGORY_NORMAL = "normale"
CATEGORY_GOLD = "gold"
CATEGORY_SPECIAL = "speciale"

# Specific card types (sub-types consumed by the rules layer)
CARD_TYPE_INCREMENT = "increment"
CARD_TYPE_JOLLY = "jolly"
CARD_TYPE_GOLD = "gold"
CARD_TYPE_SPECIAL = "special"
CARD_TYPE_IMBROGLIO = "imbroglio"

# ---------------------------------------------------------------------------
# Colors (field "Colore" in CARD_DATABASE.md)
# ---------------------------------------------------------------------------
COLOR_ORANGE = "arancione"
COLOR_GOLD = "dorato"
COLOR_PURPLE = "viola"
COLOR_RED = "rosso"
COLOR_GREEN = "verde"

# ---------------------------------------------------------------------------
# Destinations after a card is played (field "Destinazione")
# ---------------------------------------------------------------------------
DESTINATION_DISCARD = "scarti"
DESTINATION_PLATE = "piatto"

# ---------------------------------------------------------------------------
# Composition constants (fields "Copie" / "Riepilogo del Mazzo")
# ---------------------------------------------------------------------------
INCREMENT_VALUES: tuple[int, ...] = tuple(range(1, 11))  # +1 ... +10
INCREMENT_COPIES_PER_VALUE = 3                            # 30 carte totali
JOLLY_COPIES = 10
GOLD_VALUES: tuple[int, ...] = (12, 23, 34, 45, 56, 67, 78)
GOLD_COPIES = len(GOLD_VALUES)                            # 7 carte
CARD_89_COPIES = 3
PLUS11_COPIES = 5
IMBROGLIO_COPIES = 5

TOTAL_CARDS = (
    len(INCREMENT_VALUES) * INCREMENT_COPIES_PER_VALUE
    + JOLLY_COPIES
    + GOLD_COPIES
    + CARD_89_COPIES
    + PLUS11_COPIES
    + IMBROGLIO_COPIES
)  # 60


def make_increment_card(value: int, copy_index: int = 0) -> Card:
    """Build a single Increment card (+1 ... +10)."""
    return Card(
        card_id=f"increment_{value}_{copy_index}",
        name=f"+{value}",
        value=value,
        color=COLOR_ORANGE,
        metadata={
            "card_type": CARD_TYPE_INCREMENT,
            "category": CATEGORY_NORMAL,
            "destination": DESTINATION_DISCARD,
        },
    )


def make_jolly_card(copy_index: int = 0) -> Card:
    """Build a single Jolly card (player chooses +1 ... +10)."""
    return Card(
        card_id=f"jolly_{copy_index}",
        name="Jolly",
        value=None,
        color=COLOR_ORANGE,
        metadata={
            "card_type": CARD_TYPE_JOLLY,
            "category": CATEGORY_NORMAL,
            "destination": DESTINATION_DISCARD,
        },
    )


def make_gold_card(value: int) -> Card:
    """Build a single Gold card (sets the Plate to its value)."""
    return Card(
        card_id=f"gold_{value}",
        name=str(value),
        value=value,
        color=COLOR_GOLD,
        metadata={
            "card_type": CARD_TYPE_GOLD,
            "category": CATEGORY_GOLD,
            "destination": DESTINATION_PLATE,
        },
    )


def make_89_card(copy_index: int = 0) -> Card:
    """Build a single 89 card (sets the Plate to 89, starts the Advantage Round)."""
    return Card(
        card_id=f"card89_{copy_index}",
        name="89",
        value=89,
        color=COLOR_PURPLE,
        metadata={
            "card_type": CARD_TYPE_SPECIAL,
            "category": CATEGORY_SPECIAL,
            "destination": DESTINATION_PLATE,
        },
    )


def make_plus11_card(copy_index: int = 0) -> Card:
    """Build a single +11 card (adds 11 to the Plate)."""
    return Card(
        card_id=f"plus11_{copy_index}",
        name="+11",
        value=11,
        color=COLOR_RED,
        metadata={
            "card_type": CARD_TYPE_SPECIAL,
            "category": CATEGORY_SPECIAL,
            "destination": DESTINATION_DISCARD,
        },
    )


def make_imbroglio_card(copy_index: int = 0) -> Card:
    """Build a single Imbroglio card (player chooses -15 ... +15, 0 excluded)."""
    return Card(
        card_id=f"imbroglio_{copy_index}",
        name="Imbroglio",
        value=None,
        color=COLOR_GREEN,
        metadata={
            "card_type": CARD_TYPE_IMBROGLIO,
            "category": CATEGORY_SPECIAL,
            "destination": DESTINATION_DISCARD,
        },
    )


__all__ = [
    "CATEGORY_NORMAL",
    "CATEGORY_GOLD",
    "CATEGORY_SPECIAL",
    "CARD_TYPE_INCREMENT",
    "CARD_TYPE_JOLLY",
    "CARD_TYPE_GOLD",
    "CARD_TYPE_SPECIAL",
    "CARD_TYPE_IMBROGLIO",
    "COLOR_ORANGE",
    "COLOR_GOLD",
    "COLOR_PURPLE",
    "COLOR_RED",
    "COLOR_GREEN",
    "DESTINATION_DISCARD",
    "DESTINATION_PLATE",
    "INCREMENT_VALUES",
    "INCREMENT_COPIES_PER_VALUE",
    "JOLLY_COPIES",
    "GOLD_VALUES",
    "GOLD_COPIES",
    "CARD_89_COPIES",
    "PLUS11_COPIES",
    "IMBROGLIO_COPIES",
    "TOTAL_CARDS",
    "make_increment_card",
    "make_jolly_card",
    "make_gold_card",
    "make_89_card",
    "make_plus11_card",
    "make_imbroglio_card",
]
