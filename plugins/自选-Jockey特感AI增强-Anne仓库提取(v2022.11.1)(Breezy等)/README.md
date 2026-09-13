# Jockey 特感 AI 增强

## 简介

增强电脑 Jockey 接近和骑乘生还者时的移动行为，包括主动朝向、连跳加速、起跳角度调整和空中方向修正。

源码标注作者：`Breezy、High Cookie、Standalone、Newteee、cravenge、Harry、Sorallll、PaimonQwQ、夜羽真白、东`；插件内版本：`2022/11/1`。

- 自动选择最近且未倒地的生还者作为目标。
- 在配置距离内主动朝向目标并连跳加速。
- 根据目标是否正在观察 Jockey 调整骑乘起跳角度。
- 飞行方向偏离目标较大时修正空中速度方向。
- 骑中目标后可令附近其他生还者硬直。

## 来源说明

> [!NOTE]
> 本插件是从 **Anne 仓库提取** 的独立 Jockey AI 插件，并非本插件商店原创。

- Anne 上游仓库：<https://github.com/fantasylidong/CompetitiveWithAnne>
- 上游源码：<https://github.com/fantasylidong/CompetitiveWithAnne/blob/70cda19d7e98284a1d0bcb7d28221385f81829ab/addons/sourcemod/scripting/optional/AnneHappy/ai_jockey_new.sp>
- 上游路径：`addons/sourcemod/scripting/optional/AnneHappy/ai_jockey_new.sp`
- 提取基线：Anne 仓库提交 `70cda19d7e98284a1d0bcb7d28221385f81829ab`

该基线已经包含 2026-09-11 合并的 Jockey 空中移动高度判断修复。本条目保留 Anne 仓库中的 AI 逻辑和原作者信息。商店适配仅增加 `AutoExecConfig(true, "ai_jockey_new")` 和标准自动配置文件，并使用 SourceMod `1.11.0.6968` 重新编译。

## 依赖

- SourceMod 1.11 或更高版本。
- SourceMod 自带的 SDKTools。
- `必选-功能类插件(left4dhooks)(v1.155)(SilverShot)`，或 `必选-功能类插件(left4dhooks)(新版)(v1.168)(SilverShot)`。

不需要额外 Gamedata。

## 可用指令

无。

## 配置

标准自动配置文件位于 `cfg/sourcemod/ai_jockey_new.cfg`。安装包已经附带该文件；文件缺失时，插件也会通过 `AutoExecConfig` 自动重新生成。

配置项如下：

- `ai_JockeyBhopSpeed "80.0"`：每次连跳施加的推进速度。
- `ai_JockeyStartHopDistance "800.0"`：Jockey 距离目标多近时开始主动连跳。
- `ai_JockeyStumbleRadius "50.0"`：骑中后令附近生还者硬直的半径；设为 `0` 可关闭额外硬直。
- `ai_JockeyAirAngles "60.0"`：当前速度方向与目标方向的夹角超过该值时尝试空中转向，范围为 0～180。

插件还会读取游戏原生的 `z_jockey_leap_range`、`z_jockey_leap_again_timer` 和 `z_jockey_leap_time`。

## 注意事项

- 插件没有独立启用开关；安装到 `addons/sourcemod/plugins/` 后会自动生效。
- 默认 `ai_JockeyStumbleRadius "50.0"` 不只是 AI 优化，还会增强骑中后的范围压制。只需要智能移动时建议设为 `0`。
- 不要同时启用 `AI_HardSI` 的 Jockey 模块，否则两者会同时修改 Jockey 的跳跃、攻击和移动行为。
