# Skill State 重构计划

## 概述

将原本的 `SkillState` 拆分为 `scenes\battle_states\skill_state` 中的4个独立状态机以及 `SkillStateMachine`，通过状态机模式让整个技能释放流程更加清晰。

## 当前架构分析

### 现有的 SkillState (将被替代)

* 使用内部枚举 `SkillFlowState` 管理4个阶段

* 所有逻辑集中在一个文件中，通过 `_flow_state` 变量控制流程

* 状态转换通过 `_run_flow()` 方法实现

### 目标架构

```
MainState (BaseStateMachine)
└── SkillState (SkillStateMachine - 新的状态机)
    ├── GetCastRange (获取施法范围)
    ├── SelectOrigin (选择施法起点)
    ├── GetSkillRange (获取技能范围/方向)
    └── ExecuteSkill (执行技能)
```

## 状态流转图

```
                    ┌─────────────────┐
                    │   GetCastRange  │
                    │  (获取施法范围)  │
                    └────────┬────────┘
                             │
            ┌────────────────┼────────────────┐
            │                │                │
    ┌───────▼────────┐      │      ┌─────────▼────────┐
    │  有方向且非SELF │      │      │  无方向或为SELF  │
    │                │      │      │                  │
    └───────┬────────┘      │      └─────────┬────────┘
            │               │                │
            │               │                │
    ┌───────▼────────┐      │      ┌─────────▼────────┐
    │  SelectOrigin  │      │      │   GetSkillRange  │
    │ (选择施法起点)  │──────┘      │  (获取技能范围)   │
    └───────┬────────┘             └─────────┬────────┘
            │                                │
            └────────────────┬───────────────┘
                             │
                    ┌────────▼────────┐
                    │  GetSkillRange  │
                    │  (获取技能范围)  │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  ExecuteSkill   │
                    │   (执行技能)     │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │    EndState     │
                    └─────────────────┘
```

## 详细设计

### 1. SkillStateMachine (状态机管理器)

**文件**: `scenes/battle_states/main_state/skill_state_machine.gd`

**职责**:

* 管理技能释放的全局数据

* 协调4个子状态之间的流转

* 提供数据共享接口

**新增数据**:

```gdscript
var current_skill: BaseSkill          ## 当前选中的技能
var cast_range_cells: Array[Vector2i] ## 施法范围网格坐标
var origin_pos: Vector2i              ## 施法起点位置
var target_pos: Vector2i              ## 目标位置（鼠标位置）
var direction: Vector2i               ## 技能方向
var preview_direction: Vector2i       ## 预览方向
```

**方法**:

* `get_current_skill() -> BaseSkill`: 获取当前技能

* `set_origin_pos(pos: Vector2i)`: 设置施法起点

* `set_target_pos(pos: Vector2i)`: 设置目标位置

* `set_direction(dir: Vector2i)`: 设置技能方向

* `needs_origin_selection() -> bool`: 判断是否需要选择施法起点

***

### 2. GetCastRange (获取施法范围)

**文件**: `scenes/battle_states/skill_state/get_cast_range.gd`

**职责**:

* 计算并显示施法范围

* 决定下一步进入哪个状态

**流程**:

1. 获取当前技能
2. 调用 `skill.get_cast_range_cells()` 计算施法范围
3. 将施法范围存储到 `SkillStateMachine.cast_range_cells`
4. 显示施法范围高亮
5. 判断是否需要选择施法起点:

   * 如果 `skill.is_directional == true` 且 `skill.origin_type != SELF`:

     * 进入 `SelectOrigin`

   * 否则:

     * 设置施法起点:

       * 如果 `skill.origin_type == SELF`: 起点设为施法者位置

       * 否则: 起点设为施法者位置（后续由 GetSkillRange 根据鼠标更新）

     * 进入 `GetSkillRange`

***

### 3. SelectOrigin (选择施法起点)

**文件**: `scenes/battle_states/skill_state/select_origin.gd`

**职责**:

* 等待玩家选择施法起点

* 高亮显示悬停的格子

* 确认选择后流转到 GetSkillRange

**流程**:

1. 进入状态时清空之前的预览
2. 每帧更新：

   * 获取鼠标所在网格位置

   * 如果在施法范围内，高亮显示该格子

   * 否则清除高亮
3. 左键点击：

   * 如果点击位置在施法范围内:

     * 设置 `SkillStateMachine.origin_pos`

     * 流转到 `GetSkillRange`

   * 否则提示无效位置
4. 右键点击：返回 `AttackState`

***

### 4. GetSkillRange (获取技能范围)

**文件**: `scenes/battle_states/skill_state/get_skill_range.gd`

**职责**:

* 根据技能类型显示不同的预览

* 有方向技能：根据起点和鼠标位置计算方向

* 无方向技能：将鼠标位置作为施法起点

**流程**:

1. 进入状态时清空之前的预览
2. 每帧更新：

   * 获取鼠标所在网格位置

   * **如果技能有方向 (`is_directional == true`)**:

     * 根据施法起点和鼠标位置计算方向

     * 更新 `SkillStateMachine.direction`

   * **如果技能无方向**:

     * 将鼠标位置设为 `SkillStateMachine.target_pos`

   * 调用 `skill.get_skill_area_cells()` 获取技能生效范围

   * 显示技能范围预览
3. 左键点击：

   * 确认当前预览的方向/位置

   * 流转到 `ExecuteSkill`
4. 右键点击：返回 `AttackState`

**方向计算方法**:

```gdscript
func _calculate_direction(from_pos: Vector2i, to_pos: Vector2i) -> Vector2i:
    var diff = to_pos - from_pos
    if diff == Vector2i.ZERO:
        return Vector2i.ZERO
    if abs(diff.x) > abs(diff.y):
        return Vector2i(sign(diff.x), 0)
    return Vector2i(0, sign(diff.y))
```

***

### 5. ExecuteSkill (执行技能)

**文件**: `scenes/battle_states/skill_state/execute_skill.gd`

**职责**:

* 执行技能动画和效果

* 等待技能执行完成后流转到 EndState

**流程**:

1. 获取施法者、目标位置、方向
2. 播放施法动画:

   * 尝试播放 `skill.animation_name`

   * 如果失败，播放默认 "skill" 动画
3. 等待动画完成
4. 执行技能效果: `skill.execute(caster, target_pos, direction, battle)`
5. 流转到 `EndState`

***

## 数据流转图

```
┌─────────────────────────────────────────────────────────────────┐
│                     SkillStateMachine                           │
│  ┌──────────────┬──────────────┬──────────────┬──────────────┐  │
│  │current_skill │cast_range_   │  origin_pos  │  direction   │  │
│  │              │  cells       │              │              │  │
│  └──────────────┴──────────────┴──────────────┴──────────────┘  │
└─────────────────────────────────────────────────────────────────┘
         │              │              │              │
         ▼              ▼              ▼              ▼
┌─────────────────────────────────────────────────────────────────┐
│  GetCastRange ──> SelectOrigin ──> GetSkillRange ──> Execute   │
│     设置技能         设置起点        设置方向         执行技能   │
│     设置范围                                          流转结束  │
└─────────────────────────────────────────────────────────────────┘
```

## 状态转换条件总结

| 当前状态          | 条件        | 下一个状态         |
| ------------- | --------- | ------------- |
| GetCastRange  | 有方向且非SELF | SelectOrigin  |
| GetCastRange  | 无方向或为SELF | GetSkillRange |
| SelectOrigin  | 左键点击施法范围内 | GetSkillRange |
| SelectOrigin  | 右键点击      | AttackState   |
| GetSkillRange | 左键点击      | ExecuteSkill  |
| GetSkillRange | 右键点击      | AttackState   |
| ExecuteSkill  | 技能执行完成    | EndState      |

## 实现注意事项

1. **数据共享**: 所有子状态通过 `parent_fsm` 访问 `SkillStateMachine` 的数据
2. **视觉清理**: 每个状态在 `_on_exit()` 中清理自己的高亮效果
3. **技能切换**: 支持在技能状态下通过快捷键切换其他技能（重新进入 SkillState）
4. **边界处理**: 处理鼠标在窗口外、无效位置等边界情况

## 文件修改清单

### 需要修改的文件:

1. `scenes/battle_states/main_state/skill_state_machine.gd` - 添加数据管理
2. `scenes/battle_states/skill_state/get_cast_range.gd` - 实现获取施法范围
3. `scenes/battle_states/skill_state/select_origin.gd` - 实现选择施法起点
4. `scenes/battle_states/skill_state/get_skill_range.gd` - 实现获取技能范围
5. `scenes/battle_states/skill_state/execute_skill.gd` - 实现执行技能

### 不需要修改的文件:

* `scenes/battle/battle.tscn` - 场景树已经配置好

* `scenes/battle_states/main_state/skill_state.gd` - 保留但不再使用

## 验证清单

* [ ] GetCastRange 正确计算并显示施法范围

* [ ] 有方向且非SELF技能进入 SelectOrigin

* [ ] 无方向或为SELF技能跳过 SelectOrigin

* [ ] SelectOrigin 正确高亮悬停格子

* [ ] SelectOrigin 正确设置施法起点

* [ ] GetSkillRange 有方向技能正确计算方向

* [ ] GetSkillRange 无方向技能正确使用鼠标位置

* [ ] ExecuteSkill 正确播放动画并执行技能

* [ ] 技能执行完成后正确流转到 EndState

* [ ] 右键点击可以取消并返回 AttackState

