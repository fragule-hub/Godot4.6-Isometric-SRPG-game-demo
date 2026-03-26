extends Resource
class_name BUnit

## 记录单位初始状态
@export var unit_stat: UnitStat
## 记录单位阵营
@export var faction: Unit.Faction
## 记录单位位置
@export var cell_pos: Vector2i
## 记录单位朝向
@export var direction: Unit.Direction
## 记录单位当前hp
@export var current_hp: int

## 设置BUnit数据
func set_data(_unit_stat: UnitStat, _faction: Unit.Faction,\
_cell_pos: Vector2i, _direction: Unit.Direction, _current_hp: int)\
-> void:
	self.unit_stat = _unit_stat
	self.faction = _faction
	self.cell_pos = _cell_pos
	self.direction = _direction
	self.current_hp = _current_hp
