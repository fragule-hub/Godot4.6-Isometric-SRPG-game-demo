extends BaseState

var _attackable_cells: Array[Vector2i] = []
var _is_attacking: bool = false

func _on_enter() -> void:
	_is_attacking = false
	var unit = battle._main_unit
	if not unit:
		push_warning("AttackState: No main unit found!")
		return
	
	# 0. 显示骷髅图标 (重新定位并显示)
	battle.show_skull_on_unit(unit)
	
	# 1. 获取并显示攻击范围
	var center_pos = battle.game_area.game_grid.get_unit_position(unit)
	var range_val = unit.get_attack_range()
	
	_attackable_cells = battle.range_calculator.get_range_cells(center_pos, range_val)
	battle.range_selector.show_range(_attackable_cells, "attack_range", Color(1, 0, 0, 0.5))

func _on_exit() -> void:
	battle.range_selector.clear_range("attack_range")
	_attackable_cells.clear()
	_is_attacking = false

func _state_input(event: InputEvent) -> void:
	if _is_attacking: return

	# 尝试选择技能 (仅在键盘按键事件时触发，避免不必要的调用)
	if event is InputEventKey and event.pressed:
		var selected_skill = battle.try_select_main_unit_skill_from_event(event)
		if selected_skill:
			parent_fsm.change_state("SkillState")
			return
	
	if event.is_action_pressed("mouse_left"):
		var current_tile = battle.game_area.get_hovered_tile()
		# 1. 检查点击位置是否在攻击范围内
		if _attackable_cells.has(current_tile):
			# 2. 检查该位置是否有单位
			var cell_data = battle.game_area.game_grid.get_cell_data(current_tile)
			var target_unit = cell_data.get("unit")
			var attacker_unit = battle._main_unit
			if target_unit and target_unit is Unit and target_unit != attacker_unit:
				_perform_attack(attacker_unit, target_unit)
	
	if event.is_action_pressed("mouse_right"):
		parent_fsm.parent_fsm.change_state("EndState")
		
	# 重置功能
	if event.is_action_pressed("reset"):
		if not _is_attacking:
			battle.reset_state()


func _perform_attack(unit:Unit, target_unit: Unit) -> void:
	_is_attacking = true
	
	await battle.attack_processor.execute_attack(unit, target_unit)
	_is_attacking = false
	# 攻击完成后切换状态
	#parent_fsm.parent_fsm.change_state("EndState")
