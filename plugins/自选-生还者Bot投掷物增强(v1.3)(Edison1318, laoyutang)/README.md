# [L4D2] Bot Throw Grenade（生还者 Bot 投掷物增强）

## 简介

让生还者机器人自动使用、装备和投掷投掷物。

作者：`Edison1318`、`laoyutang`（商店适配与修复）；插件版本：`1.3`。

- 机器人距 Tank 500 单位内且手持燃烧瓶/胆汁时，会自动瞄准 Tank 并投掷（3.5 秒冷却）。
- 提供一整套管理员命令，可强制机器人装备或投掷指定投掷物。
- 随机命令会从"持有投掷物的机器人"中随机选一个执行。

## 来源说明

> [!NOTE] 本插件来自整合包"生还者 AI 究极增强"，上游为 AlliedModders 论坛的 [L4D2] Bot Throw
> Grenade（作者 `Edison1318`）。本条目保留原作者信息。

商店适配改动：

- 修复随机命令的非法目标问题：场上没有持有投掷物的机器人时，`GetRandomPlayer` 返回
  `-1`，原代码会继续对其调用
  `FakeClientCommand`、`GetClientUserId`，产生运行时错误；现在改为提示"没有找到持有投掷物的生还者机器人"并安全返回。
- 同类修复：`GrenadeDelay` 延迟投掷函数增加相同的有效性判断。
- 定时器回调（`Command_MakeBotShoot`、`StopShooting`）增加客户端有效性检查，机器人中途退出时不再写入无效索引。
- 启用 `AutoExecConfig(true, "l4d2_botgrenade")`，并随包提供标准配置文件。
- 修复静态数组初始化的弃用写法（`static shoot[MAXPLAYERS + 1] = 0;`
  改为依赖默认零初始化），消除编译警告。
- 使用 SourceMod `1.11.0.6968` 重新编译，0 警告。

## 依赖

- SourceMod 1.11 或更高版本。
- SourceMod 自带的 SDKTools。
- 无需 Gamedata，无需额外扩展。

## 可用指令

全部命令需要 `ROOT` 权限（`ADMFLAG_ROOT`，即 `z` 标志）。

投掷：

- `sm_botthrowgrenade`：命令所有机器人投掷手中投掷物。
- `sm_botthrowpipebomb`、`sm_botthrowmolotov`、`sm_botthrowvomitjar`：命令所有机器人投掷指定投掷物。
- `sm_botthrowrandomgrenade`：随机选一个机器人投掷手中投掷物。
- `sm_botthrowrandompipebomb`、`sm_botthrowrandommolotov`、`sm_botthrowrandomvomitjar`：随机选一个机器人投掷指定投掷物。

装备：

- `sm_botgrenade`：命令所有机器人切出投掷物。
- `sm_botpipebomb`、`sm_botmolotov`、`sm_botvomitjar`：命令所有机器人切出指定投掷物。

## 配置

标准配置文件位于 `cfg/sourcemod/l4d2_botgrenade.cfg`，安装包已附带；文件缺失时插件会通过
`AutoExecConfig` 自动生成。

- `l4d2_tank_grenade "1"`：是否允许机器人对 Tank 自动投掷投掷物。`0` 关闭，`1` 开启。

## 注意事项

- 自动投掷的 3.5 秒冷却为全队共享：任意一个机器人触发投掷后，短时间内所有机器人都不会自动投掷。
- 随机命令的随机范围是"所有持有投掷物的机器人"：例如 `sm_botthrowrandompipebomb`
  可能选中只持有燃烧瓶的机器人，此时该次命令不会产生投掷效果。
- 自动投掷仅在机器人持有燃烧瓶或胆汁时触发，土制炸弹不参与自动投掷。
