extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

func _ready() -> void:
	color_rect.color.a = 0.0 
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

# Call this from any script in your game!
func fade_to_scene(target_scene: String, fade_duration: float = 0.5) -> void:
	var tween = create_tween()
	
	# 1. Fade out the Conductor's music (Runs in parallel with the screen fade)
	if Conductor.active_player and Conductor.active_player.playing:
		var audio_tween = create_tween()
		
		# Tween the volume down to -80 decibels (silence)
		audio_tween.tween_property(Conductor.active_player, "volume_db", -80.0, fade_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		# Once the audio is silent, pause the song and reset the volume invisibly
		# so the next scene's song doesn't start off muted!
		Conductor.pause_song()

	# 2. Fade to Black
	tween.tween_property(color_rect, "color:a", 1.0, fade_duration)\
	.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	await tween.finished
	
	# 3. Change the actual scene in the background
	get_tree().change_scene_to_file(target_scene)
	
	# 4. Fade back to clear
	var fade_in_tween = create_tween()
	fade_in_tween.tween_property(color_rect, "color:a", 0.0, fade_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
