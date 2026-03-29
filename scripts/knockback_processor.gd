extends Node
class_name KnockbackProcessor

## ==============================================================================
## 击退处理器 (Knockback Processor)
## ==============================================================================
## 负责处理战斗中的击退逻辑，包括：
## - 路径规划：计算击退方向、距离和最终落点
## - 碰撞检测：检测障碍物和其他单位
## - 动画执行：播放击退移动、碰撞回弹、跌落动画
## - 伤害结算：处理碰撞造成的伤害
## - 跌落处理：处理单位跌落深渊的情况
## ==============================================================================

## ------------------------------------------------------------------------------
## 导出配置
## ------------------------------------------------------------------------------

## 游戏区域引用（用于获取网格和坐标转换）
@export var game_area: GameArea
## 攻击处理器引用（用于结算碰撞伤害）
@export var attack_processor: AttackProcessor

## 默认击退距离（格子数）
@export var default_knockback_distance: int = 1
## 击退移动每格所需时间（秒）
@export var default_per_cell_time: float = 0.1
## 跌落深渊时的视觉下落距离（像素）
@export var fall_distance: float = 64.0
## 跌落动画持续时间（秒）
@export var fall_duration: float = 0.2

## ------------------------------------------------------------------------------
## 公共方法
## ------------------------------------------------------------------------------

## 执行击退流程（基于施法者位置）
## 从施法者位置向目标单位发射击退效果
## @param attacker: 发起击退的单位（击退方向由此决定）
## @param defender: 被击退的单位
## @param distance: 击退距离（格子数），-1 表示使用默认值
## @param per_cell_time: 每格移动时间，-1 表示使用默认值
func execute_knockback(attacker: Unit, defender: Unit, distance: int = -1, per_cell_time: float = -1.0) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		return
	
	var grid := game_area.game_grid if game_area else null
	var origin_pos := grid.get_unit_position(attacker) if grid else Vector2i(-999, -999)
	
	await _execute_knockback_internal(origin_pos, defender, distance, per_cell_time)

## 执行击退流程（基于指定起点位置）
## 适用于技能从特定位置释放击退效果（如从技能目标点击退）
## @param origin_pos: 击退起点坐标（施法位置）
## @param target: 被击退的目标单位
## @param distance: 击退距离（格子数），-1 表示使用默认值
## @param per_cell_time: 每格移动时间，-1 表示使用默认值
func knockback_unit(origin_pos: Vector2i, target: Unit, distance: int = -1, per_cell_time: float = -1.0) -> void:
	if not is_instance_valid(target):
		return
	
	await _execute_knockback_internal(origin_pos, target, distance, per_cell_time)

## ------------------------------------------------------------------------------
## 内部方法 - 击退执行流程
## ------------------------------------------------------------------------------

## 击退执行的内部实现
## 统一处理击退逻辑，被 execute_knockback 和 knockback_unit 共用
## @param origin_pos: 击退方向计算的起点
## @param target: 被击退的目标单位
## @param distance: 击退距离
## @param per_cell_time: 每格移动时间
func _execute_knockback_internal(origin_pos: Vector2i, target: Unit, distance: int, per_cell_time: float) -> void:
	var actual_distance := default_knockback_distance if distance < 0 else distance
	var actual_per_cell_time := default_per_cell_time if per_cell_time < 0 else per_cell_time
	
	var plan := _plan_knockback_path(origin_pos, target, actual_distance)
	if not plan.is_valid():
		return
	
	_remove_unit_from_grid(plan.start_cell)
	await _play_knockback_animation(target, plan, actual_per_cell_time)
	_apply_collision_damage(target, plan)
	
	if not _is_unit_alive(target):
		return
	
	if plan.is_fall:
		await _handle_fall(target)
	else:
		_place_unit_on_grid(target, plan.landing_cell)

## ------------------------------------------------------------------------------
## 内部方法 - 路径规划
## ------------------------------------------------------------------------------

## 规划击退路径
## 计算单位被击退后的最终位置、碰撞情况和跌落状态
## @param origin_pos: 击退方向计算的起点
## @param target: 被击退的目标单位
## @param distance: 击退距离
## @return: 包含完整路径规划信息的 KnockbackPlan
func _plan_knockback_path(origin_pos: Vector2i, target: Unit, distance: int) -> KnockbackPlan:
	var plan := KnockbackPlan.new()
	
	if not game_area or not game_area.game_grid:
		return plan
	
	var grid := game_area.game_grid
	var target_cell := grid.get_unit_position(target)
	
	if not _is_valid_cell(target_cell):
		return plan
	
	var direction := _calculate_knockback_direction(origin_pos, target_cell)
	if direction == Vector2i.ZERO:
		return plan
	
	var path_result := _trace_knockback_path(target_cell, direction, distance, target)
	plan.set_data(
		target_cell,
		path_result.final_cell,
		path_result.collision_type,
		path_result.collision_cell,
		path_result.collision_unit,
		_should_fall(grid, path_result.final_cell, path_result.collision_type)
	)
	
	return plan

## 计算8方向击退方向向量
## 击退方向为从起点指向目标的方向（目标被推离起点）
## @param from: 击退起点坐标
## @param to: 被击退目标坐标
## @return: 击退方向向量，如果位置相同返回 ZERO
func _calculate_knockback_direction(from: Vector2i, to: Vector2i) -> Vector2i:
	return Vector2i(sign(to.x - from.x), sign(to.y - from.y))

## 沿击退方向追踪路径，检测碰撞
## @param start_cell: 击退起始格子
## @param direction: 击退方向
## @param distance: 击退距离
## @param moving_unit: 正在移动的单位（用于碰撞检测时排除）
## @return: 包含最终位置和碰撞信息的字典
func _trace_knockback_path(start_cell: Vector2i, direction: Vector2i, distance: int, moving_unit: Unit) -> Dictionary:
	var result := {
		"final_cell": start_cell,
		"collision_type": KnockbackPlan.CollisionType.NONE,
		"collision_cell": Vector2i(-999, -999),
		"collision_unit": null
	}
	
	for i in range(1, distance + 1):
		var next_cell := start_cell + direction * i
		var collision_info := _check_collision(next_cell, moving_unit)
		
		if collision_info.type != KnockbackPlan.CollisionType.NONE:
			result.collision_type = collision_info.type
			result.collision_cell = next_cell
			result.collision_unit = collision_info.unit
			return result
		
		result.final_cell = next_cell
	
	return result

## 判断落点是否会导致跌落
## 当落点为空、无地形或为河流时，单位会跌落
## @param grid: 游戏网格
## @param cell: 落点坐标
## @param collision_type: 碰撞类型（有碰撞时不检查跌落）
## @return: 是否会跌落
func _should_fall(grid: GameGrid, cell: Vector2i, collision_type: int) -> bool:
	if collision_type != KnockbackPlan.CollisionType.NONE:
		return false
	
	var data := grid.get_cell_data(cell)
	return data.is_empty() or not data.has("terrain") or data.get("terrain") == GameGrid.Terrain.RIVER

## ------------------------------------------------------------------------------
## 内部方法 - 碰撞检测
## ------------------------------------------------------------------------------

## 检测指定格子的碰撞情况
## @param cell: 要检测的格子坐标
## @param ignore_unit: 要忽略的单位（通常是正在移动的单位）
## @return: 包含碰撞类型和碰撞单位的字典
func _check_collision(cell: Vector2i, ignore_unit: Unit) -> Dictionary:
	var result := {"type": KnockbackPlan.CollisionType.NONE, "unit": null}
	var cell_data := game_area.game_grid.get_cell_data(cell)
	
	if cell_data.is_empty():
		return result
	
	if _has_obstacle(cell_data):
		result.type = KnockbackPlan.CollisionType.OBSTACLE
		return result
	
	var other_unit:Unit = cell_data.get("unit")
	if other_unit is Unit and other_unit != ignore_unit:
		result.type = KnockbackPlan.CollisionType.UNIT
		result.unit = other_unit
	
	return result

## 检查格子数据中是否有障碍物
## @param cell_data: 格子数据字典
## @return: 是否有障碍物
func _has_obstacle(cell_data: Dictionary) -> bool:
	return cell_data.get("obstacle", GameGrid.Obstacle.NULL) != GameGrid.Obstacle.NULL

## ------------------------------------------------------------------------------
## 内部方法 - 动画播放
## ------------------------------------------------------------------------------

## 播放击退动画序列
## 根据是否有碰撞决定播放普通移动还是碰撞回弹动画
## @param unit: 被击退的单位
## @param plan: 击退路径规划
## @param per_cell_time: 每格移动时间
func _play_knockback_animation(unit: Unit, plan: KnockbackPlan, per_cell_time: float) -> void:
	if plan.has_collision():
		unit.z_index = 1
		await _play_move_animation(unit, plan.start_cell, plan.collision_cell, per_cell_time)
		await _play_bounce_animation(unit, plan.collision_cell, plan.landing_cell, per_cell_time)
		unit.z_index = 0
	else:
		await _play_move_animation(unit, plan.start_cell, plan.landing_cell, per_cell_time)

## 播放击退移动动画
## 使用缓出曲线实现平滑的减速移动效果
## @param unit: 移动的单位
## @param start: 起始格子
## @param end: 目标格子
## @param per_cell_time: 每格移动时间
func _play_move_animation(unit: Unit, start: Vector2i, end: Vector2i, per_cell_time: float) -> void:
	if start == end:
		return
	
	var duration := _calculate_move_duration(start, end, per_cell_time)
	unit.play_idle()
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(unit, "position", _cell_to_world(end), duration)
	await tween.finished

## 播放碰撞回弹动画
## 使用弹跳曲线实现碰撞后的回弹效果
## @param unit: 移动的单位
## @param collision: 碰撞点格子
## @param landing: 最终落点格子
## @param per_cell_time: 每格移动时间
func _play_bounce_animation(unit: Unit, collision: Vector2i, landing: Vector2i, per_cell_time: float) -> void:
	if collision == landing:
		return
	
	unit.play_idle()
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(unit, "position", _cell_to_world(landing), max(0.03, per_cell_time * 0.35))
	await tween.finished

## 计算移动动画持续时间
## 基于切比雪夫距离（8方向移动的最大轴距离）
## @param start: 起始格子
## @param end: 目标格子
## @param per_cell_time: 每格移动时间
## @return: 动画持续时间（秒）
func _calculate_move_duration(start: Vector2i, end: Vector2i, per_cell_time: float) -> float:
	var chebyshev_distance: int = max(abs(end.x - start.x), abs(end.y - start.y))
	return max(0.05, per_cell_time * chebyshev_distance)

## ------------------------------------------------------------------------------
## 内部方法 - 跌落处理
## ------------------------------------------------------------------------------

## 处理跌落深渊逻辑
## 播放下落动画后销毁单位
## @param unit: 跌落的单位
func _handle_fall(unit: Unit) -> void:
	if not is_instance_valid(unit):
		return
	
	unit.z_index = -1
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(unit, "position", unit.position + Vector2(0, fall_distance), fall_duration)
	tween.parallel().tween_property(unit, "modulate:a", 0.0, fall_duration)
	await tween.finished
	
	if is_instance_valid(unit):
		unit.hide()
		unit.die()

## ------------------------------------------------------------------------------
## 内部方法 - 伤害结算
## ------------------------------------------------------------------------------

## 结算碰撞伤害
## 撞墙时自身受损，撞人时双方受损
## @param defender: 被击退的单位
## @param plan: 击退路径规划
func _apply_collision_damage(defender: Unit, plan: KnockbackPlan) -> void:
	if not attack_processor or not is_instance_valid(defender):
		return
	
	const COLLISION_DAMAGE_RATIO := 0.5
	var damage := int(ceil(defender.get_max_hp() * COLLISION_DAMAGE_RATIO))
	
	if plan.is_obstacle_collision():
		attack_processor.execute_world_damage(defender, damage)
	elif plan.is_unit_collision() and is_instance_valid(plan.collision_unit):
		attack_processor.execute_world_damage(defender, damage)
		attack_processor.execute_world_damage(plan.collision_unit, int(ceil(plan.collision_unit.get_max_hp() * COLLISION_DAMAGE_RATIO)))

## ------------------------------------------------------------------------------
## 内部方法 - 网格操作
## ------------------------------------------------------------------------------

## 从网格移除单位
## @param cell: 单位所在的格子
func _remove_unit_from_grid(cell: Vector2i) -> void:
	if game_area and game_area.game_grid:
		game_area.game_grid.remove_unit(cell)

## 将单位放置到网格上
## @param unit: 要放置的单位
## @param cell: 目标格子
func _place_unit_on_grid(unit: Unit, cell: Vector2i) -> void:
	if game_area and game_area.game_grid:
		game_area.game_grid.add_unit(unit, cell)
	unit.play_idle()

## ------------------------------------------------------------------------------
## 内部方法 - 工具函数
## ------------------------------------------------------------------------------

## 检查单位是否存活
## @param unit: 要检查的单位
## @return: 单位是否存活
func _is_unit_alive(unit: Unit) -> bool:
	return is_instance_valid(unit) and unit._current_hp > 0

## 检查格子坐标是否有效
## @param cell: 格子坐标
## @return: 坐标是否有效
func _is_valid_cell(cell: Vector2i) -> bool:
	return cell != Vector2i(-999, -999)

## 格子坐标转世界坐标
## @param cell: 格子坐标
## @return: 世界坐标位置
func _cell_to_world(cell: Vector2i) -> Vector2:
	return game_area.get_global_from_tile(cell) + Unit.DEFAULT_OFFSET
