extends BaseState
class_name SkillState

# ==============================================================================
# 技能释放状态
# 处理玩家释放技能的交互流程：
# 1. 显示施法范围 (Cast Range)
# 2. 选择目标/方向 (Skill Preview)
# 3. 确认并执行技能 (Execute)
# ==============================================================================

# 当前选中的技能
var current_skill: BaseSkill
# 缓存的施法范围网格坐标
var cast_range_cells: Array[Vector2i] = []

# 预览时的方向 (用于有方向性的技能)
var _preview_direction: Vector2i = Vector2i(1, 0)
# 待执行的目标位置
var _pending_target_pos: Vector2i = Vector2i.ZERO
# 待执行的技能方向
var _pending_direction: Vector2i = Vector2i.ZERO

# 技能释放流程状态枚举
enum SkillFlowState {
	GET_CAST_RANGE,  # 阶段1：计算并显示施法范围
	GET_SKILL_RANGE, # 阶段2：等待玩家选择目标，显示技能生效范围预览
	EXECUTE_SKILL    # 阶段3：执行技能逻辑
}

var _flow_state: SkillFlowState = SkillFlowState.GET_CAST_RANGE

# 上一次鼠标所在的网格位置，用于优化预览刷新
var _last_mouse_cell_pos: Vector2i = Vector2i(-999, -999)


func _on_enter() -> void:
	print("SkillState: Entered")
	
	# 获取当前选中的技能
	current_skill = battle.get_current_skill()
	if not current_skill:
		push_warning("SkillState: No skill selected!")
		parent_fsm.change_state("AttackState")
		return
		
	# 初始化状态
	_flow_state = SkillFlowState.GET_CAST_RANGE
	_preview_direction = Vector2i(1, 0)
	_last_mouse_cell_pos = Vector2i(-999, -999)
	
	_run_flow()
	print("SkillState: Showing cast range for ", current_skill.skill_name)

func _on_exit() -> void:
	battle.range_selector.clear_all_ranges()
	cast_range_cells.clear()
	_pending_target_pos = Vector2i.ZERO
	_pending_direction = Vector2i.ZERO

func _state_process(_delta: float) -> void:
	if _flow_state == SkillFlowState.GET_SKILL_RANGE:
		_update_skill_preview()

func _state_input(event: InputEvent) -> void:
	# 允许在技能状态下切换其他技能
	if event is InputEventKey and event.pressed:
		var selected_skill = battle.try_select_main_unit_skill_from_event(event)
		if selected_skill and selected_skill != current_skill:
			parent_fsm.change_state("SkillState")
			return
		
	# 处理鼠标点击
	if event.is_action_pressed("mouse_left"):
		_try_execute_skill()
	elif event.is_action_pressed("mouse_right"):
		parent_fsm.change_state("AttackState")


func _run_flow() -> void:
	match _flow_state:
		SkillFlowState.GET_CAST_RANGE:
			# 计算并显示施法范围
			var caster = battle.get_main_unit()
			if caster:
				cast_range_cells = current_skill.get_cast_range_cells(
					caster,
					battle.game_area.game_grid,
					battle.range_calculator
				)
				battle.range_selector.show_range(cast_range_cells, "skill_cast", Color(0.2, 0.4, 1.0, 0.5))
			_flow_state = SkillFlowState.GET_SKILL_RANGE
			
		SkillFlowState.GET_SKILL_RANGE:
			_last_mouse_cell_pos = Vector2i(-999, -999)
			_update_skill_preview()
			
		SkillFlowState.EXECUTE_SKILL:
			await _execute_skill()

# 更新技能效果范围预览
func _update_skill_preview() -> void:
	if not current_skill: return
	
	var caster = battle.get_main_unit()
	if not caster: return
	
	var mouse_pos = battle.get_global_mouse_position()
	var cell_pos = battle.game_area.get_tile_from_global(mouse_pos)
	
	# 如果鼠标所在的格子没变，不需要重复计算
	if cell_pos == _last_mouse_cell_pos:
		return
	_last_mouse_cell_pos = cell_pos
	
	var caster_pos = battle.game_area.game_grid.get_unit_position(caster)
	
	# 解析实际的目标位置
	var target_pos = _resolve_target_pos(caster_pos, cell_pos)
	
	# 计算技能方向 (如果有方向性)
	if current_skill.is_directional:
		var direction = _calculate_direction(caster_pos, cell_pos)
		if direction != Vector2i.ZERO:
			_preview_direction = direction
			
	# 检查目标点是否在施法范围内
	if target_pos in cast_range_cells:
		var direction = _preview_direction if current_skill.is_directional else Vector2i.ZERO
		var area_cells = current_skill.get_skill_area_cells(
			caster,
			target_pos,
			direction,
			battle.range_calculator
		)
		battle.range_selector.show_range(area_cells, "skill_preview", Color(1, 0.45, 0.35, 0.55))
	else:
		battle.range_selector.clear_range("skill_preview")

# 尝试执行技能
func _try_execute_skill() -> void:
	if not current_skill: return
	if _flow_state != SkillFlowState.GET_SKILL_RANGE:
		return
		
	var caster = battle.get_main_unit()
	if not caster: return
	
	var caster_pos = battle.game_area.game_grid.get_unit_position(caster)
	var mouse_pos = battle.get_global_mouse_position()
	var cell_pos = battle.game_area.get_tile_from_global(mouse_pos)
	
	var target_pos = _resolve_target_pos(caster_pos, cell_pos)
	
	# 确认方向
	if current_skill.is_directional:
		var direction_preview = _calculate_direction(caster_pos, cell_pos)
		if direction_preview != Vector2i.ZERO:
			_preview_direction = direction_preview
			
	# 验证目标是否在施法范围内
	if target_pos in cast_range_cells:
		_pending_target_pos = target_pos
		_pending_direction = _preview_direction if current_skill.is_directional else Vector2i.ZERO
		_flow_state = SkillFlowState.EXECUTE_SKILL
		_run_flow()
	else:
		print("SkillState: Invalid target position")

# 执行技能逻辑
func _execute_skill() -> void:
	var caster = battle.get_main_unit()
	if not caster:
		_flow_state = SkillFlowState.GET_SKILL_RANGE
		return
		
	# 播放施法动画
	var unit_direction = _to_unit_direction(_pending_direction)
	var target_animation = current_skill.animation_name.strip_edges()
	var has_animation = false
	
	# 尝试播放技能指定的动画
	if target_animation != "":
		has_animation = caster.play_animation_for_skill(target_animation, unit_direction)
	# 如果没有指定或播放失败，尝试播放默认动画
	if not has_animation:
		has_animation = caster.play_animation_for_skill("skill", unit_direction)
	# 等待动画播放完成
	if has_animation and caster.animated_sprite:
		await caster.animated_sprite.animation_finished
		caster.play_idle(unit_direction)
	
	# 执行技能效果
	await current_skill.execute(caster, _pending_target_pos, _pending_direction, battle)
	
	print("SkillState: Skill executed!")
	parent_fsm.parent_fsm.change_state("EndState")

# 解析目标位置（以自身为中心的技能强制目标为施法者位置）
func _resolve_target_pos(caster_pos: Vector2i, mouse_cell_pos: Vector2i) -> Vector2i:
	if current_skill.origin_type == BaseSkill.OriginType.SELF:
		return caster_pos
	return mouse_cell_pos

# 计算4方向（优先取差值大的轴）
func _calculate_direction(from_pos: Vector2i, to_pos: Vector2i) -> Vector2i:
	var diff = to_pos - from_pos
	if diff == Vector2i.ZERO:
		return Vector2i.ZERO
	if abs(diff.x) > abs(diff.y):
		return Vector2i(sign(diff.x), 0)
	return Vector2i(0, sign(diff.y))

# 将向量方向转换为 Unit.Direction 枚举
func _to_unit_direction(direction: Vector2i) -> Unit.Direction:
	var normalized = Vector2i(sign(direction.x), sign(direction.y))
	var main_unit = battle.get_main_unit()
	return Unit.DIR_MAP.get(normalized, main_unit._current_direction if main_unit else Unit.Direction.SE)
