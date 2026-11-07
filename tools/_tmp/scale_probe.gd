extends Node3D
func _ready() -> void:
	var av := PlayerAvatar.new()
	add_child(av)
	print("ANIMS ", av.anim.get_animation_list())
	get_tree().quit()
