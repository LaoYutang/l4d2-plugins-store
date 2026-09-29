# [L4D2]Witch_Double_Start_Fix（女巫重复惊吓动画修复）

## 简介

修复游荡中的女巫被惊动时把惊吓动画播两遍的问题，让女巫只尖叫一次并更快进入追击。

作者：`Lux`；插件版本：`1.0`。

- 女巫游荡时被惊动会先播放一段惊吓动画，原版逻辑会紧接着再播一次、中间还夹着待机动作，女巫因此醒得慢、出手晚。
- 插件给所有女巫挂 `SDKHook_Think`，检测到女巫正在播放惊吓动画（序列号 `30`）时把 `m_flCycle` 直接置为 `1.0`，立即结束该动画，取消第二次惊吓。
- 支持地图运行中加载：启用开关后场上已存在的女巫也会补挂钩子，不必等下一只女巫刷新。

## 来源说明

> [!NOTE]
> 本插件是从 **Anne 仓库提取** 的独立插件，原作者为 AlliedModders 论坛的 `Lux`，并非本插件商店原创。

- 上游发布帖：<https://forums.alliedmods.net/showthread.php?p=2647014>
- Anne 上游仓库：<https://github.com/fantasylidong/CompetitiveWithAnne>
- 上游路径：`addons/sourcemod/scripting/duoren/Witch_Double_Startle_Fix.sp`
- 提取基线：Anne 仓库提交 `607fb78e730847191d42be050b5ed0113fcc6704`

商店适配改动：

- 版本号 ConVar 由 `FCVAR_NOTIFY|FCVAR_DONTRECORD` 改为 `FCVAR_NONE|FCVAR_DONTRECORD`，不再出现在 A2S 规则列表里，并补上原本为空的 ConVar 描述。
- 增加地图运行中的加载支持（`AskPluginLoad2` 记录 `late`，并对已存在的女巫补挂 `SDKHook_Think`），使插件可以做成随时启停的开关。
- 把惊吓动画序列号提取为 `STARTLE_SEQUENCE` 常量。
- 使用 SourceMod `1.11.0.6968` 重新编译，0 警告。

## 依赖

- SourceMod 1.11 或更高版本。
- SourceMod 自带的 SDKTools、SDKHooks。
- 无需 Gamedata，无需额外扩展。

## 可用指令

无。

## 配置

无可配置的 ConVar。插件只创建一个带 `FCVAR_DONTRECORD` 的版本号 ConVar `witch_double_start_fix`，不会展示在 A2S 规则里。

## 注意事项

- 插件没有运行时开关，只能通过加载/卸载 `.smx` 启用或停用，这也是它需要支持地图运行中加载的原因。
- 与 `必选-修复类(v1.4)(修复女巫攻击错误的惊扰者)(Lux)` 修的是两个不同的问题（那个是女巫攻击了错误的惊扰者，这个是惊吓动画重复播放），可以同时启用。
- 实现方式是直接修改动画周期，不依赖签名和 Gamedata；若游戏更新调整了女巫动画表，需要重新确认惊吓动画的序列号。
- 只在 `witch` 实体上挂钩，不影响 Tank、特感 AI 和其他实体的行为。