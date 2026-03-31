extends Node
class_name KnockbackProcessor

# 开始击退时，规划路径
# 接收：单位，单位位置，距离
# 返回：终点位置
# 如果终点为虚空、或者水面，则坠落死亡
# 如果中间发生碰撞（其他单位/障碍物），停止并且发生碰撞伤害

@export var game_area: GameArea
@export var attack_processor: AttackProcessor

## 击退移动每格所需时间（秒）
@export var default_per_cell_time: float = 0.1
## 跌落深渊时的视觉下落距离（像素）
@export var fall_distance: float = 64.0
## 跌落动画持续时间（秒）
@export var fall_duration: float = 0.2

# 有攻击单位的击退
func execute_knockback(attacker: Unit, defender: Unit,\
distance: int = -1, per_cell_time: float = -1.0) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(defender) or not game_area:
		return
	
	var origin_pos := game_area.game_grid.get_unit_position(attacker)
	await _execute_knockback_internal(origin_pos, defender, distance, per_cell_time)

# 无攻击单位的击退
func knockback_unit(origin_pos: Vector2i,\
target: Unit, distance: int = -1, per_cell_time: float = -1.0) -> void:
	if not is_instance_valid(target):
		return
	
	await _execute_knockback_internal(origin_pos, target, distance, per_cell_time)





## 用于执行击退的内部方法
func _execute_knockback_internal(origin_pos: Vector2i,\
target: Unit, distance: int, per_cell_time: float) -> void:
	# 首先规划击退plan
	var plan := _plan_knockback_path(origin_pos, target, distance)
	if not plan.is_valid():
		return
	
	var move_time := default_per_cell_time if per_cell_time < 0 else per_cell_time
	
	if game_area and game_area.game_grid:
		game_area.game_grid.remove_unit(plan.start_cell)
	# 立即更新网格信息，防止网格更新不及时
	if not plan.is_fall:
		if game_area and game_area.game_grid:
			game_area.game_grid.add_unit(target, plan.landing_cell)
		target.play_idle()
	
	# 播放击退动画
	await _play_knockback_animation(target, plan, move_time)
	
	# 应用碰撞伤害
	_apply_collision_damage(target, plan)
	
	if plan.is_fall:
		await _handle_fall(target)
	
	
	
	
	
	
	
	
	



func _plan_knockback_path(origin_pos: Vector2i,\
target: Unit, distance: int) -> KnockbackPlan:
	var plan := KnockbackPlan.new()
	
	# 默认起点为单位位置
	var target_cell := game_area.game_grid.get_unit_position(target)
	if target_cell == Vector2i(-999, -999):
		return plan
	
	# 需要计算方向
	var direction := _calculate_knockback_direction(origin_pos, target_cell)
	if direction == Vector2i.ZERO:
		return plan
	# 根据方向遍历对应位置，决定是否发生碰撞
	var path_result := _trace_knockback_path(target_cell, direction, distance, target)
	# 接收到落点后，判断是否坠落
	plan.set_data(
		target_cell,
		path_result.final_cell,
		path_result.collision_type,
		path_result.collision_cell,
		path_result.collision_unit,
		_should_fall(path_result.final_cell, path_result.collision_type)
	)
	
	return plan
	

func _should_fall(cell: Vector2i, collision_type: int) -> bool:
	if collision_type != KnockbackPlan.CollisionType.NONE:
		return false
	
	var data := game_area.game_grid.get_cell_data(cell)
	
	# 如果地形不存在或者为水面则坠落
	return data.is_empty() or\
	not data.has("terrain") or data.get("terrain") == GameGrid.Terrain.RIVER


## 八向
func _calculate_knockback_direction(from: Vector2i, to: Vector2i) -> Vector2i:
	return Vector2i(sign(to.x - from.x), sign(to.y - from.y))

## 追踪击退路径
func _trace_knockback_path(start_cell: Vector2i,\
direction: Vector2i, distance: int, moving_unit: Unit) -> Dictionary:
	# 落点以及是否发生碰撞
	var result := {
		"final_cell": start_cell,
		"collision_type": KnockbackPlan.CollisionType.NONE,
		"collision_cell": Vector2i(-999, -999),
		"collision_unit": null
	}
	
	for i in range(1, distance + 1):
		var next_cell := start_cell + direction * i
		# 判断有无碰撞
		var collision_info := _check_collision(next_cell, moving_unit)
		
		if collision_info.type != KnockbackPlan.CollisionType.NONE:
			result.collision_type = collision_info.type
			result.collision_cell = next_cell
			result.collision_unit = collision_info.unit
			return result
		
		result.final_cell = next_cell
	
	return result

## 接收单位用于确认单位是否是自身放在误判
func _check_collision(cell: Vector2i, ignore_unit: Unit) -> Dictionary:
	var result := {"type": KnockbackPlan.CollisionType.NONE, "unit": null}
	var cell_data := game_area.game_grid.get_cell_data(cell)
	
	if cell_data.is_empty():
		return result
	
	if cell_data.get("obstacle", GameGrid.Obstacle.NULL) != GameGrid.Obstacle.NULL:
		result.type = KnockbackPlan.CollisionType.OBSTACLE
		return result
	
	var other_unit:Unit = cell_data.get("unit")
	if other_unit is Unit and other_unit != ignore_unit:
		result.type = KnockbackPlan.CollisionType.UNIT
		result.unit = other_unit
	
	return result
	
func _play_knockback_animation(unit: Unit,\
plan: KnockbackPlan, per_cell_time: float) -> void:
	
	# 区分，此次击退是否发生碰撞
	# 如果无碰撞则直接移动，如果碰撞需要回弹动画
	
	if not plan.has_collision():
		await _play_move_animation(unit, plan.start_cell, plan.landing_cell, per_cell_time)
		return
	
	# 为了确保碰撞时单位在其他物体上
	unit.z_index = 1
	await _play_move_animation(unit, plan.start_cell, plan.collision_cell, per_cell_time)
	await _play_bounce_animation(unit, plan.collision_cell, plan.landing_cell, per_cell_time)
	unit.z_index = 0
	
	

func _play_move_animation(unit: Unit,\
start: Vector2i, end: Vector2i, per_cell_time: float) -> void:
	if start == end:
		return
	
	var distance: int = max(abs(end.x - start.x), abs(end.y - start.y))
	var duration: float = max(0.1, per_cell_time * distance)
	unit.play_idle()
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(unit, "position", game_area.get_global_from_tile(end)\
	+ Unit.DEFAULT_OFFSET, duration)
	await tween.finished

## 接收碰撞位置和最終落點（用于在move结束后回弹）
func _play_bounce_animation(unit: Unit,\
collision: Vector2i, landing: Vector2i, per_cell_time: float) -> void:
	if collision == landing:
		return
	
	# 默认设置为idle（如果有专门的击飞动画其实最好）
	unit.play_idle()
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(unit, "position", game_area.get_global_from_tile(landing) + Unit.DEFAULT_OFFSET, max(0.03, per_cell_time * 0.35))
	await tween.finished
	
func _apply_collision_damage(defender: Unit, plan: KnockbackPlan) -> void:
	if not attack_processor or not is_instance_valid(defender) or not plan.has_collision():
		return
	
	# 设定为造成一半最大生命值的伤害
	const COLLISION_DAMAGE := 0.5
	var damage := int(ceil(defender.get_max_hp() * COLLISION_DAMAGE))
	attack_processor.execute_world_damage(defender, damage)
	
	if plan.is_unit_collision() and is_instance_valid(plan.collision_unit):
		var other_damage := int(ceil(plan.collision_unit.get_max_hp() * COLLISION_DAMAGE))
		attack_processor.execute_world_damage(plan.collision_unit, other_damage)

# 坠落动画，结束后销毁
func _handle_fall(unit: Unit) -> void:
	
	# 确保被其他物体（如地形）遮蔽
	unit.z_index = -1
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(unit, "position", unit.position + Vector2(0, fall_distance), fall_duration)
	tween.parallel().tween_property(unit, "modulate:a", 0.0, fall_duration)
	await tween.finished
	
	if is_instance_valid(unit):
		unit.hide()
		unit.die()
	
	
	
	
	
	
	
	
	
	
