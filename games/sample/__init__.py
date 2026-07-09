"""Minimal sample game for validating the generic simulator framework."""

from .rules import SampleActionController, SampleRuleSet
from .setup import build_game, run_sample

__all__ = ["SampleActionController", "SampleRuleSet", "build_game", "run_sample"]
