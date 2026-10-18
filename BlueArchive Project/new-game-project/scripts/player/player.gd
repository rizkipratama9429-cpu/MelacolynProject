extends CharacterBody3D
## Third-person player: camera-relative WASD movement (walk / run), gravity,
## jump, and state-driven animation - locomotion, idle, jump, long-idle fidget.

const WALK_SPEED := 2.6
const RUN_SPEED := 5.0
const ACCEL := 10.0
const TURN_SPEED := 14.0
const JUMP_VELOCITY := 3.4
const GRAVITY := 9.8
## Below this horizontal speed the character counts as standing still.
const IDLE_THRESHOLD := 0.2
## Standing still this long triggers the fidget clip below.
const LONG_IDLE_SECONDS := 10.0
## Played once after standing still that long, then the idle loop resumes.
const FIDGET_CLIP := &"Cafe_Reaction"
## Falling below this height means leaving the map; respawn at the start.
const VOID_Y := -25.0

enum Stance { STAND, WALK, RUN }

@onready var anim: AnimationPlayer = find_child("AnimationPlayer", true, false)

## Current stance. -1 means "not picked yet", which forces a clip to play.
var _stance := -1
var _in_air := false
var _fidgeting := false
var _stand_time := 0.0
var _spawn_point := Vector3.ZERO


func _ready() -> void:
	_spawn_point = global_position
	if anim:
		# The model's clips ship without a loop flag: each one plays once, then
		# holds its last frame forever while the body keeps sliding along.
		# Locomotion state clips must loop instead.
		_ensure_loop(&"Cafe_Idle")
		_ensure_loop(&"Cafe_Walk")
		_ensure_loop(&"Move_Ing")
		anim.play("Cafe_Idle")
	else:
		push_warning("[Player] No AnimationPlayer found under the model.")


func _ensure_loop(clip_name: StringName) -> void:
	if not anim.has_animation(clip_name):
		push_warning("[Player] Missing animation: %s" % clip_name)
		return
	var clip := anim.get_animation(clip_name)
	if clip.loop_mode == Animation.LOOP_NONE:
		clip.loop_mode = Animation.LOOP_LINEAR


func _physics_process(delta: float) -> void:
	if global_position.y < VOID_Y:
		global_position = _spawn_point
		velocity = Vector3.ZERO
		_in_air = false
		_stance = -1  # force the next update to re-pick the stance's clip
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		if not _in_air:
			_enter_air()
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		_enter_air()

	var direction := _camera_relative_direction()
	var wanted := direction * _target_speed()

	velocity.x = lerpf(velocity.x, wanted.x, ACCEL * delta)
	velocity.z = lerpf(velocity.z, wanted.z, ACCEL * delta)
	move_and_slide()

	if _in_air and is_on_floor():
		_in_air = false
		_stance = -1  # landing always replays the stance's own clip

	_face_movement(direction, delta)
	_update_animation(delta)


## Holding Shift outruns walking; without it the character walks.
func _target_speed() -> float:
	return RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED


func _enter_air() -> void:
	_in_air = true
	if anim:
		anim.play("Move_Jump", 0.12)


func _camera_relative_direction() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input == Vector2.ZERO:
		return Vector3.ZERO

	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO

	var cam_basis := cam.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0.0
	var right := cam_basis.x
	right.y = 0.0

	var direction := forward * -input.y + right * input.x
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector3.ZERO


## The body node faces -Z, so yaw is atan2(-x, -z) of the desired direction.
func _face_movement(direction: Vector3, delta: float) -> void:
	if direction == Vector3.ZERO:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))


func _update_animation(delta: float) -> void:
	if anim == null or _in_air:
		return

	var speed := Vector2(velocity.x, velocity.z).length()
	var want := Stance.STAND
	if speed > IDLE_THRESHOLD:
		want = Stance.RUN if Input.is_action_pressed("run") else Stance.WALK

	if want != _stance:
		_stance = want
		_stand_time = 0.0
		_fidgeting = false
		anim.speed_scale = 1.0
		# Tighter blend between the two locomotion clips, so the feet resync fast.
		anim.play(_clip_for(want), 0.2 if want == Stance.STAND else 0.12)

	match _stance:
		Stance.RUN:
			# Keep the run cycle in sync with actual ground speed.
			anim.speed_scale = clampf(speed / RUN_SPEED, 0.6, 1.8)
		Stance.WALK:
			anim.speed_scale = clampf(speed / WALK_SPEED, 0.6, 1.8)
		_:
			_tick_long_idle(delta)

	# Safety net: if a clip ever does end, restart the stance's clip so the
	# character can never freeze mid-pose while still moving.
	if not anim.is_playing() and not _fidgeting:
		anim.play(_clip_for(_stance), 0.15)


func _clip_for(stance: int) -> StringName:
	match stance:
		Stance.RUN:
			return &"Move_Ing"
		Stance.WALK:
			return &"Cafe_Walk"
		_:
			return FIDGET_CLIP if _fidgeting else &"Cafe_Idle"


## Counts time standing still and fires the one-shot fidget at the end of it.
func _tick_long_idle(delta: float) -> void:
	if _fidgeting:
		# The fidget is one-shot: wait for it to end, then resume the idle loop.
		if not anim.is_playing():
			_fidgeting = false
			_stand_time = 0.0
			anim.play(&"Cafe_Idle", 0.2)
		return

	_stand_time += delta
	if _stand_time >= LONG_IDLE_SECONDS:
		_fidgeting = true
		_stand_time = 0.0
		anim.play(FIDGET_CLIP, 0.25)
