@tool
extends EditorPlugin


var plugin = AnimationActionEditorImport.new()


func _enter_tree() -> void:
	add_import_plugin(plugin)
	


func _exit_tree() -> void:
	remove_import_plugin(plugin)
