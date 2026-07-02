extends Node
# Generic object pool (D7). acquire()/release(). Contract for pooled nodes:
# re-init via activate()/reset(), NEVER _ready() (consumer concern, Story 1.3).
# Minimal scaffold for 1.1 — exercised + tested when projectiles arrive (1.3).

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
	_pools[path] = pool
	_node_paths[node.get_instance_id()] = path
	return node


func release(node: Node) -> void:
	if node == null or node.is_queued_for_deletion():
		return
	var instance_id: int = node.get_instance_id()
	if not _node_paths.has(instance_id):
		push_warning("[Pool] released a node not acquired from this pool — ignored")
		return
	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	var path: String = _node_paths[instance_id]
	_node_paths.erase(instance_id)
	var pool: Array[Node] = _pools.get(path, [] as Array[Node])
	pool.append(node)
	_pools[path] = pool
