extends CanvasLayer

@onready var panel: Control = $PanelContainer
@onready var lvl1: Button = $PanelContainer/VBoxContainer/level1
@onready var lvl2: Button = $PanelContainer/VBoxContainer/level2

# Make sure you have a node named CursorIcon in your scene tree!
@onready var cursor_icon: Control = $CursorIcon 
var level_data: Array[Dictionary] = [
	{ "scene": "res://scenes/game_scene/scene_1.tscn", "name": "Frog battle" },
	{ "scene": "res://scenes/scene_2.tscn", "name": "Panda battle" },
	{ "scene": "res://scenes/scene_2.tscn", "name": "Panda battle" } # Fallback/3rd stop
]
@export var menu_scene_path: String = "res://scenes/game_scene/walk_around.tscn"

var is_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	
	# Connect standard button presses
	lvl1.pressed.connect(_on_continue_pressed)
	lvl2.pressed.connect(_on_exit_pressed)
	
	# Connect focus signals for the FNF cursor icon
	lvl1.focus_entered.connect(_on_button_focused.bind(lvl1))
	lvl2.focus_entered.connect(_on_button_focused.bind(lvl2))

	# Set initial focus so current_focus isn't null
	lvl1.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
		# Handle scrolling UP
	var current_focus = get_viewport().gui_get_focus_owner()

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



func _on_continue_pressed() -> void:
	SceneTransition.fade_to_scene("res://scenes/game_scene/scene_1.tscn")


func _on_exit_pressed() -> void:
	# Unpause first so the fade tween and scene change aren't affected
	# by the paused tree.
	SceneTransition.fade_to_scene("res://scenes/scene_2.tscn")



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
