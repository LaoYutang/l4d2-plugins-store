# Hunter 特感 AI 增强

## 简介

增强电脑 Hunter 的扑击决策和轨迹，使其根据距离、生还者视线和前方障碍选择快速扑击、直扑或侧扑。

作者：`Breezy`；插件版本：`1.0`。

- 近距离主动加快扑击节奏。
- 生还者正面观察 Hunter 时，根据配置随机改变扑击角度。
- 限制扑击的垂直角度，减少异常向上飞行。
- 可选检测正前方墙体，并向左或向右偏转扑击方向。
- 兼容 Hunter Patch 的蹲伏扑击相关 ConVar。

## 来源说明

> [!NOTE]
> 本插件是从 **Anne 仓库提取** 的独立 Hunter AI 插件，并非本插件商店原创。

- Anne 上游仓库：<https://github.com/fantasylidong/CompetitiveWithAnne>
- 上游源码：<https://github.com/fantasylidong/CompetitiveWithAnne/blob/607fb78e730847191d42be050b5ed0113fcc6704/addons/sourcemod/scripting/optional/AnneHappy/ai_hunter_new.sp>
- 上游路径：`addons/sourcemod/scripting/optional/AnneHappy/ai_hunter_new.sp`
- 提取基线：Anne 仓库提交 `607fb78e730847191d42be050b5ed0113fcc6704`

本条目保留 Anne 仓库中的 AI 逻辑和原作者信息。商店适配增加了 `AutoExecConfig(true, "ai_hunter_new")` 和标准自动配置文件，将插件自建 ConVar 统一放入 `anne_ai_hunter_*` 命名空间，并修正了视线判断把欧拉角直接当作方向向量使用的问题；最后使用 SourceMod `1.11.0.6968` 重新编译。

## 依赖

- SourceMod 1.11 或更高版本。
- SourceMod 自带的 SDKTools。
- `必选-功能类插件(left4dhooks)(v1.155)(SilverShot)`，或 `必选-功能类插件(left4dhooks)(新版)(v1.168)(SilverShot)`。

不需要额外 Gamedata。

## 可用指令

无。

## 配置

标准自动配置文件位于 `cfg/sourcemod/ai_hunter_new.cfg`。安装包已经附带该文件；文件缺失时，插件也会通过 `AutoExecConfig` 自动重新生成。

配置项如下：

- `anne_ai_hunter_fast_pounce_proximity "1000.0"`：距离最近生还者多近时开始快速扑击。
- `anne_ai_hunter_pounce_vertical_angle "7.0"`：限制 Hunter 扑击的垂直角度。
- `anne_ai_hunter_pounce_angle_mean "10.0"`：侧扑随机角度的高斯分布均值。
- `anne_ai_hunter_pounce_angle_std "20.0"`：侧扑随机角度的高斯分布标准差。
- `anne_ai_hunter_straight_pounce_proximity "200.0"`：距离低于该值时允许直接扑击。
- `anne_ai_hunter_aim_offset_sensitivity "180.0"`：判断生还者是否正在观察 Hunter 的视野角度，范围为 0～180。
- `anne_ai_hunter_wall_detection_distance "-1.0"`：前方墙体检测距离；`-1` 为关闭。

## 注意事项

- 插件没有独立启用开关；安装到 `addons/sourcemod/plugins/` 后会自动生效。
- 从旧商店包升级时需要替换 `cfg/sourcemod/ai_hunter_new.cfg`；旧的 `ai_*` 配置名不再生效。
- 距离小于 `anne_ai_hunter_straight_pounce_proximity` 时会按设计直扑；希望近距离也侧扑时可降低该值。
- 自建 ConVar 已经隔离，但仍不要同时启用 `AI_HardSI` 的 Hunter 模块；两者会同时修改 Hunter 的按键和扑击行为。
- 插件会修改若干原生 Hunter ConVar，并在卸载时恢复其默认值。
