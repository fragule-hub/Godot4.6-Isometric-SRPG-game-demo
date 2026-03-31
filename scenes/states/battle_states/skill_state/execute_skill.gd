extends BaseState

## 缓存的状态机引用
var _skill_state_machine: SkillStateMachine

func _on_enter() -> void:
	_skill_state_machine = parent_fsm as SkillStateMachine
	
	var skill = _skill_state_machine.get_current_skill()
	var caster = battle.get_main_unit()
	
	var target_pos = _skill_state_machine.get_target_pos()
	var direction = _skill_state_machine.get_direction() if skill.is_directional else Vector2i.ZERO
	
	# 播放施法动画
	var unit_direction = _to_unit_direction(direction)
	caster.play_animation_for_skill(skill.animation_name, unit_direction)
	await caster.animated_sprite.animation_finished
	caster.play_idle(unit_direction)
	
	@warning_ignore("redundant_await")
	await skill.execute(caster, target_pos, direction, battle)
	
	parent_fsm.parent_fsm.parent_fsm.change_state("EndState")
	

func _to_unit_direction(direction: Vector2i) -> Unit.Direction:
	var normalized = Vector2i(sign(direction.x), sign(direction.y))
	var unit = battle.get_main_unit()
	return Unit.DIR_MAP.get(\
	normalized, unit._current_direction if unit else Unit.Direction.SE)
