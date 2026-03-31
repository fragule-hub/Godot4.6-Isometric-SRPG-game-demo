extends Node
class_name AttackProcessor

signal attack_finished(attacker: Unit, defender: Unit)

@export var game_area: GameArea

## 执行攻击
func execute_attack(attacker: Unit, defender: Unit) -> void:
	var damage = calculate_damage(attacker, defender)
	await _play_attack_animation(attacker, defender)
	apply_damage(defender, damage)
	print("Attack: %s damaged %s by %d" % [attacker.name, defender.name, damage])
	attack_finished.emit(attacker, defender)

## 只有伤害无动画
func execute_damage(attacker: Unit, defender: Unit,\
power_multiplier: float = 1.0) -> int:
	
	var attack_power = calculate_unit_attack_power(attacker, power_multiplier)
	var damage = _calculate_damage_value(attack_power, defender.get_def())
	apply_damage(defender, damage)
	return damage

## 执行world伤害（无来源伤害）
func execute_world_damage(defender: Unit, fixed_attack_value: int) -> int:
	var attack_value = max(0, fixed_attack_value)
	var damage = _calculate_damage_value(attack_value, defender.get_def())
	apply_damage(defender, damage)
	return damage


func execute_heal(caster: Unit, target: Unit, power_multiplier: float = 1.0) -> int:
	var amount = calculate_unit_attack_power(caster, power_multiplier)
	target.heal(amount)
	return amount

func calculate_unit_attack_power(source: Unit, power_multiplier: float = 1.0) -> int:
	return max(1, int(source.get_atk() * power_multiplier))

## 计算单位之间的伤害值
func calculate_damage(attacker: Unit, defender: Unit) -> int:
	if not attacker or not defender:
		return 0
	return _calculate_damage_value(attacker.get_atk(), defender.get_def())

## 计算伤害值
func _calculate_damage_value(attack_power: int, defense_power: int) -> int:
	return max(1, attack_power - defense_power)

## 对单位应用伤害
func apply_damage(target: Unit, amount: int) -> void:
	if not target:
		return
	target.take_damage(max(0, amount))

## 播放攻击动画
func _play_attack_animation(attacker: Unit, defender: Unit) -> void:
	# 计算攻击方向
	var dir = _get_attack_direction(attacker.position, defender.position)
	
	# 播放动画
	attacker.play_atk(dir)
	
	# 等待动画结束
	if attacker.animated_sprite:
		await attacker.animated_sprite.animation_finished
	
	# 恢复待机状态
	attacker.play_idle(dir)
	
	#parent_fsm.parent_fsm.change_state("EndState")



## 根据位置计算攻击方向
func _get_attack_direction(from_pos: Vector2, to_pos: Vector2) -> Unit.Direction:
	var diff = to_pos - from_pos
	
	if diff.x >= 0:
		return Unit.Direction.SE if diff.y >= 0 else Unit.Direction.NE
	else:
		return Unit.Direction.SW if diff.y >= 0 else Unit.Direction.NW
