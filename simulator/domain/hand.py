"""Generic hand abstraction for card-game domains.

The hand is responsible only for storing the cards currently held by a player.
It does not encode any rule about how cards may be used.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Iterable, Optional

from .card import Card


@dataclass(slots=True)
class Hand:
    """Represents the cards currently held by a player.

    Attributes:
        cards: The cards currently in the hand.
    """

    cards: list[Card] = field(default_factory=list)

    def __len__(self) -> int:
        """Return the number of cards in the hand."""
        return len(self.cards)

    def is_empty(self) -> bool:
        """Return whether the hand contains no cards."""
        return len(self.cards) == 0

    def add_card(self, card: Card) -> None:
        """Add a single card to the hand.

        Args:
            card: The card to add.
        """
        self.cards.append(card)

    def add_cards(self, cards: Iterable[Card]) -> None:
        """Add multiple cards to the hand.

        Args:
            cards: An iterable of cards to add.
        """
        self.cards.extend(cards)

    def remove_card(self, card: Card) -> Optional[Card]:
        """Remove a specific card from the hand.

        Args:
            card: The card to remove.

        Returns:
            The removed card, or ``None`` if it was not present.
        """
        if card in self.cards:
            self.cards.remove(card)
            return card
        return None

    def clear(self) -> None:
        """Remove all cards from the hand."""
        self.cards.clear()

    def contains(self, card: Card) -> bool:
        """Return whether the given card is present in the hand."""
        return card in self.cards
