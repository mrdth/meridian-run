class_name HudFocusFadeState
extends State
# The HUD's "focus_fade" state (UX S1): during intense combat, score + modifier chrome dim while
# wave-timer + on-ship HP + lives STAY SHARP. v0.1 dims via modulate.a ≈ 0.32 (opacity) — true ~0.5
# saturation needs a shader and matures at E8 polish (AC8: "full per-component saturation tuning +
# climax integration mature at E8"). Entered when intensity crosses the focus_enter threshold.

func enter(_msg: Dictionary = {}) -> void:
	var hud: Hud = owner as Hud
	if hud != null:
		hud.set_focus_dimmed(true)
