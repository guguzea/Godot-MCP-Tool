# Godot MCP Server
一个在 Godot 编辑器内运行的 MCP 服务器插件，通过 HTTP 协议向 AI 客户端暴露编辑器能力，让 AI 助手可以直接操作场景、节点、脚本和项目配置。

本项目基于 [DaxianLee/godot-mcp](https://github.com/DaxianLee/godot-mcp) 修改，新增和增强了以下工具：
- **输入映射管理** — `input_map` 工具，支持列出、添加、删除输入动作及按键/鼠标/手柄绑定
- **碰撞层查询** — `collision_layer` 工具，查看和配置碰撞层与掩码
- **节点空间信息** — 新增 `get_spatial_info`、`measure_distance`、`snap_to_grid`
- **节点脚本操作** — 新增 `attach_script`、`detach_script`、`set_collision_shape`
- **材质/网格/精灵批量设置** — `set_mesh`、`set_material`、`set_sprite_texture`
- **脚本精细编辑** — `edit_script` 支持基于上下文片段的精准代码替换
- **子进程运行** — `run_project` / `stop_project` 无头运行 Godot 项目并捕获输出
- **性能监控** — `get_fps`、`get_memory`、`get_monitors`、`get_render_info`
- **项目可视化地图** — `map_project` 爬取全项目 GDScript，构建类继承和引用关系图
- **SVG 资产生成** — `generate_2d_asset` 将 SVG 代码直接渲染为 PNG 贴图
## 工具列表
### 项目与配置
| 工具 | 描述 |
|------|------|
| `info` | 获取项目基本信息、Godot 版本、窗口设置、渲染器等 |
| `settings` | 读取、设置、重置项目设置（按分类浏览） |
| `input` | 管理 Input Map：列出动作、添加/删除动作、绑定键盘/鼠标/手柄 |
| `autoload` | 列出、添加、删除 Autoload 单例脚本 |
| `list_settings` | 按分类列出所有可用设置项及其当前值和可选枚举 |
| `get_console_log` | 读取编辑器 Output 面板日志 |
| `get_errors` | 读取 Debugger Errors 面板错误列表 |
| `open_in_godot` | 在外部 Godot 实例中打开资源 |
| `scene_tree_dump` | 输出场景树文本快照 |
### 场景与节点
| 工具 | 描述 |
|------|------|
| `create_scene` | 创建新场景文件 |
| `read_scene` | 读取场景内容 |
| `add_node` | 向场景添加节点 |
| `instance_scene` | 实例化一个 PackedScene |
| `remove_node` | 删除节点 |
| `modify_node_property` | 修改节点属性 |
| `rename_node` | 重命名节点 |
| `move_node` | 移动节点位置 |
| `attach_script` | 将脚本附加到节点 |
| `detach_script` | 解除节点脚本 |
| `set_collision_shape` | 设置碰撞体形状 |
| `set_sprite_texture` | 设置 Sprite2D 贴图 |
| `set_mesh` | 设置 MeshInstance3D 网格 |
| `set_material` | 设置节点材质 |
| `get_spatial_info` | 获取节点空间信息（旋转四元数、变换矩阵等） |
| `measure_distance` | 测量两节点间距离 |
| `snap_to_grid` | 将节点对齐到网格 |
### 节点查询与操作
| 工具 | 描述 |
|------|------|
| `query` | 按名称/类型查找节点、获取子树字符串 |
| `lifecycle` | 创建、删除、复制、实例化节点 |
| `transform` | 操作节点位置、旋转（弧度/角度）、缩放 |
| `property` | 读写任意节点属性，支持过滤 |
| `hierarchy` | 重新父节点、调整兄弟顺序、设置 Owner |
| `signal` | 列出信号、连接/断开、发射、添加自定义信号 |
### 脚本
| 工具 | 描述 |
|------|------|
| `edit_script` | 基于上下文片段的精准代码替换（保留缩进和格式） |
| `validate_script` | 验证 GDScript 语法 |
| `list_scripts` | 列出项目中所有 GDScript 文件 |
| `create_folder` | 创建文件夹 |
| `delete_file` | 删除文件 |
| `rename_file` | 重命名文件 |
### 资源管理
| 工具 | 描述 |
|------|------|
| `query` | 按类型/目录列出资源、搜索资源、查看依赖关系 |
| `manage` | 创建/导入/复制/移动/删除资源 |
| `texture` | 获取贴图信息、分配贴图到节点属性 |
### 文件系统
| 工具 | 描述 |
|------|------|
| `directory` | 列出/创建/删除目录，检查存在性，按扩展名过滤文件 |
| `file` | 读写文件、追加内容、复制/移动/删除、获取文件信息 |
| `json` | 读取/写入 JSON，支持按路径 get/set 嵌套值 |
| `search` | 按名称搜索文件、全文 grep、批量查找替换 |
### 动画
| 工具 | 描述 |
|------|------|
| `player` | 控制 AnimationPlayer：播放/停止/暂停/跳转/调整速度 |
| `animation` | 创建/删除/复制/重命名动画，设置时长和循环 |
| `track` | 添加属性轨道/方法轨道，添加/删除关键帧 |
| `tween` | 创建 Tween 过程动画，支持多种缓动曲线和过渡类型 |
| `animation_state_machine` | 状态机管理（Advance、GetCurrent） |
### 物理
| 工具 | 描述 |
|------|------|
| `physics_body` | 创建/配置物理体（RigidBody、CharacterBody、StaticBody、Area） |
| `collision` | 创建/配置碰撞形状（Box、Sphere、Capsule、 cylinder、WorldBoundary） |
| `collision_layer` | 查询和配置碰撞层/掩码 |
| `joint` | 创建铰链/引脚/滑块/通用关节 |
| `query` | 空间查询：射线投射、形状扫描、相交检测 |
### 导航
| 工具 | 描述 |
|------|------|
| `navigation` | 获取导航地图信息、列出区域/代理、烘焙导航网格、计算路径、设置导航代理目标 |
### 音频
| 工具 | 描述 |
|------|------|
| `bus` | 管理音频总线：添加/删除/设置音量/静音/独奏/旁路，插入/移除音效 |
| `stream` | 播放/暂停/停止音频流，设置循环、音量、音调 |
| `effect` | 管理音效处理器（混响、延迟、均衡器等） |
### 材质与着色器
| 工具 | 描述 |
|------|------|
| `material` | 创建/查询/配置 StandardMaterial3D/ORMMaterial3D/CanvasItemMaterial |
| `shader` | 创建/读写着色器文件，获取 uniform 参数 |
| `shader_material` | 创建 ShaderMaterial 实例，设置/获取着色器参数 |
### 灯光与环境
| 工具 | 描述 |
|------|------|
| `light` | 创建/配置 DirectionalLight3D/OmniLight3D/SpotLight3D，支持 2D 光源 |
| `environment` | 配置 WorldEnvironment：背景、天空、雾效、体积光 |
| `sky` | 创建和管理 Sky 资源 |
### 粒子
| 工具 | 描述 |
|------|------|
| `particles` | 创建/控制 GPU/CPU 粒子发射器：发射开关、数量、生命周期、单发模式 |
| `process_material` | 配置粒子过程材质（重力、速度、颜色、生命曲线等） |
### 瓦片地图
| 工具 | 描述 |
|------|------|
| `tileset` | 列出/查询 TileSet 源和瓦片数据 |
| `tilemap` | 操作 TileMap 单元格：设置/擦除/填充矩形/清空图层 |
### 几何体
| 工具 | 描述 |
|------|------|
| `csg` | 创建 CSG 几何体（Box/Sphere/Cylinder/Torus/Polygon），设置布尔运算 |
| `gridmap` | 创建/操作 GridMap 网格地图 |
| `multimesh` | 创建/配置 MultiMesh 实例化渲染 |
### UI
| 工具 | 描述 |
|------|------|
| `theme` | 创建/配置 Theme：颜色、常量、字体、样式框 |
| `control` | 创建/配置 Control 节点：按钮、标签、面板等 |
### 信号与分组
| 工具 | 描述 |
|------|------|
| `signal` | 列出节点信号、查询连接、连接/断开/发射信号 |
| `group` | 管理节点分组：添加/移除/调用组方法/批量设属性 |
### 调试与性能
| 工具 | 描述 |
|------|------|
| `log` | 向编辑器 Output 面板输出普通/警告/错误/富文本消息 |
| `performance` | 获取 FPS、内存占用、所有性能监视器值、渲染统计信息 |
| `error` | 错误处理和错误信息记录 |
### 编辑器控制
| 工具 | 描述 |
|------|------|
| `status` | 获取编辑器版本、切换主屏幕（2D/3D/Script）、开关免打扰模式 |
| `settings` | 读取/修改编辑器偏好设置 |
| `theme` | 管理编辑器主题（深色/浅色） |
### 高级工具
| 工具 | 描述 |
|------|------|
| `map_project` | 爬取全项目 GDScript，构建结构地图（类名/extends/preload 关系图） |
| `generate_2d_asset` | 将 SVG 代码渲染为 PNG 贴图保存到项目 |
| `run_project` | 以无头模式运行 Godot 项目，捕获 stdout/stderr |
| `stop_project` | 停止正在运行的无头项目 |
| `get_debug_output` | 读取无头进程的调试输出 |
## 系统要求
- Godot Engine 4.x
- 支持 Windows / macOS / Linux
## 安装
1. 克隆或下载本仓库
2. 将 `addons/godot_mcp` 文件夹复制到你的 Godot 项目 `addons/` 目录下
3. 在 Godot 编辑器中打开 `项目 → 项目设置 → 插件`，启用 **Godot MCP Server**
4. 插件启动后在编辑器右侧打开 **GodotMCP** 面板，查看服务地址（默认 `http://127.0.0.1:3000/mcp`）
5. 在 AI 客户端中通过 HTTP transport 连接该地址即可
## 许可证
MIT License
Copyright (c) 2025
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
