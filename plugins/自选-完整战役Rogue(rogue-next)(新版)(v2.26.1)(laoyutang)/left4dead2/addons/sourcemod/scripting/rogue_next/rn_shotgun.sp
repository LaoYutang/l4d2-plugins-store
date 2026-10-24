#if defined _rn_shotgun_included
 #endinput
#endif
#define _rn_shotgun_included

enum RN_ShotgunBackend { RN_SG_SWITCHING, RN_SG_DHOOKS, RN_SG_WH, RN_SG_BLOCKED }
enum struct RN_ShotgunHook
{
    int entity;
    int ref;
    int reload;
    int cycle;
}

static const int g_Shotgun_Indices[4] = {0, 1, 5, 6};
float g_Shotgun_Scales[4][2];
bool g_Shotgun_Ready;
bool g_Shotgun_Failed;
ArrayList g_Shotgun_Hooks;
DynamicHook g_Shotgun_Reload;
DynamicHook g_Shotgun_Cycle;
RN_ShotgunBackend g_Shotgun_Backend = RN_SG_SWITCHING;
int g_Shotgun_Serial;

/** 四喷仍保留原武器表索引，普通枪伤分类及其他武器顺序不变。 */
bool RN_Shotgun_Index(int index)
{
    return index == 0 || index == 1 || index == 5 || index == 6;
}

/** 将原来的目标秒数换为无单位时长比例，保留原值/动画哨兵和0.001秒下限。 */
float RN_Shotgun_Scale(int index, bool reload, float target)
{
    float raw = reload ? g_Weapons_ReloadBase[index] : g_Weapons_CycleBase[index];
    if (target == raw) return 1.0;
    float normal = RN_Weapons_NormalBase(index, reload);
    return target / normal;
}

/** 候选BUFF/配置事务同时验证四喷比例及其倒数，拒绝无法表达的WH速度。 */
bool RN_Shotgun_Validate(const float durations[sizeof(g_Weapons_ReloadBase)], const float cycles[sizeof(g_Weapons_CycleBase)])
{
    for (int kind = 0; kind < 4; kind++)
    {
        int index = g_Shotgun_Indices[kind];
        float reload = RN_Shotgun_Scale(index, true, durations[index]);
        float cycle = RN_Shotgun_Scale(index, false, cycles[index]);
        if (!RN_Math_Finite(reload) || reload <= 0.0 || !RN_Math_Finite(1.0 / reload) ||
            !RN_Math_Finite(cycle) || cycle <= 0.0 || !RN_Math_Finite(1.0 / cycle)) return false;
    }
    return true;
}

/** 只创建自身记录容器；有WH时不创建或安装实体虚函数钩子。 */
void RN_Shotgun_Init()
{
    g_Shotgun_Hooks = new ArrayList(sizeof(RN_ShotgunHook));
    g_Shotgun_Backend = RN_Shotgun_Probe();
    RN_Shotgun_Clear();
}

/** 识别已加载但没有可用库的WH，暂停/异常提供者不得触发第二条写入路径。 */
RN_ShotgunBackend RN_Shotgun_Probe()
{
    if (LibraryExists("WeaponHandling")) return RN_SG_WH;
    Handle iterator = GetPluginIterator();
    bool present;
    char title[128], file[PLATFORM_MAX_PATH];
    while (MorePlugins(iterator))
    {
        Handle plugin = ReadPlugin(iterator);
        GetPluginFilename(plugin, file, sizeof(file));
        int start = 0;
        for (int i = 0; file[i] != '\0'; i++)
            if (file[i] == '/' || file[i] == '\\') start = i + 1;
        if (StrEqual(file[start], "WeaponHandling.smx", false) ||
            (GetPluginInfo(plugin, PlInfo_Name, title, sizeof(title)) && StrEqual(title, "WeaponHandling")))
        {
            present = true;
            break;
        }
    }
    delete iterator;
    return present ? RN_SG_BLOCKED : RN_SG_DHOOKS;
}

/** 四喷只读取当前已提交全队比例；回调再次检查库状态以封住切换窗口。 */
bool RN_Shotgun_Allowed(RN_ShotgunBackend backend)
{
    return g_Shotgun_Hooks != null && g_Shotgun_Ready && g_Weapons_Captured &&
        !g_Profile_Unloading && RN_Config_Enabled() && g_Shotgun_Backend == backend &&
        LibraryExists("WeaponHandling") == (backend == RN_SG_WH);
}

/** 无WH时按专用平台gamedata构造钩子；缺失时只关闭四喷新路径并明确记录。 */
bool RN_Shotgun_EnsureHooks()
{
    if (g_Shotgun_Reload != null && g_Shotgun_Cycle != null) return true;
    if (g_Shotgun_Failed) return false;
    GameData data = new GameData("rogue_next.shotguns");
    int reload = data == null ? -1 : data.GetOffset("CTerrorWeapon::GetReloadDurationModifier");
    int cycle = data == null ? -1 : data.GetOffset("CTerrorGun::GetRateOfFire");
    delete data;
    if (reload < 0 || cycle < 0)
    {
        g_Shotgun_Failed = true;
        LogError("[rogue-next] 四喷DHooks配置缺失或平台不支持；安装gamedata/rogue_next.shotguns.txt后重载。四喷时序暂停，其他武器保持原路径。");
        return false;
    }
    g_Shotgun_Reload = new DynamicHook(reload, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity);
    g_Shotgun_Cycle = new DynamicHook(cycle, HookType_Entity, ReturnType_Float, ThisPointer_CBaseEntity);
    return true;
}

/** 唯一四喷实体分类，不借用WH枚举给非霰弹枪加成。 */
int RN_Shotgun_Kind(int weapon)
{
    int index = RN_Weapons_Index(weapon);
    for (int kind = 0; kind < 4; kind++)
        if (index == g_Shotgun_Indices[kind]) return kind;
    return -1;
}

/** 每次引擎调用都核对当前拥有者，丢枪/转交/死亡无陈旧个人倍率。 */
bool RN_Shotgun_Owner(int client, int weapon)
{
    return RN_Common_Survivor(client) && IsPlayerAlive(client) &&
        HasEntProp(weapon, Prop_Send, "m_hOwnerEntity") &&
        GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity") == client;
}

/** 只登记本插件的两枚hook ID；第二枚失败立即撤销第一枚。 */
bool RN_Shotgun_Attach(int entity)
{
    if (!RN_Shotgun_Allowed(RN_SG_DHOOKS) || RN_Shotgun_Kind(entity) < 0) return true;
    RN_ShotgunHook item;
    int ref = EntIndexToEntRef(entity);
    for (int i = 0; i < g_Shotgun_Hooks.Length; i++)
    {
        g_Shotgun_Hooks.GetArray(i, item, sizeof(item));
        if (item.ref == ref) return true;
    }
    item.entity = entity;
    item.ref = ref;
    item.reload = g_Shotgun_Reload.HookEntity(Hook_Post, entity, RN_Shotgun_OnReload);
    if (item.reload == INVALID_HOOK_ID) return false;
    item.cycle = g_Shotgun_Cycle.HookEntity(Hook_Post, entity, RN_Shotgun_OnCycle);
    if (item.cycle == INVALID_HOOK_ID)
    {
        DynamicHook.RemoveHook(item.reload);
        return false;
    }
    g_Shotgun_Hooks.PushArray(item, sizeof(item));
    return true;
}

/** 提交现有总层数公式的结果，其他武器仍由原属性路径处理。 */
void RN_Shotgun_Update(const float durations[sizeof(g_Weapons_ReloadBase)], const float cycles[sizeof(g_Weapons_CycleBase)])
{
    if (g_Shotgun_Hooks == null) return;
    bool changed;
    for (int kind = 0; kind < 4; kind++)
    {
        int index = g_Shotgun_Indices[kind];
        g_Shotgun_Scales[kind][0] = RN_Shotgun_Scale(index, true, durations[index]);
        g_Shotgun_Scales[kind][1] = RN_Shotgun_Scale(index, false, cycles[index]);
        if (g_Shotgun_Scales[kind][0] != 1.0 || g_Shotgun_Scales[kind][1] != 1.0) changed = true;
    }
    g_Shotgun_Ready = changed;
    RN_Shotgun_Poll();
    if (!g_Shotgun_Ready || g_Shotgun_Backend != RN_SG_DHOOKS)
    {
        RN_Shotgun_Detach();
        return;
    }
    for (int kind = 0; kind < 4; kind++)
    {
        char classname[64];
        RN_Weapons_Name(g_Shotgun_Indices[kind], classname, sizeof(classname));
        int entity = -1;
        while ((entity = FindEntityByClassname(entity, classname)) != -1)
        {
            // No weapon means no gamedata/setup handles need allocating yet.
            if (!RN_Shotgun_EnsureHooks()) { RN_Shotgun_Clear(); return; }
            if (!RN_Shotgun_Attach(entity))
            {
                RN_Shotgun_Clear();
                LogError("[rogue-next] 四喷实体hook失败，已撤销本插件四喷hook；下次属性刷新重试。");
                return;
            }
        }
    }
}

/** 复用主调度发现WH状态变化，不新增逐帧扫描或定时器。 */
void RN_Shotgun_Poll()
{
    if (g_Shotgun_Hooks == null || g_Profile_Unloading || g_Shotgun_Backend == RN_SG_SWITCHING) return;
    if (RN_Shotgun_Probe() != g_Shotgun_Backend) RN_Shotgun_Switch();
}

/** 切换先撤销当前贡献与自有hook，下一帧从现有档案重算，不改变BUFF账本。 */
void RN_Shotgun_Switch()
{
    RN_Shotgun_Clear();
    g_Shotgun_Backend = RN_SG_SWITCHING;
    g_Shotgun_Serial++;
    RequestFrame(RN_Shotgun_Switched, g_Shotgun_Serial);
}

/** 延后选择已稳定的提供者，旧切换任务不得恢复过期路径。 */
public void RN_Shotgun_Switched(any serial)
{
    if (g_Shotgun_Hooks == null || g_Profile_Unloading || serial != g_Shotgun_Serial) return;
    g_Shotgun_Backend = RN_Shotgun_Probe();
    LogMessage("[rogue-next] 四喷时序后端=%d（1=DHooks/2=WH/3=WH不可用），按现有BUFF重算。", g_Shotgun_Backend);
    if (g_Shotgun_Backend == RN_SG_WH)
        LogMessage("[rogue-next] WH1.0.6热加载不补挂旧武器；旧实体可能需新生成武器或正常换图后才恢复四喷时序。");
    RN_Weapons_Refresh();
}

/** WH注册后立即关闭自身路径；其他库增删不触发四喷切换。 */
public void OnLibraryAdded(const char[] name)
{
    if (g_Shotgun_Hooks != null && !g_Profile_Unloading && StrEqual(name, "WeaponHandling")) RN_Shotgun_Switch();
}

/** WH移除后先保持中性，避免卸载中的旧hook与新路径同时贡献。 */
public void OnLibraryRemoved(const char[] name)
{
    if (g_Shotgun_Hooks != null && !g_Profile_Unloading && StrEqual(name, "WeaponHandling")) RN_Shotgun_Switch();
}

/** 新实体下一帧挂钩，包中记录地图/战役/后端代次防止过期任务复用索引。 */
void RN_Shotgun_Created(int entity, const char[] classname)
{
    if (!RN_Shotgun_Allowed(RN_SG_DHOOKS)) return;
    for (int kind = 0; kind < 4; kind++)
    {
        char expected[64];
        RN_Weapons_Name(g_Shotgun_Indices[kind], expected, sizeof(expected));
        if (!StrEqual(classname, expected)) continue;
        DataPack pack = new DataPack();
        pack.WriteCell(EntIndexToEntRef(entity));
        pack.WriteCell(g_Run_MapEpoch);
        pack.WriteCell(g_Run_Epoch);
        pack.WriteCell(g_Shotgun_Serial);
        RequestFrame(RN_Shotgun_NewFrame, pack);
        return;
    }
}

/** 释放每个延迟包后再复核状态；失效实体/旧地图永不安装hook。 */
public void RN_Shotgun_NewFrame(DataPack pack)
{
    pack.Reset();
    int ref = pack.ReadCell(), map = pack.ReadCell(), run = pack.ReadCell(), serial = pack.ReadCell();
    delete pack;
    if (map != g_Run_MapEpoch || run != g_Run_Epoch || serial != g_Shotgun_Serial ||
        !RN_Shotgun_Allowed(RN_SG_DHOOKS)) return;
    int entity = EntRefToEntIndex(ref);
    if (entity == INVALID_ENT_REFERENCE || !RN_Shotgun_EnsureHooks()) return;
    if (!RN_Shotgun_Attach(entity))
    {
        RN_Shotgun_Clear();
        LogError("[rogue-next] 新四喷hook失败，已撤销本插件四喷贡献。");
    }
}

/** 销毁时底层DHooks负责移除；这里只删除对应实体记录。 */
void RN_Shotgun_Destroyed(int entity)
{
    if (g_Shotgun_Hooks == null) return;
    RN_ShotgunHook item;
    for (int i = g_Shotgun_Hooks.Length - 1; i >= 0; i--)
    {
        g_Shotgun_Hooks.GetArray(i, item, sizeof(item));
        if (item.entity == entity) g_Shotgun_Hooks.Erase(i);
    }
}

/** 独立路径只调整有效原始返回值，不写动画、弹匣或全局武器属性。 */
MRESReturn RN_Shotgun_Return(int weapon, DHookReturn result, int channel)
{
    if (!RN_Shotgun_Allowed(RN_SG_DHOOKS)) return MRES_Ignored;
    int kind = RN_Shotgun_Kind(weapon);
    if (kind < 0 || !HasEntProp(weapon, Prop_Send, "m_hOwnerEntity")) return MRES_Ignored;
    if (!RN_Shotgun_Owner(GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity"), weapon)) return MRES_Ignored;
    float scale = g_Shotgun_Scales[kind][channel];
    if (scale == 1.0) return MRES_Ignored;
    float original = view_as<float>(result.Value);
    float output = original * scale;
    if (!RN_Math_Finite(original) || original <= 0.0 || !RN_Math_Finite(output) || output <= 0.0) return MRES_Ignored;
    result.Value = view_as<int>(output);
    return MRES_Override;
}

/** 霰弹枪装填时长倍率的实体后置回调。 */
public MRESReturn RN_Shotgun_OnReload(int weapon, DHookReturn result)
{
    return RN_Shotgun_Return(weapon, result, 0);
}

/** 霰弹枪射击间隔秒数的实体后置回调。 */
public MRESReturn RN_Shotgun_OnCycle(int weapon, DHookReturn result)
{
    return RN_Shotgun_Return(weapon, result, 1);
}

/** WH速度使用时长比例的倒数，只贡献一次并保留其他消费者的倍率。 */
void RN_Shotgun_WH(int client, int weapon, float &speedmodifier, int channel)
{
    if (!RN_Shotgun_Allowed(RN_SG_WH)) return;
    int kind = RN_Shotgun_Kind(weapon);
    if (kind < 0 || !RN_Shotgun_Owner(client, weapon)) return;
    float scale = g_Shotgun_Scales[kind][channel];
    if (scale == 1.0) return;
    float output = speedmodifier / scale;
    if (!RN_Math_Finite(speedmodifier) || speedmodifier <= 0.0 || !RN_Math_Finite(output) || output <= 0.0) return;
    speedmodifier = output;
}

/** WH装填入口按实际实体分类，包含团队BOT受益且不改变层数汇总。 */
public void WH_OnReloadModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
    RN_Shotgun_WH(client, weapon, speedmodifier, 0);
}

/** WH射速入口只处理四喷，不给其他枪械旧属性路径再次乘算。 */
public void WH_OnGetRateOfFire(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
    RN_Shotgun_WH(client, weapon, speedmodifier, 1);
}

/** 仅移除自身保存且EntRef仍有效的hook ID，不删除WH或其他插件的hook。 */
void RN_Shotgun_Detach()
{
    if (g_Shotgun_Hooks == null) return;
    RN_ShotgunHook item;
    for (int i = 0; i < g_Shotgun_Hooks.Length; i++)
    {
        g_Shotgun_Hooks.GetArray(i, item, sizeof(item));
        if (EntRefToEntIndex(item.ref) == INVALID_ENT_REFERENCE) continue;
        DynamicHook.RemoveHook(item.reload);
        DynamicHook.RemoveHook(item.cycle);
    }
    g_Shotgun_Hooks.Clear();
}

/** 清理只中和未来贡献，不强制恢复WH合成的动画倍率或已排定的动作。 */
void RN_Shotgun_Clear()
{
    g_Shotgun_Ready = false;
    for (int kind = 0; kind < 4; kind++)
        for (int channel = 0; channel < 2; channel++) g_Shotgun_Scales[kind][channel] = 1.0;
    RN_Shotgun_Detach();
}

/** 卸载释放本插件持有的全部四喷句柄，库切换任务据空容器失效。 */
void RN_Shotgun_Close()
{
    RN_Shotgun_Clear();
    delete g_Shotgun_Hooks;
    delete g_Shotgun_Reload;
    delete g_Shotgun_Cycle;
}
