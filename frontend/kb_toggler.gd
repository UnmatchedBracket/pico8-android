extends Node2D

@export var gaming: bool = false

func _process(delta: float) -> void:
    var gaming_now = (
        PicoVideoStreamer.instance.current_custom_data[0] & 0x2
        and not PicoVideoStreamer.instance.current_custom_data[0] & 0x4
    )
    self.visible = (gaming == gaming_now)
