extends Area2D

#var keyboard_open
func _ready() -> void:
    self.visible = DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD)

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
    if event is InputEventMouseButton:
        if event.button_index == 1 and event.pressed:
            if DisplayServer.virtual_keyboard_get_height():
                DisplayServer.virtual_keyboard_hide()
            else:
                DisplayServer.virtual_keyboard_show("                                     ")

func _notification(what: int) -> void:
    if what == NOTIFICATION_VISIBILITY_CHANGED:
        if KBMan.get_correct() == KBMan.KBType.GAMING:
            DisplayServer.virtual_keyboard_hide()
