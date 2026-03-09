extends BaseSkill
class_name HealingHowlSkill

func _apply_effect(caster: Unit, target: Unit, battle: Battle) -> void:
	if battle.attack_processor:
		battle.attack_processor.execute_heal(caster, target, power_multiplier)
		return
	target.heal(max(1, int(caster.get_atk() * power_multiplier)))
