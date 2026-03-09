extends Node
class_name KnockbackProcessor

## 击退处理器 (KnockbackProcessor)
##
## 负责处理战斗中的击退逻辑，包括：
## 1. 计算击退路径与目标落点。
## 2. 检测击退过程中的碰撞（障碍物或其他单位）。
## 3. 执行平滑的击退动画。
## 4. 结算碰撞伤害（撞墙或撞人）。
## 5. 处理跌落深渊的逻辑（当被击退到不可行走区域时）。

# --- 依赖引用 ---
@export var game_area: GameArea
@export var attack_processor: AttackProcessor

# --- 配置参数 ---
## 默认击退距离（格子数）
@export var default_knockback_distance: int = 1
## 击退移动每格所需时间（秒）
@export var default_per_cell_time: float = 0.1
## 跌落深渊时的视觉下落距离（像素）
@export var fall_distance: float = 64.0
## 跌落动画持续时间（秒）
@export var fall_duration: float = 0.2

# --- 常量定义 ---
const COLLISION_NONE = "none"
const COLLISION_OBSTACLE = "obstacle"
const COLLISION_UNIT = "unit"

# 击退计划数据结构 Key
const KEY_VALID = "valid"
const KEY_START = "start_cell"
const KEY_LANDING = "landing_cell"
const KEY_COLLISION_TYPE = "collision_type"
const KEY_COLLISION_CELL = "collision_cell"
const KEY_COLLISION_UNIT = "collision_unit"
const KEY_IS_FALL = "is_fall"


## 执行击退流程
##
## @param attacker: 发起击退的单位
## @param defender: 被击退的单位
## @param distance: 击退距离（格子数），-1 表示使用默认值
## @param per_cell_time: 每格移动时间，-1 表示使用默认值
func execute_knockback(attacker: Unit, defender: Unit, distance: int = -1, per_cell_time: float = -1.0) -> void:
	# 1. 基础校验
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		return

	var actual_distance = default_knockback_distance if distance < 0 else distance
	var actual_per_cell_time = default_per_cell_time if per_cell_time < 0 else per_cell_time

	# 2. 规划击退路径
	var plan = _plan_knockback(attacker, defender, actual_distance)
	if not plan[KEY_VALID]:
		return

	# 提取计划数据
	var start_cell: Vector2i = plan[KEY_START]
	var landing_cell: Vector2i = plan[KEY_LANDING]
	var collision_type: String = plan[KEY_COLLISION_TYPE]
	var is_fall: bool = plan[KEY_IS_FALL]

	# 3. 预处理：从网格注销单位位置
	# 避免在动画过程中单位占据原来的格子，或者被其他逻辑判定为还在原位
	_unregister_unit_from_grid(defender, start_cell)

	# 4. 执行击退动画
	# 单位将从 start_cell 平滑移动到 landing_cell
	await _play_knockback_animation(defender, start_cell, landing_cell, actual_per_cell_time)

	# 5. 处理碰撞伤害
	# 如果在移动过程中单位没有死亡则结算碰撞伤害
	if is_instance_valid(defender) and defender._current_hp > 0:
		_apply_collision_damage(defender, collision_type, plan[KEY_COLLISION_UNIT])

	# 再次检查存活状态，如果因碰撞伤害死亡，则无需处理后续逻辑
	if not is_instance_valid(defender) or defender._current_hp <= 0:
		return

	# 6. 处理落地或跌落
	if is_fall:
		# 跌落深渊逻辑
		await _handle_fall(defender)
	else:
		# 正常落地，更新网格数据
		_register_unit_to_grid(defender, landing_cell)
		defender.play_idle()


## 规划击退路径
##
## 计算单位被击退后的最终位置、是否发生碰撞以及是否会跌落。
## 返回包含路径规划信息的字典。
func _plan_knockback(attacker: Unit, defender: Unit, distance: int) -> Dictionary:
	var result := {
		KEY_VALID: false,
		KEY_START: Vector2i.ZERO,
		KEY_LANDING: Vector2i.ZERO,
		KEY_COLLISION_TYPE: COLLISION_NONE,
		KEY_COLLISION_CELL: null,
		KEY_COLLISION_UNIT: null,
		KEY_IS_FALL: false
	}

	if not _is_grid_ready():
		return result

	var game_grid = game_area.game_grid
	var attacker_cell = game_grid.get_unit_position(attacker)
	var defender_cell = game_grid.get_unit_position(defender)

	# 位置无效检查
	if not _is_valid_cell(attacker_cell) or not _is_valid_cell(defender_cell):
		return result

	# 计算击退方向 (8方向)
	var direction = _get_grid_direction_8(attacker_cell, defender_cell)
	if direction == Vector2i.ZERO:
		return result

	var current_cell = defender_cell
	var collision_found = false

	# 沿击退方向逐格检测
	for i in range(1, distance + 1):
		var next_cell = defender_cell + direction * i
		var collision_info = _check_collision(next_cell, defender)

		if collision_info.type != COLLISION_NONE:
			# 发生碰撞
			result[KEY_COLLISION_TYPE] = collision_info.type
			result[KEY_COLLISION_CELL] = next_cell
			result[KEY_COLLISION_UNIT] = collision_info.unit
			
			# 碰撞发生时，单位停留在碰撞体的前一格（即 current_cell）
			collision_found = true
			break
		else:
			# 无碰撞，继续前进
			current_cell = next_cell

	# 检查落点是否安全（是否跌落）
	# 如果发生碰撞，落点是被阻挡的位置，不会跌落
	var is_fall = false
	if not collision_found:
		is_fall = _is_landing_unsafe(current_cell)

	result[KEY_VALID] = true
	result[KEY_START] = defender_cell
	result[KEY_LANDING] = current_cell
	result[KEY_IS_FALL] = is_fall
	
	return result


## 检测指定格子的碰撞情况
func _check_collision(cell: Vector2i, ignore_unit: Unit) -> Dictionary:
	var result = { "type": COLLISION_NONE, "unit": null }
	var cell_data = game_area.game_grid.get_cell_data(cell)

	# 如果格子数据为空，通常视为不可通行或深渊，但在碰撞检测中我们主要关注障碍物和单位
	# 此处逻辑：空数据暂时不视为“碰撞体”，而是会在后续判断为“不安全落点”(跌落)
	if cell_data.is_empty():
		return result

	# 1. 检查障碍物
	var obstacle = cell_data.get("obstacle", GameGrid.Obstacle.NULL)
	if obstacle != GameGrid.Obstacle.NULL:
		result.type = COLLISION_OBSTACLE
		return result

	# 2. 检查其他单位
	var other_unit = cell_data.get("unit", null)
	if other_unit and other_unit is Unit and other_unit != ignore_unit:
		result.type = COLLISION_UNIT
		result.unit = other_unit
		return result

	return result


## 播放击退动画
func _play_knockback_animation(unit: Unit, start_cell: Vector2i, end_cell: Vector2i, per_cell_time: float) -> void:
	if start_cell == end_cell:
		return

	# 计算移动总时间
	var distance_steps = _chebyshev_distance(start_cell, end_cell)
	var total_duration = max(0.05, per_cell_time * distance_steps)
	
	# 获取世界坐标
	var target_pos = _cell_to_world(end_cell)

	# 确定单位朝向（通常是被击退的方向，即面向移动方向的相反方向，或者表现为踉跄后退）
	# 这里简单处理为面向移动方向（如果想表现后退，可以取反）
	var dir_vector = _normalize_step(end_cell - start_cell)
	var unit_dir = _vector_to_direction(dir_vector)
	
	# 设置单位动画状态
	unit.play_idle(unit_dir) # 或者播放专门的受击/后退动画

	# 使用 Tween 执行平滑移动
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(unit, "position", target_pos, total_duration)
	
	await tween.finished


## 处理跌落深渊逻辑
func _handle_fall(unit: Unit) -> void:
	if not is_instance_valid(unit):
		return

	# 创建跌落动画
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# 向下移动并渐隐
	var target_pos = unit.position + Vector2(0, fall_distance)
	tween.tween_property(unit, "position", target_pos, fall_duration)
	tween.parallel().tween_property(unit, "modulate:a", 0.0, fall_duration)
	
	await tween.finished

	# 动画结束后销毁单位
	if is_instance_valid(unit):
		unit.hide()
		unit.die()


## 结算碰撞伤害
func _apply_collision_damage(defender: Unit, collision_type: String, collision_unit: Unit) -> void:
	if not attack_processor:
		return

	# 碰撞伤害公式：最大生命值的 50%
	# 这里的伤害数值逻辑保留了原有设计，可以根据需要调整
	
	if collision_type == COLLISION_OBSTACLE:
		# 撞墙：自身受损
		var damage = int(ceil(float(defender.max_hp) * 0.5))
		attack_processor.execute_damage_no_animation_by_world(defender, damage)
		
	elif collision_type == COLLISION_UNIT:
		# 撞人：双方受损
		var self_damage = int(ceil(float(defender.max_hp) * 0.5))
		attack_processor.execute_damage_no_animation_by_world(defender, self_damage)
		
		if is_instance_valid(collision_unit):
			var other_damage = int(ceil(float(collision_unit.max_hp) * 0.5))
			attack_processor.execute_damage_no_animation_by_world(collision_unit, other_damage)


# --- 辅助与工具方法 ---

func _is_grid_ready() -> bool:
	return game_area and game_area.game_grid

func _is_valid_cell(cell: Vector2i) -> bool:
	# 简单判断，根据实际 GameGrid 实现可能需要调整
	# 假设 (-999, -999) 为无效值
	return cell != Vector2i(-999, -999)

func _unregister_unit_from_grid(unit: Unit, cell: Vector2i) -> void:
	if not _is_grid_ready(): return
	var grid = game_area.game_grid
	
	# 尝试在指定位置清除
	if grid.grid_data.has(cell) and grid.grid_data[cell].get("unit") == unit:
		grid.grid_data[cell]["unit"] = null
		return
	
	# 双重保险：通过单位查找位置并清除
	var current_pos = grid.get_unit_position(unit)
	if grid.grid_data.has(current_pos) and grid.grid_data[current_pos].get("unit") == unit:
		grid.grid_data[current_pos]["unit"] = null

func _register_unit_to_grid(unit: Unit, cell: Vector2i) -> void:
	if not _is_grid_ready(): return
	if game_area.game_grid.grid_data.has(cell):
		game_area.game_grid.grid_data[cell]["unit"] = unit

func _is_landing_unsafe(cell: Vector2i) -> bool:
	if not _is_grid_ready(): return true
	var data = game_area.game_grid.get_cell_data(cell)
	
	# 数据为空或没有 terrain 字段，视为不安全
	if data.is_empty() or not data.has("terrain"):
		return true
	
	# 假设 terrain 为 null 表示没有地块（深渊）
	return data.get("terrain") == null

func _cell_to_world(cell: Vector2i) -> Vector2:
	return game_area.get_global_from_tile(cell) + Unit.DEFAULT_OFFSET

func _get_grid_direction_8(from: Vector2i, to: Vector2i) -> Vector2i:
	var diff = to - from
	return Vector2i(sign(diff.x), sign(diff.y))

func _chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	var d = a - b
	return max(abs(d.x), abs(d.y))

func _normalize_step(v: Vector2i) -> Vector2i:
	return Vector2i(sign(v.x), sign(v.y))

func _vector_to_direction(v: Vector2i) -> Unit.Direction:
	if v.x > 0 and v.y < 0: return Unit.Direction.NE
	if v.x > 0 and v.y > 0: return Unit.Direction.SE
	if v.x < 0 and v.y > 0: return Unit.Direction.SW
	if v.x < 0 and v.y < 0: return Unit.Direction.NW
	
	# 轴向降级处理 (优先保持 Isometric 视觉上的自然)
	if v.x > 0: return Unit.Direction.SE
	if v.x < 0: return Unit.Direction.NW
	if v.y > 0: return Unit.Direction.SW
	if v.y < 0: return Unit.Direction.NE
	
	return Unit.Direction.SE
