extends Node3D
## Third-person orbit camera. Lives outside the player body on purpose: it only
## follows position, so turning the character never yanks the view around.
## Mouse X yaws the rig, mouse Y pitches the pivot.

const PLAYER_GROUP := "player"

@export var sensitivity := 0.0028
@export var min_pitch := -1.25
@export var max_pitch := 0.5
## How far above the target's feet the camera orbits around.
@export var pivot_height := 0.55

var yaw := 0.0
var pitch := -0.18

@onready var pivot: Node3D = $Pitch
@onready var target: Node3D = get_tree().get_first_node_in_group(PLAYER_GROUP)


func _ready() -> void:
	if target == null:
		push_warning("[CameraRig] No node in group '%s' to follow." % PLAYER_GROUP)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * sensitivity
		pitch = clampf(pitch - event.relative.y * sensitivity, min_pitch, max_pitch)
	elif event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if is_instance_valid(target):
		global_position = target.global_position + Vector3.UP * pivot_height

	rotation.y = yaw
	pivot.rotation.x = pitch
