extends Node2D
class_name Battle

const ICON_SKULL = preload("uid://5wwkhf6n6x0o")

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

@export var unit_positions_dict: Dictionary = {
	Unit.Faction.FRIENDLY: [Vector2i(0, 0), Vector2i(2, 1)],
	Unit.Faction.ENEMY: [Vector2i(4, -4), Vector2i(5, 6)]
}

# 活跃单位数组
var active_units: Array[Unit] = []
# 当前回合单位的索引 (持久化，防止 find 失败)
var current_unit_index: int = 0
# 当前选中的技能
var _current_skill: BaseSkill

@warning_ignore("unused_private_class_variable")
var _main_unit: Unit

@warning_ignore("unused_private_class_variable")
var _icon_skull: IconSkull

# 状态备份
var _backup_state: Dictionary = {}

func _ready() -> void:
	# 监听单位死亡信号
	GlobalSignal.unit_died.connect(_on_unit_died)
	
	# 初始化并启动状态机
	state_machine.initialize(self)
	await get_tree().process_frame
	state_machine._on_enter()

func _process(delta: float) -> void:
	state_machine._state_process(delta)

func _input(event: InputEvent) -> void:
	state_machine._state_input(event)

# 获取当前选中的技能
func get_current_skill() -> BaseSkill:
	return _current_skill

# 根据索引选中主控单位的技能
func select_main_unit_skill(skill_index: int) -> BaseSkill:
	if not _main_unit:
		return null
	
	# 确保 Unit 类有 get_skill 方法
	if not _main_unit.has_method("get_skill"):
		push_warning("Unit does not have get_skill method")
		return null
		
	var selected_skill = _main_unit.get_skill(skill_index)
	if selected_skill:
		_current_skill = selected_skill
		print("Battle: Selected skill: ", selected_skill.skill_name)
	return selected_skill

# 尝试从输入事件中选择技能
func try_select_main_unit_skill_from_event(event: InputEvent) -> BaseSkill:
	var skill_index = _extract_skill_index_from_event(event)
	if skill_index < 0:
		return null
	return select_main_unit_skill(skill_index)

# 从输入事件中提取技能索引 (0-8 对应 1-9 键)
func _extract_skill_index_from_event(event: InputEvent) -> int:
	if not (event is InputEventKey):
		return -1
	var key_event = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return -1
	
	match key_event.keycode:
		KEY_1, KEY_KP_1: return 0
		KEY_2, KEY_KP_2: return 1
		KEY_3, KEY_KP_3: return 2
		KEY_4, KEY_KP_4: return 3
		KEY_5, KEY_KP_5: return 4
		KEY_6, KEY_KP_6: return 5
		KEY_7, KEY_KP_7: return 6
		KEY_8, KEY_KP_8: return 7
		KEY_9, KEY_KP_9: return 8
		
	return -1

func _on_unit_died(unit: Unit) -> void:
	if unit in active_units:
		var died_index = active_units.find(unit)
		# 如果死亡单位在当前单位之前（或就是当前单位），索引需要前移
		if died_index != -1 and died_index <= current_unit_index:
			current_unit_index = max(0, current_unit_index - 1)
			
		active_units.erase(unit)
		print("Battle: Unit removed from active list. Remaining: ", active_units.size())

## 备份当前所有单位的状态
func backup_state() -> void:
	_backup_state.clear()
	
	# 备份活跃单位的位置和生命值
	for unit in active_units:
		var grid_pos = game_area.game_grid.get_unit_position(unit)
		_backup_state[unit] = {
			"grid_pos": grid_pos,
			"world_pos": unit.position,
			"hp": unit._current_hp,
			"direction": unit._current_direction,
			"faction": unit.faction,
			"color": unit.animated_sprite.modulate
		}
	print("Battle: State backed up.")

## 恢复状态
func reset_state() -> void:
	if _backup_state.is_empty():
		return
	# 隐藏其他
	range_selector.clear_all_ranges()
	path_painter.clear_all_paths()
	hide_skull()
	
	# 获取所有 key 的副本，以便在循环中修改字典
	var keys = _backup_state.keys()
	
	for unit_key in keys:
		var data = _backup_state[unit_key]
		var unit = unit_key
		var is_respawn = not is_instance_valid(unit)
		
		# 1. 如果单位失效，重新生成
		if is_respawn:
			print("Battle: Respawning unit from backup.")
			# 默认颜色为白色，如果备份中有颜色则使用
			var color = data.get("color", Color.WHITE)
			# 从备份中获取阵营，默认为 ENEMY
			var faction = data.get("faction", Unit.Faction.ENEMY)
			
			unit = unit_spawner.spawn_unit(data["world_pos"], faction, color)
			
			# 更新引用和列表
			active_units.append(unit)
			_backup_state.erase(unit_key)
			_backup_state[unit] = data
		else:
			# 如果单位还存在，可能正处于死亡动画中，需要取消死亡回调
			if unit.animated_sprite.animation_finished.is_connected(unit.queue_free):
				unit.animated_sprite.animation_finished.disconnect(unit.queue_free)
			# 停止当前动画，防止状态残留
			unit.animated_sprite.stop()
			# 确保单位在 active_units 中
			if unit not in active_units:
				active_units.append(unit)
		
		# 2. 统一恢复属性
		if data.has("faction"):
			unit.faction = data["faction"]
			
		unit._current_hp = data["hp"]
		unit._current_direction = data["direction"]
		unit.play_idle(data["direction"])
		unit.position = data["world_pos"]
		
		# 如果不是重新生成的（且颜色可能被改变），恢复颜色
		if not is_respawn and data.has("color"):
			unit.set_unit_color(data["color"])

		# 3. 恢复网格位置
		var target_grid_pos = data["grid_pos"]
		var current_grid_pos = game_area.game_grid.get_unit_position(unit)
		
		# 如果位置改变或者是新生成的单位（current_grid_pos 可能无效）
		if current_grid_pos != target_grid_pos:
			# 从旧位置移除（仅当旧位置确实有该单位时）
			if current_grid_pos != null and game_area.game_grid.grid_data.has(current_grid_pos):
				if game_area.game_grid.grid_data[current_grid_pos]["unit"] == unit:
					game_area.game_grid.grid_data[current_grid_pos]["unit"] = null
			
			# 添加到新位置
			if game_area.game_grid.grid_data.has(target_grid_pos):
				game_area.game_grid.grid_data[target_grid_pos]["unit"] = unit
		
	print("Battle: State reset.")
	
	state_machine.change_state("MainState")
	

## 在指定单位头顶显示骷髅图标
func show_skull_on_unit(unit: Unit) -> void:
	if not unit: return
	
	# 1. 确保图标实例存在
	if not _icon_skull:
		_icon_skull = ICON_SKULL.instantiate()
		add_child(_icon_skull)
	
	# 2. 隐藏并重置
	hide_skull()
	
	# 3. 设置位置 (单位位置 + 偏移)
	var target_pos = unit.position + Vector2(0, -16)
	_icon_skull.position = target_pos
	
	# 4. 根据阵营设置颜色
	var faction = unit.get_faction()
	var target_color = Color.GREEN if faction == Unit.Faction.FRIENDLY else Color.RED
	
	# 5. 显示并执行颜色缓动
	_icon_skull.show()
	_icon_skull.tween_color(target_color)

## 隐藏骷髅图标
func hide_skull() -> void:
	if _icon_skull:
		_icon_skull.hide()
		_icon_skull.modulate = Color.WHITE
