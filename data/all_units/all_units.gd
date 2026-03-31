extends Resource
class_name AllUnits

## key: int (1, 2, 3...) 表示顺序
## value: Dictionary {"unit": Unit, "b_unit": BUnit}
@export var units_dict: Dictionary = {}
@export var current_unit_index: int = 0

## 获取单位总数
func get_count() -> int:
	return units_dict.size()

## 获取指定索引的单位
func get_unit_by_index(index: int) -> Unit:
	var key = index + 1
	if units_dict.has(key):
		return units_dict[key].get("unit", null)
	return null

## 获取指定索引的BUnit
func get_b_unit_by_index(index: int) -> BUnit:
	var key = index + 1
	if units_dict.has(key):
		return units_dict[key].get("b_unit", null)
	return null

## 获取当前主要单位
func get_main_unit() -> Unit:
	return get_unit_by_index(current_unit_index)

## 添加单位(key自动递增)
func add_unit(unit: Unit, b_unit: BUnit) -> void:
	var key = units_dict.size() + 1
	units_dict[key] = {"unit": unit, "b_unit": b_unit}

## 设置指定索引的单位数据
func set_unit_at_index(index: int, unit: Unit, b_unit: BUnit) -> void:
	var key = index + 1
	units_dict[key] = {"unit": unit, "b_unit": b_unit}

## 获取所有单位数组
func get_all_units() -> Array[Unit]:
	var result: Array[Unit] = []
	for i in range(get_count()):
		var unit = get_unit_by_index(i)
		if unit:
			result.append(unit)
	return result

## 返回新的索引值，供 SwitchState 使用
func switch_to_next() -> int:
	if get_count() == 0:
		return current_unit_index
	current_unit_index = (current_unit_index + 1) % get_count()
	return current_unit_index

func deep_copy() -> AllUnits:
	var copy = AllUnits.new()
	copy.units_dict = {}
	copy.current_unit_index = current_unit_index
	for key in units_dict.keys():
		var unit_data = units_dict[key]
		var unit = unit_data.get("unit", null)
		var b_unit = unit_data.get("b_unit", null)
		if b_unit:
			var b_unit_copy = BUnit.new()
			b_unit_copy.set_data(b_unit.unit_stat, b_unit.faction, b_unit.cell_pos, b_unit.direction, b_unit.current_hp)
			copy.units_dict[key] = {"unit": unit, "b_unit": b_unit_copy}
	return copy

func update_b_units(cell_pos_getter: Callable) -> void:
	for key in units_dict.keys():
		var unit_data = units_dict[key]
		var unit = unit_data.get("unit", null)
		if unit:
			var cell_pos = cell_pos_getter.call(unit)
			var new_b_unit = unit.create_b_unit(cell_pos)
			units_dict[key]["b_unit"] = new_b_unit

## 移除单位并更新当前索引
func remove_unit_and_update_index(died_index: int) -> void:
	var key = died_index + 1
	if units_dict.has(key):
		units_dict.erase(key)
		_rebuild_dict_order()
	if died_index <= current_unit_index:
		current_unit_index = max(0, current_unit_index - 1)

## 重建字典顺序（删除单位后调用）
func _rebuild_dict_order() -> void:
	var temp_units: Array = []
	for key in units_dict.keys():
		temp_units.append(units_dict[key])
	units_dict.clear()
	for i in range(temp_units.size()):
		units_dict[i + 1] = temp_units[i]
