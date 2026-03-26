extends Resource
class_name UnitStat

## 移动力上限
@export var move_point: int = 8
## 移动力地形消耗
@export var move_cost_map: Dictionary = {
	GameGrid.Terrain.LAND : 1,
	GameGrid.Terrain.GRASS : 1,
	GameGrid.Terrain.STONE : 1,
	GameGrid.Terrain.RIVER : -1,
}
@export var atk_range: int = 1
@export var atk: int = 10
@export var def: int = 1
@export var speed: int = 3
@export var max_hp: int = 9

func get_move_point() -> int:
	return move_point

func get_atk_range() -> int:
	return atk_range

func get_atk() -> int:
	return atk

func get_def() -> int:
	return def

func get_speed() -> int:
	return speed

func get_max_hp() -> int:
	return max_hp

func get_move_cost_map() -> Dictionary:
	return move_cost_map

func get_move_cost(terrain: int) -> int:
	if move_cost_map.has(terrain):
		return move_cost_map[terrain]
	return -1
