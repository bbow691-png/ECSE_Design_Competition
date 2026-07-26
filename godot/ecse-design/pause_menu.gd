extends CanvasLayer

@onready var panel: Control = $PanelContainer
@onready var continue_button: Button = $PanelContainer/VBoxContainer/ContinueButton
@onready var exit_button: Button = $PanelContainer/VBoxContainer/ExitButton

# Make sure you have a node named CursorIcon in your scene tree!
@onready var cursor_icon: Control = $CursorIcon 

@export var menu_scene_path: String = "res://scenes/game_scene/walk_around.tscn"

var is_paused: bool = false

func _ready() -> void:
	# Lets this node (and its children/input) keep working while the
	# rest of the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	visible = false
	
	# Connect standard button presses
	continue_button.pressed.connect(_on_continue_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	# Connect focus signals for the FNF cursor icon
	continue_button.focus_entered.connect(_on_button_focused.bind(continue_button))
	exit_button.focus_entered.connect(_on_button_focused.bind(exit_button))


func _unhandled_input(event: InputEvent) -> void:
	# Handle Opening/Closing the menu
	if event.is_action_pressed("esc"):
		toggle_pause()
		return

	# Handle Custom Menu Navigation (Only when paused)
	if is_paused:
		var current_focus = get_viewport().gui_get_focus_owner()
		
		# Failsafe: If nothing is selected, force selection on Continue
		if not current_focus:
			continue_button.grab_focus()
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


func toggle_pause() -> void:
	set_paused(not is_paused)


func _on_continue_pressed() -> void:
	set_paused(false)


func set_paused(paused: bool) -> void:
	is_paused = paused
	get_tree().paused = paused
	visible = paused
	
	if paused:
		# Automatically select the continue button when the menu opens
		continue_button.grab_focus()
		Conductor.pause_for_menu()
	else:
		Conductor.resume_from_menu()


func _on_exit_pressed() -> void:
	# Unpause first so the fade tween and scene change aren't affected
	# by the paused tree.
	SceneTransition.fade_to_scene(menu_scene_path)
	set_paused(false)



## Function to move the icon whenever a button is highlighted
func _on_button_focused(button: Control) -> void:
	# Wait one tiny frame to guarantee the UI containers have updated their positions
	await get_tree().process_frame
	
	# Adjust this to push the cursor closer or further from the text
	var icon_offset_x = 80 
	
	# Get the true on-screen bounding box of the button
	var button_rect = button.get_global_rect()
	
	# Teleport the cursor next to the button based on its exact rect size
	cursor_icon.global_position = Vector2(
		button_rect.position.x + button_rect.size.x + icon_offset_x,
		button_rect.position.y - 4  + (button_rect.size.y)  - (cursor_icon.size.y / 2.0) + button_rect.size.y
	)
