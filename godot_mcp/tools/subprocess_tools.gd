@tool
extends "res://addons/godot_mcp/tools/base_tools.gd"
class_name SubprocessTools
## Subprocess management tools for Godot MCP.
## Provides headless Godot process control and real-time output capture.

var _subprocess_manager: SubprocessManager = null

func set_subprocess_manager(manager: SubprocessManager) -> void:
	_subprocess_manager = manager


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "run_project",
			"description": "Start a Godot project as a headless subprocess. The project runs without a window, capturing all output.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"project_path": {
						"type": "string",
						"description": "Path to the Godot project directory (must contain project.godot)"
					},
					"scene": {
						"type": "string",
						"description": "Optional: specific scene to run (relative to res://)"
					}
				},
				"required": ["project_path"]
			}
		},
		{
			"name": "stop_project",
			"description": "Stop the running headless Godot subprocess.",
			"inputSchema": {"type": "object", "properties": {}}
		},
		{
			"name": "get_debug_output",
			"description": "Read recent output from the headless subprocess. Returns stdout/stderr lines.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"max_lines": {
						"type": "integer",
						"description": "Maximum number of lines to return (default: 100)",
						"default": 100
					}
				}
			}
		},
		{
			"name": "get_godot_version",
			"description": "Detect the installed Godot version and executable path.",
			"inputSchema": {"type": "object", "properties": {}}
		},
		{
			"name": "is_process_running",
			"description": "Check if the headless Godot subprocess is currently running.",
			"inputSchema": {"type": "object", "properties": {}}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"run_project": return await _run_project(args)
		"stop_project": return await _stop_project(args)
		"get_debug_output": return _get_debug_output(args)
		"get_godot_version": return _get_godot_version(args)
		"is_process_running": return _is_process_running(args)
		_: return _error("Unknown tool: {}" .format([tool_name]))


func _check_subprocess_manager() -> Dictionary:
	if _subprocess_manager == null:
		return _error("SubprocessManager not initialized. Ensure the plugin started correctly.")
	return {"ok": true}


func _normalize_to_filesystem_path(path: String) -> String:
	# "res://..." path -> actual filesystem path
	if path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	# already absolute filesystem path -> return as-is
	if path.begins_with("/") or (path.length() >= 2 and path[1] == ":"):
		return path
	# relative path -> resolve from project root
	return ProjectSettings.globalize_path("res://") + path


func _run_project(args: Dictionary) -> Dictionary:
	var check = _check_subprocess_manager()
	if check.get("ok") != true:
		return check

	var project_path: String = str(args.get("project_path", "")).strip_edges()
	if project_path.is_empty():
		return _error("Missing 'project_path' parameter")

	project_path = _normalize_to_filesystem_path(project_path)

	var scene: String = str(args.get("scene", ""))
	var result = await _subprocess_manager.run_project(project_path, scene)
	return _success(result)


func _stop_project(_args: Dictionary) -> Dictionary:
	var check = _check_subprocess_manager()
	if check.get("ok") != true:
		return check
	var result = await _subprocess_manager.stop_project()
	return _success(result)


func _get_debug_output(args: Dictionary) -> Dictionary:
	var check = _check_subprocess_manager()
	if check.get("ok") != true:
		return check

	var max_lines: int = int(args.get("max_lines", 100))
	return _success(_subprocess_manager.get_debug_output(max_lines))


func _get_godot_version(_args: Dictionary) -> Dictionary:
	var check = _check_subprocess_manager()
	if check.get("ok") != true:
		return check
	return _success(_subprocess_manager.get_godot_version())


func _is_process_running(_args: Dictionary) -> Dictionary:
	var check = _check_subprocess_manager()
	if check.get("ok") != true:
		return check

	return {
		"success": true,
		"running": _subprocess_manager.is_process_running()
	}
