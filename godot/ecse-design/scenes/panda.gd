extends Sprite2D

@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")

# Boss note hit_times we've been told about but haven't reached yet.
# Notes spawn ~spawn_lead_time seconds early, so we hold them here and
# only act on one once the song's clock actually reaches its hit_time.
var boss_hit_queue: Array[float] = []

# State machine with only IDLE and two-part TRANSITION (In then Out/Reverse)
enum State { IDLE, TRANSITION_IN, TRANSITION_OUT }

var state: State = State.IDLE
var state_timer: float = 0.0


func _ready() -> void:
	if anim_player == null:
		print("Boss character: no AnimationPlayer child found on ", get_path(), " — check the node name/path.")
		return
	Conductor.note_spawned.connect(_on_song_manager_note_spawned)


func _on_song_manager_note_spawned(pad_index: int, hit_time: float, boss: int) -> void:
	if boss == 0:
		boss_hit_queue.append(hit_time)


func _process(delta: float) -> void:
	if anim_player == null:
		return

	# Trigger every queued hit whose time has actually arrived.
	while boss_hit_queue.size() > 0 and Conductor.get_song_position() >= boss_hit_queue[0]:
		boss_hit_queue.pop_front()
		_on_hit_triggered()

	if state_timer > 0.0:
		state_timer -= delta
		if state_timer <= 0.0:
			_advance_state()


func _on_hit_triggered() -> void:
	# A fresh hit always interrupts whatever is currently playing 
	# and starts the transition sequence from the beginning.
	_enter_state(State.TRANSITION_IN)


func _advance_state() -> void:
	match state:
		State.TRANSITION_IN:
			# Finished playing "transition" forward -> play it in reverse
			_enter_state(State.TRANSITION_OUT)
		State.TRANSITION_OUT:
			# Finished playing "transition" in reverse -> go back to idle
			_enter_state(State.IDLE)
		State.IDLE:
			pass


func _enter_state(new_state: State) -> void:
	state = new_state
	match new_state:
		State.TRANSITION_IN:
			# Play "transition" forward
			state_timer = _play("transition", false)
		State.TRANSITION_OUT:
			# Play "transition" backward
			state_timer = _play("transition", true)
		State.IDLE:
			# Return to idle loop
			_play("idle", false)
			state_timer = 0.0


# Plays anim_name (or its reverse) with zero blend time so the switch is
# instant, and returns its length in seconds (adjusted for speed_scale)
# so the caller knows how long to hold this state before advancing.
func _play(anim_name: String, backwards: bool) -> float:
	if not anim_player.has_animation(anim_name):
		print("Boss character: no animation named '", anim_name, "' found on ", anim_player.get_path())
		return 0.0

	var anim: Animation = anim_player.get_animation(anim_name)
	var speed: float = abs(anim_player.speed_scale) if anim_player.speed_scale != 0.0 else 1.0
	var duration: float = anim.length / speed

	if backwards:
		anim_player.play_backwards(anim_name, 0.0)
	else:
		anim_player.play(anim_name, 0.0)

	return duration
