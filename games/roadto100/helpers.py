"""Shared helpers for RoadTo100."""

from __future__ import annotations


def clamp_plateau(value: int) -> int:
    """Clamp the shared plateau value to a non-negative minimum."""
    # TODO: implement plateau handling.
    return max(0, value)
