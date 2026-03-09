extends Node
class_name BaseState

## 父状态机引用
var parent_fsm: BaseStateMachine = null
## 战斗场景上下文引用
var battle: Battle

## 进入状态时触发
func _on_enter() -> void:
	pass

## 退出状态时触发
func _on_exit() -> void:
	pass

## 状态每帧更新
func _state_process(_delta: float) -> void:
	pass

## 状态处理输入事件
func _state_input(_event: InputEvent) -> void:
	pass
