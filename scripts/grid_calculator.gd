extends Node
class_name GridCalculator

@export var game_area: GameArea

var _astar: AStar2D = AStar2D.new()
var _coord_to_id: Dictionary = {}
var _directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
var _unit: Unit

## 初始化 AStar 图
func _initialize_astar(unit: Unit) -> void:
	_unit = unit
	_astar.clear()
	_coord_to_id.clear()
	
	if not game_area or not game_area.game_grid: return
	
	var grid_data = game_area.game_grid.get_all_grid_data()
	
	# 1. 添加有效点并设置权重
	var move_cost_map = unit.get_move_cost_map()
	var id_counter = 0
	for cell_pos in grid_data:
		var cost = _get_move_cost(move_cost_map, cell_pos)
		if cost != -1:
			_astar.add_point(id_counter, Vector2(cell_pos.x, cell_pos.y), float(cost))
			_coord_to_id[cell_pos] = id_counter
			id_counter += 1
			
	# 2. 连接相邻点
	for cell_pos in _coord_to_id:
		var current_id = _coord_to_id[cell_pos]
		for dir in _directions:
			var neighbor_pos = cell_pos + dir
			if _coord_to_id.has(neighbor_pos):
				_astar.connect_points(current_id, _coord_to_id[neighbor_pos])

## 获取所有可移动的位置坐标及其消耗和父节点
## 返回: Dictionary { "cost_so_far": Dictionary, "parents": Dictionary }
func get_reachable_cells(unit: Unit) -> Dictionary:
	var start_pos = game_area.game_grid.get_unit_position(unit)
	if not _coord_to_id.has(start_pos): return {}
	
	var max_move = unit.get_move_points()
	
	# 记录从起点到达各点的最小消耗
	# Key: Vector2i, Value: int (cost)
	var cost_so_far: Dictionary = { start_pos: 0 }
	
	# 记录，用于重构路径
	var parents: Dictionary = { start_pos: start_pos }
	
	# 优先队列（用数组模拟），存储 [accumulated_cost, current_pos]
	var open_list = [[0, start_pos]]
	
	var move_cost_map = unit.get_move_cost_map()
	while not open_list.is_empty():
		# 1. 取出消耗最小的节点（模拟优先队列）
		var min_index = 0
		var min_cost = open_list[0][0]
		
		# 线性查找最小值
		for i in range(1, open_list.size()):
			if open_list[i][0] < min_cost:
				min_cost = open_list[i][0]
				min_index = i
		
		var current = open_list.pop_at(min_index)
		var current_cost = current[0]
		var current_pos = current[1]
		
		# 如果已经找到更优路径，跳过（Lazy Deletion）
		if current_cost > cost_so_far[current_pos]:
			continue
			
		# 2. 遍历邻居
		for dir in _directions:
			var next_pos = current_pos + dir
			var move_cost = _get_move_cost(move_cost_map, next_pos)
			
			if move_cost == -1: continue
			
			var new_cost = current_cost + move_cost
			
			# 如果在移动力范围内，且找到了更短路径
			if new_cost <= max_move:
				if not cost_so_far.has(next_pos) or new_cost < cost_so_far[next_pos]:
					cost_so_far[next_pos] = new_cost
					parents[next_pos] = current_pos
					open_list.append([new_cost, next_pos])
	
	return {
		"cost_so_far": cost_so_far,
		"parents": parents
	}

## 根据 parents 字典回溯路径
func get_target_path(target_pos: Vector2i, parents: Dictionary) -> Array[Vector2i]:
	if not parents.has(target_pos): return []
	
	var path: Array[Vector2i] = []
	var curr = target_pos
	
	# 根据start_pos = start_pos
	while curr != parents[curr]:
		path.append(curr)
		curr = parents[curr]
	
	path.append(curr) # 添加起点
	path.reverse() # 反转
	return path

# 获取路径前，必须对unit进行初始化
## 获取移动路径
## 返回: Dictionary { "reachable": Array[Vector2i], "unreachable": Array[Vector2i] }
func get_move_path(unit: Unit, target_pos: Vector2i) -> Dictionary:
	var start_pos = game_area.game_grid.get_unit_position(unit)
	if not _coord_to_id.has(start_pos): return { "reachable": [], "unreachable": [] }
	
	# 使用 AStar2D 的 get_closest_point 直接获取最近的可通行点 ID
	var target_id = _astar.get_closest_point(Vector2(target_pos))
	if target_id == -1: return { "reachable": [], "unreachable": [] }
	
	var id_path = _astar.get_id_path(_coord_to_id[start_pos], target_id)
	if id_path.is_empty(): return { "reachable": [], "unreachable": [] }
	
	var reachable: Array[Vector2i] = [start_pos]
	var unreachable: Array[Vector2i] = []
	var current_move = unit.get_move_points()
	
	var is_reachable = true
	var move_cost_map = unit.get_move_cost_map()
	
	for i in range(1, id_path.size()):
		var p_pos = Vector2i(_astar.get_point_position(id_path[i]))
		
		if is_reachable:
			var cost = _get_move_cost(move_cost_map, p_pos)
			if cost != -1 and current_move >= cost:
				current_move -= cost
				reachable.append(p_pos)
			else:
				is_reachable = false
				unreachable.append(p_pos)
		else:
			unreachable.append(p_pos)
			
	return {
		"reachable": reachable,
		"unreachable": unreachable
	}

## 获取移动消耗，返回 -1 表示不可通行
func _get_move_cost(move_cost_map: Dictionary, cell_pos: Vector2i) -> int:
	var grid_data = game_area.game_grid.get_cell_data(cell_pos)
	
	# 1. 基础检查：无效点、有障碍物
	if grid_data.is_empty() or grid_data["obstacle"] != GameGrid.Obstacle.NULL:
		return -1
		
	# 如果该格子有单位且不是当前正在计算的单位，则视为不可通行
	if grid_data["unit"] != null and grid_data["unit"] != _unit:
		return -1
		
	# 2. 根据地形计算消耗
	var terrain_type = grid_data["terrain"]
	
	var cost = move_cost_map.get(terrain_type, -1)
	
	return cost if cost >= 0 else -1
