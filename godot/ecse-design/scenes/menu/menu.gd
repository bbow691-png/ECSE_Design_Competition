extends Control

# Paths to the scenes we want to load when buttons are clicked
const GAMEPLAY_SCENE: String = "res://scenes/map_scene.tscn"
const OPTIONS_SCENE: String = "res://scenes/map_scene.tscn"

@onready var story_btn: Button = $MenuContainer/Play
@onready var options_btn: Button = $MenuContainer/Options
@onready var exit_btn: Button = $MenuContainer/Exit

# IMPORTANT: Add a TextureRect named "CursorIcon" to your Menu scene tree!
@onready var cursor_icon: Control = $CursorIcon

# 1. Drag and drop your menu music file here in the Inspector!
@export var menu_music: String
@export var fade_time: float = 0.5

@onready var beat_flasher: ColorRect = $BeatFlasher
var flash_tween: Tween

@onready var camera: Camera2D = $Camera2D
var camera_tween: Tween

var is_transitioning: bool = false

func _ready() -> void:
	camera.global_position = get_viewport_rect().size / 2.0
	
	# 1. Start the menu music looping
	if menu_music != null:
		# 2. Feed the song and BPM to the global Conductor
		Conductor.play_song(menu_music, fade_time)
	else:
		push_warning("Forgot to assign 'menu_music' in the Inspector!")
		
	# 2. Connect the button click signals
	story_btn.pressed.connect(_on_story_pressed)
	options_btn.pressed.connect(_on_options_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)
	
	# 3. Connect focus signals for the FNF cursor icon
	story_btn.focus_entered.connect(_on_button_focused.bind(story_btn))
	options_btn.focus_entered.connect(_on_button_focused.bind(options_btn))
	exit_btn.focus_entered.connect(_on_button_focused.bind(exit_btn))
	
	# 4. Grab focus on the first button so navigation works immediately
	story_btn.grab_focus()
	
	if Conductor:
		Conductor.beat_hit.connect(_on_conductor_beat_hit)

func _unhandled_input(event: InputEvent) -> void:
	# Stop players from moving the menu during a scene transition
	if is_transitioning:
		return

	var current_focus = get_viewport().gui_get_focus_owner()
	
	# Failsafe: If nothing is selected, force selection on Story
	if not current_focus:
		story_btn.grab_focus()
		return

	# Handle scrolling UP
	if event.is_action_pressed("upp_left"):
		var prev_node = current_focus.find_prev_valid_focus()
		if prev_node:
			prev_node.grab_focus()
		get_viewport().set_input_as_handled()

	# Handle scrolling DOWN
	elif event.is_action_pressed("low_righ"):
		var next_node = current_focus.find_next_valid_focus()
		if next_node:
			next_node.grab_focus()
		get_viewport().set_input_as_handled()

	# Handle SELECTING the button
	elif event.is_action_pressed("low_left"):
		if current_focus is BaseButton:
			current_focus.emit_signal("pressed")
		get_viewport().set_input_as_handled()

func _on_conductor_beat_hit(current_beat: int) -> void:
	# Flash the background every beat!
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
	is_transitioning = true
	
	# Disable all buttons so the player can't double-click anything during transition
	for button in $MenuContainer.get_children():
		if button is Button:
			button.disabled = true
			
	# Play a "confirm" sound effect if you have one
	# $ConfirmSound.play()

	if clicked_button.has_method("confirm_flash"):
		clicked_button.confirm_flash()

	# Wait just a tiny bit for the flash to register visually (0.4 seconds)
	await get_tree().create_timer(0.4).timeout
	
	# Call your global Autoload to handle the fade and scene swap
	SceneTransition.fade_to_scene(target_scene, 0.5)

# Function to move the icon whenever a button is highlighted
func _on_button_focused(button: Control) -> void:
	# Wait one tiny frame to guarantee the UI containers have updated their positions
	await get_tree().process_frame
	
	if not cursor_icon:
		return
		
	var button_rect = button.get_global_rect()
	
	# --- TWEAK THESE VALUES TO MOVE THE CURSOR ---
	# A negative X value moves it left, a positive X value moves it right.
	# If you want it inside the left edge of the button, try a positive number like 20.
	# If you want it completely to the left of the button, try a negative number like -50.
	var offset_x: float = -40.0 
	
	# A negative Y value moves it up, a positive Y value moves it down.
	# Use this to fix the vertical alignment if the slanted buttons throw it off.
	var offset_y: float = 0.0 
	# ---------------------------------------------
	
	# Calculate the new position
	var target_x = button_rect.position.x + offset_x
	var target_y = button_rect.position.y + 36 + (button_rect.size.y / 2.0) - (cursor_icon.size.y / 2.0) + offset_y
	
	# Teleport the cursor to the exact spot
	cursor_icon.global_position = Vector2(target_x, target_y)
