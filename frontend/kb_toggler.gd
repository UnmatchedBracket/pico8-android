extends Node2D
class_name KBMan

enum KBType { GAMING, FULL, COMPLIMENT }

@export var type: KBType = KBType.GAMING

static func get_correct():
    var gaming = (
        PicoVideoStreamer.instance.current_custom_data[0] & 0x2
        and not PicoVideoStreamer.instance.current_custom_data[0] & 0x4
    )
    var osk_open = DisplayServer.virtual_keyboard_get_height() > 1
    return (KBType.GAMING if gaming else (
        KBType.COMPLIMENT if osk_open else KBType.FULL
    ))

func _process(delta: float) -> void:
    var correct = get_correct()

    self.visible = (correct == type)
