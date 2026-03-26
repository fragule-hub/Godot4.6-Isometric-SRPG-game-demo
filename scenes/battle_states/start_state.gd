extends BaseState

func _on_enter() -> void:
	var main_unit = battle.get_main_unit()
	if not main_unit:
		push_warning("StartState: No main unit found!")
		return
		
	battle.show_skull_on_unit(main_unit)
	
	# 根据阵营决定进入哪个状态
	if main_unit.get_faction() == Unit.Faction.FRIENDLY:
		# 友方单位：进入玩家控制状态
		parent_fsm.change_state("MainState")
	else:
		# 敌方单位：进入敌人AI状态
		parent_fsm.change_state("EnemyState")
