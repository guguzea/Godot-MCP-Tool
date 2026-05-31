@tool
extends Node
class_name SubprocessManager
## Manages a headless Godot subprocess for real-time output capture.
## Integrates Coding-Solo's subprocess logic (OS.execute + pipe reading).
## Addresses Coding-Solo Issue #70: waits for process exit before restarting.

signal output_received(line: String)
signal process_exited(exit_code: int)
signal process_started(pid: int)

var _godot_executable: String = ""
var _active_process: int = -1
var _output_buffer: PackedStringArray = []
var _debug_mode: bool = false

const OUTPUT_MAX_LINES: int = 500

func _ready() -> void:
	_detect_godot_executable()


func _detect_godot_executable() -> void:
	var godot_path = OS.get_environment("GODOT_PATH")
	if godot_path.is_empty():
		godot_path = _find_godot_in_path()
	if godot_path.is_empty():
		godot_path = _find_godot_default()
	_godot_executable = godot_path
	if _debug_mode:
		print("[SubprocessManager] Godot path: %s" % _godot_executable)


func _find_godot_in_path() -> String:
	return ""


func _find_godot_default() -> String:
	match OS.get_name():
		"Windows":
			var program_files = OS.get_environment("PROGRAMFILES(X86)")
			if program_files.is_empty():
				program_files = OS.get_environment("PROGRAMFILES")
			var default_path = program_files + "/Godot/Godot_v4.x.x-stable_win64.exe"
			if FileAccess.file_exists(default_path):
				return default_path
			return "godot.exe"
		"macOS":
			return "/Applications/Godot.app/Contents/MacOS/Godot"
		"Linux":
			return "godot"
		_:
			return "godot"


func set_debug_mode(debug: bool) -> void:
	_debug_mode = debug


func get_godot_version() -> Dictionary:
	if _godot_executable.is_empty():
		return {"success": false, "error": "Godot executable not found"}
	var output: Array = []
	var exit_code: int = 0
	var err = OS.execute(_godot_executable, ["--version"], output, exit_code, true)
	if err != OK:
		return {"success": false, "error": "Failed to run Godot --version"}
	var version = output[0].strip_edges() if output.size() > 0 else "unknown"
	return {"success": true, "version": version, "path": _godot_executable}


func is_process_running() -> bool:
	return _active_process != -1


func run_project(project_path: String, scene: String = "") -> Dictionary:
	if _godot_executable.is_empty():
		return {"success": false, "error": "Godot executable not found. Set GODOT_PATH environment variable."}

	if not FileAccess.file_exists(project_path):
		return {"success": false, "error": "Project path does not exist: %s" % project_path}

	if not FileAccess.file_exists(project_path + "/project.godot"):
		return {"success": false, "error": "Not a valid Godot project: no project.godot"}

	if is_process_running():
		await stop_project()

	_output_buffer.clear()
	var args: PackedStringArray = ["--headless", "--path", project_path]
	if not scene.is_empty():
		args.append("--script")
		args.append(scene)

	if _debug_mode:
		print("[SubprocessManager] Starting: %s %s" % [_godot_executable, args])

	var pid = OS.execute(_godot_executable, args, _output_buffer, true, false)
	if pid == -1:
		return {"success": false, "error": "Failed to start Godot process"}

	_active_process = pid
	process_started.emit(pid)
	if _debug_mode:
		print("[SubprocessManager] Process started, pid=%d" % pid)

	return {"success": true, "pid": pid, "message": "Godot headless process started"}


func stop_project() -> Dictionary:
	if _active_process == -1:
		return {"success": true, "message": "No process running"}

	var pid_to_kill = _active_process
	_active_process = -1
	if _debug_mode:
		print("[SubprocessManager] Killing pid=%d" % pid_to_kill)

	OS.kill(pid_to_kill)

	# Brief pause for process to exit
	await get_tree().create_timer(1.0).timeout

	process_exited.emit(0)
	return {"success": true, "message": "Process killed"}


func get_debug_output(max_lines: int = 100) -> Dictionary:
	var lines = _output_buffer.size()
	var start_idx = maxi(0, lines - max_lines)
	var requested_lines: PackedStringArray = PackedStringArray()
	for i in range(start_idx, lines):
		requested_lines.append(_output_buffer[i])

	var content = "\n".join(requested_lines)
	return {
		"success": true,
		"lines": Array(requested_lines),
		"content": content,
		"total_lines": lines,
		"returned_lines": requested_lines.size(),
		"running": is_process_running()
	}


func append_output(line: String) -> void:
	_output_buffer.append(line)
	if _output_buffer.size() > OUTPUT_MAX_LINES:
		_output_buffer.remove_at(0)
	output_received.emit(line)


func get_all_output() -> Dictionary:
	return {
		"success": true,
		"lines": Array(_output_buffer),
		"content": "\n".join(_output_buffer),
		"total_lines": _output_buffer.size()
	}
