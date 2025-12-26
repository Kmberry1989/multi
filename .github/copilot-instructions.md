# Copilot Instructions for this Repo

Purpose: help AI coding agents become immediately productive in this Godot 3D multiplayer template.

1. Big picture
- Godot 4.5 3D multiplayer template. Entry scene: `scenes/level/level.tscn` ([project.godot](project.godot#L1)).
- Two autoloads provide core services: `Network` (`scripts/network.gd`) and `ItemDatabase` (`scripts/item_database.gd`) — both are singletons used across scenes ([project.godot](project.godot#L1)).
- Server-authoritative design: server (peer id 1) owns authoritative game state (inventories, authoritative movement decisions). Clients request changes via RPCs and server validates and syncs state back.

2. Key runtime and developer workflows
- Run in editor: open project in Godot and press F5 or use `Debug → Customize Run Instances` to enable multiple instances for local multiplayer testing ([README.md](README.md#L1)).
- Dedicated (headless) server: execute `./run_headless_server.sh` (ensure `godot` in PATH and `chmod +x run_headless_server.sh`) — script calls `godot --headless --path .` ([run_headless_server.sh](run_headless_server.sh#L1)).

3. Networking and RPC conventions
- ENet on port 8080: defaults in `scripts/network.gd` (`SERVER_PORT = 8080`, `MAX_PLAYERS = 10`) — host with `Network.start_host(...)`, join with `Network.join_game(...)` ([scripts/network.gd](scripts/network.gd#L1)).
- Use Godot `@rpc(...)` with explicit modes. Examples: `@rpc("any_peer","reliable")` and `@rpc("any_peer","call_local","reliable")` used heavily in `scripts/player.gd` for inventory RPCs (e.g., `request_move_item`, `request_add_item`, `sync_inventory_to_owner`) ([scripts/player.gd](scripts/player.gd#L1)).
- Authority mapping pattern: players set authority via `set_multiplayer_authority(str(name).to_int())` in `_enter_tree()` (node `name` is expected to equal the peer id). AI edits should preserve this pattern rather than changing authority logic without careful testing ([scripts/player.gd](scripts/player.gd#L1)).
- Headless checks: code often guards UI/visual logic with `if DisplayServer.get_name() == "headless": return` — keep headless-safe changes in server code paths ([scripts/network.gd](scripts/network.gd#L1)).

4. Inventory & Item patterns
- `ItemDatabase` is an autoload singleton used to look up items by id (`ItemDatabase.get_item("iron_sword")`) — changes to IDs or schemas must update usages across `player.gd`, `player_inventory.gd`, and UI scripts.
- Inventory is server-authoritative: clients call `request_*` RPCs; server validates and then calls `sync_inventory_to_owner.rpc_id(owner_id, data)` to update owner — see `request_move_item`, `request_add_item`, and `request_remove_item` ([scripts/player.gd](scripts/player.gd#L1)).

5. UI and scene conventions
- Main scene: `scenes/level/level.tscn`. UI nodes often live under the current scene (e.g., `InventoryUI` node expected by player sync code). When updating UIs, prefer calling scene methods like `update_local_inventory_display()` when available.
 - Character models: scenes now support a `CharacterModel` child node to host external character scenes (example: `scenes/characters/brawler.tscn`). `player.gd` will search for `CharacterModel` first and fall back to the embedded `3DGodotRobot` node. Use `CharacterModel` when swapping unique models or reusing shared animations.

6. Style & project-specific conventions
- Node naming: some code expects player node `name` to be the numeric peer id. Preserve or explicitly migrate this behavior.
- Server id 1 is treated as the authoritative server in RPC checks (many places compare to `1`).
- Use existing signals: `Network` emits `player_connected` and `server_disconnected` — prefer reusing them for new features instead of duplicating event plumbing ([scripts/network.gd](scripts/network.gd#L1)).

7. Quick examples to reference when editing
- Start a host: `Network.start_host(nickname, skin_name)` — see `scripts/network.gd`.
- Join game: `Network.join_game(nickname, skin_name, address)` — default address `127.0.0.1:8080`.
- Add starting items on player creation: `_add_starting_items()` uses `ItemDatabase.get_item("iron_sword")` and `ItemDatabase.get_item("health_potion")` ([scripts/player.gd](scripts/player.gd#L1)).
 - Character scenes: reusable character scenes live in `scenes/characters/*.tscn` (examples: `scenes/characters/kyle.tscn`, `scenes/characters/eric.tscn`). Use the `scripts/character_switcher.gd` helper to swap a player's `CharacterModel` at runtime.

8. Safety notes for AI edits
- Avoid refactoring authority or networking message formats without test harnesses — small changes can break synchronization in subtle ways.
- Preserve RPC signatures and reliability modifiers when changing network functions; breaking these will change runtime behavior across clients.

If anything here is unclear or you want me to emphasize other files (e.g., `scripts/inventory_ui.gd`, `scripts/network.gd`), tell me which areas to expand or merge. I'll iterate on the draft.
