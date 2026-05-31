快速开始（用户拖入仓库后）
拖入仓库
    ↓
Cursor 打开工作区，agent 检测到 .cursor/rules/godot-mcp.md
    ↓
agent 自动引导用户安装 Godot MCP 插件
    ↓
Agent 使用 godot-mcp 工具（遵循 skill 中的 GDScript 规范）
.cursor/rules/godot-mcp.md 内容
---
name: Godot MCP
description: >-
  当用户在 Godot 项目中工作，或要求操作节点、场景、脚本等任务时，
  自动使用 godot-mcp MCP 工具，并遵循 Godot 4 GDScript 规范。
---
# Godot MCP — Agent Guidelines
当用户要求在 Godot 项目中工作时，使用 godot-mcp MCP 工具（tools/list 查看所有工具）。
## 使用前检查
1. 用 `scene_get_tree` 查看当前场景结构
2. 用 `scene_get_current` 获取当前场景信息
3. 用 `script_read` 读取已有脚本再修改
## 修改后
- 用 `scene_save` 保存场景
- 出错用 `editor_undo_redo`（action: "undo"）撤销
- 用 `debug_get_logs` 查看运行时错误
## GDScript 规范（Godot 4.x）
### 字符串格式化 — 必须用 `%` 操作符
```gdscript
# ✅ 正确
var msg := "HP: %d/%d" % [hp, max_hp]
# ❌ 错误 — Godot 4 不支持 f-string
var msg := f"HP: {hp}"
函数调用必须带 ()
var name := node.get_name()   # ✅
var name := node.get_name     # ❌ Nonexistent function
Callable 对象用 .call()
var result := my_callable.call(arg1, arg2)   # ✅
var result := my_callable(arg1, arg2)         # ❌ Parse Error
异步函数必须 await
return await _run_project(args)   # ✅
return _run_project(args)          # ❌ coroutine must be called with await
字符串内不要写 []
line += " [script] %s" % [name]   # ✅
line += " [script]"                 # ❌ [script] 会被解析为数组字面量
常见错误修复
错误信息	原因	修复
Cannot call on an expression
Callable 未用 .call()，或字符串含 []
用 .call()，用 % 格式化
coroutine must be called with await
异步函数缺 await
加 await
Expected end of statement
字符串内写了 [...] 或括号不匹配
用 % 操作符
should be "Array" but is "String"
_error() 第三个参数需 [] 包裹
["hint text"]
HTTP 405 / Server unreachable
Godot 未运行或插件未启用
启动 Godot 并启用插件
Godot 4 vs Godot 3
特性	Godot 4	Godot 3
字符串格式化
% 操作符
% 操作符
异步
await func
yield()
数组类型
Array[String]
PoolStringArray
字典 key
&"key" 或字符串
仅字符串
信号连接
connect(method)
`connect("signal", obj, "method")
