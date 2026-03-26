extends Node
class_name UnitSpawner

const UNIT = preload("uid://bd7lsxqpkmdaw")

@export var container: Node

## 生成单个单位
## pos: 世界坐标位置
## stat: 单位属性资源
## faction: 阵营，默认为 ENEMY
func spawn_unit(pos: Vector2, stat: UnitStat, faction: Unit.Faction = Unit.Faction.ENEMY) -> Unit:
	var unit_instance = UNIT.instantiate() as Unit
	unit_instance.position = pos
	
	if container:
		container.add_child(unit_instance)
	else:
		add_child(unit_instance)
		
	unit_instance.set_faction(faction)
	unit_instance.unit_stat = stat
	return unit_instance
