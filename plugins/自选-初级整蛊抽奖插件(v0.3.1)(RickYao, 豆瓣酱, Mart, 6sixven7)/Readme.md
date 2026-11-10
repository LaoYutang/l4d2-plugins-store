双奖池抽奖 0.3.0——奖池、概率和实际结算详细说明

一、版本范围与配置入口
本文件对应包内l4d2_dual_draw.sp及smx，两个奖池共46项：优先12项、普通34项。
已通过SourceMod 1.11编译和配置静态核对，尚未进服测试。
所有路径以下均相对于服务器left4dead2目录：
cfg/sourcemod/draw_settings.cfg：开关、限制、次数发放、效果参数。
cfg/sourcemod/draw_priority.cfg：仅优先奖池12项权重。
cfg/sourcemod/draw_normal.cfg：仅普通奖池34项权重。
cfg/sourcemod/draw_priority_memberlist.cfg：仅自动优先抽奖人员名单。

加载时依次执行上述四个文件，执行完后才发章节初始次数和启用优先触发。
缺失文件会自动生成；已有文件不覆盖。缺失的个别配置项使用代码默认值。
文件中已有数值才是重新加载时的实际配置，代码默认值不会强行覆盖它。
sm_cvar临时调整只影响内存，不自动保存文件，换图或重载后重新执行CFG。

二、整数权重的精确定义
优先奖池只累加draw_priority_weight_*；普通只累加draw_normal_weight_*。
总权重W由插件自动计算，不提供总概率Cvar，不要求W=100。
本项权重w为0时不会出现；w>0时本次抽取概率=w/W。
实现是从1到W随机选一个整数，使用各奖项的累计区间选出唯一结果。
每次抽取只执行一个奖项，没有先抽档位、再抽物品的第二级概率。
每次抽取后权重不减少，奖品不从池中移除，可以连续抽到同一项。
长期概率不是保底承诺；抽70次不保证得到30次某奖项。
权重按Cvar整数值读取，务必填非负整数。每项允许0到1000000。
初版所有权重默认10：优先总权重120，每项1/12≈8.333333%；
普通总权重340，每项1/34≈2.941176%。改变任一权重会改变同池其他所有奖项的概率。
两池独立，优先改30不会改变普通池概率。
优先总权重为0：暂停该次抽奖，无公示、无全员赠送；测试命令给本人解释。
普通总权重为0：不执行奖品、不扣普通次数，给本人解释。

例：满血权重30、处死权重40、其余全0，则W=70，分别30/70与40/70。
普通满血和优先个人加血并不是完全相同的奖项，不共享Cvar。
如果只改两个权重、保留其余默认10，分母仍包含其余项，不能当成70计算。

三、优先抽奖与全员赠送
自动触发只适用于名单中真人：安全门开/关累计超过阈值，或受支持物品的引燃/引爆提示。
门开、关各记1，默认阈值5即第6次触发后归零，普通门不计。
物品类型有八种独立开关；默认同一玩家同类型3秒内只提示并触发一次。
普通玩家引燃也会提示，但不因提示获得自动优先抽奖资格。
不是累计击杀或Tank击杀触发，本版已经改为门与物品触发。
优先抽奖不花费普通次数，也不需要先拥有普通次数。
每成功选出一个优先奖项，包括空奖，给每位当前在线真人增加
draw_normal_grant_on_priority（默认1）次普通机会，抽奖本人同样领取。
包括旁观、感染者队伍、死亡、闲置的真人；不向BOT或离线账号补发。
全服聊天公示；屏幕使用PrintHintTextToAll，连续结果排队，间隔draw_hud_seconds默认3秒。
屏幕提示可能被其他插件的同区域提示覆盖；没有子弹时间。
奖品执行失败仍完成本次优先结算，不重抽、不撤回全员次数，并公示未生效。
非空优先效果要求角色处于存活站立幸存者状态；物品归属确认时已死亡/倒地，
仍可结算抽取和赠送，但非空奖项不会施加。空奖可正常完成。

四、游客测试命令
聊天!drawpro（或/sm别名规则支持的/drawpro），玩家控制台sm_drawpro。
注册方式是RegConsoleCmd，不要求管理员权限，也不要求在优先名单。
测试只绕过名单与开门/引爆条件，使用同一PriorityDraw流程；并非模拟或只显示结果。
本人需为存活站立幸存者；插件需开启、配置已就绪、章节未结束、优先总权重大于0。
执行后实际给予奖品或惩罚，发全员次数，聊天和HUD公示，原因标注测试。
它不消耗普通次数，不改变名单，不增加门计数，不占物品触发冷却。
没有测试次数上限或额外冷却，所以游客可连续调用，每次实际结算都给全员赠送。
只测试一个奖项时，应将优先其他11项设0，该项设1，测试后恢复原配置。
若抽中处死，后续需复活并恢复站立状态才能继续使用测试命令。

五、优先奖池逐项说明
下列每项默认权重10；只有全部保持默认时，每项概率才是1/12。

P01 空奖
配置：draw_priority_weight_none "10"
作用：不产生角色效果。本次仍算完成一次优先抽奖，正常公示、给全员发普通次数。
参数：无专属效果参数。

P02 个人中毒
配置：draw_priority_weight_drug "10"
作用：对本人周期性改变视角侧倾，形成晃动效果；不扣生命。再次抽中会重置持续时间。
参数：draw_priority_drug_duration，默认30秒；每0.2秒更新视角。

P03 冰冻炸弹
配置：draw_priority_weight_freeze_bomb "10"
作用：本人获得冰冻炸弹和肾上腺素，倒计时结束后冻结半径内所有存活幸存者（包括本人和BOT），不要求其位于优先名单。再次抽中同类炸弹会取消当前炸弹，不再给予肾上腺素。
参数：draw_priority_freeze_bomb_countdown 默认8秒；draw_priority_freeze_duration 默认15秒；draw_priority_freeze_bomb_radius 默认500游戏单位。

P04 定时炸弹
配置：draw_priority_weight_time_bomb "10"
作用：本人获得定时炸弹和肾上腺素。到时处死本人，伤害附近存活幸存者（含BOT），伤害随距离线性降低。再次抽中同类炸弹取消当前炸弹。
参数：draw_priority_time_bomb_countdown 默认8秒；draw_priority_time_bomb_radius 默认500；draw_priority_time_bomb_damage 默认200。附近目标伤害=200×(1-距离/500)，边界外不伤害。

P05 生成Tank
配置：draw_priority_weight_tank "10"
作用：在本人当前坐标调用Left 4 DHooks生成一只Tank，不统计输出、不按视线选点。受位置、感染者槽位和游戏环境限制，可能生成失败。
参数：无额外数量/位置Cvar，当前每次尝试生成1只，无自动重试。

P06 生成Witch
配置：draw_priority_weight_witch "10"
作用：在本人当前坐标生成一只Witch，可能受出生位置或实体限制而失败。
参数：无额外数量Cvar，每次1只。

P07 限时个人低重力
配置：draw_priority_weight_moon "10"
作用：将本人重力倍率设为低重力值；再次抽中重置持续时间。与个人高重力共用一套效果，后一次覆盖前一次。到期恢复首次施加前的重力。
参数：draw_priority_moon_gravity 默认0.1；draw_priority_moon_duration 默认180秒。

P08 个人高重力
配置：draw_priority_weight_heavy "10"
作用：将本人重力设为高重力倍率，覆盖正在生效的个人低重力并取消其计时。没有独立持续时间，死亡、转队、回合结束等清理事件解除。
参数：draw_priority_heavy_gravity 默认3.0；参考插件说明的爬梯解除现象需要进服验证。

P09 个人处死
配置：draw_priority_weight_kill "10"
作用：直接处死本人。全员普通次数在执行处死之前发放，因此本人也领取本次赠送，死亡不清空已有次数。
参数：无额外参数。

P10 个人加血
配置：draw_priority_weight_heal "10"
作用：随机增加本人实血，结果显式限制到m_iMaxHealth；如果原实血已高于上限，不会反向扣血。不清空临时血量，不清除倒地次数。
参数：draw_priority_heal_min 默认200；draw_priority_heal_max 默认500。最小/最大颠倒时自动交换用于抽取。

P11 个人扣血
配置：draw_priority_weight_hurt "10"
作用：从本人实血扣除随机整数，实血最低留1。直接改实血，不触发普通伤害事件、不扣临时血量。
参数：draw_priority_hurt_min 默认200；draw_priority_hurt_max 默认500。最小/最大颠倒时自动交换用于抽取。

P12 个人缴械
配置：draw_priority_weight_disarm "10"
作用：清空本人0至4号槽位的武器、投掷物、医疗和药品，并移除实体；不会把武器作为奖励留在地上。
参数：无额外参数。

优先效果补充：
1. 虽然没有“全体奖项”，两种炸弹仍有范围效果，附近幸存者包括BOT会受影响。
2. 炸弹目标死亡、转队、断线、回合结束会取消，断线重连不恢复炸弹。
3. 冰冻炸弹与定时炸弹计时独立，可同时挂在同一人身上；本人被处死时另一炸弹取消。
4. 同类炸弹重复抽到取消，不是叠加多个炸弹；重复个人冰冻则刷新解除计时。
5. 冰冻不修改RGB颜色；恢复移动方式和重力时尽量使用施加前的值。
6. 药品/武器give可能改变同槽位物品，肾上腺素不是额外抽中的第二个奖项。
7. 删除的全局/全体奖项、无限弹药、子弹时间没有对应权重，不会因空缺而隐含出现。

六、普通奖池逐项说明
通过!ldw或兼容别名!draw打开菜单，选择“抽一次”，每次成功扣1次。
所有真人都有普通资格，优先名单不影响普通奖池概率，不另分普通用户名单。
实际抽取需为存活站立幸存者，倒地、挂边、死亡、旁观、感染者队伍可保留次数等待。
所有普通结果均聊天全服公示；初版普通结果不额外加入优先HUD队列。
下列每项默认权重10；只有34项全部默认时，每项概率才是1/34。

N01 全体幸存者补满实血
配置：draw_normal_weight_heal_all "10"
作用：将所有站立幸存者（含BOT）实血补到其m_iMaxHealth。不扶起倒地、不复活、不清除临时血量或倒地次数。

N02 清除普通感染者
配置：draw_normal_weight_clear_common "10"
作用：直接移除当前所有infected普通感染者实体，不清除Witch或特感，不视为玩家逐个击杀。

N03 处死全部感染者玩家
配置：draw_normal_weight_kill_infected "10"
作用：处死当前存活的感染者队伍玩家，包括BOT特感、Tank和真人感染者。可能引发服务器其他插件的死亡奖励。

N04 M16
配置：draw_normal_weight_rifle "10"
作用：给抽奖者执行 give rifle，获得M16。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N05 AK47
配置：draw_normal_weight_rifle_ak47 "10"
作用：给抽奖者执行 give rifle_ak47，获得AK47。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N06 军用连狙
配置：draw_normal_weight_sniper_military "10"
作用：给抽奖者执行 give sniper_military，获得军用连狙。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N07 猎枪
配置：draw_normal_weight_hunting_rifle "10"
作用：给抽奖者执行 give hunting_rifle，获得猎枪。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N08 自动霰弹枪
配置：draw_normal_weight_autoshotgun "10"
作用：给抽奖者执行 give autoshotgun，获得自动霰弹枪。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N09 SPAS
配置：draw_normal_weight_shotgun_spas "10"
作用：给抽奖者执行 give shotgun_spas，获得SPAS。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N10 铬合金霰弹枪
配置：draw_normal_weight_shotgun_chrome "10"
作用：给抽奖者执行 give shotgun_chrome，获得铬合金霰弹枪。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N11 泵动霰弹枪
配置：draw_normal_weight_pumpshotgun "10"
作用：给抽奖者执行 give pumpshotgun，获得泵动霰弹枪。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N12 沙漠步枪
配置：draw_normal_weight_rifle_desert "10"
作用：给抽奖者执行 give rifle_desert，获得沙漠步枪。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N13 榴弹发射器
配置：draw_normal_weight_grenade_launcher "10"
作用：给抽奖者执行 give grenade_launcher，获得榴弹发射器。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N14 乌兹
配置：draw_normal_weight_smg "10"
作用：给抽奖者执行 give smg，获得乌兹。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N15 消音冲锋枪
配置：draw_normal_weight_smg_silenced "10"
作用：给抽奖者执行 give smg_silenced，获得消音冲锋枪。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N16 Scout
配置：draw_normal_weight_sniper_scout "10"
作用：给抽奖者执行 give sniper_scout，获得Scout。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。 CSS狙击枪能否正常生成、模型和伤害表现需要在实际地图及武器解锁环境验证。

N17 AWP
配置：draw_normal_weight_sniper_awp "10"
作用：给抽奖者执行 give sniper_awp，获得AWP。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。 CSS狙击枪能否正常生成、模型和伤害表现需要在实际地图及武器解锁环境验证。

N18 医疗包
配置：draw_normal_weight_first_aid_kit "10"
作用：给抽奖者执行 give first_aid_kit，获得医疗包。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N19 止痛药
配置：draw_normal_weight_pain_pills "10"
作用：给抽奖者执行 give pain_pills，获得止痛药。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N20 肾上腺素
配置：draw_normal_weight_adrenaline "10"
作用：给抽奖者执行 give adrenaline，获得肾上腺素。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N21 电击器
配置：draw_normal_weight_defibrillator "10"
作用：给抽奖者执行 give defibrillator，获得电击器。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N22 马格南
配置：draw_normal_weight_pistol_magnum "10"
作用：给抽奖者执行 give pistol_magnum，获得马格南。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N23 棒球棒
配置：draw_normal_weight_baseball_bat "10"
作用：给抽奖者执行 give baseball_bat，获得棒球棒。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。 近战武器受地图近战列表和资源预加载影响，需进服验证。

N24 土制炸弹
配置：draw_normal_weight_pipe_bomb "10"
作用：给抽奖者执行 give pipe_bomb，获得土制炸弹。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N25 燃烧瓶
配置：draw_normal_weight_molotov "10"
作用：给抽奖者执行 give molotov，获得燃烧瓶。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N26 胆汁
配置：draw_normal_weight_vomitjar "10"
作用：给抽奖者执行 give vomitjar，获得胆汁。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N27 燃烧弹升级包
配置：draw_normal_weight_upgradepack_incendiary "10"
作用：给抽奖者执行 give upgradepack_incendiary，获得燃烧弹升级包。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N28 高爆弹升级包
配置：draw_normal_weight_upgradepack_explosive "10"
作用：给抽奖者执行 give upgradepack_explosive，获得高爆弹升级包。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N29 煤气罐
配置：draw_normal_weight_propanetank "10"
作用：给抽奖者执行 give propanetank，获得煤气罐。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N30 汽油桶
配置：draw_normal_weight_gascan "10"
作用：给抽奖者执行 give gascan，获得汽油桶。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N31 氧气罐
配置：draw_normal_weight_oxygentank "10"
作用：给抽奖者执行 give oxygentank，获得氧气罐。同槽位已有物品可能被替换或丢下，具体由游戏give行为决定。

N32 召唤Witch
配置：draw_normal_weight_witch "10"
作用：在抽奖者当前坐标生成1只Witch；位置或实体限制可能导致失败。

N33 连续两次尸潮
配置：draw_normal_weight_mob "10"
作用：以抽奖者身份连续执行两次z_spawn mob。实际尸潮数量和生成位置仍受游戏导演和地图环境影响。

N34 个人冰冻
配置：draw_normal_weight_freeze "10"
作用：冻结抽奖者本人，持续draw_normal_freeze_duration秒，默认50；重复施加刷新解除计时，不影响附近人。

七、执行失败、次数扣除及保留
普通菜单点击时重新验证身份、站立状态、余额与总权重，不能通过旧菜单绕过。
先扣1次再执行；能明确检测到执行失败时退还1次；不自动重抽。
give命令返回表示命令已提交，不保证引擎生成物品成功；缺少模型、其他插件拦截等，
当前不一定能检测并退款。Tank/Witch的生成返回失败可以检测。
普通次数按Steam2 ID在内存中记账，客户端槽位更换不会继承别人次数。
死亡/复活/闲置/转队/断线重连保留本章节余额；同地图团灭重开保留，不再领章节初始次数。
正常过关清空所有余额及本章领取标记（包括离线者）；新地图重新发初始次数。
默认章节初始次数draw_normal_grant_on_chapter=3，中途首次加入也只补领一次。
每次地图加载都视为新章节，包括手动换图/重新加载；插件重载/服务器重启不恢复内存。
改变章节初始Cvar不会立刻给已领取的人补差额；未领取者按领取时的当前值获取。
更改每次优先赠送Cvar会影响下一次优先结算，不修改已存在的余额。

八、CFG编辑、即时调试和重载
三个数值示例：
draw_normal_grant_on_priority "2"        // 每次优先抽奖给在线真人各2次
draw_normal_grant_on_chapter "5"         // 新章节每人初始5次
draw_normal_freeze_duration "10"         // 普通个人冰冻10秒
draw_priority_freeze_duration "6"        // 冰冻炸弹冻结目标6秒
draw_priority_freeze_bomb_countdown "4"  // 冰冻炸弹4秒后引爆

在对应CFG修改保存后，从服务器控制台执行对应文件，例如：
exec sourcemod/draw_priority.cfg
exec sourcemod/draw_normal.cfg
exec sourcemod/draw_settings.cfg
exec sourcemod/draw_priority_memberlist.cfg
无需重载smx，因此不会丢失本章普通次数。
只是保存文件不会自动被插件监控发现，需要exec或等待下一次换图执行。
管理员控制台即时测试例：
sm_cvar draw_priority_weight_kill 0
sm_cvar draw_normal_weight_rifle_ak47 40
拥有相应SourceMod管理权限时也可使用!cvar等该管理插件提供的聊天入口。
draw_*是ConVar；sm_ldw、sm_draw、sm_drawpro是玩家命令；
draw_priority_clear/add是只供服务器执行的名单命令，不能用sm_cvar当作数值修改。
名单文件示例：
draw_priority_clear
draw_priority_add "STEAM_1:0:12345678"
draw_priority_add "STEAM_1:1:23456789"
默认示例被//注释，不会把示例账号真正加入。Steam2 ID精确比较，不做格式转换或去重。

九、概率配置操作实例
只想测“空奖”：将优先12项全设0，再将draw_priority_weight_none设1。
!drawpro每次得到空奖，同时公示并发普通次数；这可先验证联动而不改变角色状态。
接着测试冰冻炸弹：其他仍0，none改0，freeze_bomb改1，设置倒计时4与冻结6。
多人靠近测试范围效果，倒计时结束后应冻结约6秒（最终效果仍需实服验证）。
普通池只允许AK和医疗包：先将普通34项全设0，再设置
draw_normal_weight_rifle_ak47 "30"
draw_normal_weight_first_aid_kit "40"
此时AK概率3/7，医疗包4/7，普通每次消费1机会。
不能把普通设置复制到优先CFG并期待相同项生效；两池key与奖项定义不同。

十、推荐核对步骤与兼容边界
1. 确认四CFG存在，服务器出现[Dual Draw] CFG loaded，核对两个权重总和。
2. 名单为空时，普通真人用!drawpro仍可测试；自动门/物品不会为他抽优先。
3. 将该真人加入新名单CFG并exec，检查门第6次触发以及物品提示触发。
4. 验证每次优先抽奖全员都增加指定普通次数，抽奖本人也增加。
5. 验证普通手动一次扣1，死亡不丢失，断线重连恢复，同图失败重开不重复领初始。
6. 正常过小关，旧余额清空，新章按配置给初始次数，旧离线账号不能带上章次数回来。
7. 逐项核对冰冻持续时间、爆炸倒计时、重力结束和角色状态限制。
旧Lucky Draw与本插件都注册sm_ldw，不建议同时加载。
旧安全门插件仍会处罚玩家，本插件不自动替其关闭封禁/踢出/处死。
旧Explosion Announcer同时加载会重复提示，本插件不依赖其运行。
同一物品的OnKilled与break_prop内部合并一次，连锁爆炸和自定义模型归属需实服核对。
所需编译include已在包内，运行仍依赖服务器安装Left 4 DHooks及匹配gamedata。

参考来源
L4D2_Lucky_Drawv.sp：用户提供，原文件没有明确作者信息。
L4D2 Tank Draw：Rick Yao，https://github.com/rick-yao/L4d2-plugin
l4d2_saferoomdoor：豆瓣酱な。
Explosion Announcer：Mart，https://forums.alliedmods.net/showthread.php?t=328006