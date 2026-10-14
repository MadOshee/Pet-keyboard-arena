# Egg Keyboard Arena: notes for Claude

- Owner: Ivan. He does not write code and tests builds in Roblox Studio via Play. Talk to him in Russian.
- Design and architecture are approved: `docs/design.md` (decisions D1–D11). Explain any change to the agreed architecture before making it.
- Work stage by stage per `docs/design.md` section 12. Each stage: full code, test checklist for Ivan, update `docs/module-registry.md`.
- Layout: services (server) and controllers (client) with `Init()`/`Start()` run by `Shared/Util/Loader`; order is the explicit list in each Bootstrap. Dependencies go down the layers; upward communication uses signals.
- Pure logic (no Roblox APIs) lives in `src/shared/Logic` and gets Lune tests in `tests/*.spec.luau`.
- Server is authoritative for coins, pets, eggs, painting, hits and rewards. Clients send ids and intents, never results.
- Every `.luau` file starts with `--!strict`. CI runs StyLua, Selene, Lune tests, luau-lsp analyze and `rojo build`; keep it green.
