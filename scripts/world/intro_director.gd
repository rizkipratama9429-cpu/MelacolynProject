extends Node
class_name IntroDirector
## First-meeting cutscene, wired into main.tscn. The camera holds a close
## three-quarter shot while Seia notices you (Cafe_Reaction) and a name card
## fades in; then the camera orbits behind her and hands control back to
## CameraRig. The orbit ends on exactly the pose the rig would occupy, so
## gameplay starts without a jump cut. Any key skips straight to the handoff.
##
## Order of operations: gravity settles her first (under the black overlay),
## her physics freeze for the shot, and _stance = -1 on release makes the
## player script re-pick its clip - a clean blend back into Cafe_Idle.

const REACTION_CLIP := &"Cafe_Reaction"
const CARD_NAME := "SEIA"
const CARD_LINE := "Nice to meet you."
const HINT_TEXT := "WASD move - SHIFT run - SPACE jump - mouse look - wheel zoom - ESC cursor"
const SKIP_HINT_TEXT := "press any key to skip"

## Seconds of held shot before the orbit behind her begins.
const SWEEP_START := 6.2
const SWEEP_DURATION := 1.7
## The same sweep, compressed, when the player skips.
const SKIP_SWEEP_DURATION := 0.45
const FADE_IN_SECONDS := 0.7
## Where the camera sits for the close-up, relative to her body.
const SHOT_OFFSET := Vector3(-1.2, 0.72, -2.15)
const SHOT_AIM := Vector3(0.0, 0.58, 0.0)
## How far the camera creeps closer over the held shot.
const SHOT_PUSH := 0.4
## Close-up field of view; eases to the rig's own value as the orbit ends.
const SHOT_FOV := 46.0
## Give up waiting for floor contact after this long (should never trigger).
const SETTLE_TIMEOUT := 1.5

enum Phase { SETTLE, SHOT, DONE }

const HINT_HIDE_DELAY := 7.0

@onready var player: CharacterBody3D = get_parent().get_node("Player")
@onready var rig: Node3D = get_parent().get_node("CameraRig")

var _phase: int = Phase.SETTLE
var _settle_time := 0.0
var _time := 0.0
var _skipped := false
var _sweep_duration := SWEEP_DURATION

var _cam: Camera3D
var _layer: CanvasLayer
var _fade: ColorRect
var _card: Control
var _skip_hint: Label
var _hint: Label
## Fade-ins for the name card / skip hint, kept so a skip landing mid-interval
## can kill them - a delayed step would resurrect them after being hidden.
var _card_tween: Tween
var _skip_tween: Tween

## Orbit endpoints, derived the moment the shot begins.
var _angle_a := 0.0
var _angle_b := 0.0
var _radius_a := 0.0
var _radius_b := 0.0
var _height_a := 0.0
var _height_b := 0.0
var _aim_a := Vector3.ZERO
var _aim_b := Vector3.ZERO
var _rig_fov := 55.0


func _ready() -> void:
	_build_ui()
	# Everything is black right now: hide the camera takeover in here.
	rig.set_process(false)
	rig.set_process_unhandled_input(false)


func _process(delta: float) -> void:
	match _phase:
		Phase.SETTLE:
			_settle_time += delta
			if player.is_on_floor() or _settle_time >= SETTLE_TIMEOUT:
				if _skipped:
					_finish()
				else:
					_begin_shot()
		Phase.SHOT:
			_time += delta
			if _time >= SWEEP_START + _sweep_duration:
				_finish()
			else:
				_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventJoypadButton:
		pressed = event.pressed
	if not pressed:
		return

	match _phase:
		Phase.SETTLE:
			_skipped = true  # no shot at all: settle, then hand straight over
		Phase.SHOT:
			_skip()


## Skips the hold: the orbit still plays, just compressed, so the handoff
## never becomes a jump cut.
func _skip() -> void:
	if _skipped:
		return
	_skipped = true
	_sweep_duration = SKIP_SWEEP_DURATION
	if _time < SWEEP_START:
		_time = SWEEP_START
	_kill_pending_ui_tweens()
	_skip_hint.modulate.a = 0.0


## Kills the fade-ins that have not started their property step yet, so a
## skipped shot cannot bring the name card or skip hint back afterwards.
func _kill_pending_ui_tweens() -> void:
	if _card_tween and _card_tween.is_valid():
		_card_tween.kill()
	if _skip_tween and _skip_tween.is_valid():
		_skip_tween.kill()


func _begin_shot() -> void:
	_phase = Phase.SHOT
	_time = 0.0
	player.set_physics_process(false)  # frozen, resting on the street

	var rig_camera := rig.get_node("Pitch/Camera3D") as Camera3D
	_rig_fov = rig_camera.fov

	_cam = Camera3D.new()
	get_parent().add_child(_cam)
	_derive_orbit()
	_update_camera()
	_cam.make_current()

	var lift := create_tween()
	lift.tween_property(_fade, "color:a", 0.0, FADE_IN_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var anim := player.get("anim") as AnimationPlayer
	if anim:
		anim.play(REACTION_CLIP, 0.2)

	_card_tween = create_tween()
	_card_tween.tween_interval(0.8)
	_card_tween.tween_property(_card, "modulate:a", 1.0, 0.55) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_skip_tween = create_tween()
	_skip_tween.tween_interval(1.4)
	_skip_tween.tween_property(_skip_hint, "modulate:a", 0.6, 0.5)


## The rig's own final pose becomes the orbit's destination: same pivot, same
## yaw/pitch, same distance - reconstructed in spherical form so _update_camera
## lands on it exactly.
func _derive_orbit() -> void:
	_radius_a = Vector2(SHOT_OFFSET.x, SHOT_OFFSET.z).length()
	_angle_a = atan2(SHOT_OFFSET.x, SHOT_OFFSET.z)
	_height_a = SHOT_OFFSET.y
	_aim_a = player.global_position + SHOT_AIM

	var yaw: float = rig.get("yaw")
	var pitch: float = rig.get("pitch")
	var distance: float = rig.get("_distance")
	var pivot_height: float = rig.get("pivot_height")

	_aim_b = player.global_position + Vector3.UP * pivot_height
	var rig_basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var offset := rig_basis * Vector3(0.0, 0.0, distance)
	_radius_b = Vector2(offset.x, offset.z).length()
	_angle_b = atan2(offset.x, offset.z)
	_height_b = offset.y + pivot_height


func _update_camera() -> void:
	var sweep := clampf((_time - SWEEP_START) / _sweep_duration, 0.0, 1.0)
	sweep = smoothstep(0.0, 1.0, sweep)
	var hold := clampf(_time / maxf(SWEEP_START, 0.001), 0.0, 1.0)

	var radius := lerpf(_radius_a - SHOT_PUSH * hold, _radius_b, sweep)
	var angle := lerpf(_angle_a, _angle_b, sweep)
	var height := lerpf(_height_a, _height_b, sweep)

	var base := player.global_position
	_cam.global_position = base + Vector3(
		sin(angle) * radius, height, cos(angle) * radius)
	_cam.look_at(_aim_a.lerp(_aim_b, sweep))
	_cam.fov = lerpf(SHOT_FOV, _rig_fov, sweep)


func _finish() -> void:
	if _phase == Phase.DONE:
		return
	_phase = Phase.DONE
	set_process(false)
	set_process_unhandled_input(false)

	# Swap to the rig: its pose is what we aimed the orbit at, so this is a
	# continuation, not a cut.
	var rig_camera := rig.get_node("Pitch/Camera3D") as Camera3D
	rig_camera.make_current()
	if _cam:
		_cam.queue_free()
		_cam = null
	rig.set_process(true)
	rig.set_process_unhandled_input(true)

	# -1 forces the player's stance machine to re-pick: Cafe_Idle blends in.
	player.set("_stance", -1)
	player.set_physics_process(true)

	_kill_pending_ui_tweens()

	var card_out := create_tween()
	card_out.tween_property(_card, "modulate:a", 0.0, 0.4)
	var skip_out := create_tween()
	skip_out.tween_property(_skip_hint, "modulate:a", 0.0, 0.3)
	var lift := create_tween()
	lift.tween_property(_fade, "color:a", 0.0, 0.35)

	var hints := create_tween()
	hints.tween_interval(0.5)
	hints.tween_property(_hint, "modulate:a", 0.95, 0.6)
	hints.tween_interval(HINT_HIDE_DELAY)
	hints.tween_property(_hint, "modulate:a", 0.0, 1.2)


## The overlay, name card, skip hint, and post-intro control hints. Built in
## code because it only ever exists here - no extra scene to maintain.
func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	_layer.add_child(_fade)

	_card = Control.new()
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.offset_left = -330.0
	_card.offset_right = 330.0
	_card.offset_top = -168.0
	_card.offset_bottom = -56.0
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.modulate.a = 0.0
	_layer.add_child(_card)

	var name_label := _make_label(_card, CARD_NAME, 52, 0.45, 0.0, 0.64)
	name_label.add_theme_color_override(
		"font_outline_color", Color(0.03, 0.1, 0.18, 0.9))

	var line_label := _make_label(_card, CARD_LINE, 19, 0.25, 0.64, 1.0)
	line_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))

	_skip_hint = _make_label(_layer, SKIP_HINT_TEXT, 14, 0.4, 0.045, 0.075)
	_skip_hint.modulate.a = 0.0

	_hint = _make_label(_layer, HINT_TEXT, 16, 0.4, 0.925, 0.965)
	_hint.modulate.a = 0.0


func _make_label(parent: Node, text: String, font_size: int,
		weight: float, top: float, bottom: float) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = top
	label.anchor_bottom = bottom
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_color_override(
		"font_outline_color", Color(0.03, 0.1, 0.18, 0.8))
	label.add_theme_constant_override("outline_size", 5)
	var bold := FontVariation.new()
	bold.base_font = label.get_theme_default_font()
	bold.variation_embolden = weight
	label.add_theme_font_override("font", bold)
	parent.add_child(label)
	return label
