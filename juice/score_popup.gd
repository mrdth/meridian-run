class_name ScorePopup
extends Node2D
# Pooled one-shot score-value popup (kill juice — a "Llamasoft" +N that zooms toward the viewer,
# drifts a small random x/y offset, and fades out over the explosion's lifetime). Mirrors
# ParticleBurst's pool contract (AR6/D7): re-init via activate() ONLY — _ready() runs once and never
# re-fires for a re-acquired node; self-release via a one-shot Timer(duration + margin) →
# Pool.release(self); NEVER queue_free(). Motion is tween-driven (scale + position + modulate.a in
# parallel), NOT _process — tweens run on the SceneTree and stop cleanly when the node detaches.
#
# Asset-free / on-pattern: the label is built inline. A static "+N" needs no monospace face (it
# never changes column-to-column, so no digit jitter), so there is NO cross-domain HudFonts
# dependency — the juice node is self-contained. The "z-axis zoom" is a 2D scale tween (toward-viewer
# = scale up, ease_out); the fade is ease_in so the number stays punchy then dissolves at peak.

# Extra lifetime before self-release — guarantees the (already-finished) tween's final frame is
# rendered before the node returns to the pool. Mirrors ParticleBurst._RELEASE_MARGIN_S.
const _RELEASE_MARGIN_S: float = 0.15
const _OUTLINE_COLOR: Color = Color("#060912")  # = HudPalette.SURFACE — kept inline to avoid a juice→ui dep.
const _FONT_SIZE_PX: int = 28

@onready var _label: Label = $Label
var _tween: Tween
var _release_timer: Timer
# Configured-value caches (set in activate) — readable by tests (mirrors how ParticleBurst exposes
# `_mat` for the reduced-motion dampen assertion). Not read by gameplay.
var _scale_to: float = 5.0
var _drift: Vector2 = Vector2.ZERO


func _ready() -> void:
	# ONE-TIME setup (pool contract). Inline Label with a legibility outline (mirrors the HudFonts
	# surface-outline contract) so the gold glyph reads over a busy arena. Color + text are per-spawn.
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", _FONT_SIZE_PX)
	_label.add_theme_color_override("font_outline_color", _OUTLINE_COLOR)
	_label.add_theme_constant_override("outline_size", 6)
	# Self-release Timer — the robust release trigger for a tween-driven one-shot (mirrors ParticleBurst;
	# pairing a tween with a Timer avoids relying on a tween-finished signal across pool cycles).
	_release_timer = Timer.new()
	_release_timer.one_shot = true
	_release_timer.timeout.connect(_on_release)
	add_child(_release_timer)


func activate(text: String, at: Vector2, color: Color, profile: Dictionary) -> void:
	# Pool re-init entry (AR6) — the ONLY re-init path. Kill any in-flight tween + stop the timer
	# before re-arming so a re-acquired node never carries stale motion from its prior life.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_release_timer.stop()
	_label.text = text
	_label.modulate = color  # gold fill; the dark outline is a theme override, tinted negligibly.
	_label.reset_size()  # recompute size for the new text NOW so centering is synchronous.
	_label.position = -_label.size * 0.5  # center the glyph on the root origin ⇒ scaling pivots on it.
	global_position = at
	modulate.a = 1.0
	visible = true
	var scale_from: float = float(profile.get(&"scale_from", 0.4))
	_scale_to = float(profile.get(&"scale_to", 1.5))
	_drift = profile.get(&"drift", Vector2.ZERO)
	var duration: float = float(profile.get(&"duration", 0.55))
	scale = Vector2.ONE * scale_from
	# Parallel tween: zoom toward viewer (scale up, ease_out), drift by `drift`, fade out (ease_in).
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", Vector2.ONE * _scale_to, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", position + _drift, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Arm the self-release. Synchronous Pool.release is safe — this fires from a Timer, NOT inside
	# a physics callback. Never queue_free().
	_release_timer.wait_time = duration + _RELEASE_MARGIN_S
	_release_timer.start()


func _on_release() -> void:
	Pool.release(self)
