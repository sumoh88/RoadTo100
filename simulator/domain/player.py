"""Generic player abstraction for card-game domains.

The player is responsible only for holding its identity and the cards it owns
in the current game state. It does not contain game-specific rules.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Optional

from .card import Card
from .hand import Hand


@dataclass(slots=True)
class Player:
    """Represents a player in a generic card-game domain.

    Attributes:
        player_id: Unique identifier for the player.
        name: Display name of the player.
        hand: The cards currently held by the player.
        metadata: Additional arbitrary state for future extensibility.
    """

    player_id: str
    name: str = ""
    hand: Hand = field(default_factory=Hand)
    metadata: dict[str, Any] = field(default_factory=dict)

    def receive_card(self, card: Card) -> None:
        """Add a card to the player's hand.

        Args:
            card: The card to add.
        """
        self.hand.add_card(card)

    def receive_cards(self, cards: list[Card]) -> None:
        """Add multiple cards to the player's hand.

        Args:
            cards: The cards to add.
        """
        self.hand.add_cards(cards)

    def play_card(self, card: Card) -> Optional[Card]:
        """Remove a card from the player's hand.

        Args:
            card: The card to remove.

        Returns:
            The removed card, or ``None`` if it was not present.
        """
        return self.hand.remove_card(card)

    def has_card(self, card: Card) -> bool:
        """Return whether the player currently holds the given card."""
        return self.hand.contains(card)

    def clear_hand(self) -> None:
        """Remove all cards from the player's hand."""
        self.hand.clear()
