extends Resource
class_name BUnit

@export var unit_stat: UnitStat
@export var faction: Unit.Faction = Unit.Faction.ENEMY
@export var cell_pos: Vector2i = Vector2i.ZERO
@export var direction: Unit.Direction = Unit.Direction.SE
@export var current_hp: int = 1

## 设置BUnit数据
func set_data(_unit_stat: UnitStat, _faction: Unit.Faction,\
_cell_pos: Vector2i, _direction: Unit.Direction, _current_hp: int)\
-> void:
	self.unit_stat = _unit_stat
	self.faction = _faction
	self.cell_pos = _cell_pos
	self.direction = _direction
	self.current_hp = _current_hp
