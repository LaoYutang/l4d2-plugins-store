# L4D2 Survivor Bot Fix（生还者 Bot 增强）

## 简介

全面提升生还者机器人（AI 队友）的战斗与救援行为。

作者：`DingbatFlat`、`HarryPotter`；插件版本：`1.01`。

- 救助被控制或倒地的队友，近身时可推搡打断 Smoker / Jockey / Hunter。
- 主动清理普通感染者，近距离时自动切换近战武器。
- 攻击视野内的特殊感染者与 Tank，可配置"最近优先 / 特感优先 / Tank 优先"。
- 击退扑击飞行中的 Hunter 与跳跃中的 Jockey。
- 射落 Tank 投掷的石头。
- 暴怒 Witch 出现时集中射击；持霰弹枪时按距离控制开火时机，避免过近激怒或过远浪费。
- 主武器还有弹药时不允许切换副武器；危险状态下强制切回主武器。
- 倒地后仍可瞄准并攻击附近敌人。
- 可选择加强全部 / 随机 N 个 / 指定角色名的机器人。

## 来源说明

> [!NOTE]
> 本插件来自整合包"生还者 AI 究极增强"，上游为 AlliedModders 社区的 L4D2 Survivor Bot Fix（作者 `DingbatFlat`、`HarryPotter`）。本条目保留原作者信息，整合包中的中文 ConVar 说明原样保留。

商店适配改动：

- 修复 `player_incapacitated`、`player_death` 事件回调返回 `Plugin_Handled` 拦截事件的问题，改为 `Plugin_Continue`，避免加载顺序在其之后的插件收不到这两个事件。
- 为 4 个 Action 回调补全显式返回值，消除对应的编译警告，行为不变。
- 启用 `AutoExecConfig(true, "l4d2_sb_fix")`，并随包提供标准配置文件。
- 使用 SourceMod `1.11.0.6968` 重新编译（编译警告由 7 条降至 2 条，剩余 2 条为无害的数组赋值弃用提示）。

## 依赖

- SourceMod 1.11 或更高版本。
- SourceMod 自带的 SDKTools 与 SDKHooks。
- 无需 Gamedata，无需额外扩展。

## 可用指令

无，全部行为由 ConVar 控制。

## 配置

标准配置文件位于 `cfg/sourcemod/l4d2_sb_fix.cfg`，安装包已附带；文件缺失时插件会通过 `AutoExecConfig` 自动生成。

总开关与加强对象：

- `sb_fix_enabled "1"`：是否启用插件。等于 0 时以下其余模块全部停用。
- `sb_fix_select_type "0"`：加强哪些机器人。`0` 全部，`1` 随机 N 个，`2` 按角色名。
- `sb_fix_select_number "1"`：`sb_fix_select_type` 为 `1` 时随机加强的机器人数量。
- `sb_fix_select_character_name ""`：`sb_fix_select_type` 为 `2` 时要加强的角色名（空格分隔，如 `nick francis bill`）。
- `sb_fix_dont_switch_secondary "1"`：主武器还有弹药时禁止切换副武器。

救助队友：

- `sb_fix_help_enabled "1"`、`sb_fix_help_range "1200"`：启用救助及救助判定范围。
- `sb_fix_help_shove_type "3"`：推搡帮助的等级，`1` 只推 Smoker，`2` 加 Jockey，`3` 加 Hunter。
- `sb_fix_help_shove_reloading "0"`：为 `1` 时只在换弹时推搡帮助。

普通感染者：

- `sb_fix_ci_enabled "1"`、`sb_fix_ci_range "500"`：启用清理及搜索范围。
- `sb_fix_ci_melee_allow "1"`、`sb_fix_ci_melee_range "150"`：是否切近战清理及切换距离。

特殊感染者 / Tank：

- `sb_fix_si_enabled "1"`、`sb_fix_si_range "500"`：特感处理开关及范围。
- `sb_fix_si_ignore_boomer "1"`、`sb_fix_si_ignore_boomer_range "200"`：忽略并推开队友附近的 Boomer。
- `sb_fix_si_tank_priority_type "0"`：特感与 Tank 同时出现时的优先目标，`0` 最近，`1` 特感，`2` Tank。
- `sb_fix_tank_enabled "1"`、`sb_fix_tank_range "1200"`：Tank 处理开关及范围。
- `sb_fix_prioritize_ownersmoker "1"`：优先处理拖住自己的 Smoker。

推搡飞行特感：

- `sb_fix_bash_enabled "1"`：启用击退飞行中的 Hunter / Jockey。
- `sb_fix_bash_hunter_chance "100"`、`sb_fix_bash_hunter_range "100"`：推 Hunter 的几率与范围。
- `sb_fix_bash_jockey_chance "100"`、`sb_fix_bash_jockey_range "100"`：推 Jockey 的几率与范围。

Tank 石头与 Witch：

- `sb_fix_rock_enabled "1"`、`sb_fix_rock_range "700"`：射击 Tank 石头的开关与范围。
- `sb_fix_witch_enabled "1"`、`sb_fix_witch_range "1500"`：射击暴怒 Witch 的开关与范围。
- `sb_fix_witch_range_incapacitated "1000"`、`sb_fix_witch_range_killed "0"`：Witch 造成倒地 / 击杀后的额外索敌范围。
- `sb_fix_witch_shotgun_control "1"`、`sb_fix_witch_shotgun_range_max "300"`、`sb_fix_witch_shotgun_range_min "70"`：霰弹枪开火时机控制及距离区间。

其他：

- `sb_fix_incapacitated_enabled "1"`：启用倒地后的攻击指令。
- `sb_fix_debug "0"`：输出调试信息（开关时会播放提示音）。

## 注意事项

- 与"撤退类"机器人插件（如 `200IQBots` 系列的 FlyYouFools、DontFuckWithHerMan）同时使用时，机器人会在"被指挥射击坦克/特感"与"撤退"之间来回拉扯，建议只保留其中之一。
- 与电击救援类插件（如 `[L4D2] Defib using bots`）同装时：本插件在判定危险状态下会拦截切换到除颤器/医疗包，激烈战斗中可能影响电击救援。
- 性能：插件每帧对每个受控机器人扫描实体列表（普通感染者、Witch、石头），低配服务器或插件较多时可按需关闭对应模块（`sb_fix_ci_enabled`、`sb_fix_witch_enabled`、`sb_fix_rock_enabled`）。
- 插件会通过 `TeleportEntity` 修正机器人朝向以实现瞄准，属设计行为。