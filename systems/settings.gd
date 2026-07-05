extends Node
# Player prefs → ConfigFile → user://settings.cfg (NFR9, AR10 player tier).
# SKELETON for 1.1 — reduced_motion/ui_scale/deadzone/remap land when
# consumed (1.6 juice / E8 panel), per D14. Log loads before Settings.

signal setting_changed(key: StringName, value: Variant)

const SETTINGS_PATH := "user://settings.cfg"
const _SECTION := "prefs"

var _config := ConfigFile.new()

# Reduced-motion key (Story 1.6 / D14 — accessibility input). Consumed by the
# JuiceCoordinator; the player-facing toggle UI ships at Story 8.4 (E8). Default
# false so the v0.1 feel gate evaluates FULL juice (A1 = "default-on *capable*").
const REDUCED_MOTION_KEY := &"reduced_motion"


func _ready() -> void:
	var err := _config.load(SETTINGS_PATH)
	if err == ERR_FILE_NOT_FOUND:
		pass # first run — no prefs yet; not an error
	elif err != OK:
		Log.warn("settings", "failed to load prefs (code %d) — using defaults" % err)
		_config.clear() # discard any partial parse state from a corrupted file


func get_value(key: String, default: Variant) -> Variant:
	return _config.get_value(_SECTION, key, default)


func set_value(key: String, value: Variant) -> void:
	_config.set_value(_SECTION, key, value)
	var err := _config.save(SETTINGS_PATH)
	if err != OK:
		Log.warn("settings", "failed to save prefs (code %d)" % err)
	setting_changed.emit(StringName(key), value)


# --- reduced_motion (Story 1.6 / D14) ---
# Typed accessors over the existing ConfigFile mechanism. set_reduced_motion
# persists + emits setting_changed(&"reduced_motion", value) via set_value — the
# JuiceCoordinator listens and re-derives _motion_scale. Do NOT duplicate the signal.
func get_reduced_motion() -> bool:
	return bool(get_value(REDUCED_MOTION_KEY, false))


func set_reduced_motion(value: bool) -> void:
	set_value(REDUCED_MOTION_KEY, value)
