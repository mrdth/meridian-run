extends GutTest
# Pure-logic unit tests for RunState (no scene — it is a Resource). Mirrors the
# pure-logic style of tests/components/test_health_component.gd per the testing rule
# (separate pure logic from Node/scene code). RunState carries ships+score only in E1.


func _make() -> RunState:
	# Resource — no add_child needed; .new() is the runtime construction path (AR2/D1:
	# runtime-only, never a .tres). begin_run() in before_each via each test's _make.
	return RunState.new()


func test_begin_run_sets_ships_and_score() -> void:
	var rs := _make()
	rs.begin_run()
	assert_eq(rs.ships, Constants.BASE_SHIPS)  # 3
	assert_eq(rs.ships, 3)
	assert_eq(rs.score, 0)


func test_spend_ship_decrements_and_returns_remaining() -> void:
	var rs := _make()
	rs.begin_run()
	var remaining: int = rs.spend_ship()
	assert_eq(remaining, 2)
	assert_eq(rs.ships, 2)
	remaining = rs.spend_ship()
	assert_eq(remaining, 1)
	assert_eq(rs.ships, 1)


func test_spend_ship_floors_at_zero() -> void:
	# Never negative — the caller (Arena) decides respawn vs game-over at remaining==0.
	var rs := _make()
	rs.begin_run()
	rs.spend_ship()  # 2
	rs.spend_ship()  # 1
	rs.spend_ship()  # 0 — last ship
	var remaining: int = rs.spend_ship()  # floor at 0
	assert_eq(remaining, 0)
	assert_eq(rs.ships, 0)


func test_add_ship_clamps_at_max() -> void:
	# Forward-compat (E2/E3 ship-gain): never exceeds MAX_SHIPS (5). E1 has no caller,
	# but the cap is the load-bearing invariant — exercise it.
	var rs := _make()
	rs.begin_run()  # 3
	rs.add_ship(1)
	assert_eq(rs.ships, 4)
	rs.add_ship(10)  # over-grant clamps to the cap
	assert_eq(rs.ships, Constants.MAX_SHIPS)  # 5
	# Default-arg path (capture-keep regain grants 1).
	rs.ships = Constants.MAX_SHIPS - 1
	rs.add_ship()
	assert_eq(rs.ships, Constants.MAX_SHIPS)


func test_add_ship_ignores_negatives() -> void:
	# Defensive guard against bad callers (mirrors add_score()) — a negative amount
	# must not decrement ships, even though add_ship() has no E1 caller yet.
	var rs := _make()
	rs.begin_run()  # 3
	rs.add_ship(-2)
	assert_eq(rs.ships, 3)


func test_add_score_accumulates() -> void:
	var rs := _make()
	rs.begin_run()
	rs.add_score(100)
	assert_eq(rs.score, 100)
	rs.add_score(50)
	assert_eq(rs.score, 150)


func test_add_score_ignores_negatives() -> void:
	# Score is display-only/never spent (FR49) — a negative amount must not decrement it.
	var rs := _make()
	rs.begin_run()
	rs.add_score(100)
	rs.add_score(-30)  # defensive guard against bad callers → no-op
	assert_eq(rs.score, 100)


func test_reset_restores_baselines() -> void:
	# Game-over replay path: a fresh run starts at 3 ships / 0 score.
	var rs := _make()
	rs.begin_run()
	rs.spend_ship()
	rs.add_score(500)
	rs.reset()
	assert_eq(rs.ships, Constants.BASE_SHIPS)  # 3
	assert_eq(rs.score, 0)
