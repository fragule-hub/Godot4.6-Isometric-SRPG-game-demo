extends Node2D
class_name Battle

const ICON_SKULL = preload("uid://5wwkhf6n6x0o")
const TEST_UNIT = preload("uid://d06rf1yd48h6c")

@onready var game_area: GameArea = $GameArea
@onready var state_machine: BaseStateMachine = $BattleStateMachine
# 工具
@onready var unit_spawner: UnitSpawner = $UnitSpawner
@onready var grid_calculator: GridCalculator = $GridCalculator
@onready var range_selector: RangeSelector = $RangeSelector
@onready var unit_mover: UnitMover = $UnitMover
@onready var path_painter: PathPainter = $PathPainter
@onready var range_calculator: RangeCalculator = $RangeCalculator
@onready var attack_processor: AttackProcessor = $AttackProcessor
@onready var knockback_processor: KnockbackProcessor = $KnockbackProcessor
@onready var game_reseter: GameReseter = $GameReseter

@export var unit_positions_dict: Dictionary = {
	Vector2i(0, 0): {"faction": Unit.Faction.FRIENDLY, "unit_stat": TEST_UNIT},
	Vector2i(2, 1): {"faction": Unit.Faction.FRIENDLY, "unit_stat": TEST_UNIT},
	Vector2i(4, -4): {"faction": Unit.Faction.ENEMY, "unit_stat": TEST_UNIT},
	Vector2i(5, 6): {"faction": Unit.Faction.ENEMY, "unit_stat": TEST_UNIT}
}

# 活跃单位数组
var active_units: Array[Unit] = []
# 正在死亡的单位数组（播放死亡动画中）
var dying_units: Array[Unit] = []
# 所有单位状态管理
var all_units: AllUnits
# 当前选中的技能
var _current_skill: BaseSkill

@warning_ignore("unused_private_class_variable")
var _icon_skull: IconSkull

func _ready() -> void:
	all_units = AllUnits.new()
	GlobalSignal.unit_died.connect(_on_unit_died)
	
	state_machine.initialize(self)
	await get_tree().process_frame
	state_machine._on_enter()

func _process(delta: float) -> void:
	state_machine._state_process(delta)

func _input(event: InputEvent) -> void:
	state_machine._state_input(event)

func get_current_skill() -> BaseSkill:
	return _current_skill

func get_main_unit() -> Unit:
	return all_units.get_main_unit()

func get_current_unit_index() -> int:
	return all_units.current_unit_index

func select_skill(skill_index: int) -> BaseSkill:
	var unit = get_main_unit()
	if not unit:
		return null
	
	if not unit.has_method("get_skill"):
		push_warning("Unit does not have get_skill method")
		return null
		
	var selected_skill = unit.get_skill(skill_index)
	if selected_skill:
		_current_skill = selected_skill
		print("Battle: Selected skill: ", selected_skill.skill_name)
	return selected_skill

func try_select_skill(event: InputEvent) -> BaseSkill:
	if not (event is InputEventKey):
		return null
	var key_event = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return null
	
	var skill_index: int
	match key_event.keycode:
		KEY_1, KEY_KP_1: skill_index = 0
		KEY_2, KEY_KP_2: skill_index = 1
		KEY_3, KEY_KP_3: skill_index = 2
		KEY_4, KEY_KP_4: skill_index = 3
		KEY_5, KEY_KP_5: skill_index = 4
		KEY_6, KEY_KP_6: skill_index = 5
		KEY_7, KEY_KP_7: skill_index = 6
		KEY_8, KEY_KP_8: skill_index = 7
		KEY_9, KEY_KP_9: skill_index = 8
		_: return null
	
	return select_skill(skill_index)

func _on_unit_died(unit: Unit) -> void:
	if unit in active_units:
		var died_index = active_units.find(unit)
		active_units.erase(unit)
		all_units.remove_unit_and_update_index(died_index)
		dying_units.append(unit)
		unit.tree_exited.connect(_on_dying_unit_freed.bind(unit))
		print("Battle: Unit moved to dying list. Active: ", active_units.size(), ", Dying: ", dying_units.size())

## 死亡单位正式释放时从 dying_units 中移除
func _on_dying_unit_freed(unit: Unit) -> void:
	dying_units.erase(unit)
	print("Battle: Dying unit freed. Dying: ", dying_units.size())

## 备份游戏状态（更新 all_units 中的 b_unit 快照）
func backup_game_state() -> void:
	for i in range(all_units.get_count()):
		var unit = all_units.get_unit_by_index(i)
		if unit:
			var cell_pos = game_area.game_grid.get_unit_position(unit)
			var b_unit = unit.create_b_unit(cell_pos)
			all_units.units_dict[i + 1]["b_unit"] = b_unit
	print("Battle: Game state backed up.")

## 备份回溯状态（临时）
func backup_state() -> void:
	game_reseter.backup_rollback_state(all_units)

## 执行回溯重置
func reset_state() -> void:
	range_selector.clear_all_ranges()
	path_painter.clear_all_paths()
	hide_skull()
	
	active_units = game_reseter.reset_to_rollback_state(unit_spawner, active_units, dying_units, all_units)
	dying_units.clear()
	
	print("Battle: State reset.")
	state_machine.change_state("MainState")

## 切换到下一个单位
func switch_to_next_unit() -> int:
	return all_units.switch_to_next()

## 在指定单位头顶显示骷髅图标
func show_skull_on_unit(unit: Unit) -> void:
	if not unit: return
	
	if not _icon_skull:
		_icon_skull = ICON_SKULL.instantiate()
		add_child(_icon_skull)
	
	hide_skull()
	
	var target_pos = unit.position + Vector2(0, -16)
	_icon_skull.position = target_pos
	
	var faction = unit.get_faction()
	var target_color = Color.GREEN if faction == Unit.Faction.FRIENDLY else Color.RED
	
	_icon_skull.show()
	_icon_skull.tween_color(target_color)

## 隐藏骷髅图标
func hide_skull() -> void:
	if _icon_skull:
		_icon_skull.hide()
		_icon_skull.modulate = Color.WHITE

## 清空回溯状态
func clear_rollback_state() -> void:
	game_reseter.clear_rollback_state()
