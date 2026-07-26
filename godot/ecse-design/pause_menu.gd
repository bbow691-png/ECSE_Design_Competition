extends CanvasLayer

@onready var panel: Control = $PanelContainer
@onready var continue_button: Button = $PanelContainer/VBoxContainer/ContinueButton
@onready var exit_button: Button = $PanelContainer/VBoxContainer/ExitButton

@export var menu_scene_path: String = "res://scenes/game_scene/walk_around.tscn"

var is_paused: bool = false

func _ready() -> void:
	# Lets this node (and its children/input) keep working while the
	# rest of the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	visible = false

	continue_button.pressed.connect(_on_continue_pressed)
	exit_button.pressed.connect(_on_exit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		toggle_pause()


func toggle_pause() -> void:
	set_paused(not is_paused)

func _on_continue_pressed() -> void:
	set_paused(false)

func set_paused(paused: bool) -> void:
	is_paused = paused
	get_tree().paused = paused
	visible = paused

	if paused:
		Conductor.pause_for_menu()
	else:
		Conductor.resume_from_menu()


func _on_exit_pressed() -> void:
	# Unpause first so the fade tween and scene change aren't affected
	# by the paused tree.
	set_paused(false)
	SceneTransition.fade_to_scene(menu_scene_path)
