extends Node
# STUB (Story 1.1). Will persist META to user:// (unlocks / feats / best stats,
# D5/ADR-3) with a versioned schema for migration — DISTINCT from Settings
# (player prefs). Core save lands in Story 4.6; full meta in 7.4.

const SAVE_PATH := "user://meta_save.json"
const SCHEMA_VERSION := 1


func save_meta(_data: Dictionary) -> void:
	Log.warn("save", "SaveManager.save_meta is a stub — implemented in Story 4.6")


func load_meta() -> Dictionary:
	Log.warn("save", "SaveManager.load_meta is a stub — implemented in Story 4.6")
	return {}
