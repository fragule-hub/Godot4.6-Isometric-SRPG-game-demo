extends BaseState

func _on_enter() -> void:
	# 在回合开始时，显示单位的骷髅图标
	if battle._main_unit:
		battle.show_skull_on_unit(battle._main_unit)
		
	parent_fsm.change_state("MainState")
