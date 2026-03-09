extends BaseSkill
class_name KnockbackSkill

## 击退距离（格子数）
@export var knockback_distance: int = 3
## 击退动画每格时间
@export var knockback_per_cell_time: float = 0.1

func _apply_effect(caster: Unit, target: Unit, battle: Battle) -> void:
	if not battle:
		return
	# 2. 执行击退
	var kb_processor = battle.knockback_processor
	if kb_processor and kb_processor.has_method("execute_knockback"):
		await kb_processor.execute_knockback(caster, target, knockback_distance, knockback_per_cell_time)
