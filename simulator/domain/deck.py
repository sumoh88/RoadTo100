"""Generic deck abstraction for card-game domains.

The deck is responsible only for storing and managing cards as a collection.
It does not know the rules of any specific game.
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field
from typing import Iterable, List, Optional

from .card import Card


@dataclass
class Deck:
    """Represents a deck of cards.

    Attributes:
        cards: The cards currently contained in the deck.
    """

    cards: List[Card] = field(default_factory=list)

    def __len__(self) -> int:
        """Return the number of cards in the deck."""
        return len(self.cards)

    def is_empty(self) -> bool:
        """Return whether the deck contains no cards."""
        return len(self.cards) == 0

    def add_card(self, card: Card) -> None:
        """Add a single card to the deck.

        Args:
            card: The card to add.
        """
        self.cards.append(card)

    def add_cards(self, cards: Iterable[Card]) -> None:
        """Add multiple cards to the deck.

        Args:
            cards: An iterable of cards to append.
        """
        self.cards.extend(cards)

    def draw(self) -> Optional[Card]:
        """Draw and remove the top card from the deck.

        The top of the deck is treated as the last card in the list.

        Returns:
            The drawn card, or ``None`` if the deck is empty.
        """
        if self.is_empty():
            return None
        return self.cards.pop()

    def draw_many(self, count: int) -> List[Card]:
        """Draw multiple cards from the deck.

        Args:
            count: The number of cards to draw.

        Returns:
            A list of drawn cards.
        """
        drawn: List[Card] = []
        for _ in range(min(count, len(self.cards))):
            drawn.append(self.draw())
        return drawn

    def shuffle(self) -> None:
        """Shuffle the cards in the deck in place."""
        random.shuffle(self.cards)

    def clear(self) -> None:
        """Remove all cards from the deck."""
        self.cards.clear()
