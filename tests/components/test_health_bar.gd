extends GutTest
# Integration tests for the reusable segmented HealthBar (UX H6; arch line 470). Drives a real
# HealthComponent + verifies bind/take_damage/heal/reset_to_full tracking, the idempotent re-bind
# (pool reuse path), and the hide_when_full enemy behavior vs the always-visible player behavior.
# Mirrors the 1.6 GUT style (add_child_autofree for non-pooled scene roots).

const HealthBarScene := preload("res://components/health_bar.tscn")


func _make_bar(hide_when_full: bool = false) -> HealthBar:
	var bar: HealthBar = HealthBarScene.instantiate()
	bar.hide_when_full = hide_when_full
	add_child_autofree(bar)
	return bar


func _make_health(max_hp: int = 5) -> HealthComponent:
	var hc := HealthComponent.new()
	hc.max_hp = max_hp
	add_child_autofree(hc)  # _ready ⇒ current_hp = max_hp
	return hc


func test_bind_syncs_current_and_maximum() -> void:
	var bar := _make_bar()
	var hc := _make_health(5)
	hc.current_hp = 4  # simulate a damaged entity
	bar.bind(hc)
	assert_eq(bar._current, 4)
	assert_eq(bar._maximum, 5)


func test_health_changed_updates_bar() -> void:
	var bar := _make_bar()
	var hc := _make_health(5)
	bar.bind(hc)
	hc.take_damage(2)  # 5 → 3
	assert_eq(bar._current, 3)
	hc.heal(1)  # 3 → 4
	assert_eq(bar._current, 4)


func test_reset_to_full_updates_bar() -> void:
	var bar := _make_bar()
	var hc := _make_health(5)
	bar.bind(hc)
	hc.take_damage(3)
	hc.reset_to_full()
	assert_eq(bar._current, 5)
	assert_eq(bar._maximum, 5)


func test_bind_is_idempotent_no_double_connect() -> void:
	# The pool reuse path calls bind() every activate(); it must never stack connections.
	var bar := _make_bar()
	var hc := _make_health(5)
	bar.bind(hc)
	bar.bind(hc)
	bar.bind(hc)
	assert_eq(hc.health_changed.get_connections().size(), 1)


func test_hide_when_full_hides_at_full() -> void:
	# Enemy behavior (H6): the bar is absent at full HP — the read surfaces only when damaged.
	var bar := _make_bar(true)
	var hc := _make_health(5)
	hc.current_hp = 5
	bar.bind(hc)
	assert_false(bar.visible)


func test_hide_when_full_shows_when_damaged() -> void:
	var bar := _make_bar(true)
	var hc := _make_health(5)
	bar.bind(hc)
	assert_false(bar.visible)  # full
	hc.take_damage(1)  # 5 → 4
	assert_true(bar.visible)  # damaged → shown


func test_player_bar_always_visible_at_full() -> void:
	# hide_when_full=false (player) — the primary read is always visible.
	var bar := _make_bar(false)
	var hc := _make_health(3)
	hc.current_hp = 3
	bar.bind(hc)
	assert_true(bar.visible)


func test_rebind_to_different_component_disconnects_old_one() -> void:
	# bind() called with a DIFFERENT HealthComponent must disconnect the prior one — otherwise the bar
	# keeps reacting to an entity it no longer represents.
	var bar := _make_bar()
	var hc_a := _make_health(5)
	var hc_b := _make_health(8)
	bar.bind(hc_a)
	bar.bind(hc_b)
	assert_eq(hc_a.health_changed.get_connections().size(), 0)
	assert_eq(hc_b.health_changed.get_connections().size(), 1)
	hc_a.take_damage(1)  # must NOT affect the bar anymore
	assert_eq(bar._maximum, 8)
	assert_eq(bar._current, 8)


func test_rebind_after_damage_resyncs_to_full() -> void:
	# Pool reuse: an enemy damaged last wave re-binds at full HP on respawn — the bar must reflect that.
	var bar := _make_bar(true)
	var hc := _make_health(5)
	bar.bind(hc)
	hc.take_damage(2)  # damaged
	assert_true(bar.visible)
	hc.reset_to_full()
	bar.bind(hc)  # simulate activate() re-bind
	assert_false(bar.visible)  # back to full → hidden


# --- hp_per_segment: shots-to-kill granularity (UX H6 read clarity) ---

func test_default_one_segment_per_hp() -> void:
	# Player default (hp_per_segment = 1): one segment per HP — 3 HP ⇒ 3 segments.
	var bar := _make_bar()
	var hc := _make_health(3)
	bar.bind(hc)
	assert_eq(bar._seg_total, 3)
	assert_eq(bar._seg_filled, 3)


func test_hp_per_segment_compresses_to_shots_to_kill() -> void:
	# Enemy bar (hp_per_segment = 10 = player shot damage): 50 HP ⇒ 5 segments (shots to kill).
	var bar := _make_bar()
	bar.hp_per_segment = 10
	var hc := _make_health(50)
	bar.bind(hc)
	assert_eq(bar._seg_total, 5)
	assert_eq(bar._seg_filled, 5)


func test_hp_per_segment_drops_one_segment_per_shot() -> void:
	var bar := _make_bar()
	bar.hp_per_segment = 10
	var hc := _make_health(50)
	bar.bind(hc)
	hc.take_damage(10)  # 50 → 40 ⇒ one segment drops
	assert_eq(bar._seg_filled, 4)
	assert_eq(bar._seg_total, 5)
	hc.take_damage(10)  # 40 → 30 ⇒ another
	assert_eq(bar._seg_filled, 3)


func test_hp_per_segment_partial_hp_rounds_up() -> void:
	# ceil ⇒ 41 HP at 10/segment still reads as 5 filled (the finishing shot hasn't landed yet).
	var bar := _make_bar()
	bar.hp_per_segment = 10
	var hc := _make_health(50)
	bar.bind(hc)
	hc.current_hp = 41
	hc.health_changed.emit(41, 50)
	assert_eq(bar._seg_filled, 5)
	hc.current_hp = 40
	hc.health_changed.emit(40, 50)
	assert_eq(bar._seg_filled, 4)


func test_bomber_eight_segments() -> void:
	# Bomber 80 HP at 10/segment ⇒ 8 segments.
	var bar := _make_bar()
	bar.hp_per_segment = 10
	var hc := _make_health(80)
	bar.bind(hc)
	assert_eq(bar._seg_total, 8)
