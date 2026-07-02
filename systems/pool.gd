extends Node
# Generic object pool (D7). acquire()/release(). Contract for pooled nodes:
# re-init via activate()/reset(), NEVER _ready() (consumer concern, Story 1.3).
# Minimal scaffold for 1.1 — exercised + tested when projectiles arrive (1.3).

var _pools: Dictionary = {} # scene resource path -> Array[Node] of inactive nodes


func acquire(scene: PackedScene) -> Node:
	var path := scene.resource_path
	var pool: Array = _pools.get(path, [])
	var node: Node = null
	if pool.is_empty():
		node = scene.instantiate()
	else:
		node = pool.pop_back()
	_pools[path] = pool
	return node


func release(node: Node) -> void:
	if node == null:
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	var path := node.get_scene_file_path()
	if path.is_empty():
		path = "__generic__"
	var pool: Array = _pools.get(path, [])
	pool.append(node)
	_pools[path] = pool
