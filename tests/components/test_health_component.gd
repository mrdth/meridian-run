extends GutTest
# Pure-logic unit tests for HealthComponent (no scene). Delegates to testable
# logic per project-context testing rule (NFR13). Mirrors the 1.1 GUT style.
# HealthComponent is BUILT REAL BUT NOT WIRED this story — damage sources,
# wave-reset callers, and ship_lost wiring land in 1.4/1.5/1.6.


func _make() -> HealthComponent:
	var hc := HealthComponent.new()
	add_child_autofree(hc)
	return hc


func test_starts_at_max_hp() -> void:
	var hc := _make()
	assert_eq(hc.current_hp, hc.max_hp)
	assert_eq(hc.current_hp, 3)


func test_take_damage_reduces_and_floors() -> void:
	var hc := _make()
	hc.take_damage(1)
	assert_eq(hc.current_hp, 2)
	hc.take_damage(100)  # overkill clamps to 0
	assert_eq(hc.current_hp, 0)


func test_negative_damage_is_noop() -> void:
	var hc := _make()
	hc.take_damage(-5)  # never a heal
	assert_eq(hc.current_hp, 3)


func test_heal_clamps_to_max() -> void:
	var hc := _make()
	hc.take_damage(2)  # -> 1
	hc.heal(10)  # over-heal clamps to max
	assert_eq(hc.current_hp, 3)


func test_negative_heal_is_noop() -> void:
	var hc := _make()
	hc.take_damage(1)  # -> 2
	hc.heal(-5)
	assert_eq(hc.current_hp, 2)


func test_health_changed_payload() -> void:
	var hc := _make()
	watch_signals(hc)
	hc.take_damage(1)
	assert_signal_emitted(hc, "health_changed")
	var params: Array = get_signal_parameters(hc, "health_changed")
	assert_eq(params.size(), 2)
	assert_eq(params[0], 2)  # current
	assert_eq(params[1], 3)  # maximum


func test_no_died_above_zero() -> void:
	var hc := _make()
	watch_signals(hc)
	hc.take_damage(2)  # -> 1, still alive
	assert_signal_emit_count(hc, "died", 0)


func test_died_emits_once_at_zero() -> void:
	var hc := _make()
	watch_signals(hc)
	hc.take_damage(3)  # -> 0, died
	assert_eq(hc.current_hp, 0)
	assert_signal_emit_count(hc, "died", 1)
	hc.take_damage(5)  # already dead — double-died guard holds
	assert_signal_emit_count(hc, "died", 1)


func test_reset_to_full_restores_hp_and_signal() -> void:
	var hc := _make()
	hc.take_damage(2)  # -> 1
	watch_signals(hc)
	hc.reset_to_full()
	assert_eq(hc.current_hp, 3)
	var params: Array = get_signal_parameters(hc, "health_changed")
	assert_eq(params[0], 3)


func test_reset_to_full_allows_dying_again() -> void:
	# Lifecycle: die, reset (new life), die again — died emits exactly twice total.
	var hc := _make()
	watch_signals(hc)
	hc.take_damage(3)
	assert_signal_emit_count(hc, "died", 1)
	hc.reset_to_full()
	assert_eq(hc.current_hp, 3)
	hc.take_damage(3)
	assert_signal_emit_count(hc, "died", 2)


# --- i-frame window (Story 1.5 / AC2) ---

func _make_iframed() -> HealthComponent:
	# A player-like component: i-frame window on after a hit. Mirrors how the player sets
	# invuln_after_hit_s from tuning in _ready (1.0 here, matching player_tuning.iframe_s).
	var hc := _make()
	hc.invuln_after_hit_s = 1.0
	return hc


func test_default_invuln_is_zero_never_invulnerable() -> void:
	# Regression guard for ENEMIES (default 0.0): a hit never grants a window, so pooled
	# enemies / re-activate() are unaffected (Story 1.5 key decision #2).
	var hc := _make()  # invuln_after_hit_s = 0.0 default
	hc.take_damage(1)
	assert_false(hc.is_invulnerable())


func test_take_damage_grants_iframe_window() -> void:
	var hc := _make_iframed()
	hc.take_damage(1)  # real damaging hit
	assert_eq(hc.current_hp, 2)
	assert_true(hc.is_invulnerable())


func test_second_hit_during_window_is_noop() -> void:
	# During the window: no damage, no health_changed, no died (the hit is fully ignored).
	var hc := _make_iframed()
	watch_signals(hc)
	hc.take_damage(1)  # -> 2, grants window
	var changed_after_first: int = get_signal_emit_count(hc, "health_changed")
	hc.take_damage(2)  # within the window — fully ignored
	assert_eq(hc.current_hp, 2)  # unchanged
	assert_signal_emit_count(hc, "health_changed", changed_after_first)  # no new emit
	assert_signal_emit_count(hc, "died", 0)


func test_hit_applies_again_after_window_expires_via_process() -> void:
	var hc := _make_iframed()
	hc.take_damage(1)  # -> 2, window granted
	assert_true(hc.is_invulnerable())
	hc._process(1.0)  # step the timer down by the full window
	assert_false(hc.is_invulnerable())
	hc.take_damage(1)  # window expired — damage applies
	assert_eq(hc.current_hp, 1)


func test_hit_applies_again_after_set_invuln_zero() -> void:
	# set_invuln(0.0) disables the window immediately (the respawn/expire path).
	var hc := _make_iframed()
	hc.take_damage(1)  # -> 2
	hc.set_invuln(0.0)
	assert_false(hc.is_invulnerable())
	hc.take_damage(1)
	assert_eq(hc.current_hp, 1)


func test_is_invulnerable_tracks_timer() -> void:
	var hc := _make()
	hc.set_invuln(0.5)
	assert_true(hc.is_invulnerable())
	hc._process(0.5)
	assert_false(hc.is_invulnerable())  # exactly expired


func test_zero_damage_does_not_grant_window() -> void:
	# A no-op hit (zero/negative) grants no window — only a REAL damaging hit does.
	var hc := _make_iframed()
	hc.take_damage(0)
	assert_false(hc.is_invulnerable())
	hc.take_damage(-5)
	assert_false(hc.is_invulnerable())


func test_reset_to_full_clears_invuln_window() -> void:
	# A fresh-full ship starts vulnerable; respawn grants its OWN window via set_invuln.
	var hc := _make_iframed()
	hc.take_damage(1)
	hc.set_invuln(5.0)  # some lingering window
	assert_true(hc.is_invulnerable())
	hc.reset_to_full()
	assert_false(hc.is_invulnerable())
	assert_eq(hc.current_hp, 3)
