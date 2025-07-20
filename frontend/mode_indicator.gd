extends CanvasItem

enum IndicatorSpecial {
    NONE, CONN, FPS
}

@export var flag: int = 0
@export var special: IndicatorSpecial = IndicatorSpecial.NONE
@export var color: Color = Color.CYAN
@export var text: String = "WH"

func _ready() -> void:
    %label.text = text

func _process(delta: float) -> void:
    match special:
        IndicatorSpecial.NONE:
            var on: bool = PicoVideoStreamer.instance.current_custom_data[0] & flag
            %light.modulate = color if on else Color.BLACK
        IndicatorSpecial.CONN:
            if PicoVideoStreamer.instance.tcp:
                match PicoVideoStreamer.instance.tcp.get_status():
                    StreamPeerTCP.STATUS_NONE:
                        %light.modulate = Color.BLACK
                    StreamPeerTCP.STATUS_CONNECTED:
                        %light.modulate = Color("#00e436")
                    StreamPeerTCP.STATUS_CONNECTING, StreamPeerTCP.STATUS_ERROR:
                        %light.modulate = Color("#ff2839")
            else:
                %light.modulate = Color("#ff2839")
        IndicatorSpecial.FPS:
            if Time.get_ticks_msec() < 2000:
                %light.modulate = color
            else:
                var fps = Engine.get_frames_per_second()
                if fps > 50:
                    %light.modulate = Color("#00e436")
                elif fps > 30:
                    %light.modulate = Color("#ffec27")
                else:
                    %light.modulate = Color("#ff2839")
