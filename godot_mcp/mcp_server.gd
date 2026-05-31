@tool
extends Node
class_name MCPServer

## MCP HTTP Server for Godot Engine
## Delegates all tool execution to the unified ToolExecutor.
## Supports both tomyud1 direct-method tools and DaxianLee get_tools/execute tools.

const ToolExecutor = preload("res://addons/godot_mcp/tool_executor.gd")
const SubprocessManager = preload("res://addons/godot_mcp/subprocess_manager.gd")

signal server_started
signal server_stopped
signal client_connected
signal client_disconnected

const MCP_VERSION = "2024-11-05"
const SERVER_NAME = "godot-mcp-server"
const SERVER_VERSION = "1.0.0-hybrid"

var _tcp_server: TCPServer
var _port: int = 3001
var _host: String = "127.0.0.1"
var _running: bool = false
var _debug_mode: bool = false
var _clients: Array[StreamPeerTCP] = []
var _pending_data: Dictionary = {}

var _disabled_tools: Array = []
var _subprocess_manager: Node = null

# Centralized tool executor
var _tool_executor: ToolExecutor = null


func _ready() -> void:
	_tcp_server = TCPServer.new()
	_init_tool_executor()


func _init_tool_executor() -> void:
	if _tool_executor != null:
		return
	# Use load() at runtime instead of the preload()-at-const-scope pattern,
	# which can fail with "Nonexistent function 'new' in base 'GDScript'" when
	# the const was resolved to a bare GDScript resource rather than its class.
	# See: godotengine/godot#58957, #96065.
	var tool_cls: Script = load("res://addons/godot_mcp/tool_executor.gd")
	if tool_cls == null:
		push_error("[MCP] ToolExecutor script not found")
		return
	# In Godot 4.3+ can_instantiate() must be called on a Script-typed variable
	# (not Variant), otherwise it raises "Nonexistent function 'can_instantiate'
	# in base 'GDScript'". See: godotengine/godot#93193.
	# If the script has parse errors load() still succeeds but reload() returns != 0.
	if tool_cls.reload() != 0:
		push_error("[MCP] ToolExecutor script has parse errors — check the Godot console")
		return
	_tool_executor = tool_cls.new()
	_tool_executor.name = "ToolExecutor"
	add_child(_tool_executor)

	# Inject subprocess manager if available
	if _subprocess_manager != null:
		_tool_executor.set_subprocess_manager(_subprocess_manager)


func _process(_delta: float) -> void:
	if not _running:
		return

	if _tcp_server.is_connection_available():
		var client = _tcp_server.take_connection()
		if client:
			_clients.append(client)
			_pending_data[client] = ""
			if _debug_mode:
				print("[MCP] Client connected (total: %d)" % _clients.size())
			client_connected.emit()

	var clients_to_remove: Array[StreamPeerTCP] = []
	for client in _clients:
		client.poll()
		var status = client.get_status()
		if status == StreamPeerTCP.STATUS_CONNECTED:
			var available = client.get_available_bytes()
			if available > 0:
				var data = client.get_data(available)
				if data[0] == OK:
					var request_str = data[1].get_string_from_utf8()
					_pending_data[client] += request_str
					_process_http_request(client)
		elif status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			clients_to_remove.append(client)

	for client in clients_to_remove:
		_clients.erase(client)
		_pending_data.erase(client)
		if _debug_mode:
			print("[MCP] Client disconnected")
		client_disconnected.emit()


func set_editor_plugin(plugin: EditorPlugin) -> void:
	if _tool_executor:
		_tool_executor.set_editor_plugin(plugin)


func set_subprocess_manager(manager: Node) -> void:
	_subprocess_manager = manager
	if _tool_executor:
		_tool_executor.set_subprocess_manager(manager)


func initialize(port: int, host: String, debug: bool) -> void:
	_port = port
	_host = host
	_debug_mode = debug

	# Ensure tool executor is initialized before any external calls.
	# _ready() may not have fired yet when initialize() is called from _enter_tree().
	_init_tool_executor()


func start() -> bool:
	if _running:
		return true

	if _tcp_server == null:
		_tcp_server = TCPServer.new()

	var error = _tcp_server.listen(_port, _host)
	if error != OK:
		push_error("[MCP] Failed to start server on port %d: %s" % [_port, error_string(error)])
		return false

	_running = true
	print("[MCP] Server started on http://%s:%d/mcp" % [_host, _port])
	server_started.emit()
	return true


func stop() -> void:
	if not _running:
		return

	for client in _clients:
		client.disconnect_to_host()
	_clients.clear()
	_pending_data.clear()
	_tcp_server.stop()
	_running = false
	print("[MCP] Server stopped")
	server_stopped.emit()


func is_running() -> bool:
	return _running


func set_port(port: int) -> void:
	_port = port


func set_debug_mode(debug: bool) -> void:
	_debug_mode = debug


func get_connection_count() -> int:
	return _clients.size()


func set_disabled_tools(disabled: Array) -> void:
	_disabled_tools = disabled


func get_disabled_tools() -> Array:
	return _disabled_tools


func is_tool_enabled(tool_name: String) -> bool:
	return not (tool_name in _disabled_tools)


func get_enabled_tools() -> Array[Dictionary]:
	var enabled: Array[Dictionary] = []
	if not _tool_executor:
		return enabled
	for tool_def in _tool_executor.get_all_tool_definitions():
		if is_tool_enabled(tool_def["name"]):
			enabled.append(tool_def)
	return enabled


func get_tools_by_category() -> Dictionary:
	"""Return tools grouped by category for the plugin UI."""
	var result: Dictionary = {}
	if not _tool_executor:
		return result

	# Collect all tool definitions and group by category prefix
	for tool_def in _tool_executor.get_all_tool_definitions():
		var full_name = tool_def.get("name", "")
		if "_" in full_name:
			var category = full_name.split("_")[0]
			if not result.has(category):
				result[category] = []
			result[category].append(tool_def)
	return result


# =============================================================================
# HTTP Request Processing
# =============================================================================

func _process_http_request(client: StreamPeerTCP) -> void:
	var data = _pending_data.get(client, "")
	if data.is_empty():
		return

	var header_end = data.find("\r\n\r\n")
	if header_end == -1:
		return

	var header_section = data.substr(0, header_end)
	var headers = _parse_http_headers(header_section)
	if headers.is_empty():
		_pending_data[client] = ""
		return

	var content_length = 0
	var is_chunked = false
	if headers.has("content-length"):
		content_length = int(headers["content-length"])
	elif headers.has("transfer-encoding") and headers["transfer-encoding"].to_lower().contains("chunked"):
		is_chunked = true

	var body_start = header_end + 4
	var body = data.substr(body_start)
	var body_bytes = body.to_utf8_buffer()
	var body_byte_size = body_bytes.size()

	if body_byte_size < content_length and not is_chunked:
		return

	var request_body: String
	if is_chunked:
		var decoded_body = _decode_chunked_body(body)
		if decoded_body == null:
			return
		request_body = decoded_body
		_pending_data[client] = ""
	else:
		if body_byte_size > content_length:
			var remaining_bytes = body_bytes.slice(content_length)
			_pending_data[client] = remaining_bytes.get_string_from_utf8()
		else:
			_pending_data[client] = ""
		var request_bytes = body_bytes.slice(0, content_length)
		request_body = request_bytes.get_string_from_utf8()

	var method = headers.get("method", "GET")
	var path = headers.get("path", "/")

	var response: Dictionary
	match [method, path]:
		["POST", "/mcp"]:
			response = _handle_mcp_request(request_body)
		["GET", "/health"]:
			response = _create_health_response()
		["GET", "/api/tools"]:
			response = _create_tools_list_response()
		["OPTIONS", _]:
			response = _create_cors_response()
		_:
			response = {"error": "Not found", "status": 404}

	_send_http_response(client, response)


func _decode_chunked_body(data: String):
	var result = ""
	var pos = 0
	while pos < data.length():
		var line_end = data.find("\r\n", pos)
		if line_end == -1:
			return null
		var size_str = data.substr(pos, line_end - pos).strip_edges()
		var semicolon = size_str.find(";")
		if semicolon != -1:
			size_str = size_str.substr(0, semicolon)
		var chunk_size = size_str.hex_to_int()
		if chunk_size == 0:
			return result
		var chunk_start = line_end + 2
		var chunk_end = chunk_start + chunk_size
		if chunk_end + 2 > data.length():
			return null
		result += data.substr(chunk_start, chunk_size)
		pos = chunk_end + 2
	return null


func _parse_http_headers(header_section: String) -> Dictionary:
	var result: Dictionary = {}
	var lines = header_section.split("\r\n")
	if lines.size() == 0:
		return result
	var request_line = lines[0].split(" ")
	if request_line.size() >= 2:
		result["method"] = request_line[0]
		result["path"] = request_line[1]
	for i in range(1, lines.size()):
		var line = lines[i]
		var colon_pos = line.find(":")
		if colon_pos > 0:
			var key = line.substr(0, colon_pos).strip_edges().to_lower()
			var value = line.substr(colon_pos + 1).strip_edges()
			result[key] = value
	return result


# =============================================================================
# JSON-RPC 2.0 Handlers
# =============================================================================

func _handle_mcp_request(body: String) -> Dictionary:
	var json = JSON.new()
	var error = json.parse(body)
	if error != OK:
		return _create_json_rpc_error(-32700, "Parse error: %s" % json.get_error_message(), null)
	var request = json.get_data()
	if not request is Dictionary:
		return _create_json_rpc_error(-32600, "Invalid Request", null)
	var method = request.get("method", "")
	var params = request.get("params", {})
	var id = request.get("id")
	var response: Dictionary
	match method:
		"initialize":      response = _handle_initialize(params, id)
		"initialized":     response = _create_json_rpc_response({}, id)
		"tools/list":      response = _handle_tools_list(params, id)
		"tools/call":      response = _handle_tools_call(params, id)
		"ping":            response = _create_json_rpc_response({}, id)
		_:                 response = _create_json_rpc_error(-32601, "Method not found: %s" % method, id)
	return response


func _handle_initialize(_params: Dictionary, id) -> Dictionary:
	return _create_json_rpc_response({
		"protocolVersion": MCP_VERSION,
		"capabilities": {"tools": {"listChanged": false}},
		"serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION}
	}, id)


func _handle_tools_list(_params: Dictionary, id) -> Dictionary:
	var tools_list: Array[Dictionary] = []
	for tool_def in get_enabled_tools():
		tools_list.append({
			"name": tool_def["name"],
			"description": tool_def.get("description", ""),
			"inputSchema": tool_def.get("inputSchema", {"type": "object", "properties": {}})
		})
	return _create_json_rpc_response({"tools": tools_list}, id)


func _handle_tools_call(params: Dictionary, id) -> Dictionary:
	var tool_name = params.get("name", "")
	var arguments = params.get("arguments", {})
	if tool_name.is_empty():
		return _create_tool_response({"success": false, "error": "Missing tool name"}, id)
	if not is_tool_enabled(tool_name):
		return _create_tool_response({"success": false, "error": "Tool '%s' is disabled" % tool_name}, id)

	# Delegate to unified tool executor
	if _tool_executor:
		var result = _tool_executor.execute(tool_name, arguments)
		return _create_tool_response(result, id)
	else:
		return _create_tool_response({"success": false, "error": "Tool executor not initialized"}, id)


func _create_tool_response(result: Dictionary, id) -> Dictionary:
	var sanitized_result = _sanitize_for_json(result)
	return _create_json_rpc_response({
		"content": [{"type": "text", "text": JSON.stringify(sanitized_result)}],
		"isError": false
	}, id)


func _create_json_rpc_response(result, id) -> Dictionary:
	return {"jsonrpc": "2.0", "result": result, "id": id}


func _create_json_rpc_error(code: int, message: String, id) -> Dictionary:
	return {"jsonrpc": "2.0", "error": {"code": code, "message": message}, "id": id}


# =============================================================================
# HTTP Helpers
# =============================================================================

func _create_health_response() -> Dictionary:
	return {
		"status": "ok",
		"server": SERVER_NAME,
		"version": SERVER_VERSION,
		"running": _running,
		"connections": _clients.size()
	}


func _create_tools_list_response() -> Dictionary:
	return {"tools": get_enabled_tools()}


func _create_cors_response() -> Dictionary:
	return {"status": 204, "cors": true}


func _send_http_response(client: StreamPeerTCP, data: Dictionary) -> void:
	var sanitized = _sanitize_for_json(data)
	var body = JSON.stringify(sanitized)
	var body_bytes = body.to_utf8_buffer()
	var status_code = data.get("status", 200)
	var status_texts = {200: "OK", 204: "No Content", 404: "Not Found", 500: "Internal Server Error"}
	var status_text = status_texts.get(status_code, "OK")

	var headers = "HTTP/1.1 %d %s\r\n" % [status_code, status_text]
	headers += "Content-Type: application/json; charset=utf-8\r\n"
	headers += "Content-Length: %d\r\n" % body_bytes.size()
	headers += "Access-Control-Allow-Origin: *\r\n"
	headers += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
	headers += "Access-Control-Allow-Headers: Content-Type, Accept, X-Requested-With\r\n"
	headers += "Connection: keep-alive\r\n\r\n"

	var header_bytes = headers.to_utf8_buffer()
	client.put_data(header_bytes)
	client.put_data(body_bytes)


func _sanitize_for_json(value):
	match typeof(value):
		TYPE_DICTIONARY:
			var result = {}
			for key in value:
				result[str(key)] = _sanitize_for_json(value[key])
			return result
		TYPE_ARRAY:
			var result = []
			for item in value:
				result.append(_sanitize_for_json(item))
			return result
		TYPE_FLOAT:
			if is_nan(value): return 0.0
			if is_inf(value): return 999999999.0 if value > 0 else -999999999.0
			return value
		TYPE_STRING: return value
		TYPE_STRING_NAME: return str(value)
		TYPE_NODE_PATH: return str(value)
		TYPE_OBJECT:
			if value == null: return null
			return str(value)
		TYPE_COLOR: return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_NIL: return null
		_: return value
