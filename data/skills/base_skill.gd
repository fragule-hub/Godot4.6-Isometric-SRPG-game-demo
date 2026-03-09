extends Resource
class_name BaseSkill

# ==============================================================================
# 基础技能资源类
# Base Skill Resource Class
# ==============================================================================
# 该类定义了技能的基本属性和行为。
# 所有具体的技能都应该继承自该类（或者直接使用该类并配置参数）。
# 包含了技能的施法范围、生效范围、目标筛选以及执行逻辑。
# ==============================================================================

@export_group("基础信息 (Base Info)")
## 技能名称
@export var skill_name: String = "未命名技能"
## 技能对应的动画名称 (在 Unit 动画状态机中使用)
@export var animation_name: String = ""
## 技能描述文本
@export_multiline var description: String = ""

## 技能释放起点的枚举类型
enum OriginType {
	SELF,       # 以自身为中心释放 (如：周围AOE，自身Buff)
	GLOBAL,     # 全图任意点 (如：全图打击)
	RANGE       # 基于施法距离的范围选择 (如：火球术，远程射击)
}

## 目标筛选策略枚举
enum TargetFilter {
	ALL,            # 所有单位 (无差别攻击/治疗)
	ENEMY_ONLY,     # 仅敌方单位
	FRIENDLY_ONLY,  # 仅友方单位
	SELF_ONLY       # 仅自身
}

@export_group("施法范围配置 (Casting Range)")
## 技能释放起点类型
@export var origin_type: OriginType = OriginType.RANGE
## 施法距离（仅当 origin_type == RANGE 时生效）
## 表示玩家可以选择的中心点距离施法者多远
@export var cast_range: int = 1
## 施法距离的计算方式 (曼哈顿距离/欧几里得距离等)
@export var cast_algorithm: RangeCalculator.DistanceAlgorithm = RangeCalculator.DistanceAlgorithm.MANHATTAN

@export_group("生效范围配置 (Effect Area)")
## 技能生效的覆盖半径/长度
## x: 长度或半径 (取决于形状)
## y: 宽度或角度 (取决于形状)
@export var area_range: Vector2i = Vector2i(0, 0)
## 覆盖范围的形状 (圆形/方形/菱形等)
@export var area_shape: RangeCalculator.ShapeType = RangeCalculator.ShapeType.CIRCLE
## 覆盖范围的扩散方式（仅当 Shape 为 CIRCLE/DIAMOND 等需要扩散算法时生效）
@export var area_algorithm: RangeCalculator.DistanceAlgorithm = RangeCalculator.DistanceAlgorithm.MANHATTAN
## 是否需要方向判定 (true: 技能有方向性，如锥形/直线; false: 无方向，如圆形AOE)
@export var is_directional: bool = false

@export_group("效果配置 (Effect Config)")
## 技能倍率（基于单位攻击力等属性的乘区）
@export var power_multiplier: float = 1.0
## 自身是否包含在目标内 (通常用于范围技能是否误伤/增益自己)
@export var include_self: bool = false
## 阵营筛选逻辑 (决定技能对谁生效)
@export var target_filter: TargetFilter = TargetFilter.ENEMY_ONLY


## 获取施法范围（玩家可选择的目标网格坐标）
## @param caster: 施法者单位
## @param game_grid: 游戏网格数据引用
## @param range_calculator: 范围计算工具引用
## @return: 返回所有有效的施法中心点坐标数组
func get_cast_range_cells(caster: Unit, game_grid: GameGrid, range_calculator: RangeCalculator) -> Array[Vector2i]:
	if not caster or not game_grid:
		return []

	var caster_pos: Vector2i = game_grid.get_unit_position(caster)
	
	match origin_type:
		OriginType.SELF:
			# 以自身为起点，施法位置只能是自己脚下
			return [caster_pos]
			
		OriginType.GLOBAL:
			# 全图模式，返回网格中所有有效的坐标 key
			# 假设 grid_data 的 key 为 Vector2i 类型的坐标
			var all_cells: Array[Vector2i] = []
			for pos in game_grid.grid_data.keys():
				if pos is Vector2i:
					all_cells.append(pos)
			return all_cells
			
		OriginType.RANGE:
			# 基于距离的施法范围
			if range_calculator:
				return range_calculator.get_range_cells(caster_pos, cast_range, cast_algorithm)
			return []
			
	return []

## 获取技能实际生效的覆盖范围（受击/受益区域）
## @param _caster: 施法者 (部分技能可能需要基于施法者位置计算，暂未用到)
## @param target_pos: 技能释放的目标中心点
## @param direction: 技能释放方向（仅当 is_directional 为 true 时有效）
## @param range_calculator: 范围计算工具
## @return: 返回所有受技能影响的网格坐标数组
func get_skill_area_cells(_caster: Unit, target_pos: Vector2i, direction: Vector2i, range_calculator: RangeCalculator) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	
	if not range_calculator:
		return result
		
	if is_directional:
		# 使用 RangeCalculator 的方向性范围算法 (如直线、锥形)
		result = range_calculator.get_directional_range_cells(target_pos, direction, area_range, area_shape)
	else:
		# 使用 RangeCalculator 的扩散性范围算法 (如圆形、方形)
		result = range_calculator.get_range_cells(target_pos, area_range.x, area_algorithm)
			
	return result

## 执行技能逻辑
## @param caster: 施法者
## @param target_pos: 目标中心点
## @param direction: 技能方向
## @param game_grid: 游戏网格
## @param range_calculator: 范围计算器
## @param attack_processor: 攻击处理器 (用于处理伤害/治疗结算)
func execute(caster: Unit, target_pos: Vector2i, direction: Vector2i, game_grid: GameGrid, range_calculator: RangeCalculator, attack_processor: AttackProcessor = null) -> void:
	# 1. 获取技能覆盖的所有网格
	var affected_cells: Array[Vector2i] = get_skill_area_cells(caster, target_pos, direction, range_calculator)
	
	# 2. 遍历网格，筛选有效目标并应用效果
	for cell in affected_cells:
		var cell_data: Dictionary = game_grid.get_cell_data(cell)
		# 检查格子上是否有单位
		var target_unit: Unit = cell_data.get("unit", null)
		
		# 验证目标是否符合筛选条件
		if target_unit and _is_valid_target(caster, target_unit):
			# 3. 应用具体效果 (伤害、治疗、Buff等)
			_apply_effect(caster, target_unit, attack_processor)

## 判断目标单位是否有效
## @param caster: 施法者
## @param target: 潜在目标
## @return: 是否为有效目标
func _is_valid_target(caster: Unit, target: Unit) -> bool:
	if not target or not caster:
		return false
		
	# 特殊处理：如果目标是自己，检查 include_self 开关
	# 注意：TargetFilter.SELF_ONLY 会在 match 中处理，这里主要处理 AOE 误伤/增益
	if target == caster:
		# 如果筛选器显式指定仅自身，则允许
		if target_filter == TargetFilter.SELF_ONLY:
			return true
		# 否则遵循 include_self 设置
		return include_self
	
	# 根据筛选器判断
	match target_filter:
		TargetFilter.ALL:
			return true
		TargetFilter.SELF_ONLY:
			return target == caster
		TargetFilter.ENEMY_ONLY:
			# 敌方判定：阵营不同
			return target.faction != caster.faction
		TargetFilter.FRIENDLY_ONLY:
			# 友方判定：阵营相同
			return target.faction == caster.faction
			
	return false

## 应用具体效果（虚函数，由子类重写）
## @param caster: 施法者
## @param target: 目标单位
## @param attack_processor: 攻击处理器
func _apply_effect(caster: Unit, target: Unit, attack_processor: AttackProcessor) -> void:
	# 默认实现：如果提供了 attack_processor，则造成基于倍率的伤害
	if attack_processor:
		# 调用攻击处理器的造成伤害方法
		# 注意：此处假设 AttackProcessor 有 execute_damage_no_animation 方法
		attack_processor.execute_damage_no_animation(caster, target, power_multiplier)
		return
	
	# 如果没有 attack_processor，尝试直接扣血 (作为后备逻辑)
	var damage = max(1, int(caster.get_atk() * power_multiplier))
	target.take_damage(damage)
