extends Polygon2D
class_name HighlightArea

@onready var line: HighlighLine = $HighlightLine

func set_area_color(new_color: Color) -> void:
	self.color = new_color

func set_outline_color(new_color: Color) -> void:
	line.set_line_color(new_color)
