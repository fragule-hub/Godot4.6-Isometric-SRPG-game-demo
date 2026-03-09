extends Node
class_name PathPainter

@export var game_area: GameArea

# 对象池：存储当前空闲的Line2D节点
var _pool: Array[Line2D] = []
# 记录当前正在使用的路径组映射 (Name -> Array[Line2D])
var _path_groups: Dictionary = {}

## 接收一个网格坐标数组，绘制指定名称的路径
func show_path(cells: Array[Vector2i], group_name: String = "default", color: Color = Color(1, 1, 1, 0.8), width: float = 4.0) -> void:
	# 1. 自动清除同名的路径
	clear_path(group_name)
	
	if not game_area or cells.size() < 2:
		return
		
	# 初始化组
	var group: Array[Line2D] = []
	_path_groups[group_name] = group
		
	# 2. 生成新的路径
	var line = _get_from_pool()
	line.width = width
	line.default_color = color
	
	var local_points = PackedVector2Array()
	for cell_pos in cells:
		local_points.append(game_area.get_global_from_tile(cell_pos))
	
	line.points = local_points
	line.show()
	group.append(line)

## 清除指定名称（或全部）的路径并回收到池
func clear_path(group_name: String = "") -> void:
	if group_name == "":
		clear_all_paths()
		return

	if _path_groups.has(group_name):
		var group = _path_groups[group_name]
		for line in group:
			line.hide()
			_pool.append(line)
		_path_groups.erase(group_name)

## 清除所有路径
func clear_all_paths() -> void:
	for group in _path_groups.values():
		for line in group:
			line.hide()
			_pool.append(line)
	_path_groups.clear()

## 从池中获取一个节点，如果池为空则实例化新节点
func _get_from_pool() -> Line2D:
	var line: Line2D
	if _pool.size() > 0:
		line = _pool.pop_back()
	else:
		line = Line2D.new()
		line.z_index = 0 
		add_child(line)
	return line
