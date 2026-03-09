extends Node
class_name UnitMover

@export var game_area: GameArea
## 每格移动所需时间
@export var move_speed: float = 0.2

signal move_finished

## 使单位沿路径移动
func move_unit(unit: Unit, path: Array[Vector2i]) -> void:
	if path.size() <= 1:
		emit_signal("move_finished")
		return
		
	# 记录起始和结束网格坐标，用于后续更新 UnitGrid 数据
	var start_grid_pos = path[0]
	var end_grid_pos = path[-1]
	
	# 1. 从原网格移除单位引用（逻辑层）
	if game_area and game_area.game_grid:
		game_area.game_grid.grid_data[start_grid_pos]["unit"] = null
		
	# 2. 开始逐格移动
	var tween = create_tween()
	
	for i in range(1, path.size()):
		var prev_pos = path[i-1]
		var curr_pos = path[i]
		
		# 计算方向
		var diff = curr_pos - prev_pos
		if Unit.DIR_MAP.has(diff):
			var direction = Unit.DIR_MAP[diff]
			tween.tween_callback(func(): unit.play_move(direction))
		
		# 计算目标世界位置
		var target_pos = game_area.get_global_from_tile(curr_pos)\
		+ Unit.DEFAULT_OFFSET
		
		# 使用 Tween 进行平滑移动
		tween.tween_property(unit, "position", target_pos, move_speed)
	
	await tween.finished
		
	# 3. 移动结束
	unit.play_idle()
	
	# 4. 在新网格注册单位引用（逻辑层）
	if game_area and game_area.game_grid:
		game_area.game_grid.grid_data[end_grid_pos]["unit"] = unit
		
	emit_signal("move_finished")
