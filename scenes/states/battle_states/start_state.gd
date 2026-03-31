extends BaseState

func _on_enter() -> void:
	battle.update_all_units_b_units()
	battle.backup_all_units()
	battle.grid_calculator._initialize_astar(battle._all_units.get_main_unit())
	battle.show_skull_on_unit(battle.get_main_unit())
	parent_fsm.change_state("MainState")
