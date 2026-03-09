extends BaseState

func _on_enter() -> void:
	battle._backup_state.clear()
	parent_fsm.change_state("SwitchState")
