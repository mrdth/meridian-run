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
