extends Node
class_name UnitSpawner

const UNIT = preload("uid://1t3rhy5pbjib")

@export var game_area: GameArea
@export var container: Node

func spawn_unit(pos: Vector2, unit_stat: UnitStat,\
faction: Unit.Faction = Unit.Faction.ENEMY) -> Unit:
	var unit_instance = UNIT.instantiate() as Unit
	unit_instance.position = pos
	
	if container:
		container.add_child(unit_instance)
	else:
		add_child(unit_instance)
	unit_instance.unit_stat = unit_stat
	unit_instance.set_faction(faction)
	return unit_instance

func spawn_unit_in_cell(cell_pos: Vector2i, unit_stat: UnitStat,\
faction: Unit.Faction = Unit.Faction.ENEMY) -> Unit:
	var world_pos = game_area.get_global_from_tile(cell_pos)\
	+ Unit.DEFAULT_OFFSET
	var unit: Unit = spawn_unit(world_pos, unit_stat, faction)
	return unit
