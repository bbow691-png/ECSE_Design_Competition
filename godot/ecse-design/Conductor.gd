extends Node

# --- Song Settings ---
var bpm: float = 128.0
var crochet: float = 0.0     # Time of one beat in seconds
var step_crochet: float = 0.0 # Time of a 16th note (step) in seconds

# --- Time Tracking ---
var song_position: float = 0.0
var last_reported_playhead: float = 0.0

# --- Current Beats & Steps ---
var song_beat: int = 0
var song_step: int = 0

# --- Signals ---
signal beat_hit(beat: int)
signal step_hit(step: int)

# The internal audio player managed globally
var audio_player: AudioStreamPlayer

func _ready() -> void:
	
	# Create and configure the audio player dynamically
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	# Default setup
	map_bpm(bpm)

# Call this when starting a new song to map the correct timings
func map_bpm(new_bpm: float) -> void:
	bpm = new_bpm
	crochet = 60.0 / bpm          # e.g., at 120 BPM, a beat is 0.5 seconds
	step_crochet = crochet / 4.0  # 4 steps per beat (16th notes)

# Call this from any script to load a song and start tracking it
func play_song(stream: AudioStream, song_bpm: float) -> void:
	map_bpm(song_bpm)
	audio_player.stream = stream
	audio_player.play()
	
	# Reset state
	song_position = 0.0
	last_reported_playhead = 0.0
	song_beat = 0
	song_step = 0

func stop_song() -> void:
	audio_player.stop()

func _process(delta: float) -> void:
	if not audio_player.playing:
		return

	# 1. Grab raw position from the audio hardware
	var raw_pos: float = audio_player.get_playback_position()
	
	# 2. Prevent the time from getting stuck between audio buffer mixes
	if raw_pos != last_reported_playhead:
		last_reported_playhead = raw_pos
		song_position = raw_pos
	else:
		# Interpolate time passed since last audio mix
		song_position = raw_pos + AudioServer.get_time_since_last_mix()
	
	# Correct for output latency (especially crucial for Bluetooth or weak drivers)
	song_position -= AudioServer.get_output_latency()

	# 3. Calculate steps and beats
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
