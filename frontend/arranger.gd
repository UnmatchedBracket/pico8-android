extends Node

@export var rect: Control
@export var center_y: bool = false
@export var kb_anchor: Node2D = null

func _process(delta: float) -> void:
    var screensize := DisplayServer.window_get_size()
    var maxScale: int = max(1, floor(min(
        screensize.x/rect.size.x, screensize.y/rect.size.y
    )))
    self.scale = Vector2(maxScale, maxScale)
    var extraSpace = Vector2(screensize) - (rect.size*maxScale)
    if DisplayServer.virtual_keyboard_get_height():
        extraSpace.y -= DisplayServer.virtual_keyboard_get_height()
        if KBMan.get_correct() == KBMan.KBType.COMPLIMENT:
            extraSpace.y = max(-92*maxScale, extraSpace.y)
        else:
            extraSpace.y = max(0, extraSpace.y)
    #yknow i like how this looks
    if kb_anchor != null:
        kb_anchor.position.y = (rect.size.y + extraSpace.y/maxScale - 18)
    if not center_y:
        extraSpace.y = 0
    self.position = Vector2i(Vector2(extraSpace.x/2, extraSpace.y/2) - rect.position*maxScale)
