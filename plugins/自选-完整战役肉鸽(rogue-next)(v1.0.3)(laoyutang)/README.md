## 简介

完整战役肉鸽：生还者直接击杀特感、Tank 或 Witch，获得团队经验；团队升级后，每名真人玩家获得一次个人 BUFF 三选一。包含 47 个 BUFF，适合在同一战役中连续成长。

作者：`laoyutang`；版本：`1.0.3`；插件文件：`rogue_next.smx`。

- 从团队 0 级开始，默认每升一级每人获得一次选择，初始 ROLL 为 5 次。
- 经验需求按等级线性增加，单级需求封顶，并按生还者总人数缩放，人数包含 BOT 和留队死者。
- 游戏难度决定击杀经验倍率：专家 1 倍、高级 1.5 倍、普通 2 倍、简单 3 倍，均可配置。
- 出门后按实际经过时间提升感染者强度，正常过关保留团队成长、个人 BUFF、候选与资源。
- 失败清档并返回当前战役首图，通关后清档；直接打完整个战役。
- 全部聊天提示和管理员回复统一使用 `[rogue]` 前缀。

## 依赖

- L4D2 与 SourceMod 1.11 或更高版本。
- SDKHooks 扩展，随 SourceMod 平台提供。
- Left 4 DHooks，可选用商店中的 `必选-功能类插件(left4dhooks)(新版)(v1.168)(SilverShot)`。

请先安装并启用依赖，确保运行插件、扩展和配套 gamedata 齐全。此条目不捆绑前置文件。

## 安装

1. 在新战役开始前部署。保留旧插件备用，先将服务器上的 `rogue_buff.smx` 和 `rogue_random_map.smx` 停用，例如移入 `addons/sourcemod/plugins/disabled/`；这两个旧插件仍在运行时，新版会拒绝加载。
2. 将本目录中的 `left4dead2/` 按原路径合并到服务器的 `left4dead2/` 目录。商店面板安装时会按该目录结构部署。
3. 使用 `sm plugins list` 检查 `rogue-next` 已加载，再通过 `sm_rn_info` 查看团队等级、游戏难度与经验倍率。

运行文件为 `addons/sourcemod/plugins/rogue_next.smx` 和 `cfg/sourcemod/rogue_next.cfg`；`addons/sourcemod/scripting/rogue_next.sp` 及其同名子目录提供完整源码。

新版自动执行 `rogue_next.cfg`。旧版的 `playbuff_*` 参数需要按新版 `rne_*` 参数重新配置；旧配置可保留供切回使用。

## 可用指令

### 玩家指令

- `sm_ba` / `sm_buffadd` 打开三选一菜单，聊天中可输入 `!ba` / `!buffadd`。
- `sm_buff` / `sm_b` 查看个人 BUFF、团队等级与全队武器层数，聊天中可输入 `!buff` / `!b`。
- 双击 K 打开选卡，双击 L 查看 BUFF；默认双击间隔为 300 毫秒，首击静默。
- 菜单中的 ROLL 消耗一次 ROLL，替换当前三个候选。

自动绑定可能受到客户端限制，可在游戏控制台手动绑定：

```text
bind k sm_rn_k
bind l sm_rn_l
```

默认需存活、未倒地且未被特感控制才能选卡；查看 BUFF 不要求存活。关闭菜单、超时、断线重连和正常换图都会保留当前候选。

### 管理员指令

以下指令要求 ROOT 权限，服务器控制台或 RCON 也可执行。

- `sm_rn_info [userid 或 SteamID64]` 查看战役、计时、团队与玩家档案；userid 也支持 `#` 前缀。
- `sm_rn_xp <非负整数>` 为团队增加指定经验，按当前人数结算，不额外乘游戏难度倍率。
- `sm_rn_level <非负整数>` 设置团队等级并清空当前升级进度；降低等级不会追回已获得的 BUFF 或历史消费。
- `sm_rn_reset` 清空成长，在当前地图建立新对局；已经出门时从此刻重新计时。

## 配置

全部 99 项配置统一位于 `cfg/sourcemod/rogue_next.cfg`，包含核心规则、击杀经验、难度倍率、BUFF 数值和交互设置。随包 cfg 使用 SourceMod 自动生成格式，完整注释与默认值均保留。

主要参数：

| 参数 | 默认值 | 作用 |
| --- | --- | --- |
| `rne_enable` | `1` | 总开关；关闭后保留成长与候选，暂停时钟并撤销效果 |
| `rne_debug` | `0` | 经验和生命周期调试日志 |
| `rne_initial_choices` | `0` | 初始选择次数 |
| `rne_choices_per_level` | `1` | 每升一级增加的选择次数 |
| `rne_initial_rolls` | `5` | 初始 ROLL 次数 |
| `rne_xp_base` | `100` | 4 人基准首次升级需求 |
| `rne_xp_step` | `54` | 每升一级增加的基准经验需求 |
| `rne_xp_need_cap` | `1200` | 单级基准经验需求上限，封顶后再按人数缩放 |
| `rne_xp_count_bots` | `1` | BOT 的直接击杀也提供团队经验 |
| `rne_xp_scale_by_players` | `1` | 按生还者总人数，包含 BOT，缩放经验需求 |
| `rne_scaling_enable` | `1` | 时间难度开关；关闭后暂停难度时钟 |
| `rne_scaling_interval_min` | `5` | 每档难度所需的有效游戏分钟 |
| `rne_scaling_wait_leavesafe` | `1` | 等待首次出门启动计时 |
| `rne_scaling_ignore_empty` | `1` | 无真人连接时暂停计时 |
| `rne_scaling_max_tier` | `0` | 难度档位上限，0 表示不限 |
| `rne_doubletap_ms` | `300` | K/L 双击间隔，单位为毫秒 |
| `rne_auto_bind` | `1` | 尝试自动绑定 K/L |
| `rne_menu_in_combat` | `0` | 是否允许倒地或被控时选卡 |

八类击杀的基准经验：

| 击杀目标 | 参数 | 默认经验 |
| --- | --- | --- |
| Smoker | `rne_xp_smoker` | `10` |
| Boomer | `rne_xp_boomer` | `5` |
| Hunter | `rne_xp_hunter` | `12` |
| Spitter | `rne_xp_spitter` | `10` |
| Jockey | `rne_xp_jockey` | `12` |
| Charger | `rne_xp_charger` | `15` |
| Witch | `rne_xp_witch` | `40` |
| Tank | `rne_xp_tank` | `100` |

游戏难度经验倍率：

| 游戏难度 | `z_difficulty` | 参数 | 默认倍率 |
| --- | --- | --- | --- |
| 专家 | `Impossible` | `rne_xp_rate_expert` | `1.0` |
| 高级 | `Hard` | `rne_xp_rate_hard` | `1.5` |
| 普通 | `Normal` | `rne_xp_rate_normal` | `2.0` |
| 简单 | `Easy` | `rne_xp_rate_easy` | `3.0` |

实际经验 = 基准经验 × 击杀时的游戏难度倍率，八类目标和 BOT 击杀都适用，小数经验也计入团队进度。例如高级难度击杀一只 Boomer 获得 7.5 XP，两只共 15 XP。

基准经验必须为非负整数，倍率允许有限非负小数；0 可关闭对应目标或难度的击杀经验，非法值会回滚。未知游戏难度使用配置中的专家倍率。

修改 cfg 后执行 `exec sourcemod/rogue_next.cfg`。击杀经验与倍率热改、切换游戏难度只影响后续击杀，保留当前等级、升级百分比、候选与 ROLL。初始选择、每级选择和初始 ROLL 在新战役或 `sm_rn_reset` 时生效。

升级已有版本时，先备份并合并原配置。1.0.3 在统一 cfg 中增加了四项游戏难度倍率；八类基准经验也使用该 cfg，无需额外的经验文件。

## 成长与难度

4 人基准的单级经验需求为 `min(100 + 54 × 当前等级, 1200)`，再乘生还者总人数 / 4；默认人数系数限制在 0.25～4.0。经验需求上限不会限制团队等级。

专家默认 1 倍经验下，按每名生还者每 20 秒 2 只特感、每只参考 10 XP 估算，约 30 分钟到 15 级、51 分钟到 20 级；实际节奏由击杀供给决定。插件不负责刷新特感，无需指定的多特插件。

默认首次出门、打开起点门或首次有效击杀时启动时间戳计时，每 5 个有效分钟提升一档难度。每档感染者血量与伤害默认增加 6.7%，Tank 移速增加 3.3%；Tank 出生还默认应用 2 倍血量及人数缩放。血量和 Tank 移速按出生时档位确定，伤害按当前档位确定，升档不会为已有感染者补血。

回安全屋、倒地、死亡和旁观都不停表；总开关关闭、时间难度关闭或无真人连接时暂停计时，重叠暂停只扣一次。正常换图累计有效时间。

正常下一章节保留成长；失败清档并于两秒后返回当前战役首图；终局清档。新战役、手动换图或返回首图会建立新对局。玩家重连恢复本次对局的档案；插件重载或服务器重启后，内存中的成长不会保存。

D4 按历史应得选择总预算兑换并重抽；繁星兑换预算后默认发放十次新选择，不补发历史或初始 ROLL。双生花复制手选的普通卡与资源卡，不复制 D4、繁星或自身。

## 编译

唯一编译入口为 `addons/sourcemod/scripting/rogue_next.sp`。保留 `scripting/rogue_next/` 下全部 20 个模块，模块不可单独编译。安装对应的 SourceMod 编译器和 Left 4 DHooks include 后，在 `left4dead2/` 下执行：

```text
spcomp addons/sourcemod/scripting/rogue_next.sp -iaddons/sourcemod/scripting/include -oaddons/sourcemod/plugins/rogue_next.smx -E
```

## 验证

1.0.3 已在源码项目中通过 SourcePawn 1.11.0.6968 零警告编译和 12 组离线测试，共 236 项断言。此条目的运行文件与源码项目发布包一致。

离线测试使用模拟宿主执行正式模块字节码。完整战役、真实客户端菜单、与其他插件的配合以及至少 60 分钟稳定性仍待 L4D2 实服验收，首次部署请在测试服务器验证。
