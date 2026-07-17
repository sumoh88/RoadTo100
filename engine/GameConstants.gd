extends Node
class_name GameConstants

# ---------------------------------------------------------------------------
# Generic game phase enum (mirrors Python simulator.domain.game.GamePhase)
# ---------------------------------------------------------------------------
enum GamePhase { SETUP, PLAYING, FINISHED }

# ---------------------------------------------------------------------------
# Card categories (mirrors Python card_database.py constant strings)
# ---------------------------------------------------------------------------
const CATEGORY_NORMAL = "normale"
const CATEGORY_GOLD = "gold"
const CATEGORY_SPECIAL = "speciale"

# Card types (mirrors Python CARD_TYPE_* constants)
const CARD_TYPE_INCREMENT = "increment"
const CARD_TYPE_JOLLY = "jolly"
const CARD_TYPE_GOLD = "gold"
const CARD_TYPE_SPECIAL = "special"
const CARD_TYPE_IMBROGLIO = "imbroglio"

# Card colors (mirrors Python COLOR_* constants)
const COLOR_ORANGE = "arancione"
const COLOR_GOLD = "dorato"
const COLOR_PURPLE = "viola"
const COLOR_RED = "rosso"
const COLOR_GREEN = "verde"

# Card destinations after being played
const DESTINATION_DISCARD = "scarti"
const DESTINATION_PLATE = "piatto"

# ---------------------------------------------------------------------------
# Game configuration (mirrors Python config.py)
# ---------------------------------------------------------------------------
const TARGET_SCORE = 100
const INITIAL_HAND_SIZE = 3
const MAX_TURNS = 1000
const DEFAULT_PLAYER_COUNT = 2
const SUPPORTED_PLAYER_COUNTS = [2, 3, 4]

# +11 Gold chain: mirrors Python games/roadto100/rules.py GOLD_CHAIN
const GOLD_CHAIN = {12: 23, 23: 34, 34: 45, 45: 56, 56: 67, 67: 78, 78: 89}

# ---------------------------------------------------------------------------
# Deck composition (mirrors Python card_database.py)
# ---------------------------------------------------------------------------
const INCREMENT_VALUES = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
const INCREMENT_COPIES_PER_VALUE = 3
const JOLLY_COPIES = 10
const GOLD_VALUES = [12, 23, 34, 45, 56, 67, 78]
const CARD_89_COPIES = 3
const PLUS11_COPIES = 5
const IMBROGLIO_COPIES = 5
