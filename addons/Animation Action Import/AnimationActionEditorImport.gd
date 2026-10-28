@tool
extends EditorImportPlugin
class_name AnimationActionEditorImport


func _get_importer_name() -> String:
	return "import.animation_file"


func _get_visible_name() -> String:
	return "Animation clip"


func _get_recognized_extensions() -> PackedStringArray:
	return ["animt"]


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "Resource"


func _get_preset_count() -> int:
	return 1


func _get_preset_name(preset_index: int) -> String:
	return "Default"


func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	return [
		{"name": "skeleton_path_override", "default_value": false},
		{"name": "custom_skeleton_path", "default_value": ""},
		{"name": "optimize", "default_value": true},
		{"name": "allowed_velocity_err", "default_value": 0.01},
		{"name": "allowed_angular_err", "default_value": 0.01},
		{"name": "precision", "default_value": 3},
		{"name": "custom_file_folder", "default_value": "", "property_hint": PROPERTY_HINT_DIR},
	]


func convert_blender_matrix(arr: Array[float]) -> Transform3D:
	var proj = Projection(
		Vector4(arr[0], arr[4], arr[8],  arr[12]),
		Vector4(arr[1], arr[5], arr[9],  arr[13]),
		Vector4(arr[2], arr[6], arr[10], arr[14]),
		Vector4(arr[3], arr[7], arr[11], arr[15])
	) # Blender exported matrix 4x4
	
	return Transform3D(proj)


const ACTION = "ACTION"
const FLAG_POS = 1 << 0
const FLAG_ROT = 1 << 1
const FLAG_SC = 1 << 2


func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> Error:
	var filepath: = source_file.replace("." + source_file.get_extension(), ".") + _get_save_extension()
	
	# When custom path is enabled, move existing .res to custom folder
	var custom_path: = ""
	var orig_moved: bool = false
	if options["custom_file_folder"] != "":
		custom_path = options["custom_file_folder"] + "/" + source_file.get_file().replace("." + source_file.get_extension(), ".") + _get_save_extension()
		if FileAccess.file_exists(filepath):
			var dir = DirAccess.open(filepath.get_base_dir())
			var err = dir.rename(filepath, custom_path)
			if err == Error.OK:
				orig_moved = true
		filepath = custom_path
	
	gen_files = [filepath]
	
	# Read file
	
	var file: = ConfigFile.new()
	
	var state: = file.load(source_file)
	if state != Error.OK:
		return FAILED
	
	var animation: = Animation.new()
	
	# Keep custom tracks when reimporting, same behavior as in mesh file importing
	var anim_orig: Animation
	if FileAccess.file_exists(filepath):
		anim_orig = ResourceLoader.load(filepath)
		for i in anim_orig.get_track_count():
			if !anim_orig.track_is_imported(i):
				anim_orig.copy_track(i, animation)
		animation.loop_mode = anim_orig.loop_mode
	
	# General values
	var frame_length: float = file.get_value(ACTION, "frame_end", 10) - file.get_value(ACTION, "frame_start", 0)
	var fps: float = file.get_value(ACTION, "fps", 24)
	animation.length = frame_length / fps
	
	var armature_name: String = file.get_value(ACTION, "armature_name")
	
	var skeleton_path: String = armature_name + "/Skeleton3D"
	if options["skeleton_path_override"]:
		skeleton_path = options["custom_skeleton_path"]
	
	var bone_path: = skeleton_path + (":" if skeleton_path != "" else "")
	var key_path: = skeleton_path + ("/" if skeleton_path != "" else "")
	
	# Used for removing unchanged channels
	var clean: Dictionary = file.get_value(ACTION, "cleanup", {})
	
	# Bones
	var bone_data: Dictionary = file.get_value(ACTION, "bone_frames", {})
	for bone_name: String in bone_data.keys():
		var bone_frames: Dictionary = bone_data[bone_name]
		
		var pos_tr: = -1
		if !bool(clean.get(bone_name, 0) & FLAG_POS):  # Check if channel is marked for cleanup
			pos_tr = animation.add_track(Animation.TYPE_POSITION_3D)
			animation.track_set_path(pos_tr, bone_path + bone_name)
		var rot_tr: = -1
		if !bool(clean.get(bone_name, 0) & FLAG_ROT):
			rot_tr = animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(rot_tr, bone_path + bone_name)
		var sc_tr: = -1
		if !bool(clean.get(bone_name, 0) & FLAG_SC):
			sc_tr = animation.add_track(Animation.TYPE_SCALE_3D)
			animation.track_set_path(sc_tr, bone_path + bone_name)
		
		for frame: int in bone_frames:
			var values: PackedFloat32Array = bone_frames[frame]
			var transform: Transform3D = convert_blender_matrix(values)
			if pos_tr != -1: animation.position_track_insert_key(pos_tr, frame/fps, transform.origin)
			if rot_tr != -1: animation.rotation_track_insert_key(rot_tr, frame/fps, transform.basis.get_rotation_quaternion())
			if sc_tr != -1: animation.scale_track_insert_key(sc_tr, frame/fps, transform.basis.get_scale())
		
		if pos_tr != -1: animation.track_set_imported(pos_tr, true) # Needed for reimporting
		if rot_tr != -1: animation.track_set_imported(rot_tr, true)
		if sc_tr != -1: animation.track_set_imported(sc_tr, true)
		
	# Shape keys
	var key_data: Dictionary = file.get_value(ACTION, "shape_key_frames", {})
	for mesh_name: String in key_data.keys():
		for key_name: String in key_data[mesh_name].keys():
			var path: = key_path + mesh_name + ":" + key_name
			
			# When track already exists in imported file
			if animation.find_track(path, animation.TYPE_BLEND_SHAPE) != -1:
				continue
			
			var key_tr: = animation.add_track(animation.TYPE_BLEND_SHAPE)
			animation.track_set_path(key_tr, path)
			var key_frames: Dictionary = key_data[mesh_name][key_name]
			for frame: int in key_frames:
				animation.blend_shape_track_insert_key(key_tr, frame/fps, key_frames[frame])
			
			animation.track_set_imported(key_tr, true)
	
	# Finalize
	if options["optimize"]:
		animation.optimize(options["allowed_velocity_err"], options["allowed_angular_err"], options["precision"])
	
	# Save resource file
	if anim_orig:
		anim_orig.copy_from_resource(animation) # To update animation in editor
	
	var saved: = ResourceSaver.save(animation, filepath)
	# Save dummy file in .import folder, actual animation clip is in filepath
	ResourceSaver.save(Resource.new(), save_path + "." + _get_save_extension()) 
	if orig_moved: # When imported animation is moved to custom path
		EditorInterface.get_resource_filesystem().scan()
	
	return saved
