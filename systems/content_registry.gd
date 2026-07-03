extends Node
# ContentRegistry (D9): loads + indexes all .tres content at _ready. Gameplay code
# fetches content via get_enemy_def/get_formation_def — NEVER load("res://...") in
# gameplay code (AR8); this autoload is the single content-loading layer. Adding an
# enemy/formation = drop a .tres in resources/<domain>/, zero code.
# Fail-safe (AR11): a missing EnemyDefinition falls back to grunt — never null/crash.

const _ENEMY_DIR := "res://resources/enemies/"
const _FORMATION_DIR := "res://resources/formations/"
const _GRUNT_PATH := "res://resources/enemies/enemy_grunt.tres"

var _enemy_defs: Dictionary = {}      # StringName id -> EnemyDefinition
var _formation_defs: Dictionary = {}  # StringName id -> FormationDefinition
var _grunt_fallback: EnemyDefinition


func _ready() -> void:
	for r in _load_all(_ENEMY_DIR):
		if r is EnemyDefinition:
			if _enemy_defs.has(r.id):
				Log.warn("content", "duplicate EnemyDefinition id '%s' — overwriting" % r.id)
			_enemy_defs[r.id] = r
	for r in _load_all(_FORMATION_DIR):
		if r is FormationDefinition:
			if _formation_defs.has(r.id):
				Log.warn("content", "duplicate FormationDefinition id '%s' — overwriting" % r.id)
			_formation_defs[r.id] = r
	_grunt_fallback = load(_GRUNT_PATH) as EnemyDefinition
	if _grunt_fallback == null:
		Log.err("content", "grunt fallback missing — enemy lookups can return null")
	if _enemy_defs.is_empty():
		Log.warn("content", "no EnemyDefinitions indexed (resources/enemies/ empty?)")
	Log.info("content", "indexed %d enemies, %d formations" % [_enemy_defs.size(), _formation_defs.size()])


func _load_all(dir_path: String) -> Array[Resource]:
	# Load every .tres in dir_path. Non-EnemyDefinition/FormationDefinition resources
	# (if any ever land there) are filtered by the caller's `is` check. Order is not
	# guaranteed by DirAccess; the grunt fallback is loaded by explicit path, not order.
	var out: Array[Resource] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		Log.warn("content", "content dir missing: %s" % dir_path)
		return out
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var res: Resource = load(dir_path + fname)
			if res != null:
				out.append(res)
			else:
				Log.warn("content", "failed to load resource: %s" % fname)
		fname = dir.get_next()
	dir.list_dir_end()
	return out


func get_enemy_def(id: StringName) -> EnemyDefinition:
	# Return the indexed EnemyDefinition for id. On a miss, log + return the grunt
	# fallback (AR11 fail-safe) — never null, never a hard crash.
	var def: EnemyDefinition = _enemy_defs.get(id)
	if def == null:
		Log.err("content", "missing EnemyDefinition '%s' — grunt fallback" % id)
		return _grunt_fallback
	return def


func get_formation_def(id: StringName) -> FormationDefinition:
	# Return the indexed FormationDefinition for id. No fallback (unlike enemies) — a
	# miss is a genuine config error; the caller guards against null.
	var def: FormationDefinition = _formation_defs.get(id)
	if def == null:
		Log.err("content", "missing FormationDefinition '%s'" % id)
	return def


func get_power_up_def(_id: StringName) -> Resource:
	# Stub — power-up content lands in Story 3.2.
	return null
