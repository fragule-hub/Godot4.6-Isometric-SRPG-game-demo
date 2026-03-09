extends BaseState

var _reachable_cells: Dictionary = {}
var _parents: Dictionary = {}
var _last_hovered_tile: Vector2i = Vector2i(-999, -999)
var _is_moving: bool = false

func _on_enter() -> void:
	if battle._main_unit.get_faction() != Unit.Faction.FRIENDLY:
		parent_fsm.change_state("EnemyState")
	_is_moving = false
	var unit = battle._main_unit
	if not unit:
		push_warning("MoveState: No main unit found!")
		return

	# 0. 备份状态（用于重置）
	battle.backup_state()

	# 1. 初始化 AStar 并获取可移动范围
	battle.grid_calculator._initialize_astar(unit)
	var result = battle.grid_calculator.get_reachable_cells(unit)
	_reachable_cells = result.get("cost_so_far", {})
	_parents = result.get("parents", {})
	
	# 2. 显示移动范围
	var cells: Array[Vector2i] = []
	cells.assign(_reachable_cells.keys())
	battle.range_selector.show_range(cells, "move_range", Color(0.4, 0.6, 1.0, 0.5))


func _on_exit() -> void:
	_is_moving = false
	battle.range_selector.clear_range("")
	battle.path_painter.clear_all_paths()
	_reachable_cells.clear()
	_parents.clear()

func _state_process(_delta: float) -> void:
	if _is_moving: return
	
	var current_tile = battle.game_area.get_hovered_tile()
	if current_tile == _last_hovered_tile:
		return
		
	_last_hovered_tile = current_tile
	var last_path_pos = _update_path_preview(current_tile)
	
	if last_path_pos != null:
		_update_attack_preview(last_path_pos)
	else:
		battle.range_selector.clear_range("attack_range")

func _state_input(event: InputEvent) -> void:
	if _is_moving: return
	
	if event.is_action_pressed("mouse_left"):
		var current_tile = battle.game_area.get_hovered_tile()

		var unit = battle._main_unit
		# 0. 如果点击的是单位当前位置，视为原地待机/移动结束
		if unit and battle.game_area.game_grid.get_unit_position(unit) == current_tile:
			parent_fsm.change_state("AttackState")
			return
		# 只有点击可移动范围内的格子才移动
		if _reachable_cells.has(current_tile):
			var path = battle.grid_calculator.get_target_path(current_tile, _parents)
			_move_unit(path)
		else:
			if unit:
				var result:Dictionary = battle.grid_calculator.get_move_path(unit, current_tile)
				var reachable:Array = result.get("reachable", [])
				if not reachable.is_empty():
					_move_unit(reachable)
	
	if event.is_action_pressed("mouse_right"):
		parent_fsm.change_state("AttackState")
		
	# 重置功能
	if event.is_action_pressed("reset"):
		if not _is_moving:
			battle.reset_state()

func _move_unit(path: Array) -> void:
	_is_moving = true

	# 移动前清除高亮和路径
	battle.range_selector.clear_range("")
	battle.path_painter.clear_all_paths()
	
	# 移动开始时隐藏骷髅图标
	battle.hide_skull()
	
	# 执行移动
	if path.size() > 1:
		battle.unit_mover.move_unit(battle._main_unit, path)
		await battle.unit_mover.move_finished
	
	parent_fsm.change_state("AttackState")

# func _update_path_preview(target_tile: Vector2i) -> void:
# 	var unit = battle._main_unit
# 	if not unit: return
#
# 	# 情况1：目标在移动范围内
# 	if _reachable_cells.has(target_tile):
# 		var path = battle.grid_calculator.get_target_path(target_tile, _parents)
# 		if not path.is_empty():
# 			battle.path_painter.show_path(path, "reachable", Color(1, 1, 1, 0.9))
# 			battle.path_painter.clear_path("unreachable")
# 		return
#
# 	# 情况2：目标超出范围，显示混合路径
# 	var result = battle.grid_calculator.get_move_path(unit, target_tile)
# 	var reachable = result.get("reachable", [])
# 	var unreachable = result.get("unreachable", [])
# 	
# 	if not reachable.is_empty():
# 		battle.path_painter.show_path(reachable, "reachable", Color(1, 1, 1, 0.9))
# 	else:
# 		battle.path_painter.clear_path("reachable")
# 		
# 	if not unreachable.is_empty():
# 		# 视觉优化：连接可达与不可达路径
# 		if not reachable.is_empty():
# 			unreachable.insert(0, reachable[-1])
# 		battle.path_painter.show_path(unreachable, "unreachable", Color(0.5, 0.5, 0.5, 0.9))
# 	else:
# 		battle.path_painter.clear_path("unreachable")

func _update_path_preview(target_tile: Vector2i) -> Variant:
	var unit = battle._main_unit
	if not unit: return null

	# 情况1：目标在移动范围内
	if _reachable_cells.has(target_tile):
		var path = battle.grid_calculator.get_target_path(target_tile, _parents)
		if not path.is_empty():
			battle.path_painter.show_path(path, "reachable", Color(1, 1, 1, 0.9))
			battle.path_painter.clear_path("unreachable")
			return path[-1]
		return null

	# 情况2：目标超出范围，显示混合路径
	var result = battle.grid_calculator.get_move_path(unit, target_tile)
	var reachable = result.get("reachable", [])
	var unreachable = result.get("unreachable", [])
	
	if not reachable.is_empty():
		battle.path_painter.show_path(reachable, "reachable", Color(1, 1, 1, 0.9))
	else:
		battle.path_painter.clear_path("reachable")
		
	if not unreachable.is_empty():
		# 视觉优化：连接可达与不可达路径
		if not reachable.is_empty():
			unreachable.insert(0, reachable[-1])
		battle.path_painter.show_path(unreachable, "unreachable", Color(0.5, 0.5, 0.5, 0.9))
		return unreachable[-1]
	else:
		battle.path_painter.clear_path("unreachable")
		if not reachable.is_empty():
			return reachable[-1]
			
	return null


func _update_attack_preview(center_pos: Vector2i) -> void:
	var unit = battle._main_unit
	if not unit: return
	
	var attack_range = unit.get_attack_range()
	var cells = battle.range_calculator.get_range_cells(center_pos, attack_range)
	battle.range_selector.show_range(cells, "attack_range", Color(1, 0, 0, 0.5))
