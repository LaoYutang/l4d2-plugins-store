## 简介

多特感插件

## 数量模型

```text
额外人数 = max(幸存者人数 - ss_base_players, 0)
总上限 = ss_base_limit + RoundToNearest(ss_extra_limit × 额外人数)
```

默认配置为基准人数 4、基础上限 4、每增加一名幸存者增加 1.0 个特感上限。

物理客户端槽位不足时，实际特感数量可以低于上述目标；`g_iSILimit` 的人数缩放结果不会因此改变。

## 可用指令

- `sm_weight <类型> <比重>` 设置特感生成比重（管理员指令）
  - 类型：`reset`（重置默认）/ `all`（全部）/ `smoker` / `boomer` / `hunter` / `spitter` / `jockey` / `charger`
  - 比重：`>= 0` 的整数
- `sm_limit reset` 重置六种职业上限（管理员指令）
- `sm_limit base <1-32>` 设置基础特感总上限（管理员指令）
- `sm_limit increase <0.0-32.0>` 设置超过基准人数后每增加一人的上限增量（管理员指令）
- `sm_limit <base> <increase>` 一次设置基础上限和人数增量（管理员指令）
- `sm_limit <类型> <0-32>` 设置职业上限（管理员指令）
  - 类型：`all` / `smoker` / `boomer` / `hunter` / `spitter` / `jockey` / `charger`
- `sm_timer <固定时间>` 或 `sm_timer <最小时间> <最大时间>` 设置特感生成时间（管理员指令）
  - 固定时间：设为固定秒数（最小 0.1）
  - 最小/最大时间：设置随机范围（最小 >= 0.1，最大 >= 1.0 且大于最小值）
- `sm_resetspawn` 处死所有特感并重新开始生成计时（管理员指令）
- `sm_forcetimer` 或 `sm_forcetimer <时间>` 手动开始生成计时（管理员指令）
  - 不填时间则立即开始，填写时间则指定下次生成等待秒数
- `sm_type <类型>` 切换特感轮换模式（管理员指令）
  - `off` 关闭单一特感模式，恢复默认
  - `random` 随机轮换一种特感模式
  - `smoker` / `boomer` / `hunter` / `spitter` / `jockey` / `charger` 只刷指定特感
