# E+R 物品获取 1.3.0

作者：绪花✧(≖ ◡ ≖✿) | Ross | 鱼鱼 | laoyutang

生还者同时按住 **E + R** 打开物品获取菜单，可以选择副武器、小枪、大枪及管理员允许的物品。

## 安装

服务器需要安装 SourceMod 1.11 或更新版本，并正常加载 Left4DHooks。

将交付目录中的 `left4dead2/` 内容复制到服务器对应目录：

- 插件：`addons/sourcemod/plugins/l4d2_getitem.smx`
- 配置：`cfg/sourcemod/l4d2_getitem.cfg`

启动服务器或重载插件后生效。配置文件不存在时，插件会自动生成标准 SourceMod cfg；已有文件保留原设置。

## 默认设置与配置

默认开启副武器和小枪，关闭大枪和全部 18 种物品，仅允许安全区域内获取。安全区域包含地图标记的出生安全区和检查点安全区。

| 配置项 | 默认值 | 含义 |
| --- | --- | --- |
| `l4d2_meleedefault` | `1` | 副武器菜单；0 关闭，1 开启 |
| `l4d2_initialgundefault` | `1` | 小枪菜单，包含备弹；0 关闭，1 开启 |
| `l4d2_AdvancedGunOpen` | `0` | 大枪菜单；0 关闭，1 开启 |
| `l4d2_safearea` | `1` | 0 允许安全区域外获取，1 仅允许安全区域内获取 |

每种物品都有独立开关，默认均为 `0`；改为 `1` 后允许获取：

| 物品 | 配置项 |
| --- | --- |
| 医疗包 | `l4d2_getitem_allow_first_aid_kit` |
| 除颤仪 | `l4d2_getitem_allow_defibrillator` |
| 止痛药 | `l4d2_getitem_allow_pain_pills` |
| 肾上腺素 | `l4d2_getitem_allow_adrenaline` |
| 燃烧瓶 | `l4d2_getitem_allow_molotov` |
| 土制炸弹 | `l4d2_getitem_allow_pipe_bomb` |
| 胆汁瓶 | `l4d2_getitem_allow_vomitjar` |
| 燃烧弹药包 | `l4d2_getitem_allow_upgradepack_incendiary` |
| 高爆弹药包 | `l4d2_getitem_allow_upgradepack_explosive` |
| 汽油桶 | `l4d2_getitem_allow_gascan` |
| 煤气罐 | `l4d2_getitem_allow_propanetank` |
| 氧气瓶 | `l4d2_getitem_allow_oxygentank` |
| 烟花箱 | `l4d2_getitem_allow_fireworkcrate` |
| 可乐瓶 | `l4d2_getitem_allow_cola_bottles` |
| 圣诞老人（侏儒） | `l4d2_getitem_allow_gnome` |
| 燃烧弹药 | `l4d2_getitem_allow_incendiary_ammo` |
| 高爆弹药 | `l4d2_getitem_allow_explosive_ammo` |
| 激光瞄准器 | `l4d2_getitem_allow_laser_sight` |

例如，默认开放大枪、医疗包、止痛药与激光瞄准器，并允许安全区外获取，在 cfg 中修改对应行：

```cfg
l4d2_AdvancedGunOpen "1"
l4d2_getitem_allow_first_aid_kit "1"
l4d2_getitem_allow_pain_pills "1"
l4d2_getitem_allow_laser_sight "1"
l4d2_safearea "0"
```

**cfg 定义启动默认值。** 修改文件后，在服务器控制台执行以下命令，或重启服务器：

```text
sm plugins reload l4d2_getitem
```

切图、回合重开，以及手动执行 `exec sourcemod/l4d2_getitem.cfg` 都不会覆盖当前运行中的菜单开关；重载插件或重启服务器才会重新采用 cfg。单独修改控制台中的这些 CVar 也不会立即改变当前菜单。

## 管理员菜单

沿用原插件权限：管理员免疫等级至少为 50 时，总菜单显示管理员菜单，可以开关副武器、小枪、大枪、逐项物品以及安全区限制。拥有通用管理权限的管理员也可以用 `!getitem` 打开总菜单。

菜单修改立即生效，跨地图和回合保留，不保存到 cfg；服务器重启或插件重载后恢复为 cfg 设置。关闭的分类或物品不能通过已经打开的旧菜单继续获取。
