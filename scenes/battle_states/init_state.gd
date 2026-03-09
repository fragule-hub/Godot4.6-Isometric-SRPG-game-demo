extends BaseState

## 进入状态时触发
func _on_enter() -> void:
	# 1. 生成所有单位
	if not battle.unit_positions_dict.is_empty():
		for faction in battle.unit_positions_dict:
			var positions = battle.unit_positions_dict[faction]
			
			for cell_pos in positions:
				var world_pos = battle.game_area.get_global_from_tile(cell_pos)\
				+ Unit.DEFAULT_OFFSET
				
				# 生成单位，并传入阵营
				var color = Color.WHITE
				if faction == Unit.Faction.ENEMY:
					color = Color(1, 0.5, 0.5) # 浅红色
					
				var unit = battle.unit_spawner.spawn_unit(world_pos, faction, color)
				
				# 尝试添加到网格
				if battle.game_area.game_grid.add_unit(unit, cell_pos):
					battle.active_units.append(unit)
				else:
					# 添加失败，销毁单位
					unit.queue_free()
	
	# 2. 对活跃单位进行排序
	# 排序规则: speed (desc) -> faction (Friendly first) -> default
	battle.active_units.sort_custom(func(a: Unit, b: Unit):
		if a.speed != b.speed:
			return a.speed > b.speed
		
		if a.get_faction() != b.get_faction():
			return a.get_faction() == Unit.Faction.FRIENDLY
			
		return false # 保持原有顺序
	)
	
	# 3. 设置第一个行动单位
	if not battle.active_units.is_empty():
		battle.current_unit_index = 0
		battle._main_unit = battle.active_units[0]
	
	# 推进到 StartState
	parent_fsm.change_state("StartState")
