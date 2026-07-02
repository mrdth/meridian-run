extends Node
# Player prefs → ConfigFile → user://settings.cfg (NFR9, AR10 player tier).
# SKELETON for 1.1 — reduced_motion/ui_scale/deadzone/remap land when
# consumed (1.6 juice / E8 panel), per D14. Log loads before Settings.

signal setting_changed(key: StringName, value: Variant)

const SETTINGS_PATH := "user://settings.cfg"
const _SECTION := "prefs"

var _config := ConfigFile.new()


func _ready() -> void:
	var err := _config.load(SETTINGS_PATH)
	if err == ERR_FILE_NOT_FOUND:
		pass # first run — no prefs yet; not an error
	elif err != OK:
		Log.warn("settings", "failed to load prefs (code %d) — using defaults" % err)


func get_value(key: String, default: Variant) -> Variant:
	return _config.get_value(_SECTION, key, default)


func set_value(key: String, value: Variant) -> void:
	_config.set_value(_SECTION, key, value)
	setting_changed.emit(StringName(key), value)
	var err := _config.save(SETTINGS_PATH)
	if err != OK:
		Log.warn("settings", "failed to save prefs (code %d)" % err)
