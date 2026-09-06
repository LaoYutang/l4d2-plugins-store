# L4D2 插件商店仓库
本仓库是 [l4d2-server-next](https://github.com/LaoYutang/l4d2-server-next) 服务器面板的插件商店数据源，收录适用于L4D2专用服务器的各类**备选插件**，其他常用插件已包含在的面板中。
## 简介
面板会从本仓库读取插件列表，让服务器管理员可以通过图形界面浏览、安装和管理服务器插件，无需手动上传文件。
每个插件以独立文件夹的形式存放，文件夹内包含完整的 `left4dead2/` 目录树，可直接覆盖到服务器根目录使用。
## 目录结构
```
l4d2-plugins-store/
├── plugins/
│   ├── 插件名称(版本号)(作者)/
│   │   └── left4dead2/
│   │       ├── addons/sourcemod/
│   │       │   ├── plugins/        # 编译好的 .smx 插件文件
│   │       │   ├── scripting/      # .sp 源代码文件
│   │       │   ├── configs/        # 插件配置文件
│   │       │   └── translations/   # 翻译文件（含中文 chi/ 目录）
│   │       ├── cfg/sourcemod/      # ConVar 配置文件 (.cfg)
│   │       ├── scripts/vscripts/   # VScript 插件源码及加载入口 (.nut)
│   │       └── ems/                # VScript 使用的配置和数据
│   └── ...
└── LICENSE
```
## 如何贡献插件
若希望向本仓库贡献新插件，请确保：
1. **目录命名规范**：`自选-插件功能描述(版本号)(作者)`
2. **目录结构完整**：插件内容须放置于 `left4dead2/` 子目录下，保持与服务器目录一致的路径结构
3. **包含可运行文件**：SourceMod 插件须在 `addons/sourcemod/plugins/` 中包含 `.smx`；VScript 插件须在 `scripts/vscripts/` 中包含 `.nut` 和加载入口，无需 `.smx`
4. **包含源码与安装说明**：SourceMod 插件建议附上 `addons/sourcemod/scripting/` 下的 `.sp`；VScript 插件应说明共享加载文件（例如 `director_base_addon.nut`）的合并方式，避免覆盖其他插件
5. **配置文件齐全**：如有 ConVar 配置，请一并放入 `cfg/sourcemod/` 目录
提交方式：Fork 本仓库后发起 Pull Request。
## 相关项目
- **服务器面板**：[l4d2-server-next](https://github.com/LaoYutang/l4d2-server-next) - 使用本仓库作为插件商店数据源的 L4D2 服务器管理面板
## 许可证
本仓库以 [Apache License 2.0](LICENSE) 开源，各插件的版权归原作者所有。
