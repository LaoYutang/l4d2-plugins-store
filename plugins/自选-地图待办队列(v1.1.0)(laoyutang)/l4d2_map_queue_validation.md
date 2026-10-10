# 地图待办队列 1.1.0 验证记录

日期：2026-10-07。范围仅为 `l4d2_map_queue`，未修改 `map_changer`、地图投票、面板或其他插件，未部署到实服。

## 仓库验证

- 项目 SourcePawn 编译器 1.11.0.6968，使用 `-E`，零警告。
- `tests/map_queue/harness.sp` 包含实际插件源码及切换模块，在 PySMX 0.4.0 中执行生产字节码。
- 9 组回归，共 91 项断言通过。模拟的是 native/引擎边界；队列修改、持久化事务、消息回调、定时器回调和状态判断来自真实 SourcePawn 实现。
- 消息钩子场景禁止 SDK 读取、切图和发送用户消息，确保操作延后执行。
- PySMX 的 typeset、枚举返回值与堆作用域处理使用宿主元数据修正，未替换队列算法。

| 回归组 | 断言数 | 主要结果 |
| --- | --- | --- |
| Finale | 10 | 原事件默认 3 秒和 0.1 秒调度保留；统计不抢跑；未知模式暂缓；丢失调度可兜底。 |
| Stats | 11 | 无原事件时下一帧切换；重复信号、重复项目、暂停、耗尽及普通章节处理正确；暂停统计完成在卸载前保存，覆盖外部插件先触发卸载。 |
| Lobby | 18 | 缺少/被拦截的统计可兜底；同一目标不重复出队；保存失败放行；失败恢复原字节及接收者身份；覆盖空载荷和超限载荷。 |
| Failures | 9 | 保存回滚、BSP 失效、目录暂不可读、有限重试、慢加载和真实目标确认。 |
| Reconnect | 9 | 旧地图断开回调失效；新图缓冲；连接中长加载保留状态；真空服、休眠唤醒及模式变化。 |
| Cancellation | 10 | 清空、暂停、跳过取消旧请求；空服 RCON 直接启动/跳过。 |
| Restart | 7 | 团灭保留项目；原地重开清通关上下文；迟到的 runafter；重载回队首并停止。 |
| Compatibility | 13 | map_changer 配置接管与恢复；空目录缓存；可选 native 动态可用性；外部换图语义；原 run 行为。 |
| Protocol | 4 | status 字段、MQ_LIST schema=1、活动项及记录数量保持一致。 |

复现命令（Linux；编译器无执行权限时复制到临时目录并授权，不修改仓库二进制权限）：

```bash
python3 -m venv .venv
.venv/bin/pip install -r tests/rogue_next/requirements.txt
cp addons/sourcemod/scripting/spcomp64 /tmp/map-queue-spcomp64
chmod +x /tmp/map-queue-spcomp64
.venv/bin/python tests/map_queue/run_tests.py --compiler /tmp/map-queue-spcomp64
python3 tools/build_map_queue.py
```

打包工具使用同一编译器与 `-E`，更新仓库 SMX、未压缩 dist，生成 ZIP 并逐文件校验字节一致。包根仅包含 Markdown 文档和 `left4dead2/`；不包含实服队列数据、依赖插件、测试夹具或开发工具。校验清单为 `manifest.md`。

## 实服验收待完成

没有 L4D2 服务器或真实客户端，本轮不能证明 Freezing Point 的实际事件顺序、玩家网络重连、大厅消息的真实载荷或 SDK 切图在目标服上的表现。离线 fixture 通过不等于实服验收完成。

部署 1.1.0 后，应记录实际版本、CFG 和 SourceMod 日志，并验收：

1. Freezing Point 从第一章连续到后续章节，刷新面板时保持当前项及“跳过当前”。
2. 官方战役终局保持原延迟；缺原终局事件的三方战役由统计兜底进入下一项。
3. 统计缺失/被拦截时的返回大厅兜底，包含切图失败后原大厅通知恢复；核对实际消息长度和客户端行为。
4. 章节过图全员断开再重连、加载超过 30 秒但已建立连接、真的无人以及服务器休眠。
5. 中途跳过、暂停、清空、管理员手动换图；确认不会被旧回调再次切换。
6. 有/无 map_changer 和可选 L4D2_ChangeLevel 的真实部署组合；正常终局没有双方重复切图。

用户报告的“进行到后续章节时已停止”尚无实服日志确认根因。新版为相关断开、加载和失败路径增加保护与诊断；插件重载/重启仍按既有规则停止，不能将这类恢复误认为普通章节过图。
