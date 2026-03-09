extends Node
class_name RangeCalculator

@export var game_area: GameArea

enum DistanceAlgorithm {
	MANHATTAN = 0,
	CHEBYSHEV = 1,
	EUCLIDEAN = 2
}

enum ShapeType {
	CIRCLE = 0,     # 圆形/菱形/方形 (基于 DistanceAlgorithm)
	LINE = 1,       # 直线
	CONE = 2,       # 扇形/锥形
	RECTANGLE = 3   # 矩形/柱形
}

## 获取以指定坐标为中心，指定范围内的所有坐标
## algorithm: 距离算法，
## 支持通过枚举或者直接传入int值
func get_range_cells(center_pos: Vector2i, range_val: int, algorithm: DistanceAlgorithm = DistanceAlgorithm.MANHATTAN) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	
	for x in range(-range_val, range_val + 1):
		for y in range(-range_val, range_val + 1):
			var dist: float = 0.0
			
			match algorithm:
				DistanceAlgorithm.MANHATTAN:
					dist = abs(x) + abs(y)
				DistanceAlgorithm.CHEBYSHEV:
					dist = max(abs(x), abs(y))
				DistanceAlgorithm.EUCLIDEAN:
					dist = sqrt(pow(x, 2) + pow(y, 2))
			
			if dist <= range_val:
				var cell = center_pos + Vector2i(x, y)
				result.append(cell)
				
	return result

## 获取有方向的技能范围
## start_pos: 起始位置
## direction: 方向向量，应为基本方向（如 (1,0), (0,1), (-1,0), (0,-1)），也可支持对角线，但形状会相应旋转
## range_size: 范围尺寸，x: 长度/半径，y: 宽度/角度（对于线忽略 y，矩形为半宽，锥形为每步宽度增量）
## shape: 形状类型
func get_directional_range_cells(start_pos: Vector2i, direction: Vector2i, range_size: Vector2i, shape: ShapeType) -> Array[Vector2i]:
	# 防止方向为零向量
	if direction == Vector2i.ZERO:
		push_error("Direction cannot be zero vector.")
		return []
	
	var length = range_size.x
	var width = range_size.y
	var result: Array[Vector2i] = []
	
	match shape:
		ShapeType.LINE:
			# 直线：沿方向延伸 length 格
			result.resize(length)
			var current = start_pos
			for i in length:
				result[i] = current
				current += direction
				
		ShapeType.RECTANGLE:
			# 矩形：沿方向延伸 length，两侧扩展 width（半宽），生成完整填充矩形
			var perp_dir = Vector2i(-direction.y, direction.x)  # 垂直方向
			var total_points = length * (2 * width + 1)
			result.resize(total_points)
			var idx = 0
			for i in range(length):
				var center = start_pos + direction * i
				result[idx] = center
				idx += 1
				for w in range(1, width + 1):
					result[idx] = center + perp_dir * w
					idx += 1
					result[idx] = center - perp_dir * w
					idx += 1
					
		ShapeType.CONE:
			# 锥形：沿方向延伸 length，每步宽度增加 width
			# 当 width=0 时退化为直线；width=1 为标准 90° 锥形（45° 半角）
			var perp_dir = Vector2i(-direction.y, direction.x)
			# 总点数 = length + 2 * width * (0+1+...+(length-1)) = length + width * length * (length-1)
			var total_points = length + width * length * (length - 1)
			result.resize(total_points)
			var idx = 0
			for i in range(length):
				var current_width = i * width
				var center = start_pos + direction * i
				result[idx] = center
				idx += 1
				for w in range(1, current_width + 1):
					result[idx] = center + perp_dir * w
					idx += 1
					result[idx] = center - perp_dir * w
					idx += 1
					
		ShapeType.CIRCLE:
			# 圆形：忽略方向，直接调用无方向范围（欧几里得距离）
			return get_range_cells(start_pos, length, DistanceAlgorithm.EUCLIDEAN)
	
	return result
