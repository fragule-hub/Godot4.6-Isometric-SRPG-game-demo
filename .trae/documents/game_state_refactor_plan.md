# 游戏状态重构计划

## 概述
将 Battle 中的状态备份和重置功能迁移到 GameReseter，并使用 BUnit 和 AllUnits 资源类来管理游戏状态。

## 一、数据结构设计

### 1. BUnit (data/battle_units/b_unit.gd) - 已存在，需确认
存储单个单位的快照信息：
- `unit_stat: UnitStat` - 单位属性
- `faction: Unit.Faction` - 阵营
- `cell_pos: Vector2i` - 网格位置
- `direction: Unit.Direction` - 朝向
- `current_hp: int` - 当前生命值

### 2. AllUnits (data/battle_units/all_units.gd) - 需完善
存储所有单位的状态快照，使用字典结构：

```gdscript
extends Resource
class_name AllUnits

## 单位数据字典
## key: int (1, 2, 3...) 表示顺序
## value: Dictionary {"unit": Unit, "b_unit": BUnit}
@export var units_dict: Dictionary = {}

## 当前主要单位索引 (0-based，对应字典key-1)
@export var current_unit_index: int = 0

## 获取单位总数
func get_count() -> int:
    return units_dict.size()

## 获取指定索引的单位
func get_unit_by_index(index: int) -> Unit:
    var key = index + 1  # 转换为1-based key
    if units_dict.has(key):
        return units_dict[key].get("unit", null)
    return null

## 获取指定索引的BUnit
func get_b_unit_by_index(index: int) -> BUnit:
    var key = index + 1
    if units_dict.has(key):
        return units_dict[key].get("b_unit", null)
    return null

## 获取当前主要单位
func get_main_unit() -> Unit:
    return get_unit_by_index(current_unit_index)

## 转移到下一位单位
## 返回新的索引值，供 SwitchState 使用
func switch_to_next() -> int:
    if get_count() == 0:
        return current_unit_index
    current_unit_index = (current_unit_index + 1) % get_count()
    return current_unit_index

## 清空所有数据
func clear() -> void:
    units_dict.clear()
    current_unit_index = 0

## 添加单位（自动分配key）
func add_unit(unit: Unit, b_unit: BUnit) -> void:
    var key = units_dict.size() + 1
    units_dict[key] = {"unit": unit, "b_unit": b_unit}

## 设置指定索引的单位数据
func set_unit_at_index(index: int, unit: Unit, b_unit: BUnit) -> void:
    var key = index + 1
    units_dict[key] = {"unit": unit, "b_unit": b_unit}

## 获取所有单位数组（按顺序）
func get_all_units() -> Array[Unit]:
    var result: Array[Unit] = []
    for i in range(get_count()):
        var unit = get_unit_by_index(i)
        if unit:
            result.append(unit)
    return result

## 获取所有BUnit数组（按顺序）
func get_all_b_units() -> Array[BUnit]:
    var result: Array[BUnit] = []
    for i in range(get_count()):
        var b_unit = get_b_unit_by_index(i)
        if b_unit:
            result.append(b_unit)
    return result
```

### 3. GameReseter (scripts/game_reseter.gd) - 需重构
管理两个状态存储：
- `game_state: AllUnits` - 游戏进度状态（持久化）
- `rollback_state: AllUnits` - 回溯状态（临时）

## 二、职责划分

### GameReseter 职责：
1. 创建和管理 BUnit/AllUnits 实例
2. 备份游戏状态 (backup_game_state)
3. 备份回溯状态 (backup_rollback_state)
4. 执行回溯重置 (reset_to_rollback_state)
5. 清空回溯状态 (clear_rollback_state)
6. 处理单位死亡后的索引更新 (update_on_unit_died)

### Battle 职责：
1. 维护 active_units 数组（从 AllUnits 同步）
2. 维护 _main_unit（通过索引从 AllUnits 获取）
3. 调用 GameReseter 的方法进行状态管理
4. 提供单位生成和销毁的接口

## 三、实现步骤

### 步骤 1: 完善 AllUnits 资源类
文件: `data/battle_units/all_units.gd`
- 使用字典存储单位数据，key 为 1-based 索引
- value 为包含 unit 和 b_unit 的字典
- 添加 switch_to_next() 函数返回新索引

### 步骤 2: 重构 GameReseter
文件: `scripts/game_reseter.gd`

需要添加：
- 引用依赖 (battle, unit_spawner, game_area, game_grid, range_selector, path_painter)
- `game_state: AllUnits` - 游戏进度状态
- `rollback_state: AllUnits` - 回溯状态
- `inactive_units: Array[Unit]` - 不活跃单位数组（回溯时使用）

主要方法：
1. `backup_game_state()` - 备份到 game_state
2. `backup_rollback_state()` - 备份到 rollback_state
3. `clear_rollback_state()` - 清空 rollback_state
4. `reset_to_rollback_state()` - 执行回溯
5. `update_on_unit_died(died_index: int)` - 更新死亡单位后的索引

### 步骤 3: 重构 Battle
文件: `scenes/battle/battle.gd`

移除：
- `_backup_state: Dictionary`

修改：
- `backup_state()` -> 调用 `game_reseter.backup_rollback_state()`
- `reset_state()` -> 调用 `game_reseter.reset_to_rollback_state()`
- `_on_unit_died()` -> 调用 `game_reseter.update_on_unit_died()`

新增：
- `backup_game_state()` -> 调用 `game_reseter.backup_game_state()`
- `switch_to_next_unit()` -> 调用 `game_reseter.switch_to_next_unit()` 并更新 _main_unit

### 步骤 4: 修改状态机调用点

#### InitState (scenes/battle_states/init_state.gd)
- 在 `_on_enter()` 末尾调用 `battle.backup_game_state()`

#### SwitchState (scenes/battle_states/switch_state.gd)
- 改为调用 `battle.switch_to_next_unit()` 获取新索引和更新 _main_unit
- 更新后调用 `battle.backup_game_state()`

#### MoveState (scenes/battle_states/main_state/move_state.gd)
- 保持调用 `battle.backup_state()` (现在是回溯备份)

#### EndState (scenes/battle_states/end_state.gd)
- 改为调用 `battle.game_reseter.clear_rollback_state()`

#### AttackState (scenes/battle_states/main_state/attack_state.gd)
- 保持调用 `battle.reset_state()` (现在是回溯重置)

## 四、回溯流程详细设计

### reset_to_rollback_state() 流程：
1. 检查 rollback_state 是否存在，不存在则返回
2. 清除视觉元素 (range_selector, path_painter, skull)
3. 将 active_units 中所有单位移到 inactive_units：
   - 隐藏单位
   - 停止动画
   - 清除死亡回调
   - 从网格移除
4. 遍历 rollback_state.units_dict：
   - 尝试从 inactive_units 中找到匹配的单位
   - 如果找到：重新设置属性，移回 active_units
   - 如果没找到：重新生成单位
5. 释放 inactive_units 中剩余的单位
6. 恢复 current_unit_index
7. 更新 _main_unit（通过索引从 AllUnits 获取）
8. 切换状态机到 MainState

## 五、SwitchState 重构流程

### 原流程：
```gdscript
var next_index = (battle.current_unit_index + 1) % battle.active_units.size()
battle.current_unit_index = next_index
battle._main_unit = battle.active_units[next_index]
```

### 新流程：
```gdscript
# 在 Battle 中
func switch_to_next_unit() -> int:
    var new_index = game_reseter.switch_to_next_unit()
    _main_unit = game_reseter.get_main_unit()
    return new_index

# 在 GameReseter 中
func switch_to_next_unit() -> int:
    return game_state.switch_to_next()

# 在 SwitchState 中
var new_index = battle.switch_to_next_unit()
battle.backup_game_state()
```

## 六、文件修改清单

| 文件 | 操作 | 说明 |
|------|------|------|
| data/battle_units/all_units.gd | 完善 | 字典结构，添加 switch_to_next 等方法 |
| scripts/game_reseter.gd | 重构 | 添加状态管理功能 |
| scenes/battle/battle.gd | 简化 | 移除 _backup_state，添加 switch_to_next_unit |
| scenes/battle_states/init_state.gd | 修改 | 添加 backup_game_state 调用 |
| scenes/battle_states/switch_state.gd | 修改 | 使用 switch_to_next_unit，添加 backup_game_state |
| scenes/battle_states/end_state.gd | 修改 | 改为调用 clear_rollback_state |

## 七、依赖关系

```
Battle
  ├── GameReseter
  │     ├── AllUnits (game_state)
  │     │     └── units_dict: {1: {unit, b_unit}, 2: {unit, b_unit}, ...}
  │     ├── AllUnits (rollback_state)
  │     └── BUnit[] (快照)
  ├── UnitSpawner
  ├── GameArea
  │     └── GameGrid
  └── RangeSelector, PathPainter, etc.
```

## 八、数据同步说明

- `Battle.active_units` 与 `AllUnits.units_dict` 保持同步
- `Battle.current_unit_index` 与 `AllUnits.current_unit_index` 保持同步
- `Battle._main_unit` 通过索引从 `AllUnits` 获取，不单独存储在 AllUnits 中
