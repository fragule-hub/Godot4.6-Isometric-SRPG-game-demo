extends Node2D
class_name Battle

@onready var unit_spawner: UnitSpawner = $UnitSpawner
@onready var game_area: GameArea = $GameArea
@onready var grid_calculator: GridCalculator = $GridCalculator
@onready var path_painter: PathPainter = $PathPainter
@onready var unit_mover: UnitMover = $UnitMover
@onready var range_selector: RangeSelector = $RangeSelector
@onready var state_machine: BaseStateMachine = $BattleStateMachine
@onready var range_calculator: RangeCalculator = $RangeCalculator
@onready var attack_processor: AttackProcessor = $AttackProcessor
@onready var knockback_processor: KnockbackProcessor = $KnockbackProcessor

const TEST_UNIT = preload("uid://c62rato1itdis")
const TEST_UNIT_S_3 = preload("uid://bdw2nh8r5lkvx")
const TEST_UNIT_S_2 = preload("uid://cewttm4qdq3s8")

@export var unit_pos_dict: Dictionary = {
	Vector2i(0,0) : {"faction" : Unit.Faction.FRIENDLY, "unit_stat": TEST_UNIT},
	Vector2i(2,3) : {"faction" : Unit.Faction.ENEMY, "unit_stat": TEST_UNIT_S_2},
	Vector2i(3,2) : {"faction" : Unit.Faction.FRIENDLY, "unit_stat": TEST_UNIT_S_3},
	Vector2i(5,-4) : {"faction" : Unit.Faction.ENEMY, "unit_stat": TEST_UNIT},
}

var _all_units: AllUnits = AllUnits.new()

const ICON_SKULL = preload("uid://bcta0mlj355tv")
var _icon_skull: IconSkull
## 备份用all units
var _backup_all_units: AllUnits = null
# 正在死亡的单位数组（播放死亡动画中）
var dying_units: Array[Unit] = []

var _current_skill: BaseSkill

func _ready() -> void:
	GlobalSignal.unit_died.connect(_on_unit_died)
	state_machine.initialize(self)
	await get_tree().process_frame
	state_machine. _on_enter()

func _process(_delta: float) -> void:
	state_machine._state_process(_delta)

func _input(event: InputEvent) -> void:
	state_machine._state_input(event)

func _on_unit_died(unit: Unit) -> void:
	var active_units = _all_units.get_all_units()
	if unit in active_units:
		var dead_index = active_units.find(unit)
		_all_units.remove_unit_and_update_index(dead_index)
		dying_units.append(unit)
		unit.tree_exited.connect(_on_dying_unit_freed.bind(unit))
		print("Battle: Unit removed")
	
	var pos = game_area.game_grid.get_unit_position(unit)
	if pos != Vector2i(-999, -999):
		game_area.game_grid.remove_unit(pos)

## 死亡单位正式释放时从 dying_units 中移除
func _on_dying_unit_freed(unit: Unit) -> void:
	dying_units.erase(unit)

func get_current_skill() -> BaseSkill:
	return _current_skill

func select_skill(skill_index: int) -> BaseSkill:
	var unit = get_main_unit()
	if not unit:
		return null
	
	var selected_skill = unit.get_skill(skill_index)
	if selected_skill:
		_current_skill = selected_skill
		print("Battle: Selected skill: ", selected_skill.skill_name)
	return selected_skill

## 接收数字键，选择技能
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


func update_all_units_b_units() -> void:
	_all_units.update_b_units(func(unit: Unit) -> Vector2i:
		return game_area.game_grid.get_unit_position(unit)
	)

func backup_all_units() -> void:
	_backup_all_units = _all_units.deep_copy()

func request_reset() -> bool:
	if _backup_all_units == null:
		push_warning("Battle: No backup available for reset")
		return false
	state_machine.change_state("ResetState")
	return true

func clear_backup() -> void:
	_backup_all_units = null


func get_main_unit() -> Unit:
	return _all_units.get_main_unit()

func get_active_units() -> Array[Unit]:
	return _all_units.get_all_units()

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


func hide_skull() -> void:
	if _icon_skull:
		_icon_skull.hide()
		_icon_skull.modulate = Color.WHITE
