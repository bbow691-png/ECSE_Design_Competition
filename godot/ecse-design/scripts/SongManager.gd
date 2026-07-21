extends Node

# --------------------------------------------------------------------
# SongManager.gd (Autoload / Singleton)
# --------------------------------------------------------------------

signal note_spawned(lane_index)

var current_beatmap: Dictionary = {}
var current_note_index: int = 0
var song_time: float = 0.0
var is_playing: bool = false
var spawn_lead_time: float = 2.0 # Seconds before hit time to spawn the note
var music_player: AudioStreamPlayer

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	# Initialization code goes here if needed
	pass

func _process(delta: float) -> void:
	if not is_playing:
		return
		
	song_time += delta

	# Check the beatmap queue for any notes that need to spawn
	while current_note_index < current_beatmap.get("notes", []).size():
		var note = current_beatmap["notes"][current_note_index]
		var target_time = note["time"]
		
		# Spawn early so it has time to fall down the screen to the hit line
		if song_time >= (target_time - spawn_lead_time):
			emit_signal("note_spawned", note["pad"])
			current_note_index += 1
		else:
			break


func load_and_play_song(song_folder_path: String) -> void:
	var json_path = song_folder_path + "/beatmap.json"
	if not FileAccess.file_exists(json_path):
		print("Beatmap not found at: ", json_path)
		return
		
	var file = FileAccess.open(json_path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		print("JSON Parse Error: ", json.get_error_message())
		return
		
	current_beatmap = json.get_data()
	current_note_index = 0
	#song_time = -spawn_lead_time
	song_time = 0.0
	is_playing = true
	print("Loaded song: ", current_beatmap.get("title", "Unknown"))
	
	# --- New: load and play the mp3 ---
	var mp3_path = song_folder_path + "/song.mp3"
	if not FileAccess.file_exists(mp3_path):
		print("MP3 not found at: ", mp3_path)
		return
	
	var mp3_file = FileAccess.open(mp3_path, FileAccess.READ)
	var mp3_bytes = mp3_file.get_buffer(mp3_file.get_length())
	mp3_file.close()
	
	var stream = AudioStreamMP3.new()
	stream.data = mp3_bytes
	
	music_player.stream = stream
	music_player.play()
