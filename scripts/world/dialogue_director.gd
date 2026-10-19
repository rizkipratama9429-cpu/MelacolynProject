extends Node
## Phase 1 dialogue demo: press T in the city to play a sample conversation
## and hand control back when it ends. Freezes the player and camera while
## lines are on screen, like a classic VN cut-away.
##
## PLACEHOLDER: SAMPLE_LINES is a stub conversation so the look and feel can
## be judged now. Phase 2 replaces it with JSON story files (the real script
## the author writes); phase 4 replaces the T-key demo with real world
## triggers (walk up to someone / press E to talk).
##
## Input: Space / Enter / click = advance (first press finishes the typewriter
## line, second press moves on). T starts the sample while idle.

enum State { IDLE, PLAYING, ENDING }

const SEIA_COLOR := Color(0.043, 0.553, 0.847)
const YOU_COLOR := Color(0.30, 0.37, 0.46)

## The stub script - same shape as the future JSON lines: speaker + text.
const SAMPLE_LINES: Array[Dictionary] = [
	{ "speaker": "SEIA", "text": "Oh - hello. I didn't hear you coming." },
	{ "speaker": "YOU", "text": "Sorry - didn't mean to startle you." },
	{ "speaker": "SEIA", "text": "No, it's fine. The streets are so quiet this time of day." },
	{ "speaker": "SEIA", "text": "...would you like to walk around together for a while?" },
]

@onready var player: CharacterBody3D = get_parent().get_node("Player")
@onready var rig: CameraRig = get_parent().get_node("CameraRig")
@onready var intro: IntroDirector = get_parent().get_node("IntroDirector")
@onready var box: DialogueBox = get_parent().get_node("DialogueLayer/DialogueBox")

var _state: int = State.IDLE
var _line := 0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match _state:
			State.IDLE:
				if event.keycode == KEY_T:
					_start()
			State.PLAYING:
				if event.keycode == KEY_SPACE \
						or event.keycode == KEY_ENTER \
						or event.keycode == KEY_KP_ENTER:
					_advance()
		return

	if event is InputEventMouseButton and event.pressed and _state == State.PLAYING:
		_advance()


func _start() -> void:
	# The intro cutscene owns the camera and player until it finishes.
	if intro._phase != IntroDirector.Phase.DONE:
		return

	_state = State.PLAYING
	_line = 0

	# Freeze gameplay - same hand-off pattern as the intro director.
	player.set_physics_process(false)
	rig.set_process(false)
	rig.set_process_unhandled_input(false)

	box.visible = true
	box.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(box, "modulate:a", 1.0, 0.25)
	_show_line()


func _show_line() -> void:
	var line: Dictionary = SAMPLE_LINES[_line]
	var speaker: String = line["speaker"]
	box.show_line(speaker, _color_for(speaker), line["text"])


func _advance() -> void:
	if box.advance():  # Typewriter was still running - reveal, stay put.
		return
	_line += 1
	if _line >= SAMPLE_LINES.size():
		_end()
	else:
		_show_line()


func _end() -> void:
	_state = State.ENDING
	var fade := create_tween()
	fade.tween_property(box, "modulate:a", 0.0, 0.25)
	fade.tween_callback(_restore)


func _restore() -> void:
	box.visible = false
	# One frame in ENDING so the Space that closed the dialogue cannot also
	# register as a jump the instant physics comes back.
	await get_tree().process_frame
	rig.set_process(true)
	rig.set_process_unhandled_input(true)
	# -1 re-triggers the idle blend (reset trick, same as the intro).
	player.set("_stance", -1)
	player.set_physics_process(true)
	_state = State.IDLE


func _color_for(speaker: String) -> Color:
	if speaker == "SEIA":
		return SEIA_COLOR
	return YOU_COLOR
