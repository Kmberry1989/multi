# Board Game System Documentation

## Overview

The board game is a fully multiplayer, server-authoritative game mode integrated with the Godot 3D multiplayer template. Players move around a board based on dice rolls, land on spaces with effects, and compete to reach the highest score.

## Architecture

### Core Components

1. **BoardManager** (`scripts/board/board_manager.gd`)
   - Manages board layout, spaces, and space types
   - Automatically creates visual representations for spaces
   - Supports circular or linear board paths
   - Space types: `item`, `minigame`, `bonus`, `trap`, `normal`

2. **TurnManager** (`scripts/board/turn_manager.gd`) - **SERVER-AUTHORITATIVE**
   - Manages turn order, dice rolls, and player movement
   - Runs all game logic on server, syncs to clients via RPCs
   - Handles space event triggering
   - Network RPCs:
     - `_request_roll()`: Client requests to roll dice
     - `_sync_dice_roll()`: Server broadcasts roll result
     - `_sync_player_movement()`: Server broadcasts player movement

3. **BoardSpaceEvents** (`scripts/board/board_space_events.gd`) - **SERVER-AUTHORITATIVE**
   - Applies effects when players land on spaces
   - Effects include item rewards, point bonuses, traps, and minigame triggers
   - All effects validated and applied on server, synced to clients

4. **BoardPlayerToken** (`scripts/board/board_player_token.gd`)
   - Visual representation of a player on the board
   - Handles movement animations
   - Displays player name above token

5. **BoardUI** (`scripts/ui/board_ui.gd`)
   - Displays current player turn, round, and status
   - Shows space event messages with animations
   - Roll button (server validates request)

6. **BoardGameController** (`scripts/board/board_game_controller.gd`)
   - Orchestrates the entire board game
   - Integrates with GameDirector state machine
   - Manages player tokens and game flow
   - Tracks scores and determines winners

## Game Flow

```
START_GAME
    ├─ TurnManager.register_player() for each player
    ├─ Create BoardPlayerToken for each player at space 0
    └─ TurnManager.start_turn()

EACH_TURN
    ├─ Player clicks "Roll Dice" button
    ├─ Client sends _request_roll() RPC to server
    ├─ Server validates it's player's turn, rolls dice
    ├─ Server broadcasts _sync_dice_roll() to all clients
    ├─ Server moves player and broadcasts _sync_player_movement()
    ├─ Server triggers space event effects
    ├─ BoardUI displays result and space effect
    ├─ Token animates to new position
    └─ TurnManager.start_turn() for next player

SPACE_EFFECTS
    ├─ ITEM: Player gains random item (calls player.request_add_item)
    ├─ BONUS: Player gains 10 points
    ├─ TRAP: Player loses 5 points
    └─ MINIGAME: Trigger minigame sequence

ROUND_COMPLETE
    ├─ After all players have taken turns
    └─ Move to next round (repeat)

END_GAME
    ├─ After N rounds complete
    ├─ Calculate winner (highest score)
    ├─ Emit board_game_ended() signal
    └─ Transition to RESULTS state in GameDirector
```

## Network Protocol

All game logic is **server-authoritative** to prevent cheating:

### Client → Server
```gdscript
_request_roll()  # Client tells server player wants to roll
```

### Server → All Clients
```gdscript
_sync_dice_roll(player_index: int, roll: int)
_sync_player_movement(player_index: int, from_index: int, to_index: int)
```

**Key Principle:** Server validates all moves before syncing. Clients cannot roll twice, move backwards, or trigger effects without server approval.

## Setup Instructions

### 1. Add Board Scene to Level

In `scenes/level/level.tscn`, add the board as a child node:

```
Level (Node3D)
├─ Board (Node3D) → Instance res://scenes/board/board.tscn
├─ GameDirector
├─ Players
└─ UI
```

### 2. Configure GameDirector

In `GameDirector._ready()` or in the editor:

```gdscript
# Add BoardGameController as child of GameDirector
var board_controller = BoardGameController.new()
board_controller.name = "BoardGameController"
add_child(board_controller)
```

### 3. Integrate with Game States

In `GameDirector._apply_state()`:

```gdscript
match new_state:
    State.BOARD_TURN:
        # Show board, hide other UIs
        board_node.visible = true
        # Board game auto-starts via BoardGameController
    State.MINIGAME:
        # Pause board during minigame
        pass
    State.RESULTS:
        # Show final scores from board game
        show_leaderboard()
```

## Customizing the Board

### Change Number of Spaces

Edit `scenes/board/board.tscn`:
- Select `Board/Spaces` node
- Each child Marker3D is a space
- Add/remove spaces and update `metadata/space_type`

### Change Space Types

Set the `space_type` metadata on each space node:
- `"item"` - Yellow, grants random item
- `"minigame"` - Cyan, triggers minigame
- `"bonus"` - Green, +10 points
- `"trap"` - Red, -5 points
- `"normal"` - White, no effect

### Change Board Path

Edit the `Path/Curve` in `scenes/board/board.tscn`:
- The curve visualizes the path around the board
- Spaces don't have to follow the curve (visual only)

### Change Space Effects

Edit `BoardSpaceEvents._get_space_effect()`:

```gdscript
func _get_space_effect(space_type: String) -> Dictionary:
    match space_type:
        "item":
            return {"type": "item", "count": 2}  # Give 2 items instead of 1
        "bonus":
            return {"type": "bonus", "points": 20}  # 20 points instead of 10
        ...
```

## Debugging

### Enable Board Visualization
```gdscript
board_manager.visualize_spaces = true
```
This creates colored cubes on each space showing its type.

### Check Player Positions
```gdscript
var positions = turn_manager.player_order.map(func(p): return p.get_meta("board_index"))
print("Player positions: ", positions)
```

### Monitor RPC Calls
Enable debug logging in TurnManager:
```gdscript
print("Roll request from peer %d" % multiplayer.get_remote_sender_id())
```

## Common Issues & Fixes

**Problem:** Board doesn't appear in game
- **Fix:** Check GameDirector integration; ensure board scene is instantiated before `_ready()`

**Problem:** Players can't roll dice
- **Fix:** Verify TurnManager has correct paths to board_manager and game_director
- **Fix:** Check multiplayer.is_server() to ensure RPC authority

**Problem:** Movement not syncing to other players
- **Fix:** Ensure TurnManager._sync_player_movement is marked with @rpc("authority", "reliable", "call_local")
- **Fix:** Check player positions update on clients via BoardPlayerToken.move_to_position()

**Problem:** Score not updating
- **Fix:** Verify player has "board_score" metadata set before space effects applied
- **Fix:** Check BoardSpaceEvents._apply_bonus_effect() is called on server

## Future Enhancements

1. **Persistence:** Save board game scores to leaderboard
2. **Animations:** Add dice roll animation, celebrate when landing on bonus
3. **Special Spaces:** Warp holes, shortcuts, skip-turn traps
4. **Power-ups:** Reroll, double move, extra points
5. **Multiplayer Events:** Steal points from other players, race to finish
6. **Board Themes:** Different visual themes (candy land, space, medieval)
7. **Difficulty Levels:** Variable number of rounds, space effects

## Classes Reference

### BoardManager
```gdscript
func get_space_count() -> int
func get_space_position(index: int) -> Vector3
func get_space_type(index: int) -> String
func get_next_index(current_index: int, steps: int) -> int
```

### TurnManager
```gdscript
func register_player(player: Node3D, start_index: int = 0) -> void
func start_turn() -> void
func roll_current_player() -> void
func get_current_player() -> Node3D
func is_player_turn(player: Node3D) -> bool
func reset() -> void
```

### BoardSpaceEvents
```gdscript
func apply_space_effect(player: Node3D, space_type: String) -> void
```

### BoardPlayerToken
```gdscript
func setup(id: int, name: String, color: Color) -> void
func move_to_position(target_pos: Vector3) -> void
```

### BoardUI
```gdscript
func setup(tm: TurnManager) -> void
func set_turn_info(player_name: String, round_number: int) -> void
func set_status(text: String) -> void
func show_space_event(space_type: String, player_name: String) -> void
```

### BoardGameController
```gdscript
func start_board_game(players: Array = []) -> void
func end_board_game() -> void
func get_leaderboard() -> Array
```
