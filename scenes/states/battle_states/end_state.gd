extends BaseState

func _on_enter() -> void:
	battle.hide_skull()
	parent_fsm.change_state("SwitchState")
