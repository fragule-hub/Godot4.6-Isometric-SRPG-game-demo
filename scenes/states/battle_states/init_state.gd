extends BaseState

func _on_enter() -> void:
	var active_units: Array[Unit]
	
	var unit_pos_dict:Dictionary = battle.unit_pos_dict
	if not unit_pos_dict.is_empty():
		for cell_pos in battle.unit_pos_dict:
			var unit_data = battle.unit_pos_dict[cell_pos]
			var faction = unit_data.get("faction", Unit.Faction.ENEMY)
			var stat = unit_data.get("unit_stat", null)
			# 只有当 unit_stat 不为 null 时才生成单位
			if stat == null:
				push_warning("init: unit stat null.")
				continue
			var unit:Unit = battle.unit_spawner.spawn_unit_in_cell(cell_pos, stat, faction)
			
			# 尝试添加到网格
			if battle.game_area.game_grid.add_unit(unit, cell_pos):
				active_units.append(unit)
			else:
				# 添加失败，销毁单位
				unit.queue_free()
	
	# 对数组中单位排序，优先speed，相同时优先友方阵营
	active_units.sort_custom(func(a: Unit, b: Unit):
		if a.get_speed() != b.get_speed():
			return a.get_speed() > b.get_speed()
		
		if a.get_faction() != b.get_faction():
			return a.get_faction() == Unit.Faction.FRIENDLY
			
		return false
	)
	
	
	
	
	# 初始化 AllUnits
	for i in range(active_units.size()):
		var unit = active_units[i]
		var cell_pos = battle.game_area.game_grid.get_unit_position(unit)
		var b_unit = unit.create_b_unit(cell_pos)
		battle._all_units.add_unit(unit, b_unit)
	battle._all_units.current_unit_index = 0
	
	parent_fsm.change_state("StartState")
