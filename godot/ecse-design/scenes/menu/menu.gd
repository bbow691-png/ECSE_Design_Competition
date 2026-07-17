extends Control

# Paths to the scenes we want to load when buttons are clicked
const GAMEPLAY_SCENE: String = "res://scenes/game_scene/scene_1.tscn"
const OPTIONS_SCENE: String = "res://scenes/game_scene/scene_1.tscn"

@onready var story_btn: Button = $MenuContainer/Play
@onready var options_btn: Button = $MenuContainer/Options
@onready var exit_btn: Button = $MenuContainer/Exit

func _ready() -> void:
	# 1. Start the menu music looping
	$MenuMusic.play()
	
	# 2. Connect the button click signals
	story_btn.pressed.connect(_on_story_pressed)
	options_btn.pressed.connect(_on_options_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)
	
	# 3. Optional: Grab focus on the first button so keyboard/controller navigation works!
	story_btn.grab_focus()

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

	# Create a quick flashing effect using a Tween
	var tween: Tween = create_tween()
	# Rapidly change the button's modulation color (flash white/invisible/white)
	tween.tween_property(clicked_button, "modulate", Color(2, 2, 2, 1), 0.1) # Bright flash
	tween.tween_property(clicked_button, "modulate", Color(1, 1, 1, 0), 0.1) # Fade out slightly
	tween.tween_property(clicked_button, "modulate", Color(2, 2, 2, 1), 0.1)
	tween.tween_property(clicked_button, "modulate", Color(1, 1, 1, 1), 0.1) # Back to normal

	# Wait 1.0 second for the sound and flash to finish, then change scene
	await get_tree().create_timer(1.0).timeout
	
	get_tree().change_scene_to_file(target_scene)
