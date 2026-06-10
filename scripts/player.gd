class_name Player extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const SMOOTH_SPEED = 20
const ROTATION_SMOOTH_SPEED = 10
# If a remote player's visual is further than this from its target, snap instead
# of gliding — avoids a slow slide across the map on respawns/teleports/big corrections.
const SNAP_DISTANCE = 5.0

var _local_player = false

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var _player_input : PlayerInput
@export var _camera_input : CameraInput
@export var _player_model : Node3D
@export var _state_machine: RewindableStateMachine

@onready var rollback_synchronizer = $RollbackSynchronizer

var _animation_player

func _enter_tree():
	_player_input.set_multiplayer_authority(str(name).to_int())
	_camera_input.set_multiplayer_authority(str(name).to_int())


func _ready():
	process_priority = 100

	_player_model.global_position = global_position

	_state_machine.state = &"IdleState"
	_animation_player = _player_model.get_node("AnimationPlayer")
	
	# TODO: can this be moved to movement_state
	_state_machine.on_display_state_changed.connect(_on_display_state_changed)

	# Call this after setting authority
	# https://foxssake.github.io/netfox/netfox/tutorials/responsive-player-movement/#ownership
	rollback_synchronizer.process_settings()

	if multiplayer.get_unique_id() == str(name).to_int():
		NetworkManager.hide_loading()
		_local_player = true


func _process(delta: float) -> void:

	
	var target_pos: Vector3 = $MeshTransformPoint.global_position
	if _local_player:
		_player_model.global_position = target_pos
	elif _player_model.global_position.distance_to(target_pos) > SNAP_DISTANCE:
		_player_model.global_position = target_pos
	else:
		_player_model.global_position = _player_model.global_position.lerp(
			target_pos, 1.0 - exp(-SMOOTH_SPEED * delta))


	var look := -_camera_input.camera_basis.z
	look.y = 0.0
	if look.length_squared() > 0.0001:
		var from_q := _player_model.global_transform.basis.get_rotation_quaternion()
		var to_q := Transform3D.IDENTITY.looking_at(look, Vector3.UP).basis.get_rotation_quaternion()
		_player_model.global_transform.basis = Basis(
			from_q.slerp(to_q, 1.0 - exp(-ROTATION_SMOOTH_SPEED * delta)))

func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	_force_update_is_on_floor()
	if not is_on_floor():
		apply_gravity(delta)

func _on_display_state_changed(old_state, new_state):
	# print("Old state %s, new %s" % [old_state, new_state])

	var animation_name = new_state.animation_name
	if _animation_player && animation_name != "":
		# print("Play animation %s" % animation_name)
		_animation_player.play(animation_name)

func apply_gravity(delta):
	velocity.y -= gravity * delta

# https://foxssake.github.io/netfox/netfox/tutorials/rollback-caveats/#characterbody-on-floor
func _force_update_is_on_floor():
	var old_velocity = velocity
	velocity *= 0
	move_and_slide()
	velocity = old_velocity
