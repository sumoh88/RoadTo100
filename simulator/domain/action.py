"""Generic action abstraction for card-game domains.

Actions are intentionally generic so that different games can define their own
concrete behaviors while reusing a common representation.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class Action:
    """Represents an abstract action that a player may perform.

    Attributes:
        action_type: A generic identifier for the action kind.
        parameters: Arbitrary action-specific data.
    """

    action_type: str
    parameters: dict[str, Any] = field(default_factory=dict)
