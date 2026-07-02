extends GutTest
# First unit tests for the Pool autoload (D7). Pool was an untested scaffold through
# 1.1/1.2; 1.3 is its first real exercise AND adds D7 deactivation in release().
# Covers the acquire→activate→release→re-acquire round-trip and deactivation (T1).
#
# Singleton note: Pool is an autoload, so its state persists across tests. To stay
# robust we (a) never add_child_autofree a node that gets released to the pool — GUT
# would free a node the pool still holds — and (b) assert LIFO reuse (release X, then
# re-acquire returns X) which is deterministic regardless of prior pool contents.

const ProjectileScene := preload("res://player/projectile.tscn")


func test_acquire_returns_valid_projectile() -> void:
	var p: Projectile = Pool.acquire(ProjectileScene) as Projectile
	assert_not_null(p)
	assert_true(p is Projectile)
	Pool.release(p)


func test_release_then_reacquire_reuses_same_node() -> void:
	# LIFO reuse is deterministic regardless of prior pool state: whatever we just
	# released is the next pop_back(). Assert identity, not "fresh instantiate".
	var a: Projectile = Pool.acquire(ProjectileScene) as Projectile
	var id_a := a.get_instance_id()
	Pool.release(a)
	var b: Projectile = Pool.acquire(ProjectileScene) as Projectile
	assert_eq(b.get_instance_id(), id_a)  # reused, not re-instantiated
	Pool.release(b)


func test_release_deactivates_node() -> void:
	# D7 (the T1 extension): after release, an inactive pooled node must not process
	# or render. The flags are readable off-tree, so no add_child is needed.
	var p: Projectile = Pool.acquire(ProjectileScene) as Projectile
	p.activate(Vector2(100.0, 600.0), 620.0, 10)
	assert_true(p.is_physics_processing())  # activate flipped it on
	assert_true(p.visible)
	Pool.release(p)
	assert_false(p.is_physics_processing())  # release deactivated
	assert_false(p.is_processing())
	assert_false(p.visible)
	assert_eq(p.get_parent(), null)  # detached (release removes from parent)


func test_reacquire_activate_reflips_flags() -> void:
	# After deactivation, the consumer's activate() re-enables processing/visibility.
	var p: Projectile = Pool.acquire(ProjectileScene) as Projectile
	Pool.release(p)
	assert_false(p.is_physics_processing())
	var reused: Projectile = Pool.acquire(ProjectileScene) as Projectile
	assert_eq(reused.get_instance_id(), p.get_instance_id())  # same node, LIFO
	reused.activate(Vector2(0.0, 0.0), 620.0, 10)
	assert_true(reused.is_physics_processing())
	assert_true(reused.visible)
	Pool.release(reused)


func test_release_is_idempotent() -> void:
	# Releasing an already-released node is a no-op (no crash, no double-append). The
	# _node_paths guard routes the second release to the "not acquired" branch.
	var p: Projectile = Pool.acquire(ProjectileScene) as Projectile
	Pool.release(p)
	Pool.release(p)  # second release — no crash
	assert_false(p.is_physics_processing())  # still deactivated, unchanged
	assert_eq(p.get_parent(), null)


func test_release_of_never_acquired_node_is_ignored() -> void:
	# A node not acquired from the Pool is ignored (push_warning + early return). It
	# must NOT be detached or pooled. Observable state: still attached to its parent.
	var owner: Node2D = add_child_autofree(Node2D.new())
	var stray: Projectile = ProjectileScene.instantiate() as Projectile
	owner.add_child(stray)
	Pool.release(stray)  # never acquired — ignored
	assert_eq(stray.get_parent(), owner)  # still attached; release did nothing
