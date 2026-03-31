extends BaseSkill
class_name KnockbackSkill

## 击退距离（格子数）
@export var knockback_distance: int = 3
## 击退动画每格时间
@export var knockback_per_cell_time: float = 0.1

signal all_effects_completed

var _pending_effect_count: int = 0

func _apply_effect(_caster: Unit, target: Unit, target_pos: Vector2i, battle: Battle) -> void:
	if not battle:
		return
	var kb_processor = battle.knockback_processor
	if kb_processor and kb_processor.has_method("knockback_unit"):
		await kb_processor.knockback_unit(target_pos, target, knockback_distance, knockback_per_cell_time)

func execute(caster: Unit, target_pos: Vector2i, direction: Vector2i, battle: Battle) -> void:
	if not battle:
		return
	
	var affected_cells: Array[Vector2i] = get_skill_area_cells(target_pos, direction, battle.range_calculator)
	_pending_effect_count = 0
	
	for cell in affected_cells:
		var cell_data: Dictionary = battle.game_area.game_grid.get_cell_data(cell)
		var target_unit: Unit = cell_data.get("unit", null)
		if target_unit and _is_valid_target(caster, target_unit):
			_pending_effect_count += 1
			call_deferred("_apply_effect_parallel", caster, target_unit, target_pos, battle)
	
	if _pending_effect_count > 0:
		await all_effects_completed

func _apply_effect_parallel(caster: Unit, target: Unit, target_pos: Vector2i, battle: Battle) -> void:
	await _apply_effect(caster, target, target_pos, battle)
	_pending_effect_count -= 1
	if _pending_effect_count == 0:
		all_effects_completed.emit()
