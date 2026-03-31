extends BaseSkill

func _apply_effect(caster: Unit, target: Unit, _target_pos: Vector2i, battle: Battle) -> void:
	battle.attack_processor.execute_heal(caster, target, power_multiplier)
