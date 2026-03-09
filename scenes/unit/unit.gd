extends Node2D
class_name Unit

const DEFAULT_OFFSET := Vector2(0.0, -8.0)

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
	MOVE = "RUN",
	ATTACK = "ATK",
	DEATH = "DEATH"
}

enum Faction {ENEMY, FRIENDLY}
@export var faction: Faction = Faction.ENEMY
## 移动力上限
@export var move_point: int = 8
## 移动力地形消耗
@export var move_cost_map: Dictionary = {
	GameGrid.Terrain.LAND : 1,
	GameGrid.Terrain.GRASS : 1,
	GameGrid.Terrain.STONE : 1,
	GameGrid.Terrain.RIVER : -1,
}
@export var atk_range: int = 1
@export var atk: int = 10
@export var def: int = 1
@export var speed: int = 3
@export var max_hp: int = 9
var _current_hp: int = 1

@export var skills: Array[BaseSkill]
var _skill: BaseSkill

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
## 当前方向，默认为SE，东南
var _current_direction: Direction = Direction.SE

func _ready() -> void:
	_current_hp = max_hp

## 播放指定状态动画
func play_animation(state: String, dir: Direction = _current_direction) -> void:
	_current_direction = dir
	var dir_name = Direction.keys()[dir]
	animated_sprite.animation = "%s_%s" % [dir_name, state]
	animated_sprite.play()

func play_animation_for_skill(state: String, dir: Direction = _current_direction) -> bool:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return false
	_current_direction = dir
	var dir_name = Direction.keys()[dir]
	var animation_key = "%s_%s" % [dir_name, state.to_upper()]
	if not animated_sprite.sprite_frames.has_animation(animation_key):
		return false
	animated_sprite.animation = animation_key
	animated_sprite.play()
	return true

func play_idle(dir: Direction = _current_direction) -> void:
	play_animation(ANIM_STATE.IDLE, dir)

func play_move(dir: Direction = _current_direction) -> void:
	play_animation(ANIM_STATE.MOVE, dir)

func get_skill(skill_index: int) -> BaseSkill:
	if skill_index < 0 or skill_index >= skills.size():
		return null
	var selected_skill = skills[skill_index]
	if selected_skill:
		_skill = selected_skill
		return _skill
	return null

## 受到伤害
func take_damage(amount: int) -> void:
	_current_hp -= amount
	
	# 显示伤害数字
	GlobalSignal.show_damage_text.emit(position, amount)
	
	if _current_hp <= 0:
		die()

func heal(amount: int) -> void:
	if amount <= 0:
		return
	_current_hp = min(max_hp, _current_hp + amount)
	GlobalSignal.show_heal_text.emit(position, amount)

## 执行死亡逻辑
func die() -> void:
	
	# 1. 发送全局死亡信号，供 UnitGrid 等系统处理
	GlobalSignal.unit_died.emit(self)
	
	# 2. 播放死亡动画并自动释放
	play_animation(ANIM_STATE.DEATH)
	
	# 3. 确保动画结束后释放
	if not animated_sprite.animation_finished.is_connected(queue_free):
		animated_sprite.animation_finished.connect(queue_free, CONNECT_ONE_SHOT)


## 设置单位精灵的调色
func set_unit_color(color: Color) -> void:
	if animated_sprite:
		animated_sprite.modulate = color

## 获取攻击范围
func get_attack_range() -> int:
	return atk_range

## 获取攻击
func get_atk() -> int:
	return atk

## 获取防御
func get_def() -> int:
	return def

## 获取单位的移动力上限
func get_move_points() -> int:
	return move_point

## 获取阵营
func get_faction() -> Faction:
	return faction

## 获取特定地形的移动消耗
## 如果 terrain 不在字典中或值为 -1，则表示不可通行
func get_move_cost(terrain: int) -> int:
	if move_cost_map.has(terrain):
		return move_cost_map[terrain]
	return -1 # 默认不可通行

## 获取所有地形对应的消耗力字典
func get_move_cost_map() -> Dictionary:
	return move_cost_map
