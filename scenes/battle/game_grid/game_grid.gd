extends Node
class_name GameGrid

## 地形：土地、草地、石地、水面
enum Terrain {LAND, GRASS, STONE, RIVER}
## 障碍类型：石头、木头、无
enum Obstacle {ROCK, WOOD, NULL}

signal grid_changed

@export var main_tile_map: TileMapLayer
@export var obstacle_tile_map: TileMapLayer

## 单位网格数据
## Key: Vector2i (网格坐标)
## Value: Dictionary {
##    "unit": Node2D (or null),
##    "terrain": Terrain,
##    "obstacle": Obstacle
## }
var grid_data: Dictionary = {}

func _ready() -> void:
	if not main_tile_map:
		return
	_initialize_grid()
	GlobalSignal.unit_died.connect(_on_unit_died)

func _initialize_grid() -> void:
	grid_data.clear()
	
	# 1. 对主要地形进行标记
	for cell_pos in main_tile_map.get_used_cells():
		var tile_data = main_tile_map.get_cell_tile_data(cell_pos)
		
		# 默认地形
		var terrain_type = Terrain.LAND
		
		# 尝试从自定义数据层获取地形类型
		if tile_data:
			var custom_terrain = tile_data.get_custom_data("terrain")
			# 检查是否获取到了有效的整数数据
			if typeof(custom_terrain) == TYPE_INT:
				terrain_type = custom_terrain as Terrain
		
		grid_data[cell_pos] = { 
			"unit": null,
			"terrain": terrain_type,
			"obstacle": Obstacle.NULL
		}
	
	# 2. 对障碍物进行标记
	if obstacle_tile_map:
		for cell_pos in obstacle_tile_map.get_used_cells():
			
			var tile_data = obstacle_tile_map.get_cell_tile_data(cell_pos)
			var obstacle_type = Obstacle.ROCK # 默认障碍物类型
			
			# 尝试从自定义数据层获取障碍物类型
			# 请确保 TileSet 中配置了名为 "obstacle" 的自定义数据层（整数类型）
			if tile_data:
				var custom_obstacle = tile_data.get_custom_data("obstacle")
				if typeof(custom_obstacle) == TYPE_INT:
					obstacle_type = custom_obstacle as Obstacle
			
			grid_data[cell_pos]["obstacle"] = obstacle_type

## 获取指定位置的网格数据
func get_cell_data(cell_pos: Vector2i) -> Dictionary:
	return grid_data.get(cell_pos, {})

## 获取所有网格数据
func get_all_grid_data() -> Dictionary:
	return grid_data

func is_usable(cell_pos: Vector2i) -> bool:
	if not grid_data.has(cell_pos):
		return false
	var data = grid_data[cell_pos]
	
	# 检查障碍物
	if data["obstacle"] != Obstacle.NULL:
		return false
		
	# 检查单位占据
	if data["unit"] != null:
		return false
		
	# 检查地形本身是否可通行 (水面不可通行)
	if data["terrain"] == Terrain.RIVER:
		return false
		
	return true

## 添加单位到指定网格
## 成功返回 true，失败返回 false
func add_unit(unit: Node2D, cell_pos: Vector2i) -> bool:
	if not grid_data.has(cell_pos):
		push_warning("UnitGrid: Try to add unit to invalid pos: ", cell_pos)
		return false
		
	if not is_usable(cell_pos):
		push_warning("UnitGrid: Target pos is not usable: ", cell_pos)
		return false
		
	# 更新网格数据
	grid_data[cell_pos]["unit"] = unit
	grid_changed.emit()
	
	return true

## 获取单位所在的网格坐标
func get_unit_position(unit: Unit) -> Vector2i:
	for cell_pos in grid_data:
		if grid_data[cell_pos]["unit"] == unit:
			return cell_pos
	return Vector2i(-999, -999) # 未找到

## 获取地形类型的字符串表示（小写）
func get_terrain_string(terrain_val: int) -> String:
	var key = Terrain.find_key(terrain_val)
	if key:
		return key.to_lower()
	return "unknown"

## 获取障碍物类型的字符串表示（小写）
func get_obstacle_string(obstacle_val: int) -> String:
	var key = Obstacle.find_key(obstacle_val)
	if key:
		return key.to_lower()
	return "unknown"

## 当单位死亡时，自动从网格数据中注销
func _on_unit_died(unit: Unit) -> void:
	var pos = get_unit_position(unit)
	if pos != Vector2i(-999, -999):
		grid_data[pos]["unit"] = null
		grid_changed.emit()
