extends Node

@export var rect: Control
@export var center_y: bool = false

func _process(delta: float) -> void:
    var screensize := DisplayServer.window_get_size()
    var maxScale: int = max(1, floor(min(
        screensize.x/rect.size.x, screensize.y/rect.size.y
    )))
    self.scale = Vector2(maxScale, maxScale)
    var extraSpace = Vector2(screensize) - (rect.size*maxScale)
    #if DisplayServer.virtual_keyboard_get_height():
        #extraSpace.y -= DisplayServer.virtual_keyboard_get_height()
        #extraSpace.y = max(0, extraSpace.y)
    #yknow i like how this looks
    if not center_y:
        extraSpace.y = 0
    self.position = Vector2i(Vector2(extraSpace.x/2, extraSpace.y/2) - rect.position*maxScale)
