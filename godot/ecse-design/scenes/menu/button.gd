extends Button

@export var bounce_scale: Vector2 = Vector2(1.15, 1.15)
@export var hover_scale: Vector2 = Vector2(1.1, 1.1)
@export var float_height: float = 12.0

# Colors for selection
var normal_color: Color = Color.WHITE
var selected_color: Color = Color("fff100") # FNF yellow

var active_tween: Tween
var is_active: bool = false # Prevents duplicate signals from fighting

func _ready() -> void:
	await get_tree().process_frame
	pivot_offset = size / 2.0
	
	# --- 1. THE CHAOTIC TILT ---
	rotation_degrees = -3.0 if get_index() % 2 == 0 else 3.0
	
	# --- 2. CONNECT SIGNALS ---
	mouse_entered.connect(_on_selected)
	focus_entered.connect(_on_selected)
	
	mouse_exited.connect(_on_deselected)
	focus_exited.connect(_on_deselected)
	
	if Conductor:
		Conductor.beat_hit.connect(_on_conductor_beat_hit)

func _on_conductor_beat_hit(current_beat: int) -> void:
	if not is_inside_tree():
		return

	var cascade_delay: float = get_index() * 0.08
	get_tree().create_timer(cascade_delay).timeout.connect(bop_and_float)

func bop_and_float() -> void:
	if not is_inside_tree():
		return

	var default_pivot_y: float = size.y / 2.0
	pivot_offset.x = size.x / 2.0
	
	if active_tween and active_tween.is_running():
		active_tween.kill()
		
	active_tween = create_tween()
	active_tween.set_parallel(true)
	
	# Determine target scales based on selection state
	var target_bounce = bounce_scale if not is_active else bounce_scale * 1.05
	var target_normal = Vector2.ONE if not is_active else hover_scale
	
	# 1. Scale bop
	scale = target_bounce
	active_tween.tween_property(self, "scale", target_normal, 0.35)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
		
	# 2. Vertical float (modifying pivot keeps it safe from VBoxContainer!)
	var unique_float: float = float_height + (get_index() * 3.0)
	pivot_offset.y = default_pivot_y + unique_float
	
	active_tween.tween_property(self, "pivot_offset:y", default_pivot_y, 0.45)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

# --- 3. SAFE HOVER / FOCUS ANIMATIONS ---
func _on_selected() -> void:
	if is_active:
		return # Already selected, do nothing!
	
	is_active = true
	
	# Grab focus so keyboard and mouse sync up cleanly
	if not has_focus():
		grab_focus()
		
	# Create a quick pop-out and yellow color shift
	var select_tween = create_tween().set_parallel(true)
	select_tween.set_trans(Tween.TRANS_BACK)
	select_tween.set_ease(Tween.EASE_OUT)
	
	select_tween.tween_property(self, "scale", hover_scale, 0.2)
	select_tween.tween_property(self, "modulate", selected_color, 0.2)

func _on_deselected() -> void:
	# Ensure the mouse actually left and we don't still have keyboard focus
	if not is_active:
		return
		
	# If we still have focus (like navigating with a keyboard), don't deselect yet
	if has_focus() and not Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()):
		return

	is_active = false
	
	# Smoothly return to the resting scale and white color
	var deselect_tween = create_tween().set_parallel(true)
	deselect_tween.set_trans(Tween.TRANS_SINE)
	deselect_tween.set_ease(Tween.EASE_OUT)
	
	deselect_tween.tween_property(self, "scale", Vector2.ONE, 0.2)
	deselect_tween.tween_property(self, "modulate", normal_color, 0.2)
