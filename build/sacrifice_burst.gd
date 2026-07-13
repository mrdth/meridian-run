class_name SacrificeBurst
extends RefCounted
# Story 2.6 — NP3 output: pure data (no Node, no signals). `power` is the threat-clamped scalar
# produced by BuildRecompute.threat_ceiling(); `duration` is the fixed buff window. The fixed burst
# SHAPE (spread / cooldown / shot count / damage base) lives in SacrificeTuning and is read by
# FireSystem at apply time — this object only carries the THREAT-RELATIVE scalar that scales the
# damage multiplier. RefCounted (pure data, D8-clean — never routed through EventBus; the burst is
# entity-local, see Dev Notes §"🔗 Signal boundary").

var power: float
var duration: float


func _init(p_power: float = 1.0, p_duration: float = 10.0) -> void:
	power = p_power
	duration = p_duration
