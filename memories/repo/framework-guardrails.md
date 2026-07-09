# Framework guardrails

- simulator/domain is frozen.
- simulator/engine is frozen.
- ENGINE_API.md is the framework contract.

Development rules:
1. All new games must be implemented exclusively in games/.
2. Do not modify domain or engine unless there is a real bug or a concrete, demonstrated limitation from an implemented game.
3. Do not modify the framework for theoretical improvements or future use cases.
4. If a game reveals a framework limitation, stop, describe the limitation precisely, propose the minimal change needed, and do not apply it automatically.
5. Any future framework change must be motivated by at least one concrete case from an implemented game.
