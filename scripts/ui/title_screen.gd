extends Control
## Title screen: background art, logo, and a PLAY button. Any button (or a
## click anywhere) fades to black, then the city scene takes over.
##
## Background: drop an image (png/jpg/webp) into assets/ui/ and it becomes the
## backdrop automatically. With no image there, a soft gradient stands in.

const GAME_SCENE := "res://scenes/main/main.tscn"
const BACKGROUND_DIR := "res://assets/ui/backgrounds/"
const LOGO_TEXTURE := "res://assets/ui/logo.png"
const MUSIC_DIR := "res://assets/music/"
## Where the music sits in the mix once faded in.
const MUSIC_VOLUME_DB := -6.0

@onready var _background: TextureRect = $Background
@onready var _hint: Label = $HintLabel
@onready var _play: Button = $PlayButton
@onready var _fade: ColorRect = $Fade
@onready var _music: AudioStreamPlayer = $Music
@onready var _logo_plate: Panel = $LogoPlate
@onready var _logo_texture: TextureRect = $LogoTexture
@onready var _text_logo: HBoxContainer = $Logo

var _starting := false


func _ready() -> void:
	_apply_background()
	_apply_logo()
	_start_music()
	_make_bold($Logo/Blue)
	_make_bold($Logo/Archive)
	_make_bold($Subtitle/Fighting)
	_make_bold($Subtitle/Tentative)
	_play.pressed.connect(_start_game)

	# Open with a lift out of black instead of popping in.
	_fade.color.a = 1.0
	var intro := create_tween()
	intro.tween_property(_fade, "color:a", 0.0, 0.7)

	_blink_hint()


func _unhandled_input(event: InputEvent) -> void:
	if _starting:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_start_game()
	elif event is InputEventMouseButton and event.pressed:
		_start_game()
	elif event is InputEventJoypadButton and event.pressed:
		_start_game()


func _start_game() -> void:
	if _starting:
		return
	_starting = true
	set_process_unhandled_input(false)
	_play.disabled = true

	var fade_out := create_tween()
	fade_out.tween_property(_fade, "color:a", 1.0, 0.5).set_ease(Tween.EASE_IN)
	fade_out.parallel().tween_property(_music, "volume_db", -30.0, 0.5)
	fade_out.tween_callback(_go_to_game)


func _go_to_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


## The default font is regular weight; the logo wants heft.
func _make_bold(label: Label) -> void:
	var bold := FontVariation.new()
	bold.base_font = label.get_theme_default_font()
	bold.variation_embolden = 0.45
	label.add_theme_font_override("font", bold)


func _blink_hint() -> void:
	var blink := create_tween().set_loops()
	blink.tween_property(_hint, "modulate:a", 0.3, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	blink.tween_property(_hint, "modulate:a", 1.0, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## First image in backgrounds/ wins... by being picked at random, so the
## title gets a different view each boot. With no images, a gradient shows.
func _apply_background() -> void:
	var dir := DirAccess.open(BACKGROUND_DIR)
	if dir:
		var candidates: Array[String] = []
		for file_name: String in dir.get_files():
			var lower := file_name.to_lower()
			if lower.ends_with(".png") or lower.ends_with(".jpg") \
					or lower.ends_with(".jpeg") or lower.ends_with(".webp"):
				candidates.append(file_name)
		if not candidates.is_empty():
			var chosen: String = candidates.pick_random()
			var image_texture := load(BACKGROUND_DIR + chosen) as Texture2D
			if image_texture:
				_background.texture = image_texture
				print("[Title] background: %s" % chosen)
				return

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.30, 0.63, 0.91))
	gradient.set_color(1, Color(0.87, 0.95, 1.0))
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0.0, 0.0)
	gradient_texture.fill_to = Vector2(0.0, 1.0)
	_background.texture = gradient_texture
	print("[Title] no images in %s - gradient backdrop" % BACKGROUND_DIR)


## The artwork logo sits on a white plate; without the file the built-in
## text logo stays up instead.
func _apply_logo() -> void:
	var logo := load(LOGO_TEXTURE) as Texture2D
	if logo == null:
		print("[Title] %s missing - text logo shown" % LOGO_TEXTURE)
		return
	_logo_texture.texture = logo
	_logo_texture.visible = true
	_logo_plate.visible = true
	_text_logo.visible = false
	print("[Title] logo: %s" % LOGO_TEXTURE)


## First audio file in music/ becomes the title theme: faded in, looped,
## faded out with the screen when the game starts.
func _start_music() -> void:
	var stream := _find_audio()
	if stream == null:
		return
	_music.stream = stream
	_music.volume_db = -30.0
	_music.play()
	_music.finished.connect(_music.play)
	var fade_in := create_tween()
	fade_in.tween_property(_music, "volume_db", MUSIC_VOLUME_DB, 2.0)


func _find_audio() -> AudioStream:
	var dir := DirAccess.open(MUSIC_DIR)
	if dir == null:
		return null
	var names := dir.get_files()
	names.sort()
	for file_name: String in names:
		var lower := file_name.to_lower()
		if lower.ends_with(".ogg") or lower.ends_with(".mp3") \
				or lower.ends_with(".wav"):
			var stream := load(MUSIC_DIR + file_name) as AudioStream
			if stream:
				print("[Title] music: %s" % file_name)
				return stream
	return null
