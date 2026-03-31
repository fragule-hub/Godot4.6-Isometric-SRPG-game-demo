extends BaseState

var _last_hovered_tile: Vector2i
var _is_moving: bool
var _reachable_cells: Dictionary = {}
var _parents: Dictionary = {}

var _main_unit: Unit

func _on_enter() -> void:
	if _is_moving:
		return
	_main_unit = battle._all_units.get_main_unit()
	
	if _main_unit.get_faction() != Unit.Faction.FRIENDLY:
		parent_fsm.change_state("EnemyState")
		return
	
	var result = battle.grid_calculator.get_reachable_cells(_main_unit)
	_reachable_cells = result.get("cost_so_far", {})
	_parents = result.get("parents", {})
	
	var cells: Array[Vector2i] = []
	cells.assign(_reachable_cells.keys())
	battle.range_selector.show_range(cells, "move_range", Color(0.4, 0.6, 1.0, 0.5))

func _on_exit() -> void:
	battle.range_selector.clear_all_ranges()
	battle.path_painter.clear_all_paths()


func _state_process(_delta: float) -> void:
	if _is_moving:
		return
	var current_tile = battle.game_area.get_hovered_tile()
	if current_tile == _last_hovered_tile:
		return
	
	_last_hovered_tile = current_tile
	var last_path_pos = _update_path_preview(current_tile)
	
	if last_path_pos != Vector2i(-999, -999):
		var range_val = _main_unit.get_attack_range()
		var _attackable_cells = battle.range_calculator.get_range_cells(last_path_pos, range_val)
		battle.range_selector.show_range(_attackable_cells,\
		"attack_range", Color(1, 0, 0, 0.5))
	else:
		battle.range_selector.clear_range("attack_range")
		

func _state_input(event: InputEvent) -> void:
	
	if event.is_action_pressed("reset"):
		battle.request_reset()
		return
	
	if event.is_action_pressed("mouse_left"):
		var current_tile = battle.game_area.get_hovered_tile()
		if _main_unit:
			var result:Dictionary = battle.grid_calculator.get_move_path(_main_unit, current_tile)
			var reachable:Array = result.get("reachable", [])
			if not reachable.is_empty():
					_move_unit(reachable)
	
	if event.is_action_pressed("mouse_right"):
		parent_fsm.change_state("AttackState")
		

func _update_path_preview(target_tile: Vector2i) -> Vector2i:
	if not _main_unit: return Vector2i(-999, -999)
	
	if _reachable_cells.has(target_tile):
		var path = battle.grid_calculator.get_target_path(target_tile, _parents)
		if not path.is_empty():
			battle.path_painter.show_path(path, "reachable", Color(1, 1, 1, 0.9))
			battle.path_painter.clear_path("unreachable")
			return path[-1]
		return Vector2i(-999, -999)
	
	var result = battle.grid_calculator.get_move_path(_main_unit, target_tile)
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
	
	return Vector2i(-999, -999)


func _move_unit(path: Array) -> void:
	_is_moving = true
	battle.path_painter.clear_all_paths()
	battle.range_selector.clear_all_ranges()
	battle.hide_skull()
	
	# 执行移动
	if path.size() > 1:
		battle.unit_mover.move_unit(_main_unit, path)
		await battle.unit_mover.move_finished
	
	battle.grid_calculator._initialize_astar(_main_unit)
	_last_hovered_tile = Vector2i(-999, -999)
	_reachable_cells.clear()
	_parents.clear()
	_is_moving = false
	# 自动切换
	parent_fsm.change_state("AttackState")
