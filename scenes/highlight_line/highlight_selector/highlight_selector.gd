extends HighlighLine
class_name HighlighSelector

@export var game_area: GameArea

var last_tile: Vector2i = Vector2i(0, 0)

@onready var label_1: Label = $"Label-1"
@onready var label_2: Label = $"Label-2"
@onready var label_3: Label = $"Label-3"

func _process(_delta: float) -> void:
	if not game_area:
		return
	
	# 获取当前鼠标所在的网格坐标
	var current_tile = game_area.get_hovered_tile()
	
	# 如果网格坐标发生变化
	if current_tile != last_tile:
		last_tile = current_tile
		var tile_position = game_area.get_global_from_tile(current_tile)
		position = tile_position
		
		_update_labels(current_tile)

func _update_labels(tile_pos: Vector2i) -> void:
	if not game_area or not game_area.game_grid:
		return
	
	label_3.text = "(%d,%d)" % [tile_pos.x, tile_pos.y]
		
	var cell_data = game_area.game_grid.get_cell_data(tile_pos)
	if not cell_data.is_empty():
		var terrain = cell_data.get("terrain")
		var obstacle = cell_data.get("obstacle")
		
		# 使用 UnitGrid 提供的辅助函数转换枚举为字符串
		if terrain != null:
			label_1.text = game_area.game_grid.get_terrain_string(terrain)
		else:
			label_1.text = "unknown"
			
		if obstacle != null:
			label_2.text = game_area.game_grid.get_obstacle_string(obstacle)
		else:
			label_2.text = "unknown"
	else:
		label_1.text = "null"
		label_2.text = "null"
