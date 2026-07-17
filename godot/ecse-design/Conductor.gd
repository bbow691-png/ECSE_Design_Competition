extends Node

# --- Song Settings ---
var bpm: float = 100.0
var crochet: float = 0.0     
var step_crochet: float = 0.0 

# --- Time Tracking ---
var song_position: float = 0.0
var last_reported_playhead: float = 0.0
var song_beat: int = 0
var song_step: int = 0

# --- Signals ---
signal beat_hit(beat: int)
signal step_hit(step: int)

# --- Dynamic Audio Players ---
var active_player: AudioStreamPlayer
var fading_player: AudioStreamPlayer
var fade_tween: Tween

func _ready() -> void:
	# Create two audio players inside the Conductor so they persist across scenes
	active_player = AudioStreamPlayer.new()
	fading_player = AudioStreamPlayer.new()
	add_child(active_player)
	add_child(fading_player)
	
	map_bpm(bpm)

func map_bpm(new_bpm: float) -> void:
	bpm = new_bpm
	crochet = 60.0 / bpm          
	step_crochet = crochet / 4.0  

# CALL THIS from any scene's script to change music with a smooth fade!
func play_with_fade(new_stream: AudioStream, new_bpm: float, fade_time: float = 1.0) -> void:
	# If a fade is already happening, stop it to prevent overlapping bugs
	if fade_tween and fade_tween.is_running():
		fade_tween.kill()
		
	# 1. Swap the players (the current active player becomes the fading player)
	var old_player = active_player
	active_player = fading_player
	fading_player = old_player
	
	# 2. Setup and start the NEW song completely silent
	map_bpm(new_bpm)
	active_player.stream = new_stream
	active_player.volume_db = -80.0 # Silent
	active_player.play()
	
	# Reset beat counts
	song_position = 0.0
	last_reported_playhead = 0.0
	song_beat = 0
	song_step = 0
	
	# 3. Animate the crossfade
	fade_tween = create_tween()
	fade_tween.set_parallel(true)
	
	# Fade out the old player and then stop it
	fade_tween.tween_property(fading_player, "volume_db", -80.0, fade_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
		
	# Fade in the new player to full volume (0.0 dB)
	fade_tween.tween_property(active_player, "volume_db", 0.0, fade_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
		
	# When done, shut down the fading player so it doesn't waste CPU
	fade_tween.chain().tween_callback(fading_player.stop)

func _process(delta: float) -> void:
	if not active_player.playing:
		return

	var raw_pos: float = active_player.get_playback_position()
	
	if raw_pos != last_reported_playhead:
		last_reported_playhead = raw_pos
		song_position = raw_pos
	else:
		song_position = raw_pos + AudioServer.get_time_since_last_mix()
	
	song_position -= AudioServer.get_output_latency()
	_update_steps_and_beats()

func _update_steps_and_beats() -> void:
	var current_step: int = floor(song_position / step_crochet)
	var current_beat: int = floor(song_position / crochet)

	if current_step > song_step:
		song_step = current_step
		step_hit.emit(song_step)

	if current_beat > song_beat:
		song_beat = current_beat
		beat_hit.emit(song_beat)
