extends BaseState

func _on_enter() -> void:
	if battle.active_units.is_empty():
		push_warning("SwitchState: No active units left!")
		return

	# 0. 胜利条件检查
	# 如果所有活跃单位属于同一阵营，则战斗结束
	if _check_battle_finished():
		parent_fsm.change_state("FinishState")
		return

	# 1. 切换到下一个单位
	battle.switch_to_next_unit()
	
	print("SwitchState: Next turn -> ", battle.get_main_unit().name)
	
	# 2. 备份游戏状态
	battle.backup_game_state()
	
	# 3. 进入新回合
	parent_fsm.change_state("StartState")

# 检查是否所有单位都属于同一阵营
func _check_battle_finished() -> bool:
	if battle.active_units.size() <= 1:
		return true
		
	var first_faction = battle.active_units[0].get_faction()
	for i in range(1, battle.active_units.size()):
		if battle.active_units[i].get_faction() != first_faction:
			return false
			
	return true
