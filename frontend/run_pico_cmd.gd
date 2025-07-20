extends Node

enum ExecutionMode { PICO8, TELNETSSH }
@export var execution_mode: ExecutionMode = ExecutionMode.PICO8

var pico_pid = null

func _ready() -> void:
    var cmdline = ""
    match execution_mode:
        ExecutionMode.PICO8:
            cmdline = 'cd ' + PicoBootManager.APPDATA_FOLDER + '/package; LD_LIBRARY_PATH=. ./busybox ash start_pico_proot.sh >' + PicoBootManager.PUBLIC_FOLDER + '/logs/pico_out.txt 2>' + PicoBootManager.PUBLIC_FOLDER + "/logs/pico_err.txt"
        ExecutionMode.TELNETSSH:
            cmdline =  'cd ' + PicoBootManager.APPDATA_FOLDER + '/package; ln -s busybox ash; LD_LIBRARY_PATH=. ./busybox telnetd -l ./ash -F -p 2323'
    pico_pid = OS.create_process(
        PicoBootManager.BIN_PATH + "/sh",
        ["-c", cmdline]
    )
    print("executing as pid " + str(pico_pid) + "\n" + cmdline)
    
    if OS.is_debug_build() and execution_mode != ExecutionMode.TELNETSSH:
        OS.create_process(
            PicoBootManager.BIN_PATH + "/sh",
            ["-c", 'cd ' + PicoBootManager.APPDATA_FOLDER + '/package; ln -s busybox ash; LD_LIBRARY_PATH=. ./busybox telnetd -l ./ash -F -p 2323']
        )
    #iothread = Thread.new()
    #iothread.start(readio)

func _process(delta: float) -> void:
    if pico_pid and not OS.is_process_running(pico_pid):
        get_tree().quit()

#func _process(delta: float) -> void:
    #if proc.is_running() and Time.get_ticks_msec() > 2000:
        #print("gonna try and read")
        #var out: PackedByteArray = proc.read_stdout()
        ##print(out)
