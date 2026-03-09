extends Node
class_name UnitSpawner

const UNIT = preload("uid://bd7lsxqpkmdaw")

@export var container: Node

## 生成单个单位
## pos: 世界坐标位置
## faction: 阵营，默认为 ENEMY
## color: 单位颜色，默认为白色
func spawn_unit(pos: Vector2, faction: Unit.Faction = Unit.Faction.ENEMY, color: Color = Color.WHITE) -> Unit:
	var unit_instance = UNIT.instantiate() as Unit
	unit_instance.position = pos
	
	if container:
		container.add_child(unit_instance)
	else:
		add_child(unit_instance)
		
	unit_instance.faction = faction
	unit_instance.set_unit_color(color)
	return unit_instance
