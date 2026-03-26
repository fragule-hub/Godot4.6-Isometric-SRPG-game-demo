extends Resource
class_name AllUnits

## 单位数据字典
## key: int (1, 2, 3...) 表示顺序
## value: Dictionary {"unit": Unit, "b_unit": BUnit}
@export var units_dict: Dictionary = {}

## 当前主要单位索引
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

## 转移到下一位单位
## 返回新的索引值，供 SwitchState 使用
func switch_to_next() -> int:
	if get_count() == 0:
		return current_unit_index
	current_unit_index = (current_unit_index + 1) % get_count()
	return current_unit_index

## 清空所有数据
func clear() -> void:
	units_dict.clear()
	current_unit_index = 0

## 添加单位（自动分配key）
func add_unit(unit: Unit, b_unit: BUnit) -> void:
	var key = units_dict.size() + 1
	units_dict[key] = {"unit": unit, "b_unit": b_unit}

## 设置指定索引的单位数据
func set_unit_at_index(index: int, unit: Unit, b_unit: BUnit) -> void:
	var key = index + 1
	units_dict[key] = {"unit": unit, "b_unit": b_unit}

## 获取所有单位数组（按顺序）
func get_all_units() -> Array[Unit]:
	var result: Array[Unit] = []
	for i in range(get_count()):
		var unit = get_unit_by_index(i)
		if unit:
			result.append(unit)
	return result

## 获取所有BUnit数组（按顺序）
func get_all_b_units() -> Array[BUnit]:
	var result: Array[BUnit] = []
	for i in range(get_count()):
		var b_unit = get_b_unit_by_index(i)
		if b_unit:
			result.append(b_unit)
	return result

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
