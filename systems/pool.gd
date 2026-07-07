extends Node
# Generic object pool (D7). acquire()/release(). Contract for pooled nodes:
# re-init via activate()/reset(), NEVER _ready() (consumer concern, Story 1.3).
# 1.3 adds D7 deactivation in release() (idle pooled nodes stop processing/render);
# acquire() is unchanged — the consumer's activate() re-enables the node.

var _pools: Dictionary = {}      # resource_path -> Array[Node] of inactive nodes
var _node_paths: Dictionary = {} # instance_id (int) -> resource_path used at acquire


func acquire(scene: PackedScene) -> Node:
	var path: String = scene.resource_path
	var pool: Array[Node] = _pools.get(path, [] as Array[Node])
	var node: Node
	if pool.is_empty():
		node = scene.instantiate()
	else:
		node = pool.pop_back()
		# Defensive fail-safe (AR11): a pooled entry can be freed out-of-band — e.g. the
		# game-over replay's reload_current_scene() frees the arena subtree while released
		# pooled nodes linger, or a clear() forgets nodes without freeing them. Never hand a
		# freed node back to a consumer; make a fresh one instead of hard-crashing.
		if not is_instance_valid(node):
			node = scene.instantiate()
	_pools[path] = pool
	_node_paths[node.get_instance_id()] = path
	return node


func release(node: Node) -> void:
	if node == null or node.is_queued_for_deletion():
		return
	var instance_id: int = node.get_instance_id()
	# Idempotent: a node already released was erased from _node_paths on its first
	# release, so it falls through to the "not acquired" branch — no double-append,
	# no crash. (The _node_paths.has guard covers re-release.)
	if not _node_paths.has(instance_id):
		push_warning("[Pool] released a node not acquired from this pool — ignored")
		return
	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	# D7: inactive pooled nodes must not process/render. Generic teardown — Node
	# methods for processing, CanvasItem.visible duck-typed for rendering. The
	# consumer's activate() flips these back on (re-init via activate(), never here).
	_deactivate(node)
	var path: String = _node_paths[instance_id]
	_node_paths.erase(instance_id)
	var pool: Array[Node] = _pools.get(path, [] as Array[Node])
	pool.append(node)
	_pools[path] = pool


func clear() -> void:
	# Called by test before_each() hooks (Pool is an autoload — state otherwise persists
	# across every GUT test) AND by Arena's game-over replay (Story 1.5). Released/inactive
	# nodes are detached from the scene tree in release() (parent.remove_child) and kept
	# alive only by _pools' Array references — Godot 4 Node is NOT RefCounted, so dropping
	# those references without freeing would leak them (a real leak on every replay, since
	# reload_current_scene() only frees tree-attached nodes, not these detached ones).
	for pool: Array[Node] in _pools.values():
		for node: Node in pool:
			if is_instance_valid(node):
				node.free()
	_pools.clear()
	_node_paths.clear()


func get_pooled_count() -> int:
	# Total IDLE pooled nodes (across all pools) — currently released, NOT in play. Read-only
	# (Story 1.8 / FR50: the debug overlay reads this). _pools maps resource_path → Array of idle nodes.
	# Skips stale entries (a node freed out-of-band instead of via release() — same defensive
	# case acquire() already guards against) so the overlay's count can't silently drift upward.
	var total: int = 0
	for pool: Array[Node] in _pools.values():
		for node: Node in pool:
			if is_instance_valid(node):
				total += 1
	return total


func get_active_count() -> int:
	# Outstanding ACQUIRED nodes (in play, not yet released). Read-only (Story 1.8 / FR50).
	# _node_paths maps each live acquired node's instance_id → its resource_path; counts only
	# instance_ids still resolvable to a live node (see get_pooled_count() for the same guard).
	var total: int = 0
	for instance_id: int in _node_paths.keys():
		if is_instance_id_valid(instance_id):
			total += 1
	return total


func _deactivate(node: Node) -> void:
	# D7 gap from 1.1: stop processing + hide so pooled nodes cost nothing while idle.
	# set_process/set_physics_process are Node methods; `visible` is CanvasItem-only
	# and `monitoring`/`monitorable` are Area2D-only, so duck-type both (a pooled
	# node may not be a CanvasItem/Area2D in future use cases).
	node.set_process(false)
	node.set_physics_process(false)
	if node is CanvasItem:
		node.visible = false
	if node is Area2D:
		node.monitoring = false
		node.monitorable = false
