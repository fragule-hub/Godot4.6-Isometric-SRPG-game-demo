extends Node
class_name RangeSelector

const HIGHLIGHT_AREA = preload("uid://b4u822m6rpnjh")

@export var game_area: GameArea

# 对象池：存储当前空闲的高亮节点
var _pool: Array[Node2D] = []
# 记录当前正在使用的高亮节点组映射 (Name -> Array[Node2D])
var _highlight_groups: Dictionary = {}

# 优先级配置 (值越大越在上层显示)
const PRIORITY_MAP = {
	"move_range": 0,
	"attack_range": 1,
	"skill_cast": 1,
	"skill_preview": 2,
	"default": 0
}

## 接收一个网格坐标数组，显示指定名称的高亮区域
func show_range(cells: Array[Vector2i], group_name: String = "default", color: Color = Color(1, 1, 1, 0.5)) -> void:
	# 1. 自动清除同名的高亮
	clear_range(group_name)
	
	if not game_area:
		push_warning("RangeSelector: game_area not assigned.")
		return
		
	# 初始化组
	var group: Array[Node2D] = []
	_highlight_groups[group_name] = group
		
	# 2. 生成新的高亮
	for cell_pos in cells:
		var highlight = _get_from_pool()
		# 将网格坐标转换为本地位置
		highlight.position = game_area.get_global_from_tile(cell_pos)
		# 设置颜色
		highlight.set_area_color(color)
		highlight.show()
		group.append(highlight)
	
	# 3. 重新排序所有高亮组
	_reorder_highlights()

func _reorder_highlights() -> void:
	# 获取所有活跃的组名
	var active_groups = _highlight_groups.keys()
	if active_groups.size() <= 1:
		return
	# 根据优先级排序 (从小到大)
	active_groups.sort_custom(func(a, b):
		var p_a = PRIORITY_MAP.get(a, 0)
		var p_b = PRIORITY_MAP.get(b, 0)
		return p_a < p_b
	)
	
	# 按照排序后的顺序，将节点移动到子节点列表的末尾（即最上层）
	for group_name in active_groups:
		var group = _highlight_groups[group_name]
		for highlight in group:
			move_child(highlight, -1)

## 检查指定名称（或任意）的高亮区域是否存在
func is_active(group_name: String = "") -> bool:
	if group_name != "":
		return _highlight_groups.has(group_name) and not _highlight_groups[group_name].is_empty()
	return not _highlight_groups.is_empty()

## 清除指定名称（或全部）的高亮区域并回收到池
func clear_range(group_name: String = "") -> void:
	if group_name == "":
		clear_all_ranges()
		return

	if _highlight_groups.has(group_name):
		var group = _highlight_groups[group_name]
		for highlight in group:
			highlight.hide()
			_pool.append(highlight)
		_highlight_groups.erase(group_name)

## 清除所有高亮组
func clear_all_ranges() -> void:
	for group in _highlight_groups.values():
		for highlight in group:
			highlight.hide()
			_pool.append(highlight)
	_highlight_groups.clear()

## 从池中获取一个节点，如果池为空则实例化新节点
func _get_from_pool() -> Node2D:
	var highlight: Node2D
	if _pool.size() > 0:
		highlight = _pool.pop_back()
	else:
		highlight = HIGHLIGHT_AREA.instantiate() as Node2D
		add_child(highlight)
	
	return highlight
