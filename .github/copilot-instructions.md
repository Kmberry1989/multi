# Copilot Instructions for this Repo

Purpose: help AI coding agents become immediately productive in this Godot 3D multiplayer template.

## 1. Big Picture Architecture

- **Godot 4.5 3D multiplayer template** with entry scene [scenes/level/level.tscn](scenes/level/level.tscn)
- **Two core autoloads** (singletons): [Network](scripts/network.gd) manages ENet connections; [ItemDatabase](scripts/item_database.gd) provides item lookups
- **Server-authoritative design**: peer 1 (server) owns authoritative game state—inventories, movement decisions, state transitions. Clients request changes via RPCs; server validates, executes, and syncs back
- **Multiple game modes** managed by [GameDirector](scripts/game_director.gd): LOBBY, BOARD_TURN, MINIGAME, RESULTS, BRAWL, KART
- **10-player max** (configurable in [Network](scripts/network.gd): `MAX_PLAYERS = 10`)

## 2. Developer Workflows

**Local multiplayer testing:**
- Press **F5** to run; use `Debug → Customize Run Instances` to spawn multiple editor instances
- **Dedicated headless server**: `./run_headless_server.sh` (requires `godot` in PATH, `chmod +x`)

**Debug shortcuts:** W/A/S/D move, Shift sprint, Space jump, Ctrl toggle chat, B toggle inventory, F1/F2 debug items

## 3. Networking & RPC Conventions

- **ENet, port 8080**: `Network.start_host(nick, skin, character)` and `Network.join_game(nick, skin, address, character)` create connections
- **RPC patterns**: use `@rpc("any_peer","reliable")` or `@rpc("any_peer","call_local","reliable")`. Examples in [player.gd](scripts/player.gd): `request_move_item`, `request_add_item`, `sync_inventory_to_owner`
- **Authority**: players set `set_multiplayer_authority(str(name).to_int())` in `_enter_tree()` — node name must equal peer id. Preserve this pattern; don't refactor lightly
- **Headless safety**: guard UI/visual logic with `if DisplayServer.get_name() == "headless": return` — keep headless-safe in server paths

## 4. Inventory & Items

- **[ItemDatabase](scripts/item_database.gd)** is a singleton: `ItemDatabase.get_item("iron_sword")` returns Item objects. Item IDs must be unique; changes ripple through [player.gd](scripts/player.gd), [player_inventory.gd](scripts/player_inventory.gd), UI
- **Server-authoritative flow**: client calls `request_move_item(from, to)` RPC → server validates in `_on_request_move_item()` → server calls `sync_inventory_to_owner.rpc_id(owner_id, data)` to update client
- **20-slot grid layout**, drag-and-drop supported

## 5. Character & Model Conventions

- **Character swapper**: [CharacterSwitcher](scripts/character_switcher.gd) holds a dict of character scenes (kyle, eric, donald, kristen, etc.)
- **Player node structure**: players look for a `CharacterModel` child node first; fall back to embedded `3DGodotRobot` node if absent
- **Runtime model swaps**: `CharacterSwitcher.set_model(player_node, "kyle")` replaces the `CharacterModel` child
- **Available characters**: [scenes/characters/](scenes/characters/) (kyle.tscn, eric.tscn, donald.tscn, kristen.tscn, rochelle.tscn, vickie.tscn, connie.tscn, caleb.tscn, bethany.tscn, maia.tscn)

## 6. Game States & Scene Structure

- **Lobby**: main_menu_ui, lobby_ui handle authentication and host/join
- **Level** ([scenes/level/level.tscn](scenes/level/level.tscn)): main play scene with player spawning, inventory UI, chat
- **Minigames** ([scripts/minigame_manager.gd](scripts/minigame_manager.gd)): manage sequences, timers, state callbacks
- **Board, Kart, Brawl** modes: each tied to a game state in [GameDirector](scripts/game_director.gd); spawn/manage specialized scenes

## 7. Style & Conventions

- **Server peer id = 1**: compare against `1` for server checks
- **Signals over events**: [Network](scripts/network.gd) emits `player_connected` and `server_disconnected`; reuse them instead of creating duplicates
- **@export**: use for tunable game params (see [GameDirector](scripts/game_director.gd): microgame_duration_min, interstitial_duration)
- **Headless-aware**: avoid UI creation/calls in headless paths

## 8. Critical Safety Notes

- **Authority & sync are fragile**: changing RPC signatures or peer id mappings breaks client-server sync subtly. Test with multiple instances
- **Preserve RPC reliability modes**: `reliable` vs `unreliable` affects network behavior; don't swap without testing
- **Inventory schema changes**: update ItemDatabase, all references in player scripts, and UI displays in one pass
- **State transitions**: use `GameDirector.request_state_change()` (client) or `_apply_state()` (server) to keep states synchronized
