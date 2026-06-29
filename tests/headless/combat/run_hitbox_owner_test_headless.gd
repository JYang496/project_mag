extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _assert_beam_blast_binds_hitbox_owner_in_ready():
		return
	print("PASS: HitBox owner binding")
	quit(0)


func _assert_beam_blast_binds_hitbox_owner_in_ready() -> bool:
	var beam_scene := load("res://Player/Weapons/Projectiles/beam_blast.tscn") as PackedScene
	var beam := beam_scene.instantiate() as Node2D
	root.add_child(beam)
	var hitbox := beam.get_node_or_null("HitBoxDot")
	if hitbox == null:
		return _fail("beam_blast missing HitBoxDot")
	if hitbox.get("hitbox_owner") != beam:
		return _fail("beam_blast HitBoxDot owner was not bound during _ready")
	beam.free()
	return true


func _fail(message: String) -> bool:
	push_error("FAIL: HitBox owner binding: %s" % message)
	quit(1)
	return false
