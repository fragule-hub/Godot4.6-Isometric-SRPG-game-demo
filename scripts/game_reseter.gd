extends Node
class_name GameReseter

## 游戏区域引用（用于获取网格和坐标转换）
@export var game_area: GameArea

## 回溯状态（用于撤销操作）
var rollback_state: AllUnits = AllUnits.new()
## 不活跃单位池（回溯时临时存储）
var inactive_units: Array[Unit] = []

## 备份回溯状态
func backup_rollback_state(source: AllUnits) -> void:
	rollback_state.clear()
	for i in range(source.get_count()):
		var unit = source.get_unit_by_index(i)
		if unit:
			var cell_pos = game_area.game_grid.get_unit_position(unit)
			var b_unit = unit.create_b_unit(cell_pos)
			rollback_state.set_unit_at_index(i, unit, b_unit)
	rollback_state.current_unit_index = source.current_unit_index
	print("GameReseter: Rollback state backed up.")

## 清空回溯状态
func clear_rollback_state() -> void:
	rollback_state.clear()
	print("GameReseter: Rollback state cleared.")

## 执行回溯重置，返回恢复后的单位数组
func reset_to_rollback_state(unit_spawner: UnitSpawner, active_units: Array[Unit], dying_units: Array[Unit], all_units: AllUnits) -> Array[Unit]:
	if rollback_state.get_count() == 0:
		push_warning("GameReseter: No rollback state to reset to.")
		return active_units
	
	inactive_units.clear()
	var restored_units: Array[Unit] = []
	
	# 步骤1: 将活跃单位和死亡中单位移入不活跃池
	_move_to_inactive(active_units)
	_move_to_inactive(dying_units)
	
	# 步骤2: 从回溯状态恢复单位
	all_units.clear()
	for i in range(rollback_state.get_count()):
		var b_unit = rollback_state.get_b_unit_by_index(i)
		var unit = _find_or_create_unit(unit_spawner, b_unit)
		
		if not game_area.game_grid.add_unit(unit, b_unit.cell_pos):
			if unit not in inactive_units:
				unit.queue_free()
			continue
		
		unit.restore_from_b_unit(b_unit)
		unit.position = game_area.get_global_from_tile(b_unit.cell_pos) + Unit.DEFAULT_OFFSET
		unit.show()
		restored_units.append(unit)
		all_units.set_unit_at_index(restored_units.size() - 1, unit, b_unit)
	
	all_units.current_unit_index = clampi(rollback_state.current_unit_index, 0, all_units.get_count() - 1)
	
	# 步骤3: 清理未使用的不活跃单位
	for unit in inactive_units:
		if is_instance_valid(unit):
			unit.queue_free()
	inactive_units.clear()
	
	return restored_units

## 获取回溯状态的单位数量
func get_rollback_state_count() -> int:
	return rollback_state.get_count()

## 获取回溯状态的当前单位索引
func get_rollback_current_index() -> int:
	return rollback_state.current_unit_index

## 将单位数组移入不活跃池
func _move_to_inactive(units: Array[Unit]) -> void:
	for unit in units:
		unit.hide()
		if unit.animated_sprite.animation_finished.is_connected(unit.queue_free):
			unit.animated_sprite.animation_finished.disconnect(unit.queue_free)
		unit.animated_sprite.stop()
		var grid_pos = game_area.game_grid.get_unit_position(unit)
		if grid_pos != Vector2i(-999, -999):
			game_area.game_grid.remove_unit(grid_pos)
		inactive_units.append(unit)

## 从不活跃池查找匹配单位，找不到则创建新单位
func _find_or_create_unit(unit_spawner: UnitSpawner, b_unit: BUnit) -> Unit:
	for i in range(inactive_units.size()):
		var unit = inactive_units[i]
		if is_instance_valid(unit) and unit.unit_stat == b_unit.unit_stat:
			inactive_units.remove_at(i)
			return unit
	
	var world_pos = game_area.get_global_from_tile(b_unit.cell_pos) + Unit.DEFAULT_OFFSET
	return unit_spawner.spawn_unit(world_pos, b_unit.unit_stat, b_unit.faction)
