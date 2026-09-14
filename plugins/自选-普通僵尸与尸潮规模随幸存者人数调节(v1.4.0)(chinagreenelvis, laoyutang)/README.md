# 普通僵尸与尸潮规模随幸存者人数调节

## 简介

根据当前存活生还者人数调节普通僵尸上限和尸潮规模：四名及以下生还者使用基准值，超过四名后每多一名生还者按配置的增量叠加。

原版作者：`chinagreenelvis`；`1.4.0` 修改：`laoyutang`；版本：`1.4.0`。

- 每项数值 = 基准值 + 超出四名的生还者数 × 每玩家增量，五项设置可独立调整。
- 四名及以下生还者不再缩小数值（旧版会按人数比例减少）。
- 覆盖普通僵尸上限、背景僵尸数量、Mega-mob 规模、尸潮最小规模、尸潮最大规模、尸潮提示阈值共六个引擎 ConVar。
- 统计的生还者包含电脑生还者；需要至少一名真人生还者在线才会启用。
- 在生还者出生、死亡、被救出、换队以及灭团后重新计算，延迟 3 秒以等待游戏状态稳定。

## 配置

标准自动配置文件位于 `cfg/sourcemod/cge_l4d2_commonregulator.cfg`。安装包已经附带该文件；文件缺失时，插件也会通过 `AutoExecConfig` 自动重新生成。

每项设置由基准值和每玩家增量两个配置项组成，取值均为整数；增量填 `0` 表示超过四名后不再增加，填负数按 `0` 处理。

- `commonregulator "1"`：总开关。`1` 启用，`0` 禁用。
- `commonregulator_commons "30"`：四名及以下生还者时的普通僵尸数量上限，写入 `z_common_limit`。
- `commonregulator_commons_perplayer "8"`：超过四名后每多一名生还者增加的普通僵尸上限。
- `commonregulator_commons_background "20"`：四名及以下生还者时的背景僵尸数量，写入 `z_background_limit`。
- `commonregulator_commons_background_perplayer "5"`：超过四名后每多一名生还者增加的背景僵尸数量。
- `commonregulator_megamob "50"`：四名及以下生还者时的 Mega-mob 规模，写入 `z_mega_mob_size`。
- `commonregulator_megamob_perplayer "13"`：超过四名后每多一名生还者增加的 Mega-mob 规模。
- `commonregulator_mobmin "10"`：四名及以下生还者时的尸潮最小规模，同时用作尸潮提示阈值，写入 `z_mob_spawn_min_size` 和 `z_mob_min_notify_count`。
- `commonregulator_mobmin_perplayer "3"`：超过四名后每多一名生还者增加的尸潮最小规模。
- `commonregulator_mobmax "30"`：四名及以下生还者时的尸潮最大规模，写入 `z_mob_spawn_max_size`。
- `commonregulator_mobmax_perplayer "8"`：超过四名后每多一名生还者增加的尸潮最大规模。

默认配置下普通僵尸上限的变化：1～4 人 30，5 人 38，6 人 46，8 人 62。

## 可用指令

无。

## 注意事项

- 插件直接改写上表的引擎 ConVar，换图或卸载时不会还原。关闭 `commonregulator` 或卸载插件后，最后一次写入的值会继续生效，需要手动用 `sm_cvar` 改回、写进 `server.cfg` 或重启服务器才能恢复。
- 每次换图时 `server.cfg` 先执行，插件会在生还者事件触发时重新覆盖这些 ConVar，因此 `server.cfg` 中对上述六个 ConVar 的设置只在插件触发前有效。
- 只在生还者事件后 3 秒重算，不做周期性轮询；没有新事件时人数变化不会立即反映到数值上。
- 全 bot 局（没有真人生还者在线）不会启用；纯观察者或空服同样不生效。
- 结局关的尸潮规模由 `z_mob_spawn_finale_size` 控制，本插件不修改该值。
- 与其它修改同一批 ConVar 的插件同时使用时，以最后写入者为准。

## 来源说明

> [!NOTE]
> 原插件为 AlliedModders 论坛的 **Common Infected Regulator**（作者 chinagreenelvis），本仓库版本在其 `1.2.1` 源码基础上重写为 SourcePawn 新语法，并改为基准值 + 每额外生还者增量的数量模型。

- 原帖：<https://forums.alliedmods.net/showthread.php?t=171080>
