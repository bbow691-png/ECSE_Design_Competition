extends ProgressBar

func _ready() -> void:
	min_value = 0.0
	max_value = Health.MAX_HEALTH
	value = Health.health
	Health.health_changed.connect(_on_health_changed)


func _on_health_changed(new_health: float) -> void:
	value = new_health
