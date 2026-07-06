class_name HudStandardState
extends State
# The HUD's "standard" focus/fade state (UX S1): full HUD, calm. Entered at run/wave start and when
# combat intensity falls back below the focus_exit threshold. Restores the dimmed chrome to full
# opacity. The HUD conductor (owner) owns the actual modulate work; this state just requests it.

func enter(_msg: Dictionary = {}) -> void:
	var hud: Hud = owner as Hud
	if hud != null:
		hud.set_focus_dimmed(false)
