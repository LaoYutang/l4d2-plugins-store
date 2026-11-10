# 独立版 RGB 生还者轮廓与皮肤颜色

## 简介

让生还者玩家通过菜单分别选择自己的轮廓颜色和人物外观颜色，适合娱乐服务器使用。普通玩家无需管理员权限，但必须处于存活的生还者队伍才能打开菜单。

- 轮廓可选择多种固定颜色、动态彩虹色，或关闭自定义轮廓。
- 人物外观可选择多种颜色及“透明色”，或恢复默认颜色；这里的“皮肤”是人物染色，不是更换模型或材质包。
- 轮廓和皮肤可分别设置，不会自动为所有玩家或 BOT 分配颜色。
- 自定义轮廓可能干扰倒地、黑白或队友标记的辨识，安装前应检查服务器上其他同类插件。

## 安装与依赖

- 服务端需要已正常运行的 SourceMod，以及随其提供的 SDKTools、SDKHooks。
- 本条目保留运行文件 `left4dead2/addons/sourcemod/plugins/testrpg.smx` 和源码 `left4dead2/addons/sourcemod/scripting/testrpg.sp`，不再附带 `.inc` 头文件。已编译的 SMX 运行时不需要这些头文件。
- 不需要客户端安装额外 VPK、人物模型或材质包，也不需要配置数据库。
- 最低 SourceMod 版本及不同系统的兼容性尚未验证，不据此承诺所有版本均可运行。

通过面板插件商店选择本条目安装。手动安装时，先备份会被覆盖的文件，再将包内 `left4dead2/` 与服务器同名目录合并，不要多套一层目录。

首次安装后重启服务器，再按下方步骤确认加载和效果。

仅在重新编译源码时，才需要 SourceMod 完整开发环境中的标准 include，以及额外的 `colors.inc` 聊天颜色库。原包使用的 [`colors.inc` 1.3.2](https://github.com/LaoYutang/l4d2-plugins-store/blob/3788877620b5a13c0f77d310ddafac1e788777bc/plugins/%E8%87%AA%E9%80%89-%E7%8B%AC%E7%AB%8B%E7%89%88rgb%E7%94%9F%E8%BF%98%E8%BD%AE%E5%BB%93%E7%9A%AE%E8%82%A4%E9%A2%9C%E8%89%B2%28v0.6.1%29%28fantasylidong,%206sixven7%29/left4dead2/addons/sourcemod/scripting/include/colors.inc) 可从固定版本的仓库历史取得；不要用本插件的旧头文件覆盖平台自带的 SDK 文件。本次已使用 SourcePawn `1.11.0.6968` 与 `colors.inc` `1.2.3` 验证源码可编译，分发包仍保留原有 SMX。

## 可用指令

### 普通玩家指令

| 指令 | 执行位置 | 权限与条件 | 功能 |
| --- | --- | --- | --- |
| `sm_rgb` | 玩家的游戏控制台 | 无需管理员权限；必须处于存活的生还者队伍 | 打开自己的轮廓与皮肤颜色菜单，无需参数。 |

死亡、旁观或感染者玩家无法打开菜单。

### 管理员指令

无独立的管理员专用指令。管理员同样使用 `sm_rgb`，也必须处于存活的生还者队伍，只能设置自己的外观；本插件没有替其他玩家选色或统一重置全体颜色的管理命令。

### 服务器控制台与 RCON

本插件没有提供服务器控制台或 RCON 专用指令，不能通过 `sm_rgb` 替玩家选择颜色。下方排错使用的 `sm plugins list`、`sm exts list` 是 SourceMod 平台检查命令，不是本插件新增的指令。

## 使用方法

1. 玩家进入生还者队伍并保持存活，在自己的游戏控制台输入：
   ```text
   sm_rgb
   ```
2. 在菜单中选择“生还者轮廓”或“生还者皮肤”，再选择颜色，选中后立即应用。
3. 要取消某一项效果，在对应菜单中选择“关闭”。

同一次连接中，玩家死亡后复活或重新加入生还者队伍时，会重新应用此前选项；切换到感染者时会关闭外观效果。断开连接会清除选择，没有跨连接保存功能。

## 配置

本版没有对服主开放的 ConVar，也没有随包提供或自动生成的独立配置文件。玩家直接通过菜单设置外观，无需创建 `.cfg` 或数据库配置。

菜单中的“定制轮廓”和“定制皮肤”目前是固定预设，不提供输入任意 RGB 数值的功能。

## 注意事项与排错

- **与其他外观插件的组合需要实测。** 原说明已提醒注意倒地、黑白、标记相关插件的冲突；若颜色反复变化、状态提示被覆盖或关闭后仍异常，先关闭本插件菜单中的自定义效果，并在测试环境逐个排查同类插件。
- 原说明称换图或切换章节会清空所有玩家的选择，但目前未验证这一行为；服主不要依赖换图来统一重置颜色。
- 打开菜单后再切换队伍，旧菜单仍可能继续选色；切换队伍前请先关闭菜单。不要依赖热重载恢复默认外观，需要取消效果时先在对应菜单选择“关闭”。
- 本版保留了对 `l4d2_godframes_control_merge` 的可选配合处理，该插件不是必装依赖；两者同时使用的效果仍需实测。
- 菜单无法打开时，先确认玩家处于存活的生还者队伍，再在服务器控制台或 RCON 执行 `sm plugins list`，检查 `testrpg.smx` 是否加载。
- 插件加载失败时，检查运行文件是否位于 `left4dead2/addons/sourcemod/plugins/testrpg.smx`，并用 `sm exts list` 检查 SDKTools、SDKHooks。错误日志位于 `left4dead2/addons/sourcemod/logs/` 下的 `errors_*.log`。
- 反馈问题时请提供 SourceMod 版本、服务器系统、同类插件列表、复现步骤及脱敏后的相关错误日志，不要上传服务器密码或整份私有数据。

本说明依据随包源码和文件布局整理，未进行游戏内验证。

## 来源说明

本插件由 `6sixven7` 提交，改自东哥（`fantasylidong`）维护的 Anne 插件库，并非本插件商店原创。

保留原 README 中的来源说明：“将东哥的成品插件代码进行ai提纯，取消全部权限限制。”

- 上游仓库：[fantasylidong/CompetitiveWithAnne](https://github.com/fantasylidong/CompetitiveWithAnne)
- 原 README 提供的上游源码：[addons/sourcemod/scripting/extend/rpg.sp](https://github.com/fantasylidong/CompetitiveWithAnne/blob/ba9c824cfdd98909acdfab4092a0f3dbb48b935d/addons/sourcemod/scripting/extend/rpg.sp)
- 来源提交：`ba9c824cfdd98909acdfab4092a0f3dbb48b935d`。

当前商店目录标注 `v0.6.1`，随包源码声明版本为 `1.0-RGB`、作者字段为 `Modified by AI`；两种版本标记尚未统一，反馈问题时请同时注明。本次整理仅更新说明并移除随包头文件，没有修改插件源码或运行文件。
