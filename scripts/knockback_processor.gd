extends Node
class_name KnockbackProcessor

## 击退处理器
## 负责处理战斗中的击退逻辑，包括路径规划、碰撞检测、动画执行、伤害结算和跌落处理。

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

## 执行击退流程
## @param attacker: 发起击退的单位
## @param defender: 被击退的单位
## @param distance: 击退距离（格子数），-1 表示使用默认值
## @param per_cell_time: 每格移动时间，-1 表示使用默认值
func execute_knockback(attacker: Unit, defender: Unit, distance: int = -1, per_cell_time: float = -1.0) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		return

	var actual_distance = default_knockback_distance if distance < 0 else distance
	var actual_per_cell_time = default_per_cell_time if per_cell_time < 0 else per_cell_time

	# 规划击退路径
	var plan = _plan_knockback(attacker, defender, actual_distance)
	if not plan.is_valid():
		return

	# 从网格移除单位（避免动画期间占据原格子）
	if game_area and game_area.game_grid:
		game_area.game_grid.remove_unit(plan.start_cell)

	# 执行击退动画
	if plan.has_collision():
		# 有碰撞：先移动到碰撞点，再回弹到落点
		defender.z_index = 1
		await _play_move_animation(defender, plan.start_cell, plan.collision_cell, actual_per_cell_time)
		await _play_bounce_animation(defender, plan.collision_cell, plan.landing_cell, actual_per_cell_time)
		defender.z_index = 0
	else:
		# 无碰撞：直接移动到落点
		await _play_move_animation(defender, plan.start_cell, plan.landing_cell, actual_per_cell_time)

	# 结算碰撞伤害
	if is_instance_valid(defender) and defender._current_hp > 0:
		_apply_collision_damage(defender, plan)

	# 检查存活状态
	if not is_instance_valid(defender) or defender._current_hp <= 0:
		return

	# 处理落地或跌落
	if plan.is_fall:
		await _handle_fall(defender)
	else:
		# 正常落地，添加到网格
		if game_area and game_area.game_grid:
			game_area.game_grid.add_unit(defender, plan.landing_cell)
		defender.play_idle()

## 规划击退路径
## 计算单位被击退后的最终位置、是否发生碰撞以及是否会跌落
## @return: 包含完整路径规划信息的 KnockbackPlan
func _plan_knockback(attacker: Unit, defender: Unit, distance: int) -> KnockbackPlan:
	var plan := KnockbackPlan.new()
	
	if not game_area or not game_area.game_grid:
		return plan

	var grid = game_area.game_grid
	var attacker_cell = grid.get_unit_position(attacker)
	var defender_cell = grid.get_unit_position(defender)

	if not _is_valid_cell(attacker_cell) or not _is_valid_cell(defender_cell):
		return plan

	# 计算8方向击退方向
	var direction = _get_knockback_direction(attacker_cell, defender_cell)
	if direction == Vector2i.ZERO:
		return plan

	var current_cell = defender_cell
	var collision_type = KnockbackPlan.CollisionType.NONE
	var collision_cell = Vector2i(-999, -999)
	var collision_unit: Unit = null

	# 沿击退方向逐格检测碰撞
	for i in range(1, distance + 1):
		var next_cell = defender_cell + direction * i
		var collision_info = _check_collision(next_cell, defender)

		if collision_info.type != KnockbackPlan.CollisionType.NONE:
			collision_type = collision_info.type
			collision_cell = next_cell
			collision_unit = collision_info.unit
			break
		current_cell = next_cell

	# 检查落点是否安全（仅当无碰撞时）
	var is_fall = false
	if collision_type == KnockbackPlan.CollisionType.NONE:
		var data = grid.get_cell_data(current_cell)
		is_fall = data.is_empty() or not data.has("terrain") or data.get("terrain") == GameGrid.Terrain.RIVER

	plan.set_data(defender_cell, current_cell, collision_type, collision_cell, collision_unit, is_fall)
	return plan

## 计算8方向击退方向
## @param from: 起始格子（攻击者位置）
## @param to: 目标格子（防御者位置）
## @return: 击退方向向量，如果位置相同返回 ZERO
func _get_knockback_direction(from: Vector2i, to: Vector2i) -> Vector2i:
	return Vector2i(sign(to.x - from.x), sign(to.y - from.y))

## 检测指定格子的碰撞情况
## @param cell: 要检测的格子坐标
## @param ignore_unit: 要忽略的单位（通常是正在移动的单位）
## @return: 包含碰撞类型和碰撞单位的字典
func _check_collision(cell: Vector2i, ignore_unit: Unit) -> Dictionary:
	var result = { "type": KnockbackPlan.CollisionType.NONE, "unit": null }
	var cell_data = game_area.game_grid.get_cell_data(cell)

	if cell_data.is_empty():
		return result

	# 检查障碍物
	if cell_data.get("obstacle", GameGrid.Obstacle.NULL) != GameGrid.Obstacle.NULL:
		result.type = KnockbackPlan.CollisionType.OBSTACLE
		return result

	# 检查其他单位
	var other_unit = cell_data.get("unit", null)
	if other_unit is Unit and other_unit != ignore_unit:
		result.type = KnockbackPlan.CollisionType.UNIT
		result.unit = other_unit

	return result

## 播放击退移动动画
## 使用缓出曲线实现平滑移动
func _play_move_animation(unit: Unit, start: Vector2i, end: Vector2i, per_cell_time: float) -> void:
	if start == end:
		return

	# 计算移动时间（切比雪夫距离）
	var duration = max(0.05, per_cell_time * max(abs(end.x - start.x), abs(end.y - start.y)))
	unit.play_idle()

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(unit, "position", _cell_to_world(end), duration)
	await tween.finished

## 播放碰撞回弹动画
## 使用弹跳曲线实现碰撞后的回弹效果
func _play_bounce_animation(unit: Unit, collision: Vector2i, landing: Vector2i, per_cell_time: float) -> void:
	if collision == landing:
		return

	unit.play_idle()

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(unit, "position", _cell_to_world(landing), max(0.03, per_cell_time * 0.35))
	await tween.finished

## 处理跌落深渊逻辑
## 播放下落动画后销毁单位
func _handle_fall(unit: Unit) -> void:
	if not is_instance_valid(unit):
		return

	unit.z_index = -1

	# 下落并渐隐
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(unit, "position", unit.position + Vector2(0, fall_distance), fall_duration)
	tween.parallel().tween_property(unit, "modulate:a", 0.0, fall_duration)
	await tween.finished

	if is_instance_valid(unit):
		unit.hide()
		unit.die()

## 结算碰撞伤害
## 撞墙或撞人时，双方各受到最大生命值50%的伤害
func _apply_collision_damage(defender: Unit, plan: KnockbackPlan) -> void:
	if not attack_processor:
		return

	var damage_ratio := 0.5

	if plan.is_obstacle_collision():
		# 撞墙：仅自身受损
		attack_processor.execute_world_damage(defender, int(ceil(defender.get_max_hp() * damage_ratio)))
	elif plan.is_unit_collision() and is_instance_valid(plan.collision_unit):
		# 撞人：双方受损
		attack_processor.execute_world_damage(defender, int(ceil(defender.get_max_hp() * damage_ratio)))
		attack_processor.execute_world_damage(plan.collision_unit, int(ceil(plan.collision_unit.get_max_hp() * damage_ratio)))

## 检查格子坐标是否有效
func _is_valid_cell(cell: Vector2i) -> bool:
	return cell != Vector2i(-999, -999)

## 格子坐标转世界坐标
func _cell_to_world(cell: Vector2i) -> Vector2:
	return game_area.get_global_from_tile(cell) + Unit.DEFAULT_OFFSET
