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

	# 1. 直接使用持久化索引
	# var current_index = battle.active_units.find(battle._main_unit)
	
	# 2. 计算下一个单位的索引 (循环)
	var next_index = (battle.current_unit_index + 1) % battle.active_units.size()
	
	# 3. 更新索引和 main_unit
	battle.current_unit_index = next_index
	battle._main_unit = battle.active_units[next_index]
	
	print("SwitchState: Next turn -> ", battle._main_unit.name)
	
	# 4. 进入新回合
	parent_fsm.change_state("StartState")

# 检查是否所有单位都属于同一阵营
func _check_battle_finished() -> bool:
	if battle.active_units.size() <= 1:
		return true
		
	var first_faction = battle.active_units[0].faction
	for i in range(1, battle.active_units.size()):
		if battle.active_units[i].faction != first_faction:
			return false
			
	return true
