extends BaseState

## ==============================================================================
## 获取施法范围状态
## 计算并显示施法范围，决定下一步进入哪个状态：
## - 有方向且非SELF：进入 SelectOrigin 选择起点
## - 无方向或为SELF：直接进入 GetSkillRange
## ==============================================================================

## 缓存的状态机引用
var _skill_state_machine: SkillStateMachine

func _on_enter() -> void:
	print("GetCastRange: Entered")
	_skill_state_machine = parent_fsm as SkillStateMachine
	
	# 验证状态是否有效
	if not _skill_state_machine:
		push_error("GetCastRange: Parent is not SkillStateMachine!")
		parent_fsm.parent_fsm.change_state("AttackState")
		return
	
	if not _skill_state_machine.get_current_skill():
		push_warning("GetCastRange: No skill available!")
		parent_fsm.parent_fsm.change_state("AttackState")
		return
	
	if not battle.get_main_unit():
		push_warning("GetCastRange: No caster available!")
		parent_fsm.parent_fsm.change_state("AttackState")
		return
	
	var skill = _skill_state_machine.get_current_skill()
	var caster = battle.get_main_unit()
	
	# 计算施法范围
	var cast_range_cells = skill.get_cast_range_cells(
		caster,
		battle.game_area.game_grid,
		battle.range_calculator
	)
	
	# 存储施法范围到状态机
	_skill_state_machine.set_cast_range_cells(cast_range_cells)
	
	# 显示施法范围
	battle.range_selector.show_range(cast_range_cells, "skill_cast", Color(0.2, 0.4, 1.0, 0.5))
	print("GetCastRange: Cast range calculated, ", cast_range_cells.size(), " cells")
	
	# 根据技能类型决定下一步
	if _skill_state_machine.needs_origin_selection():
		# 有方向且非SELF，进入选择起点状态
		print("GetCastRange: Needs origin selection, going to SelectOrigin")
		parent_fsm.change_state("SelectOrigin")
	else:
		# 设置默认起点（施法者位置）
		var caster_pos = battle.game_area.game_grid.get_unit_position(caster)
		_skill_state_machine.set_origin_pos(caster_pos)
		print("GetCastRange: No origin selection needed, going to GetSkillRange")
		parent_fsm.change_state("GetSkillRange")
