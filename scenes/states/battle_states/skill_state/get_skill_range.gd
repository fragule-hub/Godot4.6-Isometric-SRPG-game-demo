extends BaseState

# 有方向：根据起点和鼠标位置获取方向
# 起点（self：自身；其他：上一个状态）
# 无方向（self：自身；其他：鼠标位置）

## 缓存的状态机引用
var _skill_state_machine: SkillStateMachine
## 上一次鼠标所在的网格位置
var _last_mouse_cell_pos: Vector2i = Vector2i(-999, -999)
## 预览方向
var _preview_direction: Vector2i = Vector2i(1, 0)

func _on_enter() -> void:
	_skill_state_machine = parent_fsm as SkillStateMachine
	_last_mouse_cell_pos = Vector2i(-999, -999)
	_preview_direction = Vector2i(1, 0)


func _state_process(_delta: float) -> void:
	var skill = _skill_state_machine.get_current_skill()
	if not skill:
		return
	
	var cell_pos = battle.game_area.get_hovered_tile()
	
	if cell_pos == _last_mouse_cell_pos:
		return
	_last_mouse_cell_pos = cell_pos
	
	_update_preview_direction(skill, cell_pos)
	
	var target_pos = _get_target_pos(skill, cell_pos)
	var direction = _preview_direction if skill.is_directional else Vector2i.ZERO
	
	var area_cells = skill.get_skill_area_cells(target_pos, direction, battle.range_calculator)
	battle.range_selector.show_range(area_cells, "skill_preview", Color(1, 0.45, 0.35, 0.55))


func _state_input(event: InputEvent) -> void:
	
	if event.is_action_pressed("mouse_left"):
		_try_execute_skill()
	
	if event is InputEventKey and event.pressed:
		var selected_skill = battle.try_select_skill(event)
		if selected_skill:
			parent_fsm.parent_fsm.change_state("SkillState")
			return

func _try_execute_skill() -> void:
	
	var skill = _skill_state_machine.get_current_skill()
	
	var cell_pos = battle.game_area.get_hovered_tile()
	
	# 最后确认更新方向
	_update_preview_direction(skill, cell_pos)
	if skill.is_directional:
		_skill_state_machine.set_direction(_preview_direction)
		
	_skill_state_machine.set_target_pos(_get_target_pos(skill, cell_pos))
	
	parent_fsm.change_state("ExecuteSkill")





## 获取技能目标位置(用于在process)
func _get_target_pos(skill: BaseSkill, cell_pos: Vector2i) -> Vector2i:
	if _skill_state_machine.needs_origin_selection():
		return _skill_state_machine.get_origin_pos()
	elif skill.origin_type != BaseSkill.OriginType.SELF:
		return cell_pos
	else:
		return _skill_state_machine.get_caster_pos()


## 更新预览方向（仅对方向性技能有效）
func _update_preview_direction(skill: BaseSkill, cell_pos: Vector2i) -> void:
	if not skill.is_directional:
		return
	
	var direction_source = _get_direction_source()
	var new_direction = _calculate_direction(direction_source, cell_pos)
	if new_direction != Vector2i.ZERO:
		_preview_direction = new_direction


## 获取方向计算的源点
func _get_direction_source() -> Vector2i:
	if _skill_state_machine.needs_origin_selection():
		return _skill_state_machine.get_origin_pos()
	return _skill_state_machine.get_caster_pos()


## 计算4方向
func _calculate_direction(from_pos: Vector2i, to_pos: Vector2i) -> Vector2i:
	var diff = to_pos - from_pos
	if diff == Vector2i.ZERO:
		return Vector2i.ZERO
	if abs(diff.x) > abs(diff.y):
		return Vector2i(sign(diff.x), 0)
	return Vector2i(0, sign(diff.y))
