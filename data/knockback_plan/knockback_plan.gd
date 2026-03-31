extends Resource
class_name KnockbackPlan

## 碰撞类型,无/障碍物/单位
enum CollisionType { NONE, OBSTACLE, UNIT }

## 起始格子
var start_cell: Vector2i = Vector2i(-999, -999)
## 落点格子
var landing_cell: Vector2i = Vector2i(-999, -999)

## 碰撞类型
var collision_type: CollisionType = CollisionType.NONE
## 碰撞发生的格子
var collision_cell: Vector2i = Vector2i(-999, -999)
## 碰撞到的单位
var collision_unit: Unit = null

## 是否坠落
var is_fall: bool = false

## 设置计划数据
func set_data(start: Vector2i, landing: Vector2i, collision: CollisionType, 
			  coll_cell: Vector2i, coll_unit: Unit, fall: bool) -> void:
	start_cell = start
	landing_cell = landing
	collision_type = collision
	collision_cell = coll_cell
	collision_unit = coll_unit
	is_fall = fall

## 计划是否有效（通过起始格子判断）
func is_valid() -> bool:
	return start_cell != Vector2i(-999, -999)

## 是否发生碰撞
func has_collision() -> bool:
	return collision_type != CollisionType.NONE
	
## 碰撞是否碰撞到了障碍物
func is_obstacle_collision() -> bool:
	return collision_type == CollisionType.OBSTACLE

## 碰撞是否碰撞到了单位
func is_unit_collision() -> bool:
	return collision_type == CollisionType.UNIT
	
	
	
	
	
