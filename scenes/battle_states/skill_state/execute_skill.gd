extends BaseState

## ==============================================================================
## 执行技能状态
## 执行技能动画和效果，等待完成后流转到 EndState
## ==============================================================================

## 缓存的状态机引用
var _skill_state_machine: SkillStateMachine

func _on_enter() -> void:
	print("ExecuteSkill: Entered")
	_skill_state_machine = parent_fsm as SkillStateMachine
	
	# 验证状态是否有效
	if not _skill_state_machine:
		push_error("ExecuteSkill: Parent is not SkillStateMachine!")
		parent_fsm.parent_fsm.change_state("AttackState")
		return
	
	if not _skill_state_machine.get_current_skill():
		push_warning("ExecuteSkill: No skill available!")
		parent_fsm.parent_fsm.change_state("AttackState")
		return
	
	if not battle.get_main_unit():
		push_warning("ExecuteSkill: No caster available!")
		parent_fsm.parent_fsm.change_state("AttackState")
		return
	
	var skill = _skill_state_machine.get_current_skill()
	var caster = battle.get_main_unit()
	
	# 获取执行参数
	var target_pos = _skill_state_machine.get_target_pos()
	var direction = _skill_state_machine.get_direction() if skill.is_directional else Vector2i.ZERO
	
	print("ExecuteSkill: Executing ", skill.skill_name, " at ", target_pos, " direction ", direction)
	
	# 播放施法动画
	var unit_direction = _to_unit_direction(direction)
	caster.play_animation_for_skill(skill.animation_name, unit_direction)
	await caster.animated_sprite.animation_finished
	caster.play_idle(unit_direction)
	
	# 执行技能效果
	await skill.execute(caster, target_pos, direction, battle)
	
	print("ExecuteSkill: Skill executed successfully!")
	
	# 流转到 EndState
	parent_fsm.parent_fsm.parent_fsm.change_state("EndState")

func _on_exit() -> void:
	# 清除所有范围高亮
	battle.range_selector.clear_all_ranges()

## ------------------------------------------------------------------------------
## 工具函数
## ------------------------------------------------------------------------------

## 将向量方向转换为 Unit.Direction 枚举
func _to_unit_direction(direction: Vector2i) -> Unit.Direction:
	var normalized = Vector2i(sign(direction.x), sign(direction.y))
	var unit = battle.get_main_unit()
	return Unit.DIR_MAP.get(normalized, unit._current_direction if unit else Unit.Direction.SE)
