"""Generic card abstraction for card-game domains.

This module defines the minimum reusable representation of a card. It remains
fully generic so it can be used by different card games without embedding
rules or game-specific behavior.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Optional


@dataclass(slots=True)
class Card:
    """Represents a single card in a generic card-game domain.

    Attributes:
        card_id: Unique identifier for the card.
        name: Human-readable name of the card.
        value: Optional numeric value associated with the card.
        color: Optional category or color used by the game.
        metadata: Additional arbitrary attributes for future extensibility.
    """

    card_id: str
    name: str = ""
    value: Optional[int] = None
    color: Optional[str] = None
    metadata: dict[str, Any] = field(default_factory=dict)
