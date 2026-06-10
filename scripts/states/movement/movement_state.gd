class_name MovementState 
extends RewindableState

# A base movement state for common functions, extend when making new movement state.

const WALK_SPEED := 5.0
const RUN_MODIFIER := 2.5
const JUMP_VELOCITY := 6.5
const JUMP_MOVE_SPEED := 3.0

@export var animation_name: String
@export var camera_input : CameraInput
@export var player_model : Node3D
@export var player_input: PlayerInput
@export var parent: Player

# Default movement, override as needed
func move_player(delta: float, speed: float = WALK_SPEED):
	parent.velocity *= NetworkTime.physics_factor
	parent.move_and_slide()
	parent.velocity /= NetworkTime.physics_factor

# https://foxssake.github.io/netfox/netfox/tutorials/rollback-caveats/#characterbody-on-floor
func force_update_is_on_floor():
	var old_velocity = parent.velocity
	parent.velocity *= 0
	parent.move_and_slide()
	parent.velocity = old_velocity

func get_movement_input() -> Vector2:
	return player_input.input_dir

func get_run() -> bool:
	return player_input.run_input
	
func get_jump() -> float:
	return player_input.jump_input
