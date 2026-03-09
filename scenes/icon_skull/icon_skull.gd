extends Sprite2D
class_name IconSkull

var _tween: Tween

## 缓动到目标颜色
## target_color: 目标颜色
## duration: 持续时间（秒）
func tween_color(target_color: Color, duration: float = 0.3) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	
	_tween = create_tween()
	_tween.tween_property(self, "modulate", target_color, duration)
