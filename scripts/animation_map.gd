@tool
extends Node

# Mapping from canonical animation keys used by gameplay -> expected AnimationLibrary basenames
var animation_map := {
    "Idle": "Bouncing Fight Idle",
    "Walk_Forward": "Walking",
    "Walk_Back": "Walking Backward",
    "Run": "Running",
    "Step_Back": "Step Backward",
    "Jump": "Jump",
    "Land": "Jumping Down",
    "Crouch": "Crouched Walking",
    "Crouch_Exit": "Crouch To Stand",
    "Punch_A": "Punching (1)",
    "Punch_Heavy": "Punching 2",
    "Kick_A": "Kicking 3",
    "Kick_Heavy": "Kicking 4",
    "Fireball": "Fireball",
    "FlashKick": "Flying Bicycle Kick",
    "Block": "Blocking",
    "Dizzy": "Dizzy Idle",
    "GetUp": "Stand Up",
    "Death": "Dying",
}

func get_library_name_for(key: String) -> String:
    return animation_map.get(key, "")
