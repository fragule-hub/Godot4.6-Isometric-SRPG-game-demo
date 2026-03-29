extends BaseState

func _on_enter() -> void:
	var unit = battle.get_main_unit()
	if not unit:
		push_warning("StartState: No unit found!")
		return
		
	battle.show_skull_on_unit(unit)
	
	if unit.get_faction() != Unit.Faction.FRIENDLY:
		parent_fsm.change_state("EnemyState")
	else:
		parent_fsm.change_state("MainState")
