extends BaseState


## 缓存的状态机引用
var _skill_state_machine: SkillStateMachine

func _on_enter() -> void:
	_skill_state_machine = parent_fsm as SkillStateMachine
	
	var skill = _skill_state_machine.get_current_skill()
	
	var caster = battle.get_main_unit()
	
	# 计算施法范围
	var cast_range_cells = skill.get_cast_range_cells(
		caster,
		battle.game_area.game_grid,
		battle.range_calculator
	)
	
	_skill_state_machine.set_cast_range_cells(cast_range_cells)
	
	battle.range_selector.show_range(\
	cast_range_cells, "skill_cast", Color(0.2, 0.4, 1.0, 0.5))
	
	# 切换状态，如果需要选择起点才进入选择起点状态
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

	
	
	
