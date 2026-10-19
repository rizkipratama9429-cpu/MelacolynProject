extends Node3D
class_name CameraRig
## Third-person orbit camera. Lives outside the player body on purpose: it only
## follows position, so turning the character never yanks the view around.
## Mouse X yaws the rig, mouse Y pitches the pivot, the wheel zooms.
##
## Distance has two owners: the wheel picks `_zoom_target`, but a wall found by
## a raycast always wins immediately, so the camera stops in front of geometry
## instead of ending up inside it. When the view clears it eases back out.

const PLAYER_GROUP := "player"
## The wheel may not come closer than min_distance, but a wall may push the
## camera closer than that - being cramped beats being inside a building.
const OCCLUSION_MIN := 0.2

@export var sensitivity := 0.0028
@export var min_pitch := -1.25
@export var max_pitch := 0.5
## How far above the target's feet the camera orbits around.
@export var pivot_height := 0.55
## Wheel limits: how close you may get, and how far you may pull back.
@export var min_distance := 1.2
@export var max_distance := 6.0
## How far one wheel notch moves the camera.
@export var zoom_step := 0.35
## How quickly the camera eases toward the wheel's target distance.
@export var zoom_smooth := 14.0
## Keep the camera at least this far in front of any wall it finds.
@export var wall_margin := 0.3

var yaw := 0.0
var pitch := -0.18
## Where the wheel wants the camera to be...
var _zoom_target := 3.1
## ...and what it is actually allowed to be.
var _distance := 3.1

@onready var pivot: Node3D = $Pitch
@onready var camera: Camera3D = $Pitch/Camera3D
@onready var target: Node3D = get_tree().get_first_node_in_group(PLAYER_GROUP)


func _ready() -> void:
	if target == null:
		push_warning("[CameraRig] No node in group '%s' to follow." % PLAYER_GROUP)
	# The scene owns the starting distance; the wheel takes over from there.
	_zoom_target = clampf(camera.position.z, min_distance, max_distance)
	_distance = _zoom_target
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * sensitivity
		pitch = clampf(pitch - event.relative.y * sensitivity, min_pitch, max_pitch)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_target = clampf(_zoom_target - zoom_step, min_distance, max_distance)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_target = clampf(_zoom_target + zoom_step, min_distance, max_distance)
	elif event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if is_instance_valid(target):
		global_position = target.global_position + Vector3.UP * pivot_height

	rotation.y = yaw
	pivot.rotation.x = pitch

	_distance = lerpf(_distance, _zoom_target, clampf(zoom_smooth * delta, 0.0, 1.0))
	_distance = minf(_distance, _occlusion_limit(_distance))
	camera.position.z = _distance


## How far out the camera may sit before the first wall, for a camera that
## wants to be `desired` units away. Returns `desired` when the view is clear.
func _occlusion_limit(desired: float) -> float:
	var space := get_world_3d().direct_space_state
	if space == null:
		return desired

	var axis := camera.global_position - global_position
	if axis.length_squared() < 0.000001:
		return desired
	var direction := axis.normalized()

	# Start a little clear of the pivot so the player's own capsule - the
	# pivot sits inside it - never reports as an obstruction.
	var from := global_position + direction * 0.05
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * desired)
	var exclude: Array[RID] = []
	var body := target as CollisionObject3D
	if body:
		exclude.append(body.get_rid())
	query.exclude = exclude

	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return desired

	var hit_distance := (hit["position"] as Vector3).distance_to(global_position)
	return maxf(hit_distance - wall_margin, OCCLUSION_MIN)
