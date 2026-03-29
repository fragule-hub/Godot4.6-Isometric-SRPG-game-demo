extends BaseSkill
class_name KnockbackSkill

## 击退距离（格子数）
@export var knockback_distance: int = 3
## 击退动画每格时间
@export var knockback_per_cell_time: float = 0.1

func _apply_effect(_caster: Unit, target: Unit, target_pos: Vector2i, battle: Battle) -> void:
	if not battle:
		return
	var kb_processor = battle.knockback_processor
	if kb_processor and kb_processor.has_method("knockback_unit"):
		await kb_processor.knockback_unit(target_pos, target, knockback_distance, knockback_per_cell_time)
