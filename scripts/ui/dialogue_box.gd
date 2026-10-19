extends Control
class_name DialogueBox
## Visual-novel dialogue box: name tab, typewriter text, advance arrow.
## Presentation only - the director owns input and decides when lines move.
##
## Feel: text types itself out; the first press reveals the rest instantly,
## the second press advances to the next line (the classic VN double-tap).

## Characters printed per second.
const TYPE_SPEED := 45.0

@onready var _text: Label = $Box/Text
@onready var _advance: Label = $Box/Advance
@onready var _name_tab: Panel = $NameTab
@onready var _name_label: Label = $NameTab/NameLabel

var _typing := false
var _typed_chars := 0.0


func _ready() -> void:
	# The arrow just pulses; visibility is toggled by state.
	var pulse := create_tween().set_loops()
	pulse.tween_property(_advance, "modulate:a", 0.25, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(_advance, "modulate:a", 1.0, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Swaps in a new line and starts the typewriter.
func show_line(speaker: String, tab_color: Color, line_text: String) -> void:
	_name_label.text = speaker
	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = tab_color
	tab_style.corner_radius_top_left = 10
	tab_style.corner_radius_top_right = 10
	tab_style.corner_radius_bottom_right = 0
	tab_style.corner_radius_bottom_left = 0
	_name_tab.add_theme_stylebox_override("panel", tab_style)

	_text.text = line_text
	_typed_chars = 0.0
	_text.visible_characters = 0
	_advance.visible = false

	if line_text.is_empty():
		_finish_typing()
	else:
		_typing = true


## Returns true when the press was consumed by the typewriter (it revealed
## the line); false when the line was already complete and may advance.
func advance() -> bool:
	if _typing:
		_finish_typing()
		return true
	return false


func is_complete() -> bool:
	return not _typing


func _process(delta: float) -> void:
	if not _typing:
		return
	_typed_chars += TYPE_SPEED * delta
	_text.visible_characters = int(_typed_chars)
	if _typed_chars >= float(_text.text.length()):
		_finish_typing()


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_advance.visible = true
