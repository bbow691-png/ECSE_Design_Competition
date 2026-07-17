extends Button

@export var bounce_scale: Vector2 = Vector2(1.15, 1.15)
@export var hover_scale: Vector2 = Vector2(1.1, 1.1) # Slightly larger when selected
@export var float_height: float = 12.0

# Colors for selection
var normal_color: Color = Color.WHITE
var selected_color: Color = Color("fff100") # Classic FNF yellow!

var active_tween: Tween

func _ready() -> void:
	await get_tree().process_frame
	pivot_offset = size / 2.0
	
	# --- 1. THE CHAOTIC TILT ---
	# Alternate rotation: Even index buttons tilt left (-3°), odd index tilt right (3°)
	rotation_degrees = -3.0 if get_index() % 2 == 0 else 3.0
	
	# --- 2. CONNECT HOVER & FOCUS SIGNALS ---
	mouse_entered.connect(_on_selected)
	focus_entered.connect(_on_selected)
	
	mouse_exited.connect(_on_deselected)
	focus_exited.connect(_on_deselected)
	
	# Connect to your global Conductor
	if Conductor:
		Conductor.beat_hit.connect(_on_conductor_beat_hit)

func _on_conductor_beat_hit(current_beat: int) -> void:
	# SAFETY CHECK: If the button isn't fully in the active scene tree, skip this beat!
	if not is_inside_tree():
		return

	# Now it is 100% safe to call get_tree()
	var cascade_delay: float = get_index() * 0.08
	get_tree().create_timer(cascade_delay).timeout.connect(bop_and_float)

func bop_and_float() -> void:
	var default_pivot_y: float = size.y / 2.0
	pivot_offset.x = size.x / 2.0
	
	if active_tween and active_tween.is_running():
		active_tween.kill()
		
	active_tween = create_tween()
	active_tween.set_parallel(true)
	
	# If we are hovered/focused, we bop from our larger hover scale!
	var target_bounce = bounce_scale if not has_focus() else bounce_scale * 1.05
	var target_normal = Vector2.ONE if not has_focus() else hover_scale
	
	scale = target_bounce
	active_tween.tween_property(self, "scale", target_normal, 0.35)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
		
	var unique_float: float = float_height + (get_index() * 3.0)
	pivot_offset.y = default_pivot_y + unique_float
	
	active_tween.tween_property(self, "pivot_offset:y", default_pivot_y, 0.45)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

# --- 3. THE HOVER / FOCUS ANIMATION ---
func _on_selected() -> void:
	# Grab focus so controller and mouse don't fight
	if not has_focus():
		grab_focus()
		
	# Quick Tween to make the button pop out, turn yellow, and slide slightly right!
	var select_tween = create_tween().set_parallel(true)
	select_tween.set_trans(Tween.TRANS_BACK)
	select_tween.set_ease(Tween.EASE_OUT)
	
	# Scale up and turn yellow
	select_tween.tween_property(self, "scale", hover_scale, 0.2)
	select_tween.tween_property(self, "modulate", selected_color, 0.2)
	# Slide 15 pixels to the right
	select_tween.tween_property(self, "position:x", 15.0, 0.2)

func _on_deselected() -> void:
	# Return back to the boring, normal state
	var deselect_tween = create_tween().set_parallel(true)
	deselect_tween.set_trans(Tween.TRANS_SINE)
	deselect_tween.set_ease(Tween.EASE_OUT)
	
	deselect_tween.tween_property(self, "scale", Vector2.ONE, 0.2)
	deselect_tween.tween_property(self, "modulate", normal_color, 0.2)
	deselect_tween.tween_property(self, "position:x", 0.0, 0.2)
