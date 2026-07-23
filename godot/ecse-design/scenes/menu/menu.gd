extends Control

# Paths to the scenes we want to load when buttons are clicked
const GAMEPLAY_SCENE: String = "res://scenes/map_scene.tscn"
const OPTIONS_SCENE: String = "res://scenes/map_scene.tscn"

@onready var story_btn: Button = $MenuContainer/Play
@onready var options_btn: Button = $MenuContainer/Options
@onready var exit_btn: Button = $MenuContainer/Exit
# 1. Drag and drop your menu music file here in the Inspector!
@export var menu_music: AudioStream
@export var menu_bpm: float = 115.0 # Set this to your song's actual BPM
@export var fade_time: float = 5.0

@onready var beat_flasher: ColorRect = $BeatFlasher
var flash_tween: Tween

@onready var camera: Camera2D = $Camera2D
var camera_tween: Tween

func _ready() -> void:
	camera.global_position = get_viewport_rect().size / 2.0
	# 1. Start the menu music looping
	if menu_music != null:
		# 2. Feed the song and BPM to the global Conductor
		Conductor.play_with_fade(menu_music, menu_bpm,fade_time)
	else:
		push_warning("Forgot to assign 'menu_music' in the Inspector!")
	# 2. Connect the button click signals
	story_btn.pressed.connect(_on_story_pressed)
	options_btn.pressed.connect(_on_options_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)
	
	# 3. Optional: Grab focus on the first button so keyboard/controller navigation works!
	story_btn.grab_focus()
	
	if Conductor:
		Conductor.beat_hit.connect(_on_conductor_beat_hit)
		
func _on_conductor_beat_hit(current_beat: int) -> void:
	# Flash the background every beat!
	# (You can also change this to 'current_beat % 2 == 0' to flash only on every 2nd beat)
	flash_screen()
	bump_camera() 

func bump_camera() -> void:
	if not camera:
		return

	if camera_tween and camera_tween.is_running():
		camera_tween.kill()

	# Instantly zoom the camera slightly in (normal is Vector2(1, 1))
	camera.zoom = Vector2(1.03, 1.03)

	# Smoothly glide the zoom back to 1.0 over the course of the beat
	camera_tween = create_tween()
	camera_tween.tween_property(camera, "zoom", Vector2.ONE, 0.3)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
func flash_screen() -> void:
	if not is_inside_tree() or not beat_flasher:
		return
		
	if flash_tween and flash_tween.is_running():
		flash_tween.kill()
		
	# Instantly set the overlay to a subtle transparent white (0.08 alpha)
	# This avoids blinding the player while creating a clear "pulse"
	beat_flasher.color.a = 0.08
	
	# Smoothly fade it back to 0
	flash_tween = create_tween()
	flash_tween.tween_property(beat_flasher, "color:a", 0.0, 0.25)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
func _on_story_pressed() -> void:
	_trigger_transition_to(GAMEPLAY_SCENE, story_btn)

func _on_options_pressed() -> void:
	_trigger_transition_to(OPTIONS_SCENE, options_btn)

func _on_exit_pressed() -> void:
	# Clean exit
	get_tree().quit()

# Handles the classic FNF "flash button, play sound, then change scene" sequence

func _trigger_transition_to(target_scene: String, clicked_button: Button) -> void:
	# Disable all buttons so the player can't double-click anything during transition
	for button in $MenuContainer.get_children():
		if button is Button:
			button.disabled = true
			
	# Play a "confirm" sound effect if you have one
	# $ConfirmSound.play()

	# --- THE FIX: Call the custom flash function instead of using modulate! ---
	if clicked_button.has_method("confirm_flash"):
		clicked_button.confirm_flash()

	# Wait just a tiny bit for the flash to register visually (0.4 seconds)
	await get_tree().create_timer(0.4).timeout
	
	# Call your global Autoload to handle the fade and scene swap
	SceneTransition.fade_to_scene(target_scene, 0.5)
