extends BaseState
class_name SkillState

## ==============================================================================
## 技能释放状态
## 处理玩家释放技能的交互流程：
## 1. 显示施法范围 (Cast Range)
## 2. 选择施法起点 (Select Origin) - 仅方向性技能且非SELF类型
## 3. 选择目标/方向 (Skill Preview)
## 4. 确认并执行技能 (Execute)
## ==============================================================================

## ------------------------------------------------------------------------------
## 导出配置
## ------------------------------------------------------------------------------

## 当前选中的技能
var current_skill: BaseSkill
## 缓存的施法范围网格坐标
var cast_range_cells: Array[Vector2i] = []

## ------------------------------------------------------------------------------
## 内部状态
## ------------------------------------------------------------------------------

## 技能释放流程状态枚举
enum SkillFlowState {
	GET_CAST_RANGE,   ## 阶段1：计算并显示施法范围
	SELECT_ORIGIN,    ## 阶段2：选择施法起点（方向性技能且非SELF类型）
	GET_SKILL_RANGE,  ## 阶段3：等待玩家选择目标，显示技能生效范围预览
	EXECUTE_SKILL     ## 阶段4：执行技能逻辑
}

var _flow_state: SkillFlowState = SkillFlowState.GET_CAST_RANGE

## 预览时的方向 (用于有方向性的技能)
var _preview_direction: Vector2i = Vector2i(1, 0)
## 待执行的目标位置（施法起点）
var _pending_target_pos: Vector2i = Vector2i.ZERO
## 待执行的技能方向
var _pending_direction: Vector2i = Vector2i.ZERO
## 选定的施法起点（用于方向性技能）
var _selected_origin_pos: Vector2i = Vector2i.ZERO

## 上一次鼠标所在的网格位置
var _last_mouse_cell_pos: Vector2i = Vector2i(-999, -999)

## ------------------------------------------------------------------------------
## 生命周期
## ------------------------------------------------------------------------------

func _on_enter() -> void:
	print("SkillState: Entered")
	
	current_skill = battle.get_current_skill()
	if not current_skill:
		push_warning("SkillState: No skill selected!")
		parent_fsm.change_state("AttackState")
		return
	
	_reset_state()
	_run_flow()
	print("SkillState: Showing cast range for ", current_skill.skill_name)

func _on_exit() -> void:
	_clear_visuals()
	_reset_state()

func _state_process(_delta: float) -> void:
	match _flow_state:
		SkillFlowState.SELECT_ORIGIN:
			_update_origin_preview()
		SkillFlowState.GET_SKILL_RANGE:
			_update_skill_preview()

func _state_input(event: InputEvent) -> void:
	# 允许在技能状态下切换其他技能
	if event is InputEventKey and event.pressed:
		var selected_skill = battle.try_select_skill(event)
		if selected_skill and selected_skill != current_skill:
			parent_fsm.change_state("SkillState")
			return
	
	if event.is_action_pressed("mouse_left"):
		_handle_mouse_left_click()
	elif event.is_action_pressed("mouse_right"):
		parent_fsm.change_state("AttackState")

## ------------------------------------------------------------------------------
## 状态管理
## ------------------------------------------------------------------------------

func _reset_state() -> void:
	_flow_state = SkillFlowState.GET_CAST_RANGE
	_preview_direction = Vector2i(1, 0)
	_pending_target_pos = Vector2i.ZERO
	_pending_direction = Vector2i.ZERO
	_selected_origin_pos = Vector2i.ZERO
	_last_mouse_cell_pos = Vector2i(-999, -999)
	cast_range_cells.clear()

func _clear_visuals() -> void:
	battle.range_selector.clear_all_ranges()

## ------------------------------------------------------------------------------
## 流程控制
## ------------------------------------------------------------------------------

func _run_flow() -> void:
	match _flow_state:
		SkillFlowState.GET_CAST_RANGE:
			_state_get_cast_range()
		SkillFlowState.SELECT_ORIGIN:
			_state_select_origin()
		SkillFlowState.GET_SKILL_RANGE:
			_state_get_skill_range()
		SkillFlowState.EXECUTE_SKILL:
			await _state_execute_skill()

## 阶段1：计算并显示施法范围
func _state_get_cast_range() -> void:
	var caster = battle.get_main_unit()
	if not caster:
		parent_fsm.change_state("AttackState")
		return
	
	cast_range_cells = current_skill.get_cast_range_cells(
		caster,
		battle.game_area.game_grid,
		battle.range_calculator
	)
	battle.range_selector.show_range(cast_range_cells, "skill_cast", Color(0.2, 0.4, 1.0, 0.5))
	
	# 判断是否需要选择施法起点
	if _needs_origin_selection():
		_flow_state = SkillFlowState.SELECT_ORIGIN
	else:
		_flow_state = SkillFlowState.GET_SKILL_RANGE
	
	_run_flow()

## 阶段2：选择施法起点
func _state_select_origin() -> void:
	_last_mouse_cell_pos = Vector2i(-999, -999)
	_update_origin_preview()
	print("SkillState: Waiting for origin selection")

## 阶段3：显示技能生效范围预览
func _state_get_skill_range() -> void:
	_last_mouse_cell_pos = Vector2i(-999, -999)
	_update_skill_preview()
	print("SkillState: Waiting for skill direction/target")

## 阶段4：执行技能
func _state_execute_skill() -> void:
	await _execute_skill()

## ------------------------------------------------------------------------------
## 判断逻辑
## ------------------------------------------------------------------------------

## 判断是否需要选择施法起点
## 条件：技能有方向性 且 施法范围类型不为 SELF
func _needs_origin_selection() -> bool:
	return current_skill.is_directional and current_skill.origin_type != BaseSkill.OriginType.SELF

## 判断位置是否在施法范围内
func _is_in_cast_range(pos: Vector2i) -> bool:
	return pos in cast_range_cells

## ------------------------------------------------------------------------------
## 输入处理
## ------------------------------------------------------------------------------

func _handle_mouse_left_click() -> void:
	match _flow_state:
		SkillFlowState.SELECT_ORIGIN:
			_try_select_origin()
		SkillFlowState.GET_SKILL_RANGE:
			_try_execute_skill()

## 尝试选择施法起点
func _try_select_origin() -> void:
	var mouse_pos = battle.get_global_mouse_position()
	var cell_pos = battle.game_area.get_tile_from_global(mouse_pos)
	
	if _is_in_cast_range(cell_pos):
		_selected_origin_pos = cell_pos
		_pending_target_pos = cell_pos
		_flow_state = SkillFlowState.GET_SKILL_RANGE
		battle.range_selector.clear_range("origin_preview")
		_run_flow()
		print("SkillState: Origin selected at ", _selected_origin_pos)
	else:
		print("SkillState: Invalid origin position")

## 尝试执行技能
func _try_execute_skill() -> void:
	var caster = battle.get_main_unit()
	if not caster:
		return
	
	var mouse_pos = battle.get_global_mouse_position()
	var cell_pos = battle.game_area.get_tile_from_global(mouse_pos)
	
	# 计算技能方向
	var direction_source = _get_direction_source(caster)
	var direction = _calculate_direction(direction_source, cell_pos)
	
	if direction != Vector2i.ZERO:
		_preview_direction = direction
	
	_pending_target_pos = _selected_origin_pos if _needs_origin_selection() else direction_source
	_pending_direction = _preview_direction if current_skill.is_directional else Vector2i.ZERO
	
	_flow_state = SkillFlowState.EXECUTE_SKILL
	_run_flow()

## 获取方向计算的源点
func _get_direction_source(caster: Unit) -> Vector2i:
	if _needs_origin_selection():
		return _selected_origin_pos
	return battle.game_area.game_grid.get_unit_position(caster)

## ------------------------------------------------------------------------------
## 预览更新
## ------------------------------------------------------------------------------

## 更新施法起点选择预览
func _update_origin_preview() -> void:
	var mouse_pos = battle.get_global_mouse_position()
	var cell_pos = battle.game_area.get_tile_from_global(mouse_pos)
	
	if cell_pos == _last_mouse_cell_pos:
		return
	_last_mouse_cell_pos = cell_pos
	
	# 高亮显示当前悬停的格子
	if _is_in_cast_range(cell_pos):
		battle.range_selector.show_range([cell_pos], "origin_preview", Color(0.4, 0.8, 1.0, 0.7))
	else:
		battle.range_selector.clear_range("origin_preview")

## 更新技能效果范围预览
func _update_skill_preview() -> void:
	if not current_skill:
		return
	
	var caster = battle.get_unit()
	if not caster:
		return
	
	var mouse_pos = battle.get_global_mouse_position()
	var cell_pos = battle.game_area.get_tile_from_global(mouse_pos)
	
	if cell_pos == _last_mouse_cell_pos:
		return
	_last_mouse_cell_pos = cell_pos
	
	var direction_source = _get_direction_source(caster)
	
	# 计算技能方向
	if current_skill.is_directional:
		var direction = _calculate_direction(direction_source, cell_pos)
		if direction != Vector2i.ZERO:
			_preview_direction = direction
	
	# 显示技能生效范围
	var target_pos = _selected_origin_pos if _needs_origin_selection() else direction_source
	var direction = _preview_direction if current_skill.is_directional else Vector2i.ZERO
	var area_cells = current_skill.get_skill_area_cells(
		target_pos,
		direction,
		battle.range_calculator
	)
	battle.range_selector.show_range(area_cells, "skill_preview", Color(1, 0.45, 0.35, 0.55))

## ------------------------------------------------------------------------------
## 技能执行
## ------------------------------------------------------------------------------

func _execute_skill() -> void:
	var caster = battle.get_unit()
	if not caster:
		_flow_state = SkillFlowState.GET_SKILL_RANGE
		return
	
	# 播放施法动画
	var unit_direction = _to_unit_direction(_pending_direction)
	var target_animation = current_skill.animation_name.strip_edges() if current_skill.animation_name else "skill"
	caster.play_animation_for_skill(target_animation, unit_direction)
	
	if caster.animated_sprite:
		await caster.animated_sprite.animation_finished
		caster.play_idle(unit_direction)
	
	# 执行技能效果
	current_skill.execute(caster, _pending_target_pos, _pending_direction, battle)
	
	print("SkillState: Skill executed!")
	parent_fsm.parent_fsm.change_state("EndState")

## ------------------------------------------------------------------------------
## 工具函数
## ------------------------------------------------------------------------------

## 计算4方向（优先取差值大的轴）
func _calculate_direction(from_pos: Vector2i, to_pos: Vector2i) -> Vector2i:
	var diff = to_pos - from_pos
	if diff == Vector2i.ZERO:
		return Vector2i.ZERO
	if abs(diff.x) > abs(diff.y):
		return Vector2i(sign(diff.x), 0)
	return Vector2i(0, sign(diff.y))

## 将向量方向转换为 Unit.Direction 枚举
func _to_unit_direction(direction: Vector2i) -> Unit.Direction:
	var normalized = Vector2i(sign(direction.x), sign(direction.y))
	var unit = battle.get_main_unit()
	return Unit.DIR_MAP.get(normalized, unit._current_direction if unit else Unit.Direction.SE)
