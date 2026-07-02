extends Node
# Thin logging wrapper — the ONLY place print-family calls may live.
# Format: [LEVEL][system] message. Release = WARN+; dev = DEBUG.
# (project-context: no print() in shipped code; route through Log.)

enum Level { ERROR, WARN, INFO, DEBUG }

var _min_level: int = Level.INFO


func _ready() -> void:
	_min_level = Level.DEBUG if OS.is_debug_build() else Level.WARN


func is_debug() -> bool:
	return OS.is_debug_build()


func err(system: String, message: String) -> void:
	if _min_level >= Level.ERROR:
		push_error(_format("ERROR", system, message))


func warn(system: String, message: String) -> void:
	if _min_level >= Level.WARN:
		push_warning(_format("WARN", system, message))


func info(system: String, message: String) -> void:
	if _min_level >= Level.INFO:
		print(_format("INFO", system, message))


func debug(system: String, message: String) -> void:
	if _min_level >= Level.DEBUG:
		print(_format("DEBUG", system, message))


func _format(level: String, system: String, message: String) -> String:
	return "[%s][%s] %s" % [level, system, message]
