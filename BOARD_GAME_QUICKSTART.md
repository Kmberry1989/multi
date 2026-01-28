## Quick Start: Integrating the Board Game

### Step 1: Add Board to Level Scene

Open `scenes/level/level.tscn` in Godot editor:

1. Right-click on the Level node
2. Select "Instance Child Scene"
3. Choose `scenes/board/board.tscn`
4. Position it (e.g., `position: (0, 0, 10)`)

### Step 2: Add BoardGameController to GameDirector

In the editor or code, add this to GameDirector:

```gdscript
# In GameDirector._ready() or instantiate in scene
var board_controller = BoardGameController.new()
board_controller.name = "BoardGameController"
add_child(board_controller)

# Optionally configure
board_controller.rounds_per_game = 3
```

### Step 3: Test Local Multiplayer

1. Open the project in Godot 4.5
2. Go to `Debug → Customize Run Instances`
3. Enable "Enable Multiple Instances", set to 2 instances
4. Press F5
5. In first window: Click "Host Game"
6. In second window: Click "Join Game" → connect to localhost
7. Once both players connected, game should auto-transition to BOARD_TURN
8. Click "Roll Dice" to play!

### Step 4: Customize Board

To change spaces:

1. Open `scenes/board/board.tscn`
2. Select `Board/Spaces` node
3. Each child is a space (Marker3D)
4. Edit `metadata/space_type` to: `item`, `minigame`, `bonus`, `trap`, or `normal`
5. Adjust position as desired

### Key Classes You'll Use

| Class | Purpose | Location |
|-------|---------|----------|
| `BoardGameController` | Main orchestrator, handles game flow | `scripts/board/board_game_controller.gd` |
| `TurnManager` | Server-authoritative turn/roll logic | `scripts/board/turn_manager.gd` |
| `BoardManager` | Board layout and space queries | `scripts/board/board_manager.gd` |
| `BoardSpaceEvents` | Space effects (items, bonuses, etc) | `scripts/board/board_space_events.gd` |
| `BoardPlayerToken` | Visual token with animations | `scripts/board/board_player_token.gd` |
| `BoardUI` | Turn info, roll button, status display | `scripts/ui/board_ui.gd` |

### Architecture Highlights

✅ **Server-Authoritative**: All rolls, moves, and effects validated on server  
✅ **Multiplayer-Ready**: Full RPC synchronization for 2-10 players  
✅ **Modular**: Easy to customize spaces, effects, board layout  
✅ **Integrated**: Works with GameDirector state machine  
✅ **Animated**: Smooth token movement, space event messages  

### Networking Flow

```
Player Click "Roll"
    ↓
Client RPC: _request_roll() → Server
    ↓
Server validates turn, rolls dice, moves player
    ↓
Server RPC: _sync_dice_roll() → All Clients
    ↓
Server RPC: _sync_player_movement() → All Clients
    ↓
Clients animate token, show UI feedback
```

No cheating possible—server owns all game state!

### Troubleshooting

**Board not showing?**
- Check that `scenes/board/board.tscn` exists and is instance child of Level
- Verify GameDirector is in scene tree

**Can't click roll button?**
- Ensure you're in BOARD_TURN state
- Check it's your turn (UI should say "Turn: Your Name")
- Verify BoardUI._on_roll_pressed() is wired

**Players not moving?**
- Check NetworkMultiplayer logs for RPC errors
- Verify turn_manager.player_order contains all players
- Check player.get_multiplayer_authority() matches expected peer ID

For full documentation, see **BOARD_GAME_README.md**
