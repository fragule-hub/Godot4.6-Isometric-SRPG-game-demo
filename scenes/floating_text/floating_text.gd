extends Label
class_name FloatingText

const AWAIT_TIME := 0.5
const TWEEN_TIME := 0.5

# 物理模拟参数
var _velocity: Vector2 = Vector2.ZERO
var _gravity: float = 980.0 # 模拟重力加速度
var _active: bool = false

## 设置并播放浮动文字
## pos: 初始位置（中心点）
## text_content: 文本内容
## font_size: 字号，默认16
## color: 颜色，默认白色
func setup(pos: Vector2, text_content: String, font_size: int = 16, color: Color = Color.WHITE) -> void:
	# 1. 初始化属性
	hide()
	text = text_content
	add_theme_font_size_override("font_size", font_size)
	add_theme_color_override("font_color", color)
	
	# 确保 pivot 在中心，以便缩放效果正确
	pivot_offset = size / 2
	
	# 2. 设置位置
	position = pos - size / 2
	
	# 3. 计算随机初速度
	
	var angle_deg = randf_range(-60, 60) - 90 # 以 -90 (上) 为中心
	var angle_rad = deg_to_rad(angle_deg)
	
	# 初速度大小随机范围 (根据实际效果调整)
	var speed = randf_range(150, 250)
	
	_velocity = Vector2(cos(angle_rad), sin(angle_rad)) * speed
	
	# 4. 激活并显示
	show()
	_active = true
	
	# 5. 设置延迟 Tween
	get_tree().create_timer(AWAIT_TIME).timeout.connect(_start_vanish_tween)

func _process(delta: float) -> void:
	if not _active: return
	
	# 应用重力
	_velocity.y += _gravity * delta
	# 应用位移
	position += _velocity * delta

func _start_vanish_tween() -> void:
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 透明度缓动至 0
	tween.tween_property(self, "modulate:a", 0.0, TWEEN_TIME)
	# 缩放缓动至 0.5
	tween.tween_property(self, "scale", Vector2(0.5, 0.5), TWEEN_TIME)
	
	# 结束后销毁
	tween.chain().tween_callback(queue_free)
