extends Button

@export var bounce_scale: Vector2 = Vector2(1.15, 1.15)
@export var hover_scale: Vector2 = Vector2(1.1, 1.1)
@export var float_height: float = 12.0
@export var tilt_angle: float = 3.5

# --- POLISHED FNF COLOR PALETTE ---
@export var text_color: Color = Color.WHITE
@export var text_outline_color: Color = Color.BLACK

@export var normal_bg_color: Color = Color("0a1118", 0.45) 
@export var selected_bg_color: Color = Color("e01255", 0.85)

var active_tween: Tween
var is_active: bool = false
var bg_stylebox: StyleBoxFlat

# --- WIGGLE VARIABLES ---
var base_tilt: float = 0.0
var time_passed: float = 0.0

func _ready() -> void:
	# 1. CREATE THE POLISHED BACKGROUND BAND
	bg_stylebox = StyleBoxFlat.new()
	bg_stylebox.bg_color = normal_bg_color
	
	# EQUAL MARGINS FOR PERFECT CENTERING
	bg_stylebox.content_margin_left = 40.0 
	bg_stylebox.content_margin_right = 40.0 
	bg_stylebox.content_margin_top = 15.0
	bg_stylebox.content_margin_bottom = 15.0
	
	# SHAPE AND DROP SHADOW
	bg_stylebox.skew = Vector2(0.15, 0.0) 
	
	# --- ALL 4 CORNERS ROUNDED ---
	bg_stylebox.corner_radius_top_right = 20 
	bg_stylebox.corner_radius_bottom_right = 20
	bg_stylebox.corner_radius_top_left = 20 
	bg_stylebox.corner_radius_bottom_left = 20
	# -----------------------------
	
	bg_stylebox.shadow_color = Color(0, 0, 0, 0.6) # Soft 60% black shadow
	bg_stylebox.shadow_size = 12
	bg_stylebox.shadow_offset = Vector2(4, 4)
	
	add_theme_stylebox_override("normal", bg_stylebox)
	add_theme_stylebox_override("hover", bg_stylebox)
	add_theme_stylebox_override("focus", bg_stylebox)
	add_theme_stylebox_override("pressed", bg_stylebox)
	
	# 2. FORCE HEAVY FNF TEXT STYLING
	add_theme_color_override("font_color", text_color)
	add_theme_color_override("font_focus_color", text_color)
	add_theme_color_override("font_hover_color", text_color)
	add_theme_color_override("font_pressed_color", text_color) 
	add_theme_color_override("font_disabled_color", text_color) 
	add_theme_color_override("font_hover_pressed_color", text_color)
	add_theme_color_override("font_outline_color", text_outline_color)
	add_theme_constant_override("outline_size", 16)
	add_theme_stylebox_override("disabled", bg_stylebox)
	
	# 3. CONNECT SIGNALS
	mouse_entered.connect(_on_selected)
	focus_entered.connect(_on_selected)
	mouse_exited.connect(_on_deselected)
	focus_exited.connect(_on_deselected)
	
	# Check for global rhythm conductor
	if has_node("/root/Conductor"):
		var conductor = get_node("/root/Conductor")
		if conductor.has_signal("beat_hit"):
			conductor.beat_hit.connect(_on_conductor_beat_hit)

	# 4. WAIT FOR CONTAINER TO FINISH MATH
	call_deferred("_init_transform")

func _init_transform() -> void:
	# Assign initial chaotic tilt and stagger the time so they don't wiggle perfectly synced
	base_tilt = -tilt_angle if get_index() % 2 == 0 else tilt_angle
	time_passed = get_index() * 0.4

# -------------------------------------------------------------
# CONSTANT TRANSFORM OVERRIDE (Defeats VBoxContainer locks)
# -------------------------------------------------------------
func _process(delta: float) -> void:
	time_passed += delta
	
	# Force rotation via sine wave for a smooth "breathing" rock effect
	rotation_degrees = base_tilt + (sin(time_passed * 2.5) * 1.5)
	
	# Keep the X pivot exactly centered at all times
	pivot_offset.x = size.x / 2.0
	
	# Lock the Y pivot only if the rhythm bounce is inactive
	if not (active_tween and active_tween.is_running()):
		pivot_offset.y = size.y / 2.0

# -------------------------------------------------------------
# RHYTHM BOUNCING
# -------------------------------------------------------------
func _on_conductor_beat_hit(current_beat: int) -> void:
	if not is_inside_tree(): return

	# Stagger the bounce down the list
	var cascade_delay: float = get_index() * 0.08
	get_tree().create_timer(cascade_delay).timeout.connect(bop_and_float)

func bop_and_float() -> void:
	if not is_inside_tree(): return

	var default_pivot_y: float = size.y / 2.0
	
	if active_tween and active_tween.is_running():
		active_tween.kill()
		
	active_tween = create_tween()
	active_tween.set_parallel(true)
	
	var target_bounce = bounce_scale if not is_active else bounce_scale * 1.05
	var target_normal = Vector2.ONE if not is_active else hover_scale
	
	# 1. Scale Bop
	scale = target_bounce
	active_tween.tween_property(self, "scale", target_normal, 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	# 2. Vertical Float
	var unique_float: float = float_height + (get_index() * 3.0)
	pivot_offset.y = default_pivot_y + unique_float
	active_tween.tween_property(self, "pivot_offset:y", default_pivot_y, 0.45)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# -------------------------------------------------------------
# HOVER AND SELECTION EFFECTS
# -------------------------------------------------------------
func _on_selected() -> void:
	if is_active: return 
	is_active = true
	
	if not has_focus(): grab_focus()
		
	var select_tween = create_tween().set_parallel(true)
	select_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Visually scale and change color
	select_tween.tween_property(self, "scale", hover_scale, 0.2)
	select_tween.tween_property(bg_stylebox, "bg_color", selected_bg_color, 0.1)

func _on_deselected() -> void:
	if not is_active: return
	if has_focus() and not Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()):
		return

	is_active = false
	
	var deselect_tween = create_tween().set_parallel(true)
	deselect_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Retract back to resting state
	deselect_tween.tween_property(self, "scale", Vector2.ONE, 0.2)
	deselect_tween.tween_property(bg_stylebox, "bg_color", normal_bg_color, 0.2)
# -------------------------------------------------------------
# FNF CONFIRMATION FLASH
# -------------------------------------------------------------
func confirm_flash() -> void:
	# Stop the hover/rhythm animations so they don't fight the flash
	if active_tween and active_tween.is_running():
		active_tween.kill()
		
	# Create a fast, looping tween just for the flash effect
	var flash_tween = create_tween().set_loops(4) 
	
	# Rapidly alternate the background band between Pure White and Magenta!
	flash_tween.tween_property(bg_stylebox, "bg_color", Color.WHITE, 0.05)
	flash_tween.tween_property(bg_stylebox, "bg_color", selected_bg_color, 0.05)
