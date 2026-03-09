extends Node
class_name AttackProcessor

## 攻击处理器
## 负责处理战斗中的伤害计算、攻击动画播放以及伤害/治疗的应用。

@export var game_area: GameArea

signal attack_finished(attacker: Unit, defender: Unit)

# --- 公共接口 ---

## 执行完整攻击流程（包含动画）
## @param attacker: 攻击方单位
## @param defender: 防守方单位
func execute_attack(attacker: Unit, defender: Unit) -> void:
	if not _validate_units(attacker, defender):
		attack_finished.emit(attacker, defender)
		return
	
	# 1. 计算伤害
	var damage = calculate_damage(attacker, defender)
	
	# 2. 播放攻击动画
	await _play_attack_animation(attacker, defender)
	
	# 3. 应用伤害
	apply_damage(defender, damage)
	print("Attack: %s damaged %s by %d points." % [attacker.name, defender.name, damage])
	
	# 4. 发送攻击结束信号
	attack_finished.emit(attacker, defender)

## 执行无动画伤害（基于攻击者属性）
## @param attacker: 攻击方
## @param defender: 防守方
## @param power_multiplier: 攻击倍率
## @return: 实际造成的伤害值
func execute_damage_no_animation(attacker: Unit, defender: Unit, power_multiplier: float = 1.0) -> int:
	if not _validate_units(attacker, defender):
		return 0
		
	var attack_power = calculate_unit_attack_power(attacker, power_multiplier)
	var damage = _calculate_damage_value(attack_power, defender.get_def())
	apply_damage(defender, damage)
	return damage

## 执行无动画伤害（基于固定攻击值，通常用于环境/碰撞伤害）
## 注意：此伤害仍会受防御力影响
## @param attacker: 攻击来源（可以为 null，视业务逻辑而定，但此处保留参数以兼容旧接口）
## @param defender: 受击方
## @param fixed_attack_value: 固定的攻击力数值
## @return: 实际造成的伤害值
func execute_damage_no_animation_by_world(defender: Unit, fixed_attack_value: int) -> int:
	if not defender:
		return 0
		
	var attack_value = max(0, fixed_attack_value)
	var damage = _calculate_damage_value(attack_value, defender.get_def())
	apply_damage(defender, damage)
	return damage

## 执行治疗
## @param caster: 施法者
## @param target: 目标
## @param power_multiplier: 治疗倍率（基于施法者攻击力）
## @return: 实际治疗量
func execute_heal(caster: Unit, target: Unit, power_multiplier: float = 1.0) -> int:
	if not _validate_units(caster, target):
		return 0
		
	var amount = calculate_unit_attack_power(caster, power_multiplier)
	target.heal(amount)
	return amount

# --- 计算逻辑 ---

## 计算两个单位之间的伤害（基于当前状态）
func calculate_damage(attacker: Unit, defender: Unit) -> int:
	if not attacker or not defender:
		return 0
	return _calculate_damage_value(attacker.get_atk(), defender.get_def())

## 计算单位的攻击力（应用倍率）
func calculate_unit_attack_power(source: Unit, power_multiplier: float = 1.0) -> int:
	if not source:
		return 0
	return max(1, int(source.get_atk() * power_multiplier))

## 核心伤害公式
## @param attack_power: 攻击力
## @param defense_power: 防御力
## @return: 最终伤害（至少为1）
func _calculate_damage_value(attack_power: int, defense_power: int) -> int:
	return max(1, attack_power - defense_power)

## 应用伤害到底层单位
func apply_damage(target: Unit, amount: int) -> void:
	if not target:
		return
	target.take_damage(max(0, amount))

# --- 内部辅助方法 ---

## 验证单位有效性
func _validate_units(unit_a: Unit, unit_b: Unit) -> bool:
	if not unit_a or not unit_b:
		push_warning("AttackProcessor: Invalid units.")
		return false
	return true

## 播放攻击动画
func _play_attack_animation(attacker: Unit, defender: Unit) -> void:
	# 计算攻击方向
	var dir = _get_attack_direction(attacker.position, defender.position)
	
	# 播放动画
	attacker.play_animation(Unit.ANIM_STATE.ATTACK, dir)
	
	# 等待动画结束
	if attacker.animated_sprite:
		await attacker.animated_sprite.animation_finished
	else:
		# 如果没有动画组件，简单的延时模拟
		await get_tree().create_timer(0.5).timeout
	
	# 恢复待机状态
	attacker.play_idle(dir)

## 根据位置计算攻击方向
func _get_attack_direction(from_pos: Vector2, to_pos: Vector2) -> Unit.Direction:
	var diff = to_pos - from_pos
	
	if diff.x >= 0:
		return Unit.Direction.SE if diff.y >= 0 else Unit.Direction.NE
	else:
		return Unit.Direction.SW if diff.y >= 0 else Unit.Direction.NW
