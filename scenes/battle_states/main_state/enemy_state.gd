extends BaseState

# ==============================================================================
# 敌人AI状态
# Enemy AI Logic State
# ==============================================================================
# 处理敌方单位的自动行动逻辑：
# 1. 移动：寻找最近的敌对目标并靠近
# 2. 攻击：如果在攻击范围内，选择血量最低的目标攻击
# ==============================================================================

func _on_enter() -> void:
	print("EnemyState: Entered")
	var unit = battle._main_unit
	if not unit:
		_end_turn()
		return
		
	# 1. 阵营检查：如果是友方单位，转交给 MoveState 由玩家控制
	if unit.faction == Unit.Faction.FRIENDLY:
		parent_fsm.change_state("MoveState")
		return
		
	# 2. 执行 AI 逻辑
	await _execute_ai_turn(unit)

# 执行 AI 回合流程
func _execute_ai_turn(unit: Unit) -> void:
	# --- 阶段 1: 移动 ---
	# 初始化寻路系统
	battle.grid_calculator._initialize_astar(unit)
	
	# 获取所有敌对目标
	var targets = _get_hostile_units(unit)
	if targets.is_empty():
		# 没有目标，直接跳过移动
		pass
	else:
		# 计算最佳移动路径
		var best_path = _calculate_best_move_path(unit, targets)
		
		# 如果有路径且长度大于1（不仅仅是原地），则移动
		if not best_path.is_empty() and best_path.size() > 1:
			# 移动开始：隐藏骷髅
			battle.hide_skull()
			
			# 移动单位
			battle.unit_mover.move_unit(unit, best_path)
			# 等待移动完成
			await battle.unit_mover.move_finished
			
			# 移动结束：显示骷髅
			battle.show_skull_on_unit(unit)
	
	# --- 阶段 2: 攻击 ---
	await _try_attack(unit)
	
	# --- 阶段 3: 结束回合 ---
	_end_turn()

# 获取所有敌对单位
func _get_hostile_units(self_unit: Unit) -> Array[Unit]:
	var hostiles: Array[Unit] = []
	for unit in battle.active_units:
		# 排除自己和已死亡单位
		if unit == self_unit or not is_instance_valid(unit):
			continue
		# 筛选不同阵营
		if unit.faction != self_unit.faction:
			hostiles.append(unit)
	return hostiles

# 计算最佳移动路径
func _calculate_best_move_path(unit: Unit, targets: Array[Unit]) -> Array[Vector2i]:
	var best_path: Array[Vector2i] = []
	var min_dist: int = 999999
	var is_best_reachable: bool = false
	
	# 遍历所有目标，寻找最优路径
	for target in targets:
		var target_pos = battle.game_area.game_grid.get_unit_position(target)
		if target_pos == Vector2i(-999, -999):
			continue
			
		# 调用 GridCalculator 获取路径
		# 返回 { "reachable": [], "unreachable": [] }
		var result = battle.grid_calculator.get_move_path(unit, target_pos)
		var reachable: Array = result.get("reachable", [])
		var unreachable: Array = result.get("unreachable", [])
		
		# 判断当前路径是否完全可达
		# 如果 unreachable 为空且 reachable 不为空，则视为可达
		var current_is_reachable:bool = unreachable.is_empty() and not reachable.is_empty()
		
		var dist = 0
		var current_execute_path = []
		
		if current_is_reachable:
			# 如果可达，距离为 reachable 的长度
			dist = reachable.size()
			current_execute_path = reachable
		else:
			# 如果不可达，距离为 reachable + unreachable 的总长度 (即完整路径长度)
			dist = reachable.size() + unreachable.size()
			# 但实际执行只能走 reachable 部分
			current_execute_path = reachable
		
		if current_execute_path.is_empty():
			continue
			
		# 决策逻辑：
		# 1. 如果之前找到的是不可达路径，而现在找到了可达路径 -> 必须选可达的
		if current_is_reachable and not is_best_reachable:
			best_path = current_execute_path
			min_dist = dist
			is_best_reachable = true
			continue
			
		# 2. 如果之前是可达路径，现在找到了不可达路径 -> 忽略不可达的
		if not current_is_reachable and is_best_reachable:
			continue
			
		# 3. 如果状态相同（都是可达 或 都是不可达）
		if current_is_reachable == is_best_reachable:
			# 选择路径总长度最短的
			if dist < min_dist:
				min_dist = dist
				best_path = current_execute_path
	
	return best_path

# 尝试攻击
func _try_attack(unit: Unit) -> void:
	# 1. 获取攻击范围内的所有格子
	var unit_pos = battle.game_area.game_grid.get_unit_position(unit)
	var attack_range = unit.get_attack_range()
	# 使用 RangeCalculator 获取范围（曼哈顿距离）
	var attackable_cells = battle.range_calculator.get_range_cells(
		unit_pos, 
		attack_range, 
		RangeCalculator.DistanceAlgorithm.MANHATTAN
	)
	
	# 2. 筛选范围内的敌对单位
	var valid_targets: Array[Unit] = []
	
	for cell in attackable_cells:
		var cell_data = battle.game_area.game_grid.get_cell_data(cell)
		if cell_data.is_empty(): continue
		
		var target_unit = cell_data.get("unit")
		if target_unit and target_unit is Unit:
			# 排除自己和同阵营
			if target_unit != unit and target_unit.faction != unit.faction:
				valid_targets.append(target_unit)
	
	if valid_targets.is_empty():
		return
		
	# 3. 选择目标：血量最低优先
	var best_target: Unit = valid_targets[0]
	var min_hp = best_target._current_hp
	
	for i in range(1, valid_targets.size()):
		var t = valid_targets[i]
		if t._current_hp < min_hp:
			min_hp = t._current_hp
			best_target = t
			
	# 4. 执行攻击
	# 使用 AttackProcessor 执行攻击逻辑
	await battle.attack_processor.execute_attack(unit, best_target)
	if is_instance_valid(best_target) and best_target._current_hp > 0:
		await battle.knockback_processor.execute_knockback(unit, best_target)


# 结束回合
func _end_turn() -> void:
	parent_fsm.parent_fsm.change_state("EndState")
