extends BaseState

# 存储可攻击的格子
var _attackable_cells: Array[Vector2i] = []
var _is_attacking: bool = false

func _on_enter() -> void:
	#parent_fsm.parent_fsm.change_state("EndState")
	_is_attacking = false
	battle.show_skull_on_unit(battle.get_main_unit())
	
	var unit = battle._all_units.get_main_unit()
	var center_pos = battle.game_area.game_grid.get_unit_position(unit)
	var range_val = unit.get_attack_range()
	
	_attackable_cells = battle.range_calculator.get_range_cells(center_pos, range_val)
	battle.range_selector.show_range(_attackable_cells,\
	"attack_range", Color(1, 0, 0, 0.5))

func _on_exit() -> void:
	battle.range_selector.clear_all_ranges()

func _state_input(event: InputEvent) -> void:
	if _is_attacking: return
	
	if event.is_action_pressed("reset"):
		battle.request_reset()
		return
	
	if event is InputEventKey and event.pressed:
		var selected_skill = battle.try_select_skill(event)
		if selected_skill:
			parent_fsm.change_state("SkillState")
			return
	
	if event.is_action_pressed("mouse_left"):
		var current_tile = battle.game_area.get_hovered_tile()
		
		if _attackable_cells.has(current_tile):
			var cell_data = battle.game_area.game_grid.get_cell_data(current_tile)
			var target_unit = cell_data.get("unit")
			var attacker_unit = battle._all_units.get_main_unit()
			if target_unit and target_unit is Unit and target_unit != attacker_unit:
				battle.range_selector.clear_range("attack_range")
				_is_attacking = true
				await battle.attack_processor.execute_attack(attacker_unit, target_unit)
				_is_attacking = false
				#parent_fsm.parent_fsm.change_state("EndState")
	
	if event.is_action_pressed("mouse_right"):
		parent_fsm.parent_fsm.change_state("EndState")
