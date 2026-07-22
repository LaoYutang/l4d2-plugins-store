## 简介

为 Special Spawner 2.1.0 提供独立的参数投票功能，不修改多特感插件本体。

投票通过后由服务器执行原有的 `sm_timer` 或 `sm_limit` 管理命令，最终配置逻辑与原插件保持一致。

## 依赖

- `自选-多特感插件(v2.1.0)(Tordecybombo, breezy, laoyutang)`
- `必选-功能类插件(原生投票函数库)(v0.4)(Powerlord, fdxx)`

## 可用指令

- `sm_timervote <固定时间>` 发起固定特感刷新时间投票
- `sm_timervote <最小时间> <最大时间>` 发起特感刷新时间范围投票
- `sm_limitvote reset` 发起重置各类特感数量上限投票
- `sm_limitvote base <1-32>` 发起设置基础特感总上限投票
- `sm_limitvote increase <0.0-32.0>` 发起设置每名额外玩家上限增量投票
- `sm_limitvote <base> <increase>` 一次投票设置基础上限和人数增量
- `sm_limitvote <类型> <0-32>` 发起设置职业上限投票
  - 类型：`all` / `smoker` / `boomer` / `hunter` / `spitter` / `jockey` / `charger`

## 投票规则

- 所有在服真人均可发起和参与，包括旁观者；机器人和服务器控制台不能发起。
- 投票持续 20 秒，赞成票严格多于反对票时通过；平票视为失败。
- 同一时间只能进行一个原生投票。
