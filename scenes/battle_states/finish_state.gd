extends BaseState

# ==============================================================================
# 战斗结束状态
# Battle Finish State
# ==============================================================================
# 当战斗中只剩下一个阵营的单位时进入此状态
# 负责显示胜利信息
# ==============================================================================

func _on_enter() -> void:
	print("FinishState: Entered")
	
	if battle.active_units.is_empty():
		print("FinishState: No units left.")
		return
		
	# 检查是否所有单位阵营一致
	var first_unit = battle.active_units[0]
	var winning_faction = first_unit.faction
	var all_same_faction = true
	
	for i in range(1, battle.active_units.size()):
		if battle.active_units[i].faction != winning_faction:
			all_same_faction = false
			break
			
	if all_same_faction:
		var faction_name = "FRIENDLY" if winning_faction == Unit.Faction.FRIENDLY else "ENEMY"
		print("Battle Finished! Winner: ", faction_name)
		# 这里可以添加 UI 显示、场景切换等逻辑
	else:
		push_warning("FinishState: Entered but factions are not unified!")
