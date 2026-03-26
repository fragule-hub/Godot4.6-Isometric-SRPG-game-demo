extends BaseState

## 进入状态时触发
func _on_enter() -> void:
	# 1. 生成所有单位
	if not battle.unit_positions_dict.is_empty():
		for cell_pos in battle.unit_positions_dict:
			var unit_data = battle.unit_positions_dict[cell_pos]
			var faction = unit_data.get("faction", Unit.Faction.ENEMY)
			var stat = unit_data.get("unit_stat", null)
			
			# 只有当 unit_stat 不为 null 时才生成单位
			if stat == null:
				push_warning("InitState: Skipping unit spawn at pos ", cell_pos, " - no unit_stat provided")
				continue
			
			var world_pos = battle.game_area.get_global_from_tile(cell_pos)\
			+ Unit.DEFAULT_OFFSET
			
			var unit = battle.unit_spawner.spawn_unit(world_pos, stat, faction)
			
			# 尝试添加到网格
			if battle.game_area.game_grid.add_unit(unit, cell_pos):
				battle.active_units.append(unit)
			else:
				# 添加失败，销毁单位
				unit.queue_free()
	
	# 2. 对活跃单位进行排序
	# 排序规则: speed (desc) -> faction (Friendly first) -> default
	battle.active_units.sort_custom(func(a: Unit, b: Unit):
		if a.get_speed() != b.get_speed():
			return a.get_speed() > b.get_speed()
		
		if a.get_faction() != b.get_faction():
			return a.get_faction() == Unit.Faction.FRIENDLY
			
		return false
	)
	
	# 3. 初始化 AllUnits
	for i in range(battle.active_units.size()):
		var unit = battle.active_units[i]
		var cell_pos = battle.game_area.game_grid.get_unit_position(unit)
		var b_unit = unit.create_b_unit(cell_pos)
		battle.all_units.set_unit_at_index(i, unit, b_unit)
	battle.all_units.current_unit_index = 0
	
	# 4. 备份游戏初始状态
	battle.backup_game_state()
	
	# 推进到 StartState
	parent_fsm.change_state("StartState")
