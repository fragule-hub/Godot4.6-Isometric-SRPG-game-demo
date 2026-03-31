extends BaseState

func _on_enter() -> void:
	
	if _check_battle_finished():
		var faction_name = "FRIENDLY"\
		if battle.get_main_unit().get_faction() == Unit.Faction.FRIENDLY else "ENEMY"
		print("Battle Finished! Winner: ", faction_name)
		return
	
	battle._all_units.switch_to_next()
	parent_fsm.change_state("StartState")

## 检查是否所有单位都属于同一阵营
func _check_battle_finished() -> bool:
	var active_units: Array = battle.get_active_units()
	if active_units.size() <= 1:
		return true
	
	var first_faction = active_units[0].get_faction()
	for i in range(1, active_units.size()):
		if active_units[i].get_faction() != first_faction:
			return false
			
	return true
