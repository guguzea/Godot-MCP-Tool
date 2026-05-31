@tool
extends Node
class_name ToolExecutor

## Unified Tool Executor for Godot MCP
## Supports BOTH:
## 1. tomyud1 direct-method tools (via _tool_map routing)
## 2. DaxianLee get_tools/execute tools (via MCPBaseTool pattern)
## The MCP server calls execute(tool_name, args) where tool_name is the short form.

var _editor_plugin: EditorPlugin = null
var _subprocess_manager: Node = null

# =============================================================================
# tomyud1-style tools: tool_name → [handler_node, method_name]
# =============================================================================
var _file_tools: Node
var _scene_tools: Node
var _script_tools: Node
var _project_tools: Node
var _asset_tools: Node
var _visualizer_tools: Node

var _direct_tool_map: Dictionary = {}

# =============================================================================
# DaxianLee-style tools: category → executor instance
# =============================================================================
var _base_tools: Dictionary = {}
var _all_tool_definitions: Array[Dictionary] = []
var _initialized := false


func _safe_instantiate(script_path: String) -> Node:
	# Load at runtime and validate with reload() to detect parse errors.
	# This avoids the "Nonexistent function 'new' in base 'GDScript'" error
	# that can occur with preload() when the script is invalid.
	# See: godotengine/godot#58957, #96065.
	var cls: Script = load(script_path)
	if cls == null:
		push_warning("[ToolExecutor] Script not found: " + script_path)
		return null
	if cls.reload() != 0:
		push_error("[ToolExecutor] Script has parse errors: " + script_path)
		return null
	var instance = cls.new()
	if instance == null:
		push_warning("[ToolExecutor] Failed to instantiate: " + script_path)
		return null
	return instance


func _init_tools() -> void:
	if _initialized:
		return
	_initialized = true

	# --- tomyud1 tools (direct method call) ---
	_file_tools = _safe_instantiate("res://addons/godot_mcp/tools/file_tools.gd")
	if _file_tools:
		_file_tools.name = "FileTools"
		add_child(_file_tools)

	_scene_tools = _safe_instantiate("res://addons/godot_mcp/tools/scene_tools.gd")
	if _scene_tools:
		_scene_tools.name = "SceneTools"
		add_child(_scene_tools)

	_script_tools = _safe_instantiate("res://addons/godot_mcp/tools/script_tools.gd")
	if _script_tools:
		_script_tools.name = "ScriptTools"
		add_child(_script_tools)

	_project_tools = _safe_instantiate("res://addons/godot_mcp/tools/project_tools.gd")
	if _project_tools:
		_project_tools.name = "ProjectTools"
		add_child(_project_tools)

	_asset_tools = _safe_instantiate("res://addons/godot_mcp/tools/asset_tools.gd")
	if _asset_tools:
		_asset_tools.name = "AssetTools"
		add_child(_asset_tools)

	_visualizer_tools = _safe_instantiate("res://addons/godot_mcp/tools/visualizer_tools.gd")
	if _visualizer_tools:
		_visualizer_tools.name = "VisualizerTools"
		add_child(_visualizer_tools)

	# Build tomyud1 tool routing map
	_direct_tool_map = {
		&"list_dir": [_file_tools, &"list_dir"],
		&"read_file": [_file_tools, &"read_file"],
		&"search_project": [_file_tools, &"search_project"],
		&"create_script": [_file_tools, &"create_script"],

		&"create_scene": [_scene_tools, &"create_scene"],
		&"read_scene": [_scene_tools, &"read_scene"],
		&"add_node": [_scene_tools, &"add_node"],
		&"remove_node": [_scene_tools, &"remove_node"],
		&"modify_node_property": [_scene_tools, &"modify_node_property"],
		&"rename_node": [_scene_tools, &"rename_node"],
		&"move_node": [_scene_tools, &"move_node"],
		&"duplicate_node": [_scene_tools, &"duplicate_node"],
		&"reorder_node": [_scene_tools, &"reorder_node"],
		&"attach_script": [_scene_tools, &"attach_script"],
		&"detach_script": [_scene_tools, &"detach_script"],
		&"set_collision_shape": [_scene_tools, &"set_collision_shape"],
		&"set_sprite_texture": [_scene_tools, &"set_sprite_texture"],
		&"instance_scene": [_scene_tools, &"instance_scene"],
		&"set_mesh": [_scene_tools, &"set_mesh"],
		&"set_material": [_scene_tools, &"set_material"],
		&"get_node_spatial_info": [_scene_tools, &"get_node_spatial_info"],
		&"measure_node_distance": [_scene_tools, &"measure_node_distance"],
		&"snap_node_to_grid": [_scene_tools, &"snap_node_to_grid"],
		&"get_scene_hierarchy": [_scene_tools, &"get_scene_hierarchy"],
		&"get_scene_node_properties": [_scene_tools, &"get_scene_node_properties"],
		&"set_scene_node_property": [_scene_tools, &"set_scene_node_property"],

		&"edit_script": [_script_tools, &"edit_script"],
		&"validate_script": [_script_tools, &"validate_script"],
		&"list_scripts": [_script_tools, &"list_scripts"],
		&"create_folder": [_script_tools, &"create_folder"],
		&"delete_file": [_script_tools, &"delete_file"],
		&"rename_file": [_script_tools, &"rename_file"],

		&"get_project_settings": [_project_tools, &"get_project_settings"],
		&"list_settings": [_project_tools, &"list_settings"],
		&"update_project_settings": [_project_tools, &"update_project_settings"],
		&"get_input_map": [_project_tools, &"get_input_map"],
		&"configure_input_map": [_project_tools, &"configure_input_map"],
		&"get_collision_layers": [_project_tools, &"get_collision_layers"],
		&"setup_autoload": [_project_tools, &"setup_autoload"],
		&"get_node_properties": [_project_tools, &"get_node_properties"],
		&"get_console_log": [_project_tools, &"get_console_log"],
		&"get_errors": [_project_tools, &"get_errors"],
		&"clear_console_log": [_project_tools, &"clear_console_log"],
		&"open_in_godot": [_project_tools, &"open_in_godot"],
		&"scene_tree_dump": [_project_tools, &"scene_tree_dump"],
		&"classdb_query": [_project_tools, &"classdb_query"],
		&"rescan_filesystem": [_project_tools, &"rescan_filesystem"],
		&"run_scene": [_project_tools, &"run_scene"],
		&"stop_scene": [_project_tools, &"stop_scene"],
		&"is_playing": [_project_tools, &"is_playing"],

		&"generate_2d_asset": [_asset_tools, &"generate_2d_asset"],

		&"map_project": [_visualizer_tools, &"map_project"],
		&"map_scenes": [_visualizer_tools, &"map_scenes"],
	}

	# --- DaxianLee-style tools (get_tools/execute pattern) ---
	_register_base_tools()

	# Collect all tool definitions
	_collect_tool_definitions()


func _register_base_tools() -> void:
	# NOTE: Do NOT add tomyud1-style tools here (scene_tools, project_tools,
	# script_tools). They are NOT MCPBaseTool subclasses and lack execute().
	# They are already registered via _direct_tool_map for direct method calls.
	# Adding them here would create a dispatch conflict (tool name collision)
	# AND cause execute() to fail since they don't implement that interface.
	_base_tools["node"] = _make_base_tool("res://addons/godot_mcp/tools/node_tools.gd")
	_base_tools["resource"] = _make_base_tool("res://addons/godot_mcp/tools/resource_tools.gd")
	_base_tools["editor"] = _make_base_tool("res://addons/godot_mcp/tools/editor_tools.gd")
	_base_tools["debug"] = _make_base_tool("res://addons/godot_mcp/tools/debug_tools.gd")
	_base_tools["filesystem"] = _make_base_tool("res://addons/godot_mcp/tools/filesystem_tools.gd")
	_base_tools["animation"] = _make_base_tool("res://addons/godot_mcp/tools/animation_tools.gd")
	_base_tools["subprocess"] = _make_base_tool("res://addons/godot_mcp/tools/subprocess_tools.gd")
	_base_tools["material"] = _make_base_tool("res://addons/godot_mcp/tools/material_tools.gd")
	_base_tools["shader"] = _make_base_tool("res://addons/godot_mcp/tools/shader_tools.gd")
	_base_tools["lighting"] = _make_base_tool("res://addons/godot_mcp/tools/lighting_tools.gd")
	_base_tools["particle"] = _make_base_tool("res://addons/godot_mcp/tools/particle_tools.gd")
	_base_tools["tilemap"] = _make_base_tool("res://addons/godot_mcp/tools/tilemap_tools.gd")
	_base_tools["geometry"] = _make_base_tool("res://addons/godot_mcp/tools/geometry_tools.gd")
	_base_tools["physics"] = _make_base_tool("res://addons/godot_mcp/tools/physics_tools.gd")
	_base_tools["navigation"] = _make_base_tool("res://addons/godot_mcp/tools/navigation_tools.gd")
	_base_tools["audio"] = _make_base_tool("res://addons/godot_mcp/tools/audio_tools.gd")
	_base_tools["ui"] = _make_base_tool("res://addons/godot_mcp/tools/ui_tools.gd")
	_base_tools["signal"] = _make_base_tool("res://addons/godot_mcp/tools/signal_tools.gd")
	_base_tools["group"] = _make_base_tool("res://addons/godot_mcp/tools/group_tools.gd")
	_base_tools["scene_mgmt"] = _make_base_tool("res://addons/godot_mcp/tools/scene_mgmt.gd")
	_base_tools["project_mgmt"] = _make_base_tool("res://addons/godot_mcp/tools/project_mgmt.gd")


func _make_base_tool(path: String) -> Object:
	if not FileAccess.file_exists(path):
		push_warning("[ToolExecutor] Base tool not found: " + path)
		return null
	var cls: Script = load(path)
	if cls == null:
		push_warning("[ToolExecutor] Failed to load tool: " + path)
		return null
	# Detect parse errors — load() still returns a GDScript object even on
	# syntax errors, but .new() will then fail. See godotengine/godot#96065.
	if cls.reload() != 0:
		push_error("[ToolExecutor] Script has parse errors: " + path)
		return null
	var instance = cls.new()
	if instance == null:
		push_warning("[ToolExecutor] Failed to instantiate: " + path)
		return null
	# RefCounted instances don't belong in the scene tree — they are plain
	# objects held in memory by the tool executor. add_child() on a RefCounted
	# produces the "rp_child is null" error, so skip it.
	return instance


func _collect_tool_definitions() -> void:
	_all_tool_definitions.clear()
	for category in _base_tools:
		var executor = _base_tools[category]
		if executor and executor.has_method("get_tools"):
			var tools = executor.get_tools()
			for tool_def in tools:
				# Add category prefix to tool name
				var short_name = tool_def.get("name", "")
				var full_name = category + "_" + short_name
				var def_copy = tool_def.duplicate(true)
				def_copy["name"] = full_name
				_all_tool_definitions.append(def_copy)


func set_editor_plugin(plugin: EditorPlugin) -> void:
	_editor_plugin = plugin

	if not _initialized:
		_init_tools()

	# Inject editor plugin into tomyud1 tools
	if _file_tools: _file_tools.set_editor_plugin(plugin)
	if _scene_tools: _scene_tools.set_editor_plugin(plugin)
	if _script_tools: _script_tools.set_editor_plugin(plugin)
	if _project_tools: _project_tools.set_editor_plugin(plugin)
	if _asset_tools: _asset_tools.set_editor_plugin(plugin)
	if _visualizer_tools:
		_visualizer_tools.set_editor_plugin(plugin)
		_visualizer_tools.set_scene_tools_ref(_scene_tools)

	# Inject editor plugin into DaxianLee tools
	for category in _base_tools:
		var executor = _base_tools[category]
		if executor and executor.has_method("set_editor_plugin"):
			executor.set_editor_plugin(plugin)


func set_subprocess_manager(manager: Node) -> void:
	_subprocess_manager = manager
	if _base_tools.has("subprocess"):
		var st = _base_tools["subprocess"]
		if st and st.has_method("set_subprocess_manager"):
			st.set_subprocess_manager(manager)


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	"""Main entry point. tool_name is the MCP tool name (may include category prefix)."""

	# --- Try DaxianLee-style tools first (category_toolname format) ---
	var parts = tool_name.split("_", true, 1)
	if parts.size() >= 2:
		var category = parts[0]
		var short_name = parts[1]
		if _base_tools.has(category):
			var executor = _base_tools[category]
			if executor and executor.has_method("execute"):
				var result = executor.execute(short_name, args)
				return _normalize_result(result)

	# --- Try tomyud1-style direct method tools ---
	if _direct_tool_map.has(tool_name):
		return _execute_direct_tool(tool_name, args)

	# --- Try visualizer internal commands ---
	if tool_name.begins_with("visualizer._internal_"):
		var method = tool_name.replace("visualizer.", "")
		if _visualizer_tools and _visualizer_tools.has_method(method):
			return _normalize_result(_visualizer_tools.call(method, args))

	return {
		"success": false,
		"error": "Unknown tool: %s" % tool_name
	}


func _execute_direct_tool(tool_name: String, args: Dictionary) -> Dictionary:
	var handler: Array = _direct_tool_map[tool_name]
	var node: Node = handler[0]
	var method: StringName = handler[1]

	if not node.has_method(method):
		return {
			"success": false,
			"error": "Tool handler not found: %s.%s" % [node.name, method]
		}

	_parse_stringified_args(args)
	var result = node.call(method, args)

	if result == null or not (result is Dictionary):
		push_error("[MCP] Tool '%s' returned invalid result: %s" % [tool_name, str(result)])
		return {
			"success": false,
			"error": "Tool '%s' returned null or non-Dictionary (possible crash — check Godot console)" % tool_name
		}

	return _normalize_result(result)


func _normalize_result(result: Dictionary) -> Dictionary:
	"""Normalize result to MCP standard format: {success, data?, error?, message?}"""
	if result == null:
		return {"success": false, "error": "Tool returned null"}

	# Already in MCP format
	if result.has("success"):
		return result

	# tomyud1 format: {ok: bool, data?, error?, message?}
	if result.has("ok"):
		return {
			"success": bool(result["ok"]),
			"data": result.get("data"),
			"error": result.get("error"),
			"message": result.get("message")
		}

	# Unknown format
	return {
		"success": true,
		"data": result
	}


func _parse_stringified_args(args: Dictionary) -> void:
	for key in args:
		var val = args[key]
		if val is String:
			var s: String = val.strip_edges()
			if (s.begins_with("{") and s.ends_with("}")) or (s.begins_with("[") and s.ends_with("]")):
				var parsed = JSON.parse_string(s)
				if parsed != null:
					args[key] = parsed


func get_all_tool_definitions() -> Array[Dictionary]:
	"""Return ALL tool definitions (for MCP tools/list)."""
	return _all_tool_definitions


func get_all_tool_names() -> Array:
	"""Return list of all available tool names (direct methods + base tool names)."""
	var names: Array = []
	for tool_name in _direct_tool_map:
		names.append(tool_name)
	for def in _all_tool_definitions:
		names.append(def.get("name", ""))
	return names
