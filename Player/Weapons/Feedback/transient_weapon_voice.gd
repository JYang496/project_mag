extends AudioStreamPlayer2D

func _ready() -> void:
	add_to_group(PhaseManager.BATTLE_RUNTIME_TRANSIENT_GROUP)
	finished.connect(cleanup_for_battle_end)

func cleanup_for_battle_end() -> void:
	stop()
	stream = null
	queue_free()

func _exit_tree() -> void:
	stop()
	stream = null
