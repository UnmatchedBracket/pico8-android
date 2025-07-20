extends Sprite2D

func _process(delta: float) -> void:
    self.position.y = fmod(self.position.y + delta*4, 4)
