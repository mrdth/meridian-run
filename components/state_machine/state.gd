class_name State
extends Node
# Reusable FSM state (D6). Concrete states override the hooks they need. Consumers in
# 1.4: enemy AI (EnterState/FormationState/DiveState); later: Captor 5-state FSM
# (Story 2.1), HUD focus/fade (Story 1.7). The owning entity is reached from each
# concrete state via the inherited `owner` (the scene root) cast to the entity type —
# NO get_parent() string lookups, NO per-frame $/get_node (AR5/AR14, hot-path discipline).


func enter(_msg: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


func physics_process(_delta: float) -> void:
	pass


func process(_delta: float) -> void:
	pass
