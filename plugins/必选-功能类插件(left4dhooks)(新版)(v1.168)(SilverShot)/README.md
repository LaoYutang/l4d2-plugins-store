## 简介

Left 4 Downtown 与 L4D Direct 的转换与合并，被大量插件依赖，必选。

> 这是新版 Hooks；插件商店同时保留 `1.155` 旧版供手动选择或回退。

> [!WARNING]
> 不要同时安装 `1.155` 和 `1.168` 两个版本的 Left 4 DHooks。升级或回退前，请先卸载当前版本，确保服务器中只保留一个 `left4dhooks.smx` 及其配套文件。

## 版本

- 当前版本：`1.168`（2026-06-18）
- 上游仓库：<https://github.com/SilvDev/Left4DHooks>
- 上游提交：`f90ae5e62228e0b7baf12cda922e3fd40db844f4`
- SourceMod：支持项目当前使用的 1.11

升级时请同时覆盖插件和 gamedata，不要只替换 `left4dhooks.smx`。

## 可用指令

大多数人用不到这些指令，除非你是插件开发者。

- `sm_l4dd_unreserve` 移除大厅预留（管理员指令）
- `sm_l4dd_reload` 重载拦截钩子，根据其他插件需求启用或禁用（管理员指令）
- `sm_l4dd_detours` 列出当前活动的转发及使用它们的插件（管理员指令）
- `sm_l4dhooks_reload` 重载拦截钩子，根据其他插件需求启用或禁用（管理员指令）
- `sm_l4dhooks_detours` 列出当前活动的转发及使用它们的插件（管理员指令）
