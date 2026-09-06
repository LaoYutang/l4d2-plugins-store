## 简介

随机生成 F18 空袭、爆炸特效和角色反应语音，默认支持战役和写实模式。使用游戏自带 VScript，无需额外前置；爆炸会伤害生还者。

原作者：[ChimiChamo](https://steamcommunity.com/sharedfiles/filedetails/?id=3163466945)，修改：laoyutang。

## 可用指令

在服务器控制台执行（远程连接可用 RCON）：

| 指令 | 说明 |
|---|---|
| `script DirectorScript.ChCh_RandomAirStrikes.Diagnose()` | 输出地图、更新状态、等待原因和选点结果，不产生空袭 |
| `script DirectorScript.ChCh_RandomAirStrikes.TestAirStrike()` | 离开安全区后立即尝试无炸弹试飞，跳过概率和等待时间，保留地图及落点限制 |

正常运行日志会显示 `State: ready`、`Strike #`；无法选点时最多每 30 秒输出一次原因。`map_disabled` 表示当前地图被配置禁用。

## 修改项

- v1.0.2：修复上方碰撞导致整批落点被拒绝的问题，按净空降低飞机高度；补充导航缓存重试、运行日志及诊断/试飞指令。
- v1.0.1：修复射线未返回 `startsolid` 等字段时空袭中断的问题，兼容选点、净空和踉跄检测。
- 修复选点失败时无限递归的问题，限制重试次数。
- 增加落点距离、地面及上方净空检测，排除安全区导航、水下和阻塞区域。
- 补齐飞机、粒子、爆炸和音源清理，修复回合重开时的状态与延迟回调问题。
- 踉跄范围跟随配置，仅影响视线未受阻的存活生还者，移除重复爆炸音效。
- 增加配置类型和范围校验，兼容原版配置，错误时使用默认值。

## 默认配置

配置文件：`left4dead2/ems/random_airstrikes/Settings.cfg`，修改后下一回合生效。

| 参数 | 默认值 | 说明 |
|---|---|---|
| `allowed_gamemodes` | `["coop", "realism"]` | 允许的基础模式 |
| `disallowed_maps` | 见下方列表 | 禁用空袭的地图 |
| `one_in_what_chance` | `20` | 每次抽签概率为 1/20 |
| `flow_percent_dist_variance` | `5` | 与领先生还者的路线进度差，单位为百分点 |
| `air_strike_delay` | `75` | 成功生成飞机后的冷却秒数 |
| `drop_bomb` | `1` | 1 开启爆炸，0 仅飞越 |
| `summon_horde` | `0` | 1 在爆炸后重置导演尸潮计时 |
| `explode_radius` | `500` | 爆炸及踉跄半径，游戏单位 |
| `explode_dmg` | `200` | 爆炸强度 |
| `initial_delay` | `40` | 首人离开安全区后的等待秒数 |
| `check_interval` | `1.0` | 两次抽签的最小间隔秒数 |
| `max_position_attempts` | `16` | 每次空袭最多尝试的导航区域数 |
| `max_strike_distance` | `1500` | 落点距领先生还者的最大直线距离 |
| `plane_height` | `2048` | 飞机最大相对高度；遇上方碰撞自动降低，最低 256，预留 128 单位净空 |

默认禁用地图：`c1m1_hotel`、`c1m3_mall`、`c1m4_atrium`、`c5m4_quarter`、`c8m2_subway`、`c8m4_interior`、`c10m2_drainage`、`c11m4_terminal`、`c12m5_cornfield`。

## 注意事项

净空检测不能精确区分天空和屋顶，高顶室内也可能触发空袭。

已有 `director_base_addon.nut` 时，保留原内容并合并 `IncludeScript("chch_airstrike", this);`，避免覆盖其他插件的加载项。
