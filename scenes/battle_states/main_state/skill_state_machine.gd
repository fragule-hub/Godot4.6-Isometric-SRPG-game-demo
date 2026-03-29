extends BaseStateMachine
class_name SkillStateMachine

## ==============================================================================
## 技能状态机管理器
## 管理技能释放的全局数据，协调4个子状态之间的流转
## ==============================================================================

## ------------------------------------------------------------------------------
## 技能数据
## ------------------------------------------------------------------------------

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

## ------------------------------------------------------------------------------
## 生命周期
## ------------------------------------------------------------------------------

func _on_enter() -> void:
	print("SkillStateMachine: Entered")
	_reset_data()
	
	current_skill = battle.get_current_skill()
	if not current_skill:
		push_warning("SkillStateMachine: No skill selected!")
		parent_fsm.change_state("AttackState")
		return
	
	print("SkillStateMachine: Skill = ", current_skill.skill_name)
	
	super._on_enter()

func _on_exit() -> void:
	_clear_visuals()
	_reset_data()
	super._on_exit()

## ------------------------------------------------------------------------------
## 数据管理
## ------------------------------------------------------------------------------

func _reset_data() -> void:
	current_skill = null
	cast_range_cells.clear()
	origin_pos = Vector2i.ZERO
	target_pos = Vector2i.ZERO
	direction = Vector2i.ZERO

func _clear_visuals() -> void:
	battle.range_selector.clear_all_ranges()

## ------------------------------------------------------------------------------
## 公共接口
## ------------------------------------------------------------------------------

## 获取当前技能
func get_current_skill() -> BaseSkill:
	return current_skill

## 设置施法范围
func set_cast_range_cells(cells: Array[Vector2i]) -> void:
	cast_range_cells = cells

## 设置施法起点
func set_origin_pos(pos: Vector2i) -> void:
	origin_pos = pos
	print("SkillStateMachine: Origin set to ", pos)

## 获取施法起点
func get_origin_pos() -> Vector2i:
	return origin_pos

## 设置技能方向
func set_direction(dir: Vector2i) -> void:
	direction = dir

## 获取技能方向
func get_direction() -> Vector2i:
	return direction

## 设置目标位置
func set_target_pos(pos: Vector2i) -> void:
	target_pos = pos

## 获取目标位置
func get_target_pos() -> Vector2i:
	return target_pos

## 判断是否需要选择施法起点
## 条件：技能有方向性 且 施法范围类型不为 SELF
func needs_origin_selection() -> bool:
	if not current_skill:
		return false
	return current_skill.is_directional and current_skill.origin_type != BaseSkill.OriginType.SELF

## 判断位置是否在施法范围内
func is_in_cast_range(pos: Vector2i) -> bool:
	return pos in cast_range_cells

## 获取施法者位置
func get_caster_pos() -> Vector2i:
	var caster = battle.get_main_unit()
	if not caster:
		return Vector2i.ZERO
	return battle.game_area.game_grid.get_unit_position(caster)
