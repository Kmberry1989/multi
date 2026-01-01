@tool
extends Node

# Mapping from canonical animation keys used by gameplay -> expected AnimationLibrary basenames
var animation_map := {
    "Idle": "Bouncing Fight Idle",
    "Walk_Forward": "Walking",
    "Walk_Back": "Walking Backward",
    "Run": "Running",
    "Sprint": "Running", # Duplicate mapping for Sprint
    "Step_Back": "Step Backward",
    "Jump": "Jump",
    "Fall": "Jumping Down", # Fallback for fall
    "Land": "Jumping Down",
    "Crouch": "Crouched Walking",
    "Crouch_Exit": "Crouch To Stand",
    # Light punch combo chain
    "Punch_Combo1": "Punching (1)",
    "Punch_Combo2": "Punching 2",
    "Punch_Combo3": "Fist Fight A",
    # Heavy punch on hold
    "Punch_Heavy": "Hook Punch",
    # Light kick combo chain
    "Kick_Combo1": "Kicking 3",
    "Kick_Combo2": "Kicking 4",
    "Kick_Combo3": "Roundhouse Kick",
    # Heavy kick on hold
    "Kick_Heavy": "Drop Kick",
    "Fireball": "Fireball",
    "FlashKick": "Flying Bicycle Kick",
    "Special_Charged": "Superhuman Choke Lift",
    "Block": "Blocking",
    "Dizzy": "Dizzy Idle",
    "GetUp": "Stand Up",
    "Death": "Dying",
}

func get_library_name_for(key: String) -> String:
    return animation_map.get(key, "")
