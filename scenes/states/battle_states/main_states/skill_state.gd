extends BaseStateMachine
class_name SkillStateMachine
# 1、施法范围（自身、全图、扩散范围（range calculator））
# 2、生效范围（有无方向）（无方向：圆形，range calculator）
#			（有方向） （直线、柱形、扇形）（新增）
# 3、目标筛选（自身、友方、敌方、所有单位）（是否包括自身）
# 4、具体的效果实现（以群体伤害为例）
# value（由攻击力决定/固定值）：power_multiplier（技能倍率）
# 通过继承实现

# skill state，用于执行技能效果
# base skill，用于存储技能的实现

# 1、决定施法范围
# 2、根据施法范围决定skill的起点（如果为self，默认为自身，如果为其他，需要选择）
# 3、获取到起点后，决定skill的生效范围
# （如果有方向，需要根据起点决定方向。如果无方向并且为self，固定范围；非self，跟随鼠标选择范围）
# 4、执行skill

# 作为状态机，存储状态中共通的量

## 当前选中的技能
var current_skill: BaseSkill
## 缓存的施法范围网格坐标
var cast_range_cells: Array[Vector2i] = []
## 施法起点位置
var origin_pos: Vector2i = Vector2i.ZERO
## 目标位置（鼠标位置）
var target_pos: Vector2i = Vector2i.ZERO
## 技能方向
var direction: Vector2i = Vector2i.ZERO

func _on_enter() -> void:
	_reset_data()
	_clear_visuals()
	current_skill = battle.get_current_skill()
	
	if not current_skill:
		push_warning("SkillStateMachine: No skill selected!")
		parent_fsm.change_state("AttackState")
		return
		
	super._on_enter()

func _on_exit() -> void:
	_reset_data()
	_clear_visuals()
	super._on_exit()

func _reset_data() -> void:
	current_skill = null
	cast_range_cells.clear()
	origin_pos = Vector2i.ZERO
	target_pos = Vector2i.ZERO
	direction = Vector2i.ZERO

func _clear_visuals() -> void:
	battle.range_selector.clear_all_ranges()

## 获取当前技能
func get_current_skill() -> BaseSkill:
	return current_skill

## 设置施法范围
func set_cast_range_cells(cells: Array[Vector2i]) -> void:
	cast_range_cells = cells
	
## 需要选择起点
func needs_origin_selection() -> bool:
	if not current_skill:
		return false
	# 有方向并且不是self 
	return current_skill.is_directional and\
	current_skill.origin_type != BaseSkill.OriginType.SELF

## 设置施法起点
func set_origin_pos(pos: Vector2i) -> void:
	origin_pos = pos
	print("SkillStateMachine: Origin set to ", pos)

func get_origin_pos() -> Vector2i:
	return origin_pos

func get_caster_pos() -> Vector2i:
	var caster = battle.get_main_unit()
	if not caster:
		return Vector2i.ZERO
	return battle.game_area.game_grid.get_unit_position(caster)

## 设置目标位置
func set_target_pos(pos: Vector2i) -> void:
	target_pos = pos

## 获取目标位置
func get_target_pos() -> Vector2i:
	return target_pos

func set_direction(value: Vector2i) -> void:
	direction = value

func get_direction() -> Vector2i:
	return direction

## 判断位置是否在施法范围内
func is_in_cast_range(pos: Vector2i) -> bool:
	return pos in cast_range_cells
