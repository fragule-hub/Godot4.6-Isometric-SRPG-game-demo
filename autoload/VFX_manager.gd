extends Node

const FLOATING_TEXT = preload("uid://b0y6mess27jek")


func _ready() -> void:
	GlobalSignal.show_damage_text.connect(_on_show_damage_text)
	GlobalSignal.show_heal_text.connect(_on_show_heal_text)

func spawn_floating_text(pos: Vector2, text: String,\
color: Color = Color.WHITE, font_size: int = 16) -> void:
	var instance = FLOATING_TEXT.instantiate() as FloatingText
	add_child(instance)
	instance.setup(pos, text, font_size, color)
	
	
func _on_show_damage_text(pos: Vector2, damage: int) -> void:
	spawn_floating_text(pos, "-%d" % damage, Color.RED, 24)

func _on_show_heal_text(pos: Vector2, amount: int) -> void:
	spawn_floating_text(pos, "+%d" % amount, Color.GREEN, 24)
	
	
	
	
