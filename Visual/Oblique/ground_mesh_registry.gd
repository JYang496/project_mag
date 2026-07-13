class_name GroundMeshRegistry
extends RefCounted

var _view: Node
var board_renderer: BoardGroundRenderer
var connected_renderer: ConnectedEffectRenderer
var aura_renderer: AuraRenderer
var area_renderer: AreaEffectRenderer
var mesh_pool: GroundMeshInstancePool

func setup(
	view: Node,
	board: BoardGroundRenderer,
	connected: ConnectedEffectRenderer,
	aura: AuraRenderer,
	area: AreaEffectRenderer
) -> void:
	_view = view
	board_renderer = board
	connected_renderer = connected
	aura_renderer = aura
	area_renderer = area
	mesh_pool = GroundMeshInstancePool.new()
	mesh_pool.setup(_view.get("_ground_root") as Node3D)

func sync_late(delta: float) -> void:
	if not _is_ready():
		return
	board_renderer.sync_late(delta)
	area_renderer.sync_late(delta)
	connected_renderer.sync_late(delta)
	aura_renderer.sync_late(delta)

func clear() -> void:
	if board_renderer != null:
		board_renderer.clear()
	if area_renderer != null:
		area_renderer.clear()
	if connected_renderer != null:
		connected_renderer.clear()
	if aura_renderer != null:
		aura_renderer.clear()
	if mesh_pool != null:
		mesh_pool.clear()

func acquire_mesh(pool_key: StringName, mesh_resource: Mesh = null) -> MeshInstance3D:
	return mesh_pool.acquire(pool_key, mesh_resource)

func release_mesh(instance: MeshInstance3D) -> void:
	mesh_pool.release(instance)

func _is_ready() -> bool:
	return _view != null and is_instance_valid(_view)
