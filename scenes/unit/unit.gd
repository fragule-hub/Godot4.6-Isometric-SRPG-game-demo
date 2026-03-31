extends Node2D
class_name Unit

## 东北、西北、东南、西南
enum Direction { NE, NW, SE, SW }
## 地图方向向量映射
const DIR_MAP = {
	Vector2i(0, -1): Direction.NE,
	Vector2i(-1, 0): Direction.NW,
	Vector2i(1, 0): Direction.SE,
	Vector2i(0, 1): Direction.SW
}
## 动画状态定义
const ANIM_STATE = {
	IDLE = "IDLE",
	RUN = "RUN",
	ATK = "ATK",
	DEATH = "DEATH",
	SKILL = "SKILL"
}
const DEFAULT_OFFSET := Vector2(0.0, -8.0)

enum Faction {ENEMY, FRIENDLY}
@export var faction: Faction = Faction.ENEMY

@export var unit_stat: UnitStat :
	get:
		return _unit_stat
	set(value):
		_unit_stat = value
		#_current_hp = value.get_max_hp()
		
var _unit_stat: UnitStat

@export var skills: Array[BaseSkill]

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

## 当前方向，默认为SE，东南
var _current_direction: Direction = Direction.SE
var _current_hp: int = 1

func _ready() -> void:
	play_animation(ANIM_STATE.IDLE)
	await get_tree().process_frame
	_current_hp = _unit_stat.get_max_hp()

## 播放指定状态动画
func play_animation(state: String, dir: Direction = _current_direction) -> void:
	_current_direction = dir
	var dir_name = Direction.keys()[dir]
	animated_sprite.animation = "%s_%s" % [dir_name, state]
	animated_sprite.play()

## 为技能播放动画，如果技能名找不到自动回退寻找SKILL
func play_animation_for_skill(state: String, dir: Direction = _current_direction) -> void:
	_current_direction = dir
	var dir_name = Direction.keys()[dir]
	
	var animation_key = "%s_%s" % [dir_name, state.to_upper()]
	if not animated_sprite.sprite_frames.has_animation(animation_key):
		animation_key = "%s_SKILL" % dir_name
		if not animated_sprite.sprite_frames.has_animation(animation_key):
			return
	
	animated_sprite.animation = animation_key
	animated_sprite.play()

func play_idle(dir: Direction = _current_direction) -> void:
	play_animation(ANIM_STATE.IDLE, dir)

func play_move(dir: Direction = _current_direction) -> void:
	play_animation(ANIM_STATE.RUN, dir)

func play_atk(dir: Direction = _current_direction) -> void:
	play_animation(ANIM_STATE.ATK, dir)

# 接收skill在数组中的索引
func get_skill(skill_index: int) -> BaseSkill:
	if skill_index < 0 or skill_index >= skills.size():
		return null
	return skills[skill_index]


## 受到伤害
func take_damage(amount: int) -> void:
	_current_hp -= amount
	GlobalSignal.show_damage_text.emit(position, amount)
	if _current_hp <= 0:
		die()

func heal(amount: int) -> void:
	if amount <= 0:
		return
	_current_hp = min(get_max_hp(), _current_hp + amount)
	GlobalSignal.show_heal_text.emit(position, amount)

func get_max_hp() -> int:
	return _unit_stat.get_max_hp()

func die() -> void:
	GlobalSignal.unit_died.emit(self)
	play_animation(ANIM_STATE.DEATH)
	if not animated_sprite.animation_finished.is_connected(queue_free):
		animated_sprite.animation_finished.connect(queue_free, CONNECT_ONE_SHOT)

func get_faction() -> Faction:
	return faction

func set_faction(value: Faction) -> void:
	faction = value
	_update_visual()

func _update_visual() -> void:
	if not is_inside_tree():
		return
	if faction == Faction.FRIENDLY:
		set_unit_color(Color(0.5, 1.0, 0.5))
	elif faction == Faction.ENEMY:
		set_unit_color(Color(1.0, 0.5, 0.5))

## 获取攻击
func get_atk() -> int:
	return _unit_stat.get_atk()

## 获取防御
func get_def() -> int:
	return _unit_stat.get_def()

## 获取攻击范围
func get_attack_range() -> int:
	return _unit_stat.get_atk_range()

func get_speed() -> int:
	return _unit_stat.get_speed()

## 获取单位的移动力上限
func get_move_points() -> int:
	return _unit_stat.get_move_point()

## 获取特定地形的移动消耗
## 如果 terrain 不在字典中或值为 -1，则表示不可通行
func get_move_cost(terrain: int) -> int:
	return _unit_stat.get_move_cost(terrain)

## 获取所有地形对应的消耗力字典
func get_move_cost_map() -> Dictionary:
	return _unit_stat.get_move_cost_map()

## 创建当前状态的 BUnit 快照
func create_b_unit(cell_pos: Vector2i) -> BUnit:
	var b_unit = BUnit.new()
	b_unit.set_data(unit_stat, get_faction(), cell_pos, _current_direction, _current_hp)
	return b_unit

## 从 BUnit 恢复数据
func restore_from_b_unit(b_unit: BUnit) -> void:
	unit_stat = b_unit.unit_stat
	set_faction(b_unit.faction)
	_current_hp = b_unit.current_hp
	_current_direction = b_unit.direction
	play_idle(b_unit.direction)


## 设置单位精灵的调色
func set_unit_color(color: Color) -> void:
	if animated_sprite:
		animated_sprite.modulate = color
