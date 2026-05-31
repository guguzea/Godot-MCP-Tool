\---

name: godot-mcp

description: >-

&#x20; Guidelines for using the Godot MCP plugin to interact with the Godot editor.

&#x20; Use this skill whenever the user asks to work with a Godot project, create

&#x20; nodes, edit scenes, modify scripts, or any task involving the godot-mcp server.

\---

\# Godot MCP — Agent Guidelines



This skill covers how to use the Godot MCP plugin (godot-mcp) correctly when working with a Godot project.



\## Prerequisites



\- The Godot editor must be \*\*running\*\* with the godot-mcp plugin enabled.

\- The plugin starts an HTTP MCP server at `http://127.0.0.1:3001/mcp` by default.

\- The godot-mcp-bridge bridges Cursor's stdio protocol to the HTTP server — if the bridge logs "unreachable", the Godot editor is not running or the plugin is disabled.



\## Workflow



\### Before writing Godot code



1\. Check the current scene tree with `scene\_get\_tree` to understand existing nodes.

2\. Check the current scene with `scene\_get\_current`.

3\. Read any existing scripts with `script\_read` before modifying them.



\### After making changes



1\. Use `editor\_undo\_redo` with `action: "undo"` if something went wrong.

2\. Use `debug\_get\_logs` to check for runtime errors.

3\. For scene changes, save with `scene\_save`.



\## GDScript Conventions (Godot 4.x)



The MCP tools inject GDScript into the running editor. Follow these rules strictly or the tools will fail.



\### String formatting — use `%` operator only



Godot 4 GDScript does \*\*not\*\* support Python-style f-strings or chained `.format()` calls.



```gdscript

\# ✅ CORRECT

var msg := "Player health: %d / %d" % \[current\_hp, max\_hp]

var path := "res://scenes/%s.tscn" % scene\_name

var summary := "Found %d errors" % error\_count



\# ❌ WRONG — f-strings don't exist in Godot 4

var msg := f"Player health: {current\_hp}"



\# ❌ WRONG — .format() returns a String, calling () on it is invalid syntax

var msg := "{} errors".format(\[count])()   # Parse Error

```



\### Function calls with parentheses



GDScript requires `()` when calling methods, even on the same line:



```gdscript

\# ✅ CORRECT

node.name = "Player"

var file := script.resource\_path.get\_file()



\# ❌ WRONG — missing parentheses

var file := script.resource\_path.get\_file    # Nonexistent function

```



\### Callable objects — use `.call()` explicitly



If you obtain a reference to a method (Callable), invoke it with `.call()`:



```gdscript

\# ✅ CORRECT

var result := my\_callable.call(arg1, arg2)



\# ❌ WRONG — trying to call a Callable directly as a function

var result := my\_callable(arg1, arg2)    # Parse Error: Cannot call on an expression

```



\### Coroutines (async functions) — must use `await`



Functions declared with `async func` or that `await` internally are coroutines and \*\*must\*\* be called with `await`:



```gdscript

\# ❌ WRONG

func execute(tool\_name: String) -> Dictionary:

&#x20;   match tool\_name:

&#x20;       "run\_project": return \_run\_project(args)   # Parse Error: coroutine must be called with "await"



\# ✅ CORRECT

func execute(tool\_name: String) -> Dictionary:

&#x20;   match tool\_name:

&#x20;       "run\_project": return await \_run\_project(args)

```



\### Typed arrays and dictionaries



```gdscript

\# Typed array

var items: Array\[String] = \[]



\# Typed dictionary keys use \&"key" syntax (Godot 4)

var result := {\&"ok": true, \&"errors": errors}



\# Regular string keys (safer, compatible)

var result := {"ok": true, "errors": errors}

```



\### Array literals in strings



Do not use `\[...]` inside a string literal — GDScript will parse it as an array:



```gdscript

\# ❌ WRONG — \[script] inside a string is parsed as array literal

line += " \[script]"   # Parse Error



\# ✅ CORRECT — use % operator instead

line += " \[script] %s" % \[script\_name]

```



\## Tool Categories



\### Scene \& Node tools (`scene\_\*`, `node\_\*`)

\- Always verify parent node exists before adding children.

\- Node paths use `res://` prefix for resources, absolute paths for scene nodes.

\- Use `node\_get` to check existing node properties before modifying.



\### Script tools (`script\_\*`)

\- `script\_read` returns the raw file content.

\- `script\_write` replaces the entire file — use `script\_read` first to preserve existing code.

\- New scripts need `@tool` and `extends` declarations.



\### Resource/File tools (`resource\_\*`, `filesystem\_\*`, `file\_\*`)

\- Resources live under `res://`.

\- Use `filesystem\_list` to browse before writing.

\- `file\_write` creates or overwrites; `file\_read` reads raw text/binary.



\### Animation tools (`animation\_\*`)

\- Animations are accessed via `AnimationPlayer` nodes.

\- Track paths in animations match the node path in the scene tree.

\- Key times are in seconds (float).



\### Project tools (`project\_\*`)

\- `project\_get\_info` returns engine version, platform, debug/release mode.

\- `project\_get\_settings` reads from `project.godot` settings.



\### Editor tools (`editor\_\*`)

\- `editor\_undo\_redo` supports `"undo"` and `"redo"`.

\- `editor\_get\_selection` returns currently selected nodes.



\## Error Recovery



| Error pattern | Cause | Fix |

|---|---|---|

| `Parse Error: Cannot call on an expression` | Missing `.call()` on Callable, or string literal contains `\[...]` | Use `.call()`, fix string formatting |

| `Parse Error: Function "X" is a coroutine` | Missing `await` on async function call | Add `await` |

| `Parse Error: Expected end of statement` | Array literal `\[{}]` inside string, or mismatched brackets | Use `%` formatting, check bracket balance |

| `Parse Error: Invalid argument ... should be "Array" but is "String"` | `\_error()` hints param needs `\[]` wrapping | Pass hints as `\["hint text"]` |

| Server unreachable (HTTP 405/0) | Godot not running or plugin disabled | Start Godot with plugin enabled |



\## Godot 4 vs Godot 3 Differences



If working with older Godot 3 projects:

\- No `await` keyword (use `yield()` instead)

\- Typed arrays use `PoolStringArray`, `PoolIntArray`, etc.

\- Dictionary keys don't use `\&""` syntax

\- Signal connection: `connect("signal", object, "method")` instead of `connect(method)`



