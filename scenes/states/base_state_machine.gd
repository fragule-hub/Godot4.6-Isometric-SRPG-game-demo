extends BaseState
class_name BaseStateMachine

## 状态发生改变时发出信号
signal state_changed(from_state: BaseState, to_state: BaseState)

## 当前活跃的状态
var current_state: BaseState = null
## 所有子状态的映射表 {状态名: 状态节点}
var states: Dictionary = {}

## 默认初始状态名称，若为空则默认进入第一个子状态
@export var initial_state_name: StringName = &""

## 初始化状态机：注入依赖并递归初始化子状态
func initialize(battle_ref: Battle) -> void:
	battle = battle_ref
	
	states.clear()
	for child in get_children():
		if child is BaseState:
			states[child.name] = child
			child.parent_fsm = self
			
			# 如果子节点也是状态机，递归初始化
			if child is BaseStateMachine:
				child.initialize(battle_ref)
			else:
				child.battle = battle_ref

## 进入状态机：激活初始状态
func _on_enter() -> void:
	if not current_state:
		if initial_state_name and states.has(initial_state_name):
			change_state(initial_state_name)
		elif not states.is_empty():
			# 默认进入第一个注册的状态
			change_state(states.keys()[0])

## 退出状态机：清理当前子状态
func _on_exit() -> void:
	if current_state:
		current_state._on_exit()
		current_state = null

## 代理更新
func _state_process(delta: float) -> void:
	if current_state:
		current_state._state_process(delta)

## 代理输入
func _state_input(event: InputEvent) -> void:
	if current_state:
		current_state._state_input(event)

## 切换到指定名称的状态
func change_state(state_name: StringName) -> void:
	print(state_name)
	var new_state = states.get(state_name)
	if not new_state:
		push_error("State not found: " + str(state_name))
		return
		
	if current_state == new_state:
		print("state same.")
		#return
	
	var previous = current_state
	
	# 退出旧状态
	if current_state:
		current_state._on_exit()
	
	# 进入新状态
	current_state = new_state
	current_state._on_enter()
	
	state_changed.emit(previous, current_state)
