extends BaseState

# ==============================================================================
# 敌人AI状态
# 处理敌方单位的自动行动逻辑：
# 1. 移动：寻找最近的敌对目标并靠近
# 2. 攻击：如果在攻击范围内，选择血量最低的目标攻击
# ==============================================================================

func _on_enter() -> void:
	print("EnemyState: Entered")
	var unit = battle.get_main_unit()
	if not unit:
		_end_turn()
		return
		
	await _execute_ai_turn(unit)

# 执行 AI 回合流程
func _execute_ai_turn(unit: Unit) -> void:
	# --- 阶段 1: 移动 ---
	battle.grid_calculator._initialize_astar(unit)
	
	var targets = _get_hostile_units(unit)
	if not targets.is_empty():
		var best_path = _calculate_best_move_path(unit, targets)
		
		if not best_path.is_empty() and best_path.size() > 1:
			battle.hide_skull()
			battle.unit_mover.move_unit(unit, best_path)
			await battle.unit_mover.move_finished
			battle.show_skull_on_unit(unit)
	
	# --- 阶段 2: 攻击 ---
	await _try_attack(unit)
	
	# --- 阶段 3: 结束回合 ---
	_end_turn()

# 获取所有敌对单位
func _get_hostile_units(self_unit: Unit) -> Array[Unit]:
	var hostiles: Array[Unit] = []
	for unit in battle.active_units:
		if unit == self_unit or not is_instance_valid(unit):
			continue
		if unit.get_faction() != self_unit.get_faction():
			hostiles.append(unit)
	return hostiles

# 计算最佳移动路径
func _calculate_best_move_path(unit: Unit, targets: Array[Unit]) -> Array[Vector2i]:
	var best_path: Array[Vector2i] = []
	var min_dist: int = 999999
	var is_best_reachable: bool = false
	
	for target in targets:
		var target_pos = battle.game_area.game_grid.get_unit_position(target)
		if target_pos == Vector2i(-999, -999):
			continue
			
		var result = battle.grid_calculator.get_move_path(unit, target_pos)
		var reachable: Array = result.get("reachable", [])
		var unreachable: Array = result.get("unreachable", [])
		
		var current_is_reachable: bool = unreachable.is_empty() and not reachable.is_empty()
		
		var dist = 0
		var current_execute_path = []
		
		if current_is_reachable:
			dist = reachable.size()
			current_execute_path = reachable
		else:
			dist = reachable.size() + unreachable.size()
			current_execute_path = reachable
		
		if current_execute_path.is_empty():
			continue
			
		if current_is_reachable and not is_best_reachable:
			best_path = current_execute_path
			min_dist = dist
			is_best_reachable = true
			continue
			
		if not current_is_reachable and is_best_reachable:
			continue
			
		if current_is_reachable == is_best_reachable:
			if dist < min_dist:
				min_dist = dist
				best_path = current_execute_path
	
	return best_path

# 尝试攻击
func _try_attack(unit: Unit) -> void:
	var unit_pos = battle.game_area.game_grid.get_unit_position(unit)
	var attack_range = unit.get_attack_range()
	var attackable_cells = battle.range_calculator.get_range_cells(
		unit_pos, 
		attack_range, 
		RangeCalculator.DistanceAlgorithm.MANHATTAN
	)
	
	var valid_targets: Array[Unit] = []
	
	for cell in attackable_cells:
		var cell_data = battle.game_area.game_grid.get_cell_data(cell)
		if cell_data.is_empty(): continue
		
		var target_unit = cell_data.get("unit")
		if target_unit and target_unit is Unit:
			if target_unit != unit and target_unit.get_faction() != unit.get_faction():
				valid_targets.append(target_unit)
	
	if valid_targets.is_empty():
		return
		
	var best_target: Unit = valid_targets[0]
	var min_hp = best_target._current_hp
	
	for i in range(1, valid_targets.size()):
		var t = valid_targets[i]
		if t._current_hp < min_hp:
			min_hp = t._current_hp
			best_target = t
			
	await battle.attack_processor.execute_attack(unit, best_target)

# 结束回合
func _end_turn() -> void:
	parent_fsm.change_state("EndState")
