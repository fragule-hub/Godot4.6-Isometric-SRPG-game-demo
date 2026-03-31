extends BaseState

## 缓存的状态机引用
var _skill_state_machine: SkillStateMachine

## 上一次鼠标所在的网格位置
var _last_mouse_cell_pos: Vector2i = Vector2i(-999, -999)


func _on_enter() -> void:
	_skill_state_machine = parent_fsm as SkillStateMachine
	_last_mouse_cell_pos = Vector2i(-999, -999)

func _on_exit() -> void:
	battle.range_selector.clear_range("origin_preview")

func _state_process(_delta: float) -> void:
	
	var cell_pos = battle.game_area.get_hovered_tile()
	
	if cell_pos == _last_mouse_cell_pos:
		return
	_last_mouse_cell_pos = cell_pos
	
	if _skill_state_machine.is_in_cast_range(cell_pos):
		battle.range_selector.show_range([cell_pos], "origin_preview", Color(0.4, 0.8, 1.0, 0.7))
	else:
		battle.range_selector.clear_range("origin_preview")
	
func _state_input(event: InputEvent) -> void:
	
	if event.is_action_pressed("mouse_left"):
		var cell_pos = battle.game_area.get_hovered_tile()
		
		if _skill_state_machine.is_in_cast_range(cell_pos):
			# 设置施法起点
			_skill_state_machine.set_origin_pos(cell_pos)
			# 流转到GetSkillRange
			print("SelectOrigin: Origin selected at ", cell_pos)
			parent_fsm.change_state("GetSkillRange")
		else:
			print("SelectOrigin: Invalid origin position")
	
	if event is InputEventKey and event.pressed:
		var selected_skill = battle.try_select_skill(event)
		if selected_skill:
			parent_fsm.parent_fsm.change_state("SkillState")
			return
	
	elif event.is_action_pressed("mouse_right"):
		# 右键取消，返回AttackState
		parent_fsm.parent_fsm.change_state("AttackState")
	
	
	
