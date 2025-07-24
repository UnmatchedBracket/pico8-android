extends Node
class_name PicoBootManager

static var pico_zip_path: String = ""

const BIN_PATH = "/system/bin"
const APPDATA_FOLDER = "/data/data/io.wip.pico8/files"
const PUBLIC_FOLDER = "/sdcard/Documents/pico8"

func get_pico_zip() -> Variant:
    var public_folder = DirAccess.open(PUBLIC_FOLDER)
    if not public_folder:
        print("could not open public folder")
        return null
    var valid_pico_zips = Array(public_folder.get_files()).filter(
        func (name):
            return "pico-8" in name and "raspi.zip" in name
    )
    if valid_pico_zips:
        valid_pico_zips.sort()
        return PUBLIC_FOLDER + "/" + valid_pico_zips[-1]
    print("no valid zips")
    return null

var android_picker

func _ready() -> void:
    check()

const BOOTSTRAP_PACKAGE_VERSION = "1"

func setup():
    %SelectPicoZip.visible = false
    (%UnpackProgressContainer as Node2D).visible = true
    if (
        "android.permission.MANAGE_EXTERNAL_STORAGE" not in OS.get_granted_permissions()
        and FileAccess.file_exists("user://dont-ask-for-storage")
    ):
        %UnpackProgress.text += "warning: all files access is disabled"

    var tar_path = APPDATA_FOLDER + "/package.tar.gz"
    var tar_path_godot = "user://package.tar.gz"
    var pico_path = APPDATA_FOLDER + "/pico8.zip"
    var pico_path_godot = "user://pico8.zip"
    
    DirAccess.make_dir_recursive_absolute(PUBLIC_FOLDER + "/logs")
    DirAccess.make_dir_recursive_absolute(PUBLIC_FOLDER + "/data/carts/.placeholder")
    var public_folder = DirAccess.open(PUBLIC_FOLDER)
    
    var DEBUG = OS.is_debug_build()
    
    #step 1: untar package
    var need_to_untar = DEBUG
    if not DEBUG:
        var f = FileAccess.open("user://package/package_version", FileAccess.READ)
        if f:
            pass
            var data = f.get_as_text().strip_edges()
            if data != BOOTSTRAP_PACKAGE_VERSION:
                need_to_untar = true
        else:
            need_to_untar = true
    print("need to untar: ", need_to_untar)
    if need_to_untar:
        %UnpackProgress.text += "extracting bootstrap package..."
        if get_tree():
            await get_tree().process_frame
        print( # for now just gonna assume this works
            "tar copy: ",
            error_string(public_folder.copy("res://package.dat", tar_path_godot))
        )
        
        OS.execute(
            BIN_PATH + "/sh",
            ["-c", " ".join([
                BIN_PATH + "/tar",
                "-xzf", tar_path, "-C", APPDATA_FOLDER+"/",
                ">" + PUBLIC_FOLDER + "/logs/tar_out.txt",
                "2>" + PUBLIC_FOLDER + "/logs/tar_err.txt"
            ])]
        )

        %UnpackProgress.text += "done\n"
        if get_tree():
            await get_tree().process_frame
    
    var need_to_unzip = DEBUG
    if not DEBUG:
        if not FileAccess.file_exists("user://package/rootfs/home/pico/pico-8/pico8_64"):
            need_to_unzip = true
    print("need to unzip: ", need_to_unzip)
    if need_to_unzip:
        %UnpackProgress.text += "extracting pico-8 zip..."
        if get_tree():
            await get_tree().process_frame
        
        print(
            "pico zip copy: ",
            error_string(public_folder.copy(pico_zip_path, pico_path_godot))
        )
        OS.execute(
            BIN_PATH + "/sh",
            ["-c", " ".join([
                "cd", APPDATA_FOLDER + "/package;",
                BIN_PATH + "/sh",
                "unzip-pico.sh",
                ">" + PUBLIC_FOLDER + "/logs/zip_out.txt",
                "2>" + PUBLIC_FOLDER + "/logs/zip_err.txt"
            ])]
        )
        
        %UnpackProgress.text += "done\n"
        if get_tree():
            await get_tree().process_frame
    if %UnpackProgress.text == "":
        %UnpackProgress.text = "no setup needed"
        if get_tree():
            await get_tree().process_frame
    if (
        "android.permission.MANAGE_EXTERNAL_STORAGE" in OS.get_granted_permissions()
        or FileAccess.file_exists("user://dont-ask-for-storage")
    ):
        get_tree().change_scene_to_file("res://main.tscn")
    else:
        (%UnpackProgressContainer as Node2D).visible = false
        (%AllFileAccessContainer as Node2D).visible = true
        %GrantButton.pressed.connect(permission_grant)
        %DenyButton.pressed.connect(permission_deny)

var waiting_for_focus = false
func permission_grant():
    OS.request_permission("android.permission.MANAGE_EXTERNAL_STORAGE")
    waiting_for_focus = true

func _notification(what: int) -> void:
    if waiting_for_focus and what == NOTIFICATION_APPLICATION_FOCUS_IN:
        get_tree().change_scene_to_file("res://main.tscn")

func permission_deny():
    var f = FileAccess.open("user://dont-ask-for-storage", FileAccess.WRITE)
    f.close()
    await get_tree().process_frame
    get_tree().change_scene_to_file("res://main.tscn")

func check():
    var picozip = get_pico_zip()
    print("Pico zip: ", picozip)
    if picozip:
        pico_zip_path = picozip
        setup()
    else:
        %SelectPicoZip.visible = true
        %OpenPickerButton.pressed.connect(open_picker)
        %Label.text = "pico8 zip not found"
        
        
func open_picker():
    if Engine.has_singleton("GodotFilePicker"):
        android_picker = Engine.get_singleton("GodotFilePicker")
        android_picker.file_picked.connect(picker_callback)
        android_picker.openFilePicker("application/zip")
    else:
        %Label.text = "no singleton"
    #var filters = PackedStringArray(["*.zip;ZIP Files;application/zip"])
    #var current_directory = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
    #DisplayServer.file_dialog_show("title", current_directory, "filename", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, filters, picker_callback)

#func picker_callback(status: bool, selected_paths: PackedStringArray, selected_filter_index: int):
    #if status:
        #check_pico_zip(selected_paths[0])
    #else:
        #%Label.text = "nothing selected"

func picker_callback(path: String, mime: String):
    check_pico_zip(path)

const REQUIRED_FILES = ["pico-8/pico8_64", "pico-8/pico8.dat", "pico-8/readme_raspi.txt"]

func check_pico_zip(path: String):
    var zipname = path.split("/")[-1]
    var zipper = ZIPReader.new()
    var err = zipper.open(path)
    if err != OK:
        %Label.text = "error reading: " + error_string(err).to_lower()
        return
    var files = zipper.get_files()
    for f in REQUIRED_FILES:
        if f not in files:
            %Label.text = zipname + ": not a pico-8 raspberry pi file"
            return
    %Label.text = "yep that's a pico pi file"
    var diraccess = DirAccess.open("user://")
    var target_name = zipname
    if not ("pico-8" in zipname and "raspi.zip" in zipname):
        target_name = "pico-8_unknown_version_raspi.zip"
    OS.execute("/system/bin/mkdir", ["-p", PUBLIC_FOLDER])
    print(path, " -> ", PUBLIC_FOLDER + "/" + zipname)
    err = diraccess.copy(path, PUBLIC_FOLDER + "/" + zipname)
    if err != OK:
        %Label.text = "error copying: " + error_string(err).to_lower()
        return
    check()
