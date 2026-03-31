extends BaseState

var main_unit: Unit

func _on_enter() -> void:
	main_unit = battle.get_main_unit()
	
	if main_unit.get_faction() != Unit.Faction.ENEMY:
		parent_fsm.change_state("MoveState")
		return
		
	_execute_ai_turn()


# 先获取所有单位，尝试寻找最短路径并进行移动
# 移动后对于攻击范围内的敌人，获取生命值最低的敌人进行攻击
func _execute_ai_turn() -> void:
	battle.grid_calculator._initialize_astar(main_unit)
	
	var targets = _get_enemy_units()
	
	if not targets.is_empty():
		var best_path = _calculate_best_move_path(targets)
		if not best_path.is_empty() and best_path.size() > 1:
			battle.hide_skull()
			battle.unit_mover.move_unit(main_unit, best_path)
			await battle.unit_mover.move_finished
			battle.show_skull_on_unit(main_unit)
		
	await _try_attack()
	parent_fsm.parent_fsm.change_state("EndState")
	
	
	
## 获取所有敌对单位（与当前单位不同阵营的单位）
func _get_enemy_units() -> Array[Unit]:
	var enemies: Array[Unit] = []
	for unit in battle.get_active_units():
		if unit == main_unit or not is_instance_valid(unit):
			continue
		if unit.get_faction() != main_unit.get_faction():
			enemies.append(unit)
	return enemies
	
func _calculate_best_move_path(targets: Array[Unit]) -> Array[Vector2i]:
	var best_path: Array[Vector2i] = []
	var min_dist: int = 999999
	var is_best_reachable: bool = false
	
	for target in targets:
		var target_pos = battle.game_area.game_grid.get_unit_position(target)
		if target_pos == Vector2i(-999, -999):
			continue
		
		var result = battle.grid_calculator.get_move_path(main_unit, target_pos)
		var reachable: Array = result.get("reachable", [])
		var unreachable: Array = result.get("unreachable", [])
		
		# 路径
		var current_execute_path: Array = reachable
		if current_execute_path.is_empty():
			continue
		
		# 如果可达
		var current_is_reachable: bool = unreachable.is_empty()\
		and not reachable.is_empty()
		
		# 获取距离
		var dist: int
		if current_is_reachable:
			dist = reachable.size()
		else:
			dist = reachable.size() + unreachable.size()
		
		# 如果更好
		var is_better := false
		# 如果当前路径可达，并且之前没有可达路径
		if current_is_reachable and not is_best_reachable:
			is_better = true
		# 如果有可达路径，但是当前路径的距离更小
		elif current_is_reachable == is_best_reachable and dist < min_dist:
			is_better = true
			
		if is_better:
			best_path = current_execute_path
			min_dist = dist
			is_best_reachable = current_is_reachable
	
	return best_path
			
func _try_attack() -> void:
	var unit_pos = battle.game_area.game_grid.get_unit_position(main_unit)
	var attack_range = main_unit.get_attack_range()
	var attackable_cells = battle.range_calculator.get_range_cells(
		unit_pos, 
		attack_range, 
		RangeCalculator.DistanceAlgorithm.MANHATTAN
	)
	
	var best_target: Unit = null
	var min_hp: int = -1
	
	for cell in attackable_cells:
		var cell_data = battle.game_area.game_grid.get_cell_data(cell)
		if cell_data.is_empty():
			continue
		
		var target_unit = cell_data.get("unit")
		if not target_unit or not target_unit is Unit:
			continue
		if target_unit == main_unit:
			continue
		# 回避友方
		if target_unit.get_faction() == main_unit.get_faction():
			continue
		
		if best_target == null or target_unit._current_hp < min_hp:
			best_target = target_unit
			min_hp = target_unit._current_hp
	
	if best_target == null:
		return
	
	await battle.attack_processor.execute_attack(main_unit, best_target)
		
