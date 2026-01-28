# Portrait-Style Character Selection Implementation

## Overview

This implementation brings the portrait-style character selection UI from the Sakuga Engine into the multi project. The system includes:

1. **CharacterPortraitButton** - Individual character portrait buttons with hover/select states
2. **CharacterSelectUI** - Grid-based character selection screen
3. **PlayerReadyUI** - VS screen animation showing both players' selected characters
4. **LobbyCharacterSelect** - Complete lobby scene combining selection and ready screens

## Components Created

### 1. Character Portrait Button (`character_portrait_button.tscn` / `.gd`)

A reusable portrait button component with:
- Character portrait texture display
- Hover state visualization (HOVERED.png overlay)
- Selection flash animation (SELECTED.png overlay)
- Signals for selection and hovering states

**Key Features:**
- Automatically loads character portraits from `res://assets/characters/player/Portraits/{CHARACTER}.png`
- Displays HOVERED and SELECTED overlay textures on interaction
- Emits `selected`, `hovered`, and `unhovered` signals
- 200x200 custom size with expandable mode

### 2. Character Select UI (`character_select_ui.tscn` / `.gd`)

Main character selection interface featuring:
- 5-column grid of all 10 character portrait buttons
- "Select Your Character" title
- Live preview of selected character with ready image
- Host, Join, and Quit action buttons at the bottom
- Confirm/Ready button (disabled until character selected)

**Signals:**
- `character_selected(character_name)` - Emitted when a character portrait is clicked
- `selection_confirmed(character_name)` - Emitted when "Ready" button is pressed
- `host_pressed()` - Emitted when Host button is clicked
- `join_pressed()` - Emitted when Join button is clicked
- `quit_pressed()` - Emitted when Quit button is clicked

**Methods:**
- `reset()` - Clears selection state and resets all button states
- `get_selected_character()` - Returns currently selected character name

### 3. Player Ready UI (`player_ready_ui.tscn` / `.gd`)

VS screen animation showing both players' selected characters:
- Side-by-side character ready images
- "VS" label in the center
- Animated slide-in and fade transitions
- Parallel animation for smooth visual effect

**Features:**
- Slides Player 1 from left, Player 2 from right
- Fades in character images with 0.6s animation
- VS label pulses and scales during appearance
- Automatically waits 1.75s after animation before emitting `animation_finished` signal

**Methods:**
- `show_ready_screen(player1_name, player2_name)` - Displays the ready screen with animation
- `hide_ready_screen()` - Hides the ready screen

### 4. Lobby Character Select (`lobby_character_select.tscn` / `.gd`)

Complete lobby scene combining character selection and ready display:
- Container for both CharacterSelectUI and PlayerReadyUI
- Manages state transitions between selection and ready screens
- Coordinates multi-player selection flow

**Methods:**
- `show_character_select(is_player1)` - Shows character selection screen
- `show_both_players_ready(p1_char, p2_char)` - Shows ready screen with both characters

## Asset Integration

The implementation uses existing assets from the multi project:

- **Character Portraits**: `res://assets/characters/player/Portraits/{CHARACTER}.png`
  - Kyle, Eric, Donald, Kristen, Rochelle, Vickie, Connie, Caleb, Bethany, Maia
  - Plus HOVERED.png and SELECTED.png overlay textures

- **Ready Images**: `res://assets/characters/player/ReadySelect/{CHARACTER}_READY.png`
  - Full-body character images for ready screen display

## Integration with Multi Project

### Main Menu Updates

The `main_menu_ui.tscn` and `main_menu_ui.gd` have been updated to:
1. Replace the old OptionButton character selector with CharacterSelectUI
2. Connect character selection signals to game flow
3. Route Host/Join/Quit button presses to appropriate handlers

### Character Selection Flow

1. **Main Menu**: User browses character portraits and clicks to select
2. **Selected Character**: Preview image updates as user hovers/selects
3. **Ready Button**: Once character selected, "Ready" button becomes enabled
4. **Host/Join/Quit**: Action buttons at bottom of screen for game start/joining/quit

### For Server-Authoritative Flow

When implementing multiplayer character confirmation:
1. Client selects character and presses Ready → sends RPC to server
2. Server validates and syncs character selection to all clients
3. Once both players confirm → show PlayerReadyUI with both characters
4. Animate ready screen, then transition to game

## Customization Guide

### Modifying Grid Layout

To change the character grid columns (currently 5):
```gdscript
# In character_select_ui.tscn, modify CharacterGridContainer:
columns = 5  # Change this value
```

### Adjusting Animation Timing

In `player_ready_ui.gd`, modify the `_setup_animations()` method:
```gdscript
anim.length = 1.5  # Total animation duration
# Adjust track_insert_key timing values for slide/fade/scale effects
```

### Adding New Characters

Simply add new portrait images to:
- `res://assets/characters/player/Portraits/{CHARACTER_NAME}.png`
- `res://assets/characters/player/ReadySelect/{CHARACTER_NAME}_READY.png`

Then add to the characters list in `character_select_ui.gd`:
```gdscript
var characters = ["Kyle", "Eric", ..., "NewCharacter"]
```

## Files Created/Modified

### New Files:
- `scenes/ui/character_portrait_button.tscn`
- `scripts/character_portrait_button.gd`
- `scenes/ui/character_select_ui.tscn`
- `scripts/character_select_ui.gd`
- `scenes/ui/player_ready_ui.tscn`
- `scripts/player_ready_ui.gd`
- `scenes/ui/lobby_character_select.tscn`
- `scripts/lobby_character_select.gd`

### Modified Files:
- `scenes/ui/main_menu_ui.tscn` - Now uses CharacterSelectUI instead of OptionButton
- `scripts/main_menu_ui.gd` - Updated to route new button signals

## Testing

To test the portrait selection:

1. Open the level scene (`scenes/level/level.tscn`)
2. Run the scene (F5)
3. Observe the portrait-based character selector in the main menu
4. Click different character portraits to see selection feedback
5. Selected character preview updates on the right side
6. Host/Join/Quit buttons work as before

## Notes

- All character names are case-insensitive when loading assets
- Portrait assets automatically convert character names to uppercase for file lookups
- Hover overlay automatically loads from existing HOVERED.png
- Selection flash uses existing SELECTED.png asset
- Animation system is optimized for smooth 60fps performance
