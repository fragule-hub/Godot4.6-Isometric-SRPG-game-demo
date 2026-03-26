extends BaseState

func _on_enter() -> void:
	battle.clear_rollback_state()
	parent_fsm.change_state("SwitchState")
